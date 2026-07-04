# Coach Accuracy + Trust Hardening v1 — Implementation Plan

**Status:** Sprint prep (planning only — no behavior changes on `main`)  
**Baseline audited:** `main` @ `4f1e381` (2026-07-04)  
**Related docs:** `COACH_ACCURACY_TRUST_CONTEXT_PACKET.md`, `COACH_ACCURACY_HARDENING_IMPLEMENTATION.md`, `Docs/CoachNutritionEstimateCards.md`

---

## Sprint goal

Make Coach food estimates **honest about uncertainty** (calorie ranges, explicit assumptions, confidence) and **safer to confirm** (sanity-aware gating, correction-aware context, benchmark coverage) **without**:

- AB-gating the sprint
- Removing existing Coach flows
- Weakening confirmation safety or auto-logging food
- Introducing broad Coach navigation or proactive nudges
- Requiring SwiftData schema migrations (additive DTO/context fields only)

Scalar `totalCalories` / `FoodEntry.calories` remain the authoritative log values. Ranges and trust metadata **enhance** the primary log path.

---

## 1. Current primary food log path (text)

```
CoachView / CoachComposer
  → CoachModel.send(_:) / sendCurrentMessage()
  → CoachContextPacketV2Builder.makeContext()          [read path]
  → CoachRouteDecider.decide()
      1. LocalNoAPIGuard (greeting, local water/weight, local catalog food)
      2. CheapLLMIntentClassifier → AIService.classifyCoachIntent
      3. CoachIntentPhraseGuard.applyGuards
      4. CoachIntentConfidenceGate.evaluate (0.70 / 0.45 thresholds)
      5. CoachIntentRouter → .ai(RoutedAITask(.estimateFood, tier: .cheap))
  → CoachAIRouteHandler.handleAITask(.estimateFood)
  → AIService.estimateFood()
      → FormaAIBackendClient POST /v1/ai/estimate-food
      → FoodEstimateResponseValidator.validate (client)
      → optional client repair retry
  → Backend estimateFood (functions/src/index.ts)
      → foodEstimateInstructions() (coachPromptInstructions.ts)
      → OpenAI structured extraction (aiFoodExtractionResponseSchema)
      → normalizeFoodExtraction + validateFoodExtraction (foodEstimateExtraction.ts)
      → mapExtractionToGatewayPayload → foodLogDrafts[]
  → CoachAIRouteHandler.presentEstimateFoodResponse
      → FoodLogDraftMapper.primaryMeal
      → optional classifier FoodDraft merge
  → presentAIFoodEstimate
      → FoodLogDraftNutritionCompleter.sanitize
      → NutritionSanityValidator.validate (downgrade only — does NOT block confirm)
      → ConfirmationPolicy.decision → always requiresConfirmation for AI food
  → CoachPendingConfirmationPresenter.presentFoodPending
      → AIFoodConfirmationDraft + chat copy (CoachResponseBuilder / CoachPendingCopyFormatter)
  → CoachConfirmationBar (inline) + optional AIFoodConfirmationSheet (edit)
  → CoachModel.confirmPendingFromBar / typed confirm
  → CoachMutationExecutor.executeLogFood → FitnessActionCenter → FoodLogService → SwiftData
  → CoachTimelineRecorder.recordFoodLogged (userEditedBeforeConfirm, sourceAttribution)
```

**Local catalog bypass:** `CoachRoute.localFoodEstimate` → `handleLocalFoodEstimate` → same pending-confirmation path (no gateway).

**Key files:** `CoachModel.swift`, `CoachRouteDecider.swift`, `CoachAIRouteHandler.swift`, `AIService.swift`, `FoodEstimateResponseValidator.swift`, `NutritionSanityValidator.swift`, `ConfirmationPolicy.swift`, `AIResponseValidator.swift`, `CoachPendingConfirmationPresenter.swift`, `CoachMutationExecutor.swift`, `functions/src/foodEstimateExtraction.ts`.

---

## 2. Current photo food path

