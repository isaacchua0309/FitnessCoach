# Forma Dead Code Audit

**Date:** 2026-06-28  
**Scope:** Read-only classification for the code-cleanup sprint. No deletions performed.  
**Method:** `rg` reference search across `Fitness Coach/` and `Fitness CoachTests/`, plus route/flag tracing for onboarding and auth paths.

**Hard exclusions (never classify as safe delete without explicit approval):**
- Auth / profile / cloud restore routing
- Firestore paths and `CloudUserProfileDocument` mapping
- Plan calculation engine and formulas
- AI pipeline / LLM contracts
- SwiftData entities registered in `FitPilotModelContainer` (migration-sensitive)
- Canonical onboarding flow (single path; version flags removed 2026-06-28)

---

## A. Safe delete candidates

**Status:** Stage 3 (2026-06-28) completed items marked ✅ below. Remaining rows are still open.

These have **no production references**, **no test references**, and are **not** schema, cloud, auth, calculation, or AI contract code. Self-referential `#Preview` blocks only (design gallery previews excluded).

| File path | Type / function | Reference search | Reason safe | Risk | Action | Validation |
|-----------|-----------------|------------------|-------------|------|--------|------------|
| `FitPilot/Core/Training/TrainingIntegrationPreviewData.swift` | `enum TrainingIntegrationPreviewData` | `rg` → enum unused; **same file also had `StubTrainingIntegrationProvider`** used by previews/tests | ✅ **Stage 3:** enum removed; `StubTrainingIntegrationProvider` extracted to `StubTrainingIntegrationProvider.swift` | **Low** | ✅ **done** (partial) | Build + `TrainingIntegrationTests` |
| `Features/Onboarding/UI/OnboardingV3LegacyPlaceholderStepView.swift` | `OnboardingV3LegacyPlaceholderStepView` | `rg` → **self + `#Preview` only**; not in `OnboardingView` | v3 uses real step views | **Low** | ✅ **deleted** | `OnboardingV3StructureTests` pass |
| `Features/Onboarding/Components/OnboardingJourneyHeroCard.swift` | `OnboardingPlanJourneySummary` | `rg` → **self + preview** | Never mounted in `OnboardingView` | **Low** | ✅ **deleted** | Build |
| `Features/Journey/Components/JourneyTimelineView.swift` | `JourneyTimelineView` | `rg` → **self + `#Preview` only** | Not used in `ProgressView` | **Low** | ✅ **deleted** | Build |
| `FitPilot/App/AppContainer.swift` | `makeTrainingInsightsView()` | `rg` → **definition only** | Factory never called | **Low** | ✅ **removed** | Build |
| `FitPilot/App/AppContainer.swift` | `makeTrainingModel()` | `rg makeTrainingModel` → **def + `TrainingConnectedDashboard` preview** | Only legacy preview path; **deferred** (training models excluded from Stage 3) | **Low** | **defer** | Batch 2 |
| `Features/TrainingInsights/TrainingInsightsView.swift` | `private func openAppSettings()` | Unreachable private method | Dead code | **Low** | ✅ **removed** | Build |
| `Domain/Onboarding/ProfilePlanConflictSummary.swift` | typealiases `OnboardingProfileConflictSummary`, `OnboardingProfileConflictSummaryBuilder` | Unused aliases | Call sites use `Profile*` names | **Low** | ✅ **removed** | Conflict summary tests pass |
| `Features/Auth/ProfilePlanConflictView.swift` | `typealias OnboardingProfileConflictView` | Alias line only | Call sites use `ProfilePlanConflictView` | **Low** | ✅ **removed** | Build |

---

## B. Needs verification

Reachable via flags, shared with active code, preview-only tooling, or intentional hide-until-ship UI. **Verify before delete.**

### B1 — Legacy manual Training dashboard (tab removed)

Production training UX is **`TrainingInsightsView`** (Apple Health). The SwiftData workout dashboard under `Features/TrainingInsights/Legacy/` is **not routed** from `MainTabView` (`TrainingView` comment: tab removed).

