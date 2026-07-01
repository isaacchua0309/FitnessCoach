# Cursor Context Packet: Onboarding Flow, Profile Data, Calories, and Weight-Loss Pace

## Goal For Cursor

FitPilot currently lets a new user choose a target/goal weight during onboarding, but the onboarding UI does not clearly let the user choose how quickly they want to lose weight. The codebase already contains most of the domain model and calorie math for weight-loss pace. The next feature should expose and validate pace selection in onboarding, then ensure that chosen pace flows into generated calories/macros, saved profile targets, cloud sync, plan reveal UI, and later Plan editing.

Do not rewrite unrelated app areas. Prefer threading the existing `WeightLossPaceChoice` / `WeightLossAdvancedPaceDraft` system through onboarding UI and tests.

## Current Onboarding Flow

Primary SwiftUI entry:

- `Fitness Coach/Features/Onboarding/OnboardingView.swift`
- `Fitness Coach/Features/Onboarding/Model/OnboardingModel.swift`
- `Fitness Coach/Features/Onboarding/Model/OnboardingStep.swift`
- `Fitness Coach/Features/Onboarding/Model/OnboardingFormState.swift`

Canonical step order is in `OnboardingStep.flow`:

1. `.introProof`
2. `.heightWeight`
3. `.targetWeight`
4. `.targetEncouragement`
5. `.birthday`
6. `.activityLevel`
7. `.appleHealth`
8. `.almostThere`
9. `.formaProof`
10. `.review`
11. `.generatingPlan`
12. `.planReveal`
13. `.savePlan`

`OnboardingView` renders each step in `stepContent`. The goal weight screen is currently:

- `Fitness Coach/Features/Onboarding/UI/OnboardingTargetWeightStepView.swift`

That screen currently focuses on an absolute goal-weight ruler:

- `OnboardingTargetWeightRulerSelector`
- `OnboardingTargetWeightHeroSummary`
- `OnboardingTargetWeightGuidanceCard`
- `OnboardingTargetWeightValues`
- `OnboardingTargetWeightGuidanceBuilder`

The shared bottom navigation is handled by:

- `Fitness Coach/Features/Onboarding/UI/OnboardingStepContainer.swift`
- `Fitness Coach/Features/Onboarding/Components/OnboardingBottomBar.swift`
- `safeAreaInset(edge: .bottom)` in `OnboardingView`

Validation currently runs through `OnboardingFormState.validate(step:)` and `canAdvance(from:)`.

## Existing Onboarding Data Model

`OnboardingFormState` is the local source of truth for onboarding input state. Key fields:

- `birthDate`, `ageText`
- `sex`
- `heightCmText`
- `currentWeightKgText`
- `goalWeightKgText`
- `estimatedBodyFatPercentageText`
- `activityLevel`
- `trainingFrequencyPerWeekText`
- `averageStepsText`
- `dietPreference`
- `unitSystem`
- `selectedMotivations`
- `loggingPreferences`
- `aggressiveness`
- `weightLossPaceChoice`
- `advancedPaceDraft`

Important: pace fields already exist:

```swift
var aggressiveness: CalorieAggressiveness = .moderate
var weightLossPaceChoice: WeightLossPaceChoice = .moderate
var advancedPaceDraft: WeightLossAdvancedPaceDraft = .default
```

Useful existing helpers:

- `selectPaceChoice(_:)`
- `syncAggressivenessFromPaceChoice()`
- `isPaceApplicable()`
- `pacePreview(referenceDate:)`
- `paceDisplayLabel(result:)`
- `resolvedWeightLossPace()`
- `blocksWeightLossPaceForNonCutGoal()`

`isPaceApplicable()` returns true only when `goalWeightKg < currentWeightKg - goalDirectionEpsilonKg`. Pace should only be shown for weight-loss/cut goals, not maintain or gain.

## Existing Pace Domain Model

Files:

- `Fitness Coach/Domain/PlanCalculation/WeightLossPaceChoice.swift`
- `Fitness Coach/Domain/PlanCalculation/WeightLossPace.swift`
- `Fitness Coach/Domain/PlanCalculation/WeightLossRateCalculator.swift`
- `Fitness Coach/Domain/PlanCalculation/WeightLossPacePreviewBuilder.swift`
- `Fitness Coach/Features/Settings/UI/WeightLossPaceSettingsView.swift`

`WeightLossPaceChoice` cases:

- `.gentle`
- `.moderate`
- `.aggressive`
- `.advanced`

Preset meanings:

- Gentle: about `0.25%` of body weight per week
- Moderate: about `0.50%` of body weight per week
- Aggressive: about `0.75%` of body weight per week
- Advanced: custom weekly or monthly target

`WeightLossAdvancedPaceDraft` supports:

- `period: .weekly | .monthly`
- `amountText`

`WeightLossPaceChoiceResolver.resolvedPace(choice:advancedDraft:)` converts UI selection into `WeightLossPace`.

There is already a reusable UI in:

- `Fitness Coach/Features/Settings/UI/WeightLossPaceSettingsView.swift`

It is currently used by the Plan edit wizard, not onboarding:

- `Fitness Coach/Features/Plan/UI/PlanEditWizard.swift`

This view already renders all pace choices, advanced input, preview cards, weekly/monthly equivalents, and daily deficit preview.

## Current Plan Generation Pipeline

Onboarding generates a preview plan from `OnboardingModel.beginGeneration()`:

1. `OnboardingModel.beginGeneration()`
2. `OnboardingPlanGenerationExecutor.runGeneration(formState:)`
3. `OnboardingPlanGenerationExecutor.generatePlan(from:)`
4. `OnboardingFormState.makeCalorieTargetInput()`
5. `TargetService.generateInitialTargets(from:)`
6. `PlanCalculationBridge.calorieTargetResult(from:)`
7. `FormaCalculationEngine.calculate(_:)`

Key files:

- `Fitness Coach/Application/UseCases/Onboarding/OnboardingPlanGenerationExecutor.swift`
- `Fitness Coach/Application/Services/TargetService.swift`
- `Fitness Coach/Domain/Models/CalculationResultModels.swift`
- `Fitness Coach/Domain/PlanCalculation/PlanCalculationBridge.swift`
- `Fitness Coach/Domain/PlanCalculation/FormaCalculationEngine.swift`

Critical existing behavior:

`OnboardingFormState.makeCalorieTargetInput()` already passes pace into the calculation:

```swift
let pace = try resolvedWeightLossPace()
return CalorieTargetInput(
    ...
    aggressiveness: weightLossPaceChoice.legacyAggressiveness,
    weightLossPace: pace
)
```

`PlanCalculationBridge.planInput(from:)` maps `CalorieTargetInput.weightLossPace` to `PlanCalculationInput.weightLossPace`; if missing, it falls back to legacy `aggressiveness`.

Therefore the calorie calculation pipeline already supports pace. The feature gap is mostly onboarding UX exposure and validation.

## How Calories Are Calculated

Main engine:

- `Fitness Coach/Domain/PlanCalculation/FormaCalculationEngine.swift`

Input:

- `PlanCalculationInput`

Calculation sequence:

1. Validate anthropometrics and pace using `PlanCalculationInput.validate()`.
2. Calculate BMR with Mifflin-St Jeor in `EnergyCalculator.bmrKcal`.
3. Calculate TDEE in `EnergyCalculator.energyBreakdown`:
   - BMR multiplied by activity multiplier
   - plus step bonus
   - plus training frequency bonus
4. Determine goal direction from `goalWeightKg - weightKg`:
   - cut if below current weight
   - maintain if near current weight
   - gain if above current weight
5. For cuts, derive requested weekly loss from `WeightLossRateCalculator.paceBreakdown(input:)`.
6. Convert weekly kg loss to daily deficit:

```swift
dailyDeficit = (weeklyLossKg * FormaCalculationConstants.kcalPerKgFat) / 7.0
```