```
CoachImagePickFlowController / CoachModel.sendMealPhoto
  → CoachImagePipeline.process (JPEG ≤500KB)
  → ImageAnalysisSession created
  → CoachMealPhotoAnalyzer.analyze
  → CoachAIRouteHandler.analyzeMealPhoto (NOT estimateFood+image in production UI)
  → CoachMealImageAIRequestBuilder → AIMealImageAnalysisRequest
  → AIService.analyzeMealImage
      → FormaAIBackendClient POST /v1/ai/analyze-meal-image
      → MealImageAnalysisResponseValidator.validate
  → Backend analyzeMealImage (functions/src/index.ts)
      → mealImageAnalysisInstructions() + schema (mealImageAnalysis.ts)
      → needsUserReview: true (always)
  → MealImageAnalysisMapper.foodLogDraft
      → per-item assumptions → FoodComponent.sourceText
      → warnings for needsUserReview / clarifyingQuestion
  → NutritionSanityValidator.validate
  → presentAIFoodEstimate(fromPhotoAnalysis: true)
  → same CoachConfirmationBar + AIFoodConfirmationSheet + confirm → log path
```

**Clarification / recommission:** `ImageAnalysisSession` → user answer → `submitImageAnalysisClarification` → `ImageAnalysisRecommissionContext` with `MealImageAnalysisMapper.previousAnalysis` resent to gateway.

**Retry:** `CoachModel.retryMealPhotoAnalysis` when `confirmation.supportsPhotoRetry` (low confidence + linked photo message).

**Note:** `AIService.estimateFood(imageJPEGData:)` and backend `estimateFood` with `imageJPEGBase64` exist but production photo UI uses the dedicated `analyzeMealImage` endpoint only.

**Key files:** `CoachMealPhotoAnalyzer.swift`, `MealImageAnalysisMapper.swift`, `MealImageAnalysisResponseValidator.swift`, `ImageAnalysisSession.swift`, `functions/src/mealImageAnalysis.ts`.

---

## 3. Current estimate-only card path (no auto-log)

```
Classifier intents: nutritionEstimateQuery, calorieLookup, macroLookup, mealDecision
  → CoachIntentRouter → .ai(.nutritionEstimate)
  → CoachAIRouteHandler.presentNutritionEstimate
  → AIService.generateNutritionEstimate
  → Backend generate-nutrition-estimate (nutritionEstimateInstructions)
  → NutritionEstimateResponseParser.parseEstimate
  → NutritionEstimateCardFormatter.cardState
  → CoachActionResult.structured(.nutritionEstimate)
  → NutritionEstimateCard in chat (advice-only)
```

**“Log Meal” chip:** `CoachModel.handleNutritionEstimateAction(.logMeal)` → `NutritionSuggestedActionHandler.mealDraft` → scalar-only `FoodLogDraft` (no sanity/trust gate, no ranges) → pending confirmation.

**Comparison path:** `generateNutritionComparison` → `NutritionComparisonCard` (same range-capable transport models).

**Key files:** `NutritionEstimateCard.swift`, `NutritionEstimateCardFormatter.swift`, `NutritionSuggestedActionHandler.swift`, `NutritionEstimateResponseParser.swift`, `functions/src/coachPromptInstructions.ts`, `functions/src/nutritionResponseSanitizer.ts`.

---

## 4. Current correction / recommission path

| Flow | Entry | Behavior |
|------|-------|----------|
| **Edit before confirm** | `AIFoodConfirmationSheet` / `FoodLogEditFormState` | User edits scalar macros; `CoachModel.saveFoodEdit` sets `userEditedPendingBeforeConfirm` |
| **Photo clarification** | `submitImageAnalysisClarification` | Re-sends image + `previousAnalysis` to `analyzeMealImage` |
| **Photo retry** | `retryMealPhotoAnalysis` | Same image, `isRetry: true` |
| **Post-log edit** | `parseEditOrDelete` → `CoachEntryReferenceResolver` | `CoachMutationExecutor.applyFoodEdit`, `source: .corrected`, timeline `foodEdited` |
| **Post-log delete** | same | `recordFoodDeleted` with supersede link |
| **Undo** | local / `CoachMutationHistory` | Deletes last entry; weight undo not supported |

**Correction memory today:** Timeline records `userEditedBeforeConfirm` on `FoodLoggedPayload` and `foodEdited` events, but **no dedicated correction store** is sent back to the LLM beyond generic timeline summaries and `CoachContextFoodMemoryBuilder` recent meals.

---

## 5. Where scalar calories are currently displayed