| File path | Type | Reference search | Reason verify | Risk | Action | Validation |
|-----------|------|------------------|---------------|------|--------|------------|
| `Legacy/TrainingView.swift` | `TrainingView` | `rg TrainingView` → self, `MainTabView` comment, preview | Thin wrapper around `TrainingInsightsView`; may be future push target | **Medium** | **delete** after cluster | Build; Training Insights smoke |
| `Legacy/TrainingConnectedDashboard.swift` | `TrainingConnectedDashboard` | Preview + `TrainingModel` only | Old connected dashboard | **Medium** | **delete** | Previews only |
| `Legacy/TrainingModel.swift` | `TrainingModel` | `makeTrainingModel()` preview only | Orphan model | **Medium** | **delete** | With cluster |
| `Legacy/TrainingDashboardState.swift` | `TrainingDashboardState` | `TrainingModel`, `TrainingPreviewData` | State for dead dashboard | **Medium** | **delete** | With cluster |
| `Legacy/TrainingViewState.swift` | `TrainingViewState` | `TrainingModel` only | Dead enum | **Medium** | **delete** | With cluster |
| `Legacy/TrainingHeroSection.swift` | View | `TrainingConnectedDashboard` + previews | Section UI | **Medium** | **delete** | With cluster |
| `Legacy/TrainingWeeklySummarySection.swift` | View | `TrainingConnectedDashboard` + previews | Section UI | **Medium** | **delete** | With cluster |
| `Legacy/TrainingMuscleDistributionSection.swift` | View | `TrainingConnectedDashboard` + previews | Section UI | **Medium** | **delete** | With cluster |
| `Legacy/TrainingRecentWorkoutsSection.swift` | View | `TrainingConnectedDashboard` + previews | Section UI | **Medium** | **delete** | With cluster |
| `Legacy/WorkoutDetailView.swift` | View | Preview only | Detail push never wired | **Medium** | **delete** | With cluster |
| `Legacy/ExerciseSetListView.swift` | View | `WorkoutDetailView` + preview | Child of dead detail | **Medium** | **delete** | With cluster |
| `Legacy/TrainingMuscleDistributionBuilder.swift` | `enum` | `TrainingModel` only | Builder for dead dashboard | **Medium** | **delete** | With cluster |
| `Legacy/TrainingPreviewData.swift` | `TrainingPreviewData` | Legacy section previews + `TrainingModel` | Not same as `TrainingInsightsPreviewData` (active) | **Medium** | **delete** | With cluster |

**Shared with active Training Insights — do not delete with cluster:**

| File path | Type | Reference search | Reason verify | Risk | Action | Validation |
|-----------|------|------------------|---------------|------|--------|------------|
| `Legacy/TrainingLayout.swift` | `enum TrainingLayout` | `TrainingInsightsConnectedView`, `GateView`, `EmptyConnectedView` | Active layout constants | **High** if deleted with cluster | **move** out of `Legacy/` then delete rest | Training Insights UI |
| `Legacy/TrainingFormatter.swift` | `enum TrainingFormatter` | `TrainingInsightsFormatter` + legacy sections | Active delegate for duration formatting | **High** | **move** then delete legacy-only methods | Formatter tests |
| `Legacy/TrainingLoadingView.swift` | View | `TrainingInsightsConnectedView` | Active loading state | **High** | **move** | Connected view smoke |
| `Legacy/TrainingErrorView.swift` | View | `TrainingInsightsConnectedView` | Active error state | **High** | **move** | Connected view smoke |

### B2 — Journey UI hidden from production scroll

| File path | Type | Reference search | Reason verify | Risk | Action | Validation |
|-----------|------|------------------|---------------|------|--------|------------|
| `Features/Journey/Components/JourneyAchievementsSection.swift` | View | Not in `ProgressView`; `#Preview` only; TODO: intentionally hidden | Product may re-enable Option A | **Medium** | **delete** or keep until ship | Product confirm |
| `Features/Journey/Components/JourneyMilestonesSection.swift` | View | Not in `ProgressView`; `showsMilestonesSection: false` | Milestone **data** still used for hero `nextCheckpointKg` | **Medium** | **delete view only** | Journey hero checkpoint |
| `Features/Journey/Model/ProgressModel.swift` | `achievements` build | Written to state; **no view reads** `state.achievements` | Dead computation, not dead file | **Low–Medium** | **remove computation + field** after product OK | `ProgressModel` / Journey tests |

### B3 — Onboarding / preview tooling