7. Apply calorie target in `EnergyCalculator.calorieTargetBreakdown`:
   - maintain: target = TDEE
   - gain: target = TDEE for now; surplus not implemented
   - cut: target = max(TDEE - requested deficit, calorie floor)
8. Calculate macros in `PlanMacroCalculator.macroBreakdown`.
9. Calculate water target in `WaterCalculator.targetMl`.
10. Validate warnings/safety in `PlanSafetyValidator`.
11. Return `PlanCalculationResult`, then bridge to `CalorieTargetResult`.

`CalorieTargetResult.targets` is a `UserTargets`:

- `calorieTarget`
- `proteinTarget`
- `carbTarget`
- `fatTarget`
- `waterTargetMl`
- `expectedWeeklyWeightLossKg`
- `aggressiveness`

Important limitation: `UserTargets` currently persists only `expectedWeeklyWeightLossKg` and legacy `aggressiveness`; it does not persist the exact pace choice or advanced period. The exact advanced monthly-vs-weekly choice can be inferred imperfectly only from expected weekly loss.

## Profile Creation And Persistence

Onboarding profile save:

1. `OnboardingModel.completeOnboarding()` / save flow
2. `OnboardingProfileCommitter.commitIfNeeded(formState:generatedPlan:)`
3. `OnboardingFormState.makeUserProfileDraft(targets:)`
4. `FitnessActionCenter.createProfile`
5. `UserProfileService.createProfile`
6. `UserProfileEntity(model:)`
7. SwiftData storage

Key files:

- `Fitness Coach/Application/UseCases/Onboarding/OnboardingProfileCommitter.swift`
- `Fitness Coach/Data/DTOs/UserProfileDraft.swift`
- `Fitness Coach/Domain/Models/UserProfile.swift`
- `Fitness Coach/Data/Repositories/UserProfileService.swift`
- `Fitness Coach/Infrastructure/Persistence/SwiftData/Entities/UserProfileEntity.swift`
- `Fitness Coach/Infrastructure/Persistence/SwiftData/Mapping/UserProfileEntity+Mapping.swift`

Persisted profile stores:

- baseline body fields
- activity fields
- preferences
- flattened `UserTargets`

SwiftData entity stores:

- `calorieTarget`
- `proteinTarget`
- `carbTarget`
- `fatTarget`
- `waterTargetMl`
- `expectedWeeklyWeightLossKg`
- `aggressivenessRawValue`

Cloud profile sync:

- `Fitness Coach/Infrastructure/Cloud/CloudUserProfileDocument.swift`

Cloud stores the same target fields:

- `expectedWeeklyWeightLossKg`
- `aggressiveness`

Again, exact pace choice is not separately stored in the committed user profile today.

## Onboarding Draft Persistence

Onboarding autosaves local drafts to UserDefaults:

- `Fitness Coach/Data/DTOs/Onboarding/OnboardingDraft.swift`
- `Fitness Coach/Data/DTOs/Onboarding/OnboardingDraftStore.swift`
- `Fitness Coach/Domain/Onboarding/OnboardingDraftMigration.swift`

Good news: draft persistence already includes pace fields:

- `weightLossPaceChoiceRawValue`
- `advancedPacePeriodRawValue`
- `advancedPaceAmountText`

`OnboardingDraftFormFields.makeFormState()` restores them and calls:

```swift
state.syncAggressivenessFromPaceChoice()
```

Migration from v1 also attempts to restore or infer pace. So onboarding draft persistence is already prepared for the feature.

## Runtime Daily Calories And User Data Consumption

Daily nutrition/calorie state comes from the saved profile targets copied into each `DailyLog`.

Key files:

- `Fitness Coach/Domain/Models/DailyLog.swift`
- `Fitness Coach/Domain/Models/UserTargets.swift`
- `Fitness Coach/Application/StateBuilders/Nutrition/DailyNutritionSummaryBuilder.swift`
- `Fitness Coach/Application/StateBuilders/Today/TodayDashboardNutritionMapper.swift`
- `Fitness Coach/Domain/Nutrition/MacroCalculator.swift`
- `Fitness Coach/Data/Repositories/DailyLogService.swift`