| Surface | File | Source |
|---------|------|--------|
| Pending bar summary | `CoachPendingConfirmation.summaryLine` | `meal.totalCalories` |
| Pending bar compact | `CoachPendingConfirmation.compactDetailLine` | `~\(meal.totalCalories) kcal` |
| Pending chat message | `CoachPendingCopyFormatter.chatNutritionLine` | `mealDraft.totalCalories` |
| Edit sheet | `FoodLogEditFormState` / `AIFoodConfirmationSheet` | `totalCaloriesText` from `meal.totalCalories` |
| Estimate card hero | `NutritionEstimateCard` | `state.caloriesDisplay` — formatter **prefers** `caloriesKcal` scalar before range |
| Comparison card | `NutritionComparisonCard` | pre-formatted calorie strings |
| Timeline payloads | `CoachModelTimelineSupport` | `meal.totalCalories` |
| Photo recommission copy | `ImageAnalysisSession` | `result.mealDraft.totalCalories` |
| Logged Today UI | `FoodEntry.calories` | persisted scalar |

---

## 6. Where confidence is currently available

| Layer | Location | Surfaced in UI? |
|-------|----------|-----------------|
| Draft model | `FoodLogDraft.confidence`, `FoodComponent.confidence` | Bar label via `AIFoodConfirmationFormatter.confidenceLabel` |
| API transport | `AIFoodEstimateResponse.confidence`, `AIMealImageAnalysisItem.confidence` | Mapped to draft |
| Pending draft | `AIFoodConfirmationDraft.confidence` | Bar + `FormaEstimateContextBanner` in edit sheet |
| Sanity | `NutritionSanityValidator` | Downgrades to `.low`, adds warnings — **does not block** |
| Classifier | `CoachIntentResult.confidence` | Routing only (`CoachIntentConfidenceGate`) |
| Estimate card | `confidenceLevel`, `confidenceLabel`, `confidenceReason` | `NutritionEstimateCard.confidenceSection` |
| Context | `CoachContextFoodMemoryBuilder.macroConfidence`, timeline event confidence | Prompt-only |
| Observability | `CoachAccuracyObservability` (partial) | Production logs — route/context/mutation |

---

## 7. Where assumptions are currently available

| Layer | Location | Surfaced in UI? |
|-------|----------|-----------------|
| Backend text extraction | `FoodExtractionMeal.assumptions[]` | Mapped into `warnings` as `"Assumption: …"` only |
| Backend photo | `MealImageAnalysisItem.assumptions[]` | Joined into `FoodComponent.sourceText` |
| Draft model | **No first-class `assumptions` on `FoodLogDraft`** | — |
| Component | `FoodComponent.sourceText` | `AIFoodConfirmationFormatter.assumptionLines` in bar (component-level only) |
| Validators | `FoodEstimateResponseValidator`, `validateFoodExtraction` | Require assumptions text in warnings for ambiguous prompts |
| Estimate card | `NutritionEstimateResponse.caveats[]` | Caveats section (not structured assumptions) |
| Context packet | `CoachContextPacketV2.assumptions` | Prompt-only (`CoachAssumptionContext`) |
| Edit sheet | `AIFoodConfirmationSheet` | Shows assistant/notes banner — **not** assumption list |

---

## 8. Where ranges already exist but are not wired

| Location | Fields | Wired to log-path UI? |
|----------|--------|----------------------|
| `NutritionEstimateResponse` | `caloriesRangeLowerKcal`, `caloriesRangeUpperKcal` | Estimate/comparison cards only (fallback when scalar nil) |
| `NutritionComparisonItem` | same | Comparison card formatter |
| `NutritionEstimateCardFormatter` | `caloriesDisplay(for:)` | **Yes** for advice cards |
| `FoodLogDraft` | **none on `main`** | Pending bar uses scalar `totalCalories` |
| `functions/foodEstimateExtraction.ts` | **none on `main`** | Gateway returns scalar totals only |
| `mealImageAnalysis.ts` schema | **no range fields** | Photo path has no server-side ranges |
| `NutritionSuggestedActionHandler.mealDraft` | scalar `caloriesKcal` from card payload | Log-from-card path has no ranges |
| `FoodEntry` persistence | single `calories` int | Expected — ranges are pre-log metadata only |

---

## 9. Exact files to change