| File path | Type | Reference search | Reason verify | Risk | Action | Validation |
|-----------|------|------------------|---------------|------|--------|------------|
| `Features/Onboarding/Components/Inputs/OnboardingInputComponentsPreview.swift` | Preview gallery | `#Preview` only | Useful for v3 input design in Canvas | **Low** | **keep** or move to Preview target | Designer workflow |
| `Features/Onboarding/UI/OnboardingPlanPreviewStepView.swift` | View (`@deprecated`) | `OnboardingView.legacyStepContent` `.planPreview` | **Active when v2 flag off** (rollback path) | **High** | **keep** until v1 retired | `OnboardingStageProgressTests` |
| `Features/Onboarding/UI/OnboardingWelcomeStepView.swift` | View | `OnboardingView` legacy + v2 branches | Legacy / v2 welcome | **High** | **keep** | Onboarding flow tests |

### B4 — Infrastructure scaffolds

| File path | Type | Reference search | Reason verify | Risk | Action | Validation |
|-----------|------|------------------|---------------|------|--------|------------|
| `functions/` | Firebase Functions template | `helloWorld` export **commented out** | No deployed backend | **Low** | **delete** or implement | Confirm no CI deploy |
| `Tools/LocalAIBackend/` | dev scripts | `LocalAIBackendConfiguration`, README | DEBUG device backend | **Low** | **keep** | Dev workflow |

### B5 — FitPilot-named active components (rename later, not delete)

| File path | Type | Reference search | Reason verify | Risk | Action | Validation |
|-----------|------|------------------|---------------|------|--------|------------|
| `DesignSystem/Legacy/FitPilotScreenStyle.swift` | `FitPilotScreenStyle`, `FitPilotPlanCard` | 30+ production usages | Active design primitive | **High** | **rename/consolidate** (later sprint) | Visual regression |
| `Domain/Legal/FitPilotLegalCopy.swift` | Legal strings | Settings / sign-in | Active copy | **Medium** | **rename** later | Legal review |

---

## C. Keep for now

Migration-sensitive, cloud/auth, feature-flagged flows, debug tooling, or near-term planned work.

| File path | Type | Reference search | Reason keep | Risk if deleted | Action |
|-----------|------|------------------|-------------|-----------------|--------|
| `Data/SwiftData/Entities/ChatMessageEntity.swift` + mapping | Entity | In `FitPilotModelContainer`; **no read/write service** | Schema on disk; future chat persistence possible | **High** | **keep** until migration plan |
| `Data/SwiftData/Entities/WeeklyReviewEntity.swift` + `Domain/Models/WeeklyReview.swift` | Entity + model | Container + mapping; **`ReviewService` uses `DailyReviewEntity` only** | Orphan schema field | **High** | **keep** until migration plan |
| `Data/SwiftData/Entities/ExerciseSetEntity.swift` | Entity | `WorkoutLogService`, `WorkoutEntryEntity` relationship | Coach manual workout logging | **High** | **keep** |
| `Data/Firebase/*` | Cloud stores, DTOs | Auth gate, bootstrap, tests | Core profile sync | **High** | **keep** |
| `Domain/Routing/*`, `Features/Auth/*` | Routing / UI | Entire signed-in shell | Auth sprint surface | **High** | **keep** |
| `Domain/PlanCalculation/*`, `FormaCalculationEngine.swift` | Engine | Extensive test suite | Product math | **High** | **keep** |
| `FitPilot/Infrastructure/LLM/*`, `Features/Coach/Pipeline/*` | AI pipeline | `CoachModel`, `AIService`, tests | Coach behavior | **High** | **keep** |
| `Domain/Onboarding/OnboardingFlowScope.swift`, `OnboardingStep.swift` | Canonical flow | Production onboarding | Single onboarding path | **High** | **keep** |
| `Features/Settings/UI/*Diagnostics*` | Debug views | `SettingsRootView` | Engineering diagnostics | **Low** | **keep** |
| `Data/Firebase/NoOpCloudUserProfileStore.swift` | Store | `AppContainer` preview / no-Firebase builds | Test & preview wiring | **Medium** | **keep** |
| `Features/Journey/Model/JourneyStateBuilder.swift` | `milestones(...)` | `ProgressModel` → `nextCheckpointKg` | Hero checkpoint math | **Medium** | **keep** (even if milestone UI deleted) |
| `FitPilot/App/AppContainer.swift` | DI root | App entry | Runtime wiring | **High** | **keep** |
| `ContentView.swift` | Root view | `Fitness_CoachApp` | App shell | **High** | **keep** |

---