Runtime flow:

1. User profile stores current `UserTargets`.
2. Daily log stores its own `targets: UserTargets`.
3. Food entries are summed into `MacroTotals`.
4. `DailyNutritionSummaryBuilder.build(from:)` maps log targets and totals to:
   - consumed calories
   - target calories
   - remaining calories
   - macro progress
   - water progress
5. Today, Coach, reviews, journey, and AI context consume this canonical summary.

Adding onboarding pace affects runtime calories indirectly by changing the generated `UserTargets.calorieTarget`, macro targets, and `expectedWeeklyWeightLossKg` at profile creation time.

## Current Gap

The app already has:

- pace model
- pace preview builder
- plan edit pace UI
- onboarding form state pace fields
- draft persistence for pace
- calorie engine support for pace

The app is missing:

- a polished onboarding UI for choosing weight-loss speed
- onboarding validation/error handling for invalid advanced pace
- plan reveal/review copy that clearly reflects selected pace
- tests proving different onboarding pace choices produce different targets

## Recommended Product Behavior

When target weight is below current weight:

- Show pace selection after or within the target weight step.
- Default to Moderate.
- Let user choose Gentle, Moderate, Aggressive, or Advanced.
- For Advanced, allow weekly or monthly kg input.
- Show a preview:
  - weekly loss
  - monthly equivalent
  - approximate daily deficit
  - safety/warning text
- Continue should be disabled or inline-error if advanced amount is blank/invalid/unsafe.

When target weight is equal to or above current weight:

- Hide pace selection.
- Do not block Continue due to pace.
- Reset or ignore advanced custom input for calculation.
- Use `.moderate` fallback for legacy compatibility, but calculation should treat maintain/gain as no deficit.

## Recommended Implementation Approach

Prefer reusing `WeightLossPaceSettingsView` rather than inventing a second pace selector. Options:

1. Extract a more design-system-neutral component from `WeightLossPaceSettingsView`.
2. Or wrap `WeightLossPaceSettingsView` inside an onboarding-styled card/shell.
3. If the settings styling clashes with onboarding, create `OnboardingWeightLossPaceStepView` but reuse:
   - `WeightLossPaceChoice`
   - `WeightLossAdvancedPaceDraft`
   - `WeightLossPacePreviewBuilder`
   - `WeightLossPaceChoiceResolver`

Preferred flow change:

- Add a new onboarding step after `.targetWeight` and before `.targetEncouragement`, e.g. `.weightLossPace`.
- Dynamically skip it when `formState.isPaceApplicable() == false`.

Alternative:

- Add pace selection into `OnboardingTargetWeightStepView` below the ruler. This is faster, but the target weight screen already uses a compact fixed viewport and may get crowded on small phones.

Safer architecture:

- Add a dedicated `.weightLossPace` step because advanced input needs space and keyboard handling.

Files likely to change:

- `Fitness Coach/Features/Onboarding/Model/OnboardingStep.swift`
- `Fitness Coach/Features/Onboarding/OnboardingView.swift`
- `Fitness Coach/Features/Onboarding/Model/OnboardingFormState.swift`
- `Fitness Coach/Features/Onboarding/Model/OnboardingModel.swift`
- `Fitness Coach/Domain/Onboarding/OnboardingInteractionPolicy.swift`
- `Fitness Coach/Domain/Onboarding/OnboardingDraftStepResolver.swift`
- `Fitness Coach/Features/Onboarding/UI/OnboardingWeightLossPaceStepView.swift` new file
- `Fitness Coach/Features/Onboarding/Formatting/OnboardingPersonalizationSummaryBuilder.swift`
- `Fitness Coach/Domain/Onboarding/OnboardingPlanRevealBuilder.swift`
- tests around calculation/onboarding if present

Need to inspect navigation helpers before editing:

- `nextStep(after:)`
- `backTarget(for:)`
- `advance(to:)`
- any custom step skipping in `OnboardingModel`
- `OnboardingDraftStepResolver`
- `OnboardingInteractionPolicy`

## Validation Requirements