### iOS — models & domain

| File | Change |
|------|--------|
| `Fitness Coach/Data/DTOs/FoodLogDraft.swift` | Add optional `assumptions`, `caloriesRangeLower`, `caloriesRangeUpper`; backward-compatible `Codable` |
| `Fitness Coach/Data/DTOs/FoodLogDraftNutritionCompleter.swift` | Fill missing ranges after sanitize |
| `Fitness Coach/Domain/Nutrition/FoodCalorieRangeResolver.swift` | **New** — resolve explicit or confidence-derived ranges |
| `Fitness Coach/Domain/Nutrition/FoodEstimateTrustPolicy.swift` | **New** — sanity-failed confirm gate (edit required) |
| `Fitness Coach/Domain/Nutrition/NutritionSanityValidator.swift` | Keep downgrade behavior; wire to trust policy (no silent swallow) |

### iOS — pipeline & presentation

| File | Change |
|------|--------|
| `Fitness Coach/Application/UseCases/Coach/CoachAIRouteHandler.swift` | Pass trust gate results into pending presenter |
| `Fitness Coach/Application/UseCases/Coach/CoachPendingConfirmationPresenter.swift` | Set `requiresEditBeforeConfirm`, block typed confirm |
| `Fitness Coach/Application/UseCases/Coach/MealImageAnalysisMapper.swift` | Populate `assumptions` + derived ranges |
| `Fitness Coach/Application/UseCases/Coach/NutritionSuggestedActionHandler.swift` | Carry ranges from estimate card payload when logging |
| `Fitness Coach/Features/Coach/Formatting/AIFoodConfirmationDraft.swift` | Trust metadata fields |
| `Fitness Coach/Features/Coach/Formatting/AIFoodConfirmationFormatter.swift` | `caloriesDisplay`, explicit assumption section |
| `Fitness Coach/Features/Coach/Formatting/CoachPendingCopyFormatter.swift` | Use range-aware calorie line in chat copy |
| `Fitness Coach/Features/Coach/Model/CoachPendingConfirmation.swift` | Range display in summary/compact; confirm-blocked state |
| `Fitness Coach/Features/Coach/Model/CoachModel.swift` | Block `confirmPendingFromBar` when trust gate active; clear gate on edit |
| `Fitness Coach/Features/Coach/Components/CoachConfirmationBar.swift` | Disable Log when blocked |
| `Fitness Coach/Features/Coach/Components/AIFoodConfirmationSheet.swift` | Show assumptions + range context (read-only section) |
| `Fitness Coach/Features/Coach/Components/NutritionEstimateCard.swift` | Prefer range display when scalar absent or caveats imply uncertainty |
| `Fitness Coach/Infrastructure/AI/FoodEstimateResponseValidator.swift` | Validate `assumptions[]` field, not only warnings prefix |

### iOS — context & observability

| File | Change |
|------|--------|
| `Fitness Coach/Application/StateBuilders/Coach/CoachCorrectionMemoryBuilder.swift` | **New** — timeline-backed correction assumptions |
| `Fitness Coach/Application/StateBuilders/Coach/CoachContextPacketV2Builder.swift` | Append correction assumptions |
| `Fitness Coach/Infrastructure/Diagnostics/CoachAccuracyObservability.swift` | `food_estimate_trust` event fields |

### Firebase functions

| File | Change |
|------|--------|
| `functions/src/foodCalorieRange.ts` | **New** — derive/resolve calorie ranges |
| `functions/src/foodEstimateExtraction.ts` | Map `assumptions` + `caloriesRangeLower/Upper` on `foodLogDrafts` |
| `functions/src/mealImageAnalysis.ts` | Optional: add meal-level range on `total` (or document client-only derivation) |
| `functions/src/coachPromptInstructions.ts` | Require ranges + assumptions in extraction prompts |
| `functions/src/nutritionResponseSanitizer.ts` | Pass through range fields on estimate card responses; sanitize `logMeal` payload keys |
| `functions/src/index.ts` | Schema updates if meal-image ranges added |

### Tests