## D. Consolidation candidates

Behavior-neutral refactors for later batches. **Not deletions.**

| Area | Files / types | Reference evidence | Duplication | Risk | Action | Validation |
|------|---------------|-------------------|-------------|------|--------|------------|
| Card primitive | `FitPilotPlanCard` vs `FormaFormCard` vs `FormaEmptyStateCard` | `FormaFormCard` wraps `FitPilotPlanCard`; empty card wraps both | Three-layer card stack | **Medium** | **consolidate** to `FormaCard` | Visual / snapshot |
| Screen metrics | `FitPilotScreenStyle` vs `FormaTokens` vs `*Layout` enums | Widespread `FitPilotScreenStyle.horizontalPadding` | Split legacy/modern spacing | **Medium** | **consolidate** into tokens | UI pass |
| Text fields | `OnboardingTextField` vs `FormaLabeledField` | Onboarding vs Today/Plan forms | Parallel TextField wrappers | **Medium** | **consolidate** with style param | Form tests |
| Unit settings | `UnitSettingsView` vs `UnitsSettingsScreen` | Wizard vs Settings root | Same picker, two shells | **Low** | **consolidate** | Settings smoke |
| Progress headers | `OnboardingProgressHeader`, `OnboardingStageProgressHeader`, `OnboardingV3StageProgressHeader` | `OnboardingStepContainer` switches | One header per flow generation | **Medium** | **consolidate** with scope param | Onboarding tests |
| Weight formatting | `OnboardingBodyStepView` private formatters, `CoachResponseBuilder`, `DailyReviewFormatter` | Each defines `formatWeight` | Triplicated | **Low** | **extract** `WeightFormatting` | Formatter tests |
| Pace labels | `OnboardingFormatter` vs `PlanPaceLabelFormatter` | Goal step + plan reveal | Overlap | **Low** | **consolidate** | Pace tests |
| Product copy | `FormaProductCopy.swift` (~841 LOC) | Single enum, v1 aliases at L499+ | Monolith + legacy mirrors | **Medium** | **split** by feature domain | `EmptyStateCopyTests`, guardrails |
| Empty-state copy | `FormaProductCopy.EmptyState` vs `Today`/`Journey` nested strings | `EmptyStateCopyTests` asserts mirrors | Intentional duplication | **Low** | **dedupe** with test update | Copy tests |
| Loading views | `TodayLoadingView`, `ProfileLoadingView`, `ProgressLoadingView`, `TrainingLoadingView` | Each tab/feature | Same spinner pattern | **Low** | **consolidate** `FormaLoadingView` | Tab smoke |
| Error views | `TodayErrorView`, `ProfileErrorView`, `ProgressErrorView`, `CoachErrorView`, `TrainingErrorView` | Per-feature retry UI | Repeated layout | **Low** | **consolidate** with copy injection | Error path smoke |
| God files | `CoachModel.swift` (971), `OnboardingModel.swift` (928), `AuthGateView.swift` (900) | Central coordinators | Too many responsibilities | **High** | **extract** helpers only | Full test suites |

---

## Summary

### 1. Safest 5 deletions

**Stage 3 completed** items 2–5 below plus typealiases and dead methods. Item 1 corrected to enum-only delete + provider split.

1. **`TrainingIntegrationPreviewData` enum** — removed (provider split to `StubTrainingIntegrationProvider.swift`).
2. **`OnboardingV3LegacyPlaceholderStepView.swift`** — deleted.
3. **`OnboardingJourneyHeroCard.swift`** — deleted.
4. **`JourneyTimelineView.swift`** — deleted.
5. **Unused typealiases** — removed.

Also removed: `makeTrainingInsightsView()`, `openAppSettings()`.

### 2. Riskiest candidates

1. **Any SwiftData entity removal** (`ChatMessageEntity`, `WeeklyReviewEntity`) — schema migration required.
2. **Legacy onboarding rollback paths** — removed; single canonical flow only (2026-06-28).
3. **Deleting `TrainingLayout` / `TrainingFormatter` / `TrainingLoadingView` / `TrainingErrorView` with the Legacy folder** — breaks active `TrainingInsightsConnectedView`.
4. **Auth / profile / cloud files** — out of scope for deletion.
5. **`JourneyStateBuilder.milestones`** — still feeds `nextCheckpointKg` even if milestone UI is deleted.

### 3. Biggest bloat sources