Add `OnboardingFormState.validate(step:)` handling for the new pace step.

Suggested validation:

- If `!formState.isPaceApplicable()`, pass.
- If pace choice is preset, pass.
- If pace choice is `.advanced`, call `resolvedWeightLossPace()` and map `PlanCalculationError.invalidInput` into `OnboardingFormError.invalid`.
- Consider using `WeightLossPacePreviewBuilder` validation result for inline UX.

Also ensure:

- Changing target weight from cut to maintain/gain does not leave onboarding stuck on a pace step.
- Advanced pace input uses keyboard-safe layout.
- Bottom bar remains visible via existing `safeAreaInset`.

## Persistence Design Decision

For the immediate feature, it may be acceptable to keep committed `UserProfile` persistence unchanged because generated targets already include:

- calorie target
- macros
- water
- expected weekly loss
- legacy aggressiveness

However, if the product needs exact user-selected pace to appear later, add explicit fields to profile/target persistence:

- `weightLossPaceChoiceRawValue`
- `advancedPacePeriodRawValue`
- `advancedPaceAmount`

This requires SwiftData entity changes, cloud DTO changes, migration/defaults, and profile mapping. Do not do this unless the next feature explicitly requires exact recovery of the selected pace. Current Plan edit code can infer advanced pace from `expectedWeeklyWeightLossKg`, but not exact monthly-vs-weekly intent.

## Cursor Workflow Prompt

Use this prompt in Cursor:

```text
You are working in the FitPilot iOS app. Add weight-loss speed selection to the onboarding flow.

Context:
- Onboarding is driven by OnboardingView, OnboardingModel, OnboardingStep, and OnboardingFormState.
- OnboardingFormState already contains weightLossPaceChoice and advancedPaceDraft.
- makeCalorieTargetInput() already resolves weightLossPace and passes it into CalorieTargetInput.
- The calculation engine already supports WeightLossPace through PlanCalculationBridge and FormaCalculationEngine.
- WeightLossPaceSettingsView already exists and is used by PlanEditWizard.

Goal:
Expose pace selection during onboarding for users whose goal weight is lower than current weight. This pace must affect generated calories/macros through the existing calculation pipeline.

Implementation:
1. Add a dedicated onboarding pace step after targetWeight and before targetEncouragement, or justify an inline approach if smaller.
2. Show this step only for cut goals where formState.isPaceApplicable() is true.
3. Reuse WeightLossPaceChoice, WeightLossAdvancedPaceDraft, WeightLossPacePreviewBuilder, and WeightLossPaceChoiceResolver.
4. Prefer reusing or adapting WeightLossPaceSettingsView.
5. Add onboarding-styled UI with dark theme, card styling, safe keyboard behavior, and bottom bar compatibility.
6. Add validation for advanced pace input. Continue should not proceed with invalid advanced pace.
7. Ensure changing goal weight from loss to maintain/gain skips or ignores pace cleanly.
8. Update review / generated plan reveal copy so selected pace and expected weekly loss are visible.
9. Preserve existing profile creation, target generation, SwiftData persistence, cloud sync, and daily log behavior unless explicit persistence of exact pace is needed.
10. Add focused tests/previews proving gentle/moderate/aggressive/advanced choices produce different generated calorie targets for a cut goal.

Do not change unrelated app areas, networking, API keys, Coach pipeline, or Firebase backend.
```

## Acceptance Checklist

- A cut-goal onboarding user can choose Gentle, Moderate, Aggressive, or Advanced pace.
- Maintain/gain users do not see a confusing weight-loss speed step.
- Advanced pace requires a valid numeric amount.
- The selected pace changes `CalorieTargetResult.targets.calorieTarget`.
- `UserTargets.expectedWeeklyWeightLossKg` reflects the applied post-safety/floor weekly loss.
- Bottom CTA remains visible with keyboard open.
- Draft restore preserves selected pace and advanced input.
- Profile creation still succeeds.
- Today dashboard still reads calories from saved `UserTargets`.
- Existing Plan edit wizard still works.
- Build/tests pass.