| File | Change |
|------|--------|
| `Fitness CoachTests/FoodCalorieRangeResolverTests.swift` | **New** |
| `Fitness CoachTests/FoodEstimateTrustPolicyTests.swift` | **New** |
| `Fitness CoachTests/AIFoodConfirmationFormatterTrustTests.swift` | **New** |
| `Fitness CoachTests/CoachCorrectionMemoryBuilderTests.swift` | **New** |
| `Fitness CoachTests/CoachAccuracyBenchmarkTests.swift` | **New** — Singapore fixture pass-rate harness |
| `Fitness CoachTests/CoachPendingCopyTests.swift` | Range-aware chat copy |
| `Fitness CoachTests/CoachFoodLoggingRegressionTests.swift` | Trust gate + range display |
| `Fitness CoachTests/FoodLogDraftTests.swift` | Decode new optional fields |
| `Fitness CoachTests/CoachAccuracyObservabilityTests.swift` | Trust snapshot fields |
| `Fitness CoachTests/TestingSupport/SingaporeFoodEstimationFixtureSupport.swift` | Assumptions + range validation |
| `functions/test/foodCalorieRange.test.ts` | **New** |
| `functions/test/foodEstimateExtraction.test.ts` | Range + assumptions mapping |
| `functions/test/mealImageAnalysis.test.ts` | If schema extended |
| `functions/test/nutritionResponseSanitizer.test.ts` | Range payload passthrough |

---

## 10. Proposed additive data model

### `FoodLogDraft` (DTO — no SwiftData migration)

```swift
// Additive fields — all optional for backward-compatible decoding
var assumptions: [String] = []
var caloriesRangeLower: Int? = nil
var caloriesRangeUpper: Int? = nil

// Unchanged authoritative scalar
var totalCalories: Int { components.reduce(0) { $0 + $1.calories } }
```

### `AIFoodConfirmationDraft` (pending UI state)

```swift
var sanityFailed: Bool = false
var requiresEditBeforeConfirm: Bool = false
// existing: sanityWarning, confidence, mealDraft
```

### `CoachFoodEstimateTrustObservabilitySnapshot` (diagnostics)

```swift
confidenceBucket: String      // low | medium | high
sanityFailed: Bool
hasCalorieRange: Bool
assumptionCount: Int
requiresEditBeforeConfirm: Bool
```

### Gateway `foodLogDrafts[]` payload (additive JSON keys)

```json
{
  "assumptions": ["Medium plate", "Includes chili sauce"],
  "caloriesRangeLower": 450,
  "caloriesRangeUpper": 750,
  "warnings": ["..."],
  "components": [ ... ],
  "confidence": "medium"
}
```

### Context correction memory (no new SwiftData entity)

```swift
CoachAssumptionContext(
  key: "correction.<entryId>",
  detail: "User edited an AI estimate before logging · Chicken rice · 680 kcal",
  confidence: .medium
)
```

Sourced from `CoachTimelineEvent` payloads: `foodEdited`, `foodLogged` where `userEditedBeforeConfirm == true`.

---

## 11. Backend schema changes needed

### Text `estimate-food` (required)

| Area | Change |
|------|--------|
| `foodExtractionTotalsSchema` | Optional `calories_range_lower`, `calories_range_upper` (nullable integers) |
| `mapExtractionToGatewayPayload` | Emit `caloriesRangeLower`, `caloriesRangeUpper`, `assumptions` on each `foodLogDraft` |
| `normalizeFoodExtraction` | Derive ranges when model omits them (`foodCalorieRange.ts`) |
| `foodEstimateInstructions` | Explicitly require ranges + assumptions for ambiguous/compound meals |

### Photo `analyze-meal-image` (recommended v1.1 or optional v1)

| Area | Change |
|------|--------|
| `MealImageAnalysisTotals` | Optional `caloriesRangeLower`, `caloriesRangeUpper` |
| Prompt rules | Ask model for meal-level range when portion ambiguous |
| **Alternative (v1 minimal):** | Keep schema unchanged; derive ranges client-side via `FoodCalorieRangeResolver` |

### Estimate cards (low risk)

| Area | Change |
|------|--------|
| `nutritionResponseSanitizer` | Do not strip `caloriesRangeLowerKcal` / `UpperKcal` from estimate responses |
| `logMeal` suggested-action payload | Include optional `caloriesRangeLowerKcal`, `caloriesRangeUpperKcal` keys |

---

## 12. UI components to update