| Source | ~LOC / files | Notes |
|--------|----------------|-------|
| `FormaProductCopy.swift` | 841 lines | v1 aliases + all features in one file |
| `CoachModel.swift` | 971 lines | Chat + routing + mutations + tracing |
| `OnboardingModel.swift` | 928 lines | v1/v2/v3 navigation in one type |
| `Features/TrainingInsights/Legacy/` | 17 files | ~half dead dashboard, half shared with Insights |
| `Features/Onboarding/` | 56 files | v1 + v2 + v3 parallel implementations |
| Duplicate UI primitives | 30+ `FitPilotPlanCard` call sites | Rename/consolidate later |

### 4. Suggested first deletion batch (Stage A — after approval)

**Stage 3 completed 2026-06-28** — see [Stage 3 log](#stage-3-deletions-2026-06-28) below.

**Defer to batch 4 (next):** Legacy manual-training cluster (move shared `TrainingLayout` / `TrainingFormatter` / loading / error first), Journey hidden sections, `makeTrainingModel()` + `TrainingModel` file group.

---

## Stage 3 deletions (2026-06-28)

### Deleted files

| File | Lines removed | Why safe |
|------|---------------|----------|
| `Features/Onboarding/UI/OnboardingV3LegacyPlaceholderStepView.swift` | ~52 | Never referenced from `OnboardingView`; v3 uses dedicated step views |
| `Features/Onboarding/Components/OnboardingJourneyHeroCard.swift` | ~87 | `OnboardingPlanJourneySummary` preview-only; not in any flow |
| `Features/Journey/Components/JourneyTimelineView.swift` | ~60 | Not mounted in `ProgressView`; preview-only |

### Deleted types / methods

| Location | Symbol | Why safe |
|----------|--------|----------|
| `TrainingIntegrationPreviewData.swift` (file removed) | `enum TrainingIntegrationPreviewData` | Enum had zero references |
| `AppContainer.swift` | `makeTrainingInsightsView()` | Never called |
| `TrainingInsightsView.swift` | `openAppSettings()` | Private, unreachable |
| `ProfilePlanConflictSummary.swift` | 2 typealiases | Unused; production uses `Profile*` names |
| `ProfilePlanConflictView.swift` | 1 typealias | Unused |

### Split / correction (audit lesson)

Deleting `TrainingIntegrationPreviewData.swift` **whole-file** initially broke the build: the same file also defined **`StubTrainingIntegrationProvider`**, used by:

- `AppleHealthIntegrationView` preview
- `SettingsRootView` preview
- `TrainingInsightsEmptyConnectedView` preview
- `TrainingIntegrationTests`

**Fix:** Removed only the unused `TrainingIntegrationPreviewData` enum; moved `StubTrainingIntegrationProvider` to `FitPilot/Core/Training/StubTrainingIntegrationProvider.swift`.

### Stage 3 validation

| Check | Result |
|-------|--------|
| Build (Debug, iPhone 17 sim) | **BUILD SUCCEEDED** |
| `OnboardingV3StructureTests` | 10/10 passed |
| `OnboardingProfileConflictSummaryBuilderTests` | 3/3 passed |
| `TrainingIntegrationTests` | 14/14 passed |
| `ProfilePlanConflictFlowTests` | 4/5 completed; `testRestoreExistingReplacesLocalAndSetsOwnerUID` **simulator crash** (pre-existing AppContainer/Firebase duplicate-class flake) |

### Stale doc references (not updated in Stage 3)

- `Docs/Architecture.md` still mentions `makeTrainingInsightsView()` and `JourneyTimelineView` — update in a docs pass.

---

## Audit commands (repeatable)

```bash
# Reference check example
rg -l "\\bTrainingIntegrationPreviewData\\b" --glob "*.swift"

# Clean build
xcodebuild -scheme "Fitness Coach" \
  -destination "platform=iOS Simulator,name=iPhone 17" clean build

# Tests (serial, less flaky)
xcodebuild -scheme "Fitness Coach" \
  -destination "platform=iOS Simulator,name=iPhone 17" \
  -parallel-testing-enabled NO test
```

**Known test infra note:** Full-suite runs can hit duplicate Firebase/GTM ObjC classes in the test bundle (`Fitness Coach.app` + `Fitness CoachTests.xctest`). Prefer serial test runs and lightweight harness tests when validating cleanup batches.