| Component | v1 change |
|-----------|-----------|
| `CoachConfirmationBar` | Show `450–750 kcal`; disable Log when `requiresEditBeforeConfirm`; keep Edit/Discard |
| `CoachPendingConfirmation` | Range-aware `summaryLine` / `compactDetailLine`; assumptions section header |
| `AIFoodConfirmationSheet` | Read-only assumptions list; show range above scalar edit fields |
| `CoachPendingCopyFormatter` | Chat pending message uses same `caloriesDisplay` helper as bar |
| `NutritionEstimateCard` | When `caloriesKcal` nil and range present, show range in hero (already supported by formatter — verify wiring) |
| `NutritionComparisonCard` | No change required if formatter already handles ranges |
| `FormaEstimateContextBanner` | Optional: surface sanity + assumption count badge |

**Explicitly out of scope for v1 UI:** Today tab redesign, Journey nudges, new Coach navigation, estimate-card layout rewrite.

---

## 13. Tests to add or update

### iOS unit tests (new)

- `FoodCalorieRangeResolverTests` — explicit vs derived ranges, backward-compatible decode
- `FoodEstimateTrustPolicyTests` — sanity fail blocks confirm; edit clears block
- `AIFoodConfirmationFormatterTrustTests` — range display strings, assumption lines
- `CoachCorrectionMemoryBuilderTests` — timeline event → context assumptions
- `CoachAccuracyBenchmarkTests` — run `singapore_food_estimation_cases.json` (≥50 cases, ≥95% pass rate)

### iOS unit tests (update)

- `CoachPendingCopyTests` — chat copy shows ranges
- `CoachFoodLoggingRegressionTests` — confirm blocked on underestimated bowl until edit
- `CoachPendingConfirmationFormattingTests` — assumptions section in summary
- `FoodLogDraftTests` — decode new fields; scalar totals unchanged
- `NutritionSuggestedActionHandlerTests` — log-from-card carries ranges when present
- `CoachAccuracyObservabilityTests` — `food_estimate_trust` fields

### iOS integration / regression (existing suites to run)

- `CoachFoodLoggingRegressionTests`
- `SingaporeFoodEstimationFixtureTests`
- `CoachMealPhotoAnalysisTests`
- `CoachPendingFoodCardLayoutRegressionTests`
- `FoodLoggingGoldenTests` / `NutritionSanityValidatorTests`

### Firebase Jest (new / update)

- `foodCalorieRange.test.ts` — margin by confidence, explicit override
- `foodEstimateExtraction.test.ts` — gateway payload includes ranges + assumptions
- `singaporeFoodEstimationFixture.test.ts` — reference extraction still validates
- `nutritionResponseSanitizer.test.ts` — range keys preserved in estimate responses

### Manual QA (from `COACH_ACCURACY_HARDENING_QA.md`)

- Pending bar shows range + assumptions for chicken rice / nasi lemak
- Sanity-failed estimate requires Edit before Log
- Photo recommission adjusts components; assumptions visible
- Estimate card “Log Meal” still requires confirmation; no auto-log

---

## 14. Risks and rollback notes

| Risk | Mitigation | Rollback |
|------|------------|----------|
| More friction on low-confidence estimates | Trust gate only blocks when sanity fails; edit clears block | Remove `FoodEstimateTrustPolicy` gate; keep range display |
| Range/scalar mismatch confuses users | Always show range alongside midpoint scalar in edit sheet | Revert formatters to scalar-only display |
| Backend prompt drift increases latency | Reuse existing repair loop; additive schema only | Gateway ignores new fields; iOS decodes optionally |
| Photo/text path divergence | Document client-derived photo ranges; align in v1.1 | Photo path unchanged on rollback |
| Log-from-card bypasses sanity | Apply `NutritionSanityValidator` + trust gate in `handleNutritionEstimateAction` | Revert handler-only change |
| Observability cardinality | Log buckets only — no food names | Disable `food_estimate_trust` event |
| Feature branch drift | Single vertical slice PR; no AB flag | Revert PR — no SwiftData migration to undo |

**Rollback is safe:** all model changes are additive DTO fields with `decodeIfPresent`. Persisted `FoodEntry` schema unchanged. No Remote Config / `FormaAbTest` gate required.

---

## Recommended order of changes

1. **Additive models + resolvers** — `FoodLogDraft` fields, `FoodCalorieRangeResolver`, decode tests  
2. **Backend mapping** — `foodCalorieRange.ts`, `mapExtractionToGatewayPayload`, Jest  
3. **Formatters (display-only)** — `AIFoodConfirmationFormatter`, `CoachPendingConfirmation`, `CoachPendingCopyFormatter`  
4. **Trust gate** — `FoodEstimateTrustPolicy`, `CoachModel`, `CoachConfirmationBar`, presenter typed-confirm block  
5. **Photo mapper** — `MealImageAnalysisMapper` assumptions + derived ranges  
6. **Context memory** — `CoachCorrectionMemoryBuilder` + `CoachContextPacketV2Builder`  
7. **Observability** — `CoachAccuracyObservability` trust event  
8. **Estimate-card log path** — `NutritionSuggestedActionHandler` + sanity/trust on `handleNutritionEstimateAction`  
9. **Edit sheet assumptions** — `AIFoodConfirmationSheet` read-only section  
10. **Benchmark harness** — `CoachAccuracyBenchmarkTests` + CI script wiring  
11. **Regression pass** — full Coach food + Singapore fixture suites  

---

## Build / test discovery (prep run)

| Check | Result |
|-------|--------|
| `functions/npm run build` (`tsc`) | **PASS** (no type errors on `main`) |
| `xcodebuild` | **Not available** in cloud agent environment |
| iOS schemes | `Fitness Coach.xcscheme`, `Fitness Coach CI.xcscheme` |
| iOS Coach test files | **82** `Fitness CoachTests/Coach*.swift` suites discovered |
| Firebase food/nutrition tests | **16** Jest files (see `functions/test`) |

### Key iOS test targets for this sprint

`CoachFoodLoggingRegressionTests`, `SingaporeFoodEstimationFixtureTests`, `NutritionSanityValidatorTests`, `FoodEstimateResponseValidatorTests`, `MealImageAnalysisResponseValidatorTests`, `CoachPendingCopyTests`, `CoachPendingConfirmationFormattingTests`, `CoachMealPhotoAnalysisTests`, `CoachAccuracyObservabilityTests`.

### Key Firebase test targets

`foodEstimateExtraction.test.ts`, `mealImageAnalysis.test.ts`, `singaporeFoodEstimationFixture.test.ts`, `foodLoggingGolden.test.ts`, `nutritionSchema.test.ts`, `nutritionResponseSanitizer.test.ts`.

---

## Implementation map (summary)

```
┌─────────────────────────────────────────────────────────────────┐
│                        USER CONFIRMATION UI                      │
│  CoachConfirmationBar / AIFoodConfirmationSheet / chat copy      │
│  ← AIFoodConfirmationFormatter (ranges + assumptions)             │
│  ← FoodEstimateTrustPolicy (block Log if sanity failed)          │
└────────────────────────────┬────────────────────────────────────┘
                             │
┌────────────────────────────▼────────────────────────────────────┐
│                     PENDING DRAFT LAYER                          │
│  AIFoodConfirmationDraft + FoodLogDraft (additive trust fields)  │
│  ← NutritionSanityValidator (downgrade)                          │
│  ← FoodLogDraftNutritionCompleter + FoodCalorieRangeResolver     │
└────────────────────────────┬────────────────────────────────────┘
                             │
        ┌────────────────────┼────────────────────┐
        ▼                    ▼                    ▼
┌───────────────┐  ┌─────────────────┐  ┌──────────────────┐
│ estimate-food │  │ analyze-meal-   │  │ nutrition-estimate│
│ extraction    │  │ image           │  │ (advice cards)    │
│ + ranges      │  │ + assumptions   │  │ + logMeal chip    │
└───────────────┘  └─────────────────┘  └──────────────────┘
        │                    │                    │
        └────────────────────┼────────────────────┘
                             ▼
┌─────────────────────────────────────────────────────────────────┐
│              CONTEXT + OBSERVABILITY (read path)                 │
│  CoachCorrectionMemoryBuilder → CoachContextPacketV2.assumptions │
│  CoachAccuracyObservability → food_estimate_trust event          │
│  CoachAccuracyBenchmarkTests → Singapore fixture pass rate       │
└─────────────────────────────────────────────────────────────────┘
```

---

*End of implementation plan. No behavior changes included in this document.*
