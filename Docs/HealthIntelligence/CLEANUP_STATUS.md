# Health Intelligence — Cleanup Status

Last updated: 2026-07-05 (Health Intelligence consolidation v2 — final implementation notes, PR #178).

This document tracks **removed**, **deprecated**, and **remaining** cleanup items for Apple Health / Health Intelligence. Use it before deleting additional legacy paths.

**Sprint map:** [HI_CONSOLIDATION_V2.md](../Sprints/HI_CONSOLIDATION_V2.md) · **Debt:** [TechnicalDebtRegister.md](../TechnicalDebt/TechnicalDebtRegister.md) (TD-HI-002, TD-HI-003)

---

## Consolidation v2 — final status (2026-07-05)

### TD-HI-002

| Field | Value |
|-------|-------|
| **Status** | **Mostly closed** |
| **What landed** | Shared loader core, Today loader extraction, tab loader delegation, presentation core delegation, golden parity gate, dead Today composition stubs removed |
| **What remains** | `*CompositionPolicy.swift` files + legacy dashboard sections until `healthIntelligenceUIEnabled` is permanently on; P1 tab-builder LOC slimming (stretch) |
| **Unblock to close** | Product decision to retire flag-off HI UI; then delete composition policies with composition tests green |

### Files consolidated or added

| File / area | Role | LOC (approx.) |
|-------------|------|---------------|
| `HealthIntelligenceSectionLoaderCore.swift` | **Added** — shared fetch, connection, weekly-review load, UI-state gating | 361 |
| `TodayHealthIntelligenceSectionLoader.swift` | **Added** — Today HI load path (extracted from `TodayModel`) | 175 |
| `JourneyHealthIntelligenceSectionLoader.swift` | Delegates to core | 203 |
| `PlanHealthIntelligenceSectionLoader.swift` | Delegates to core | 88 |
| `HealthIntelligencePresentationCore.swift` | Shared card mapping, sanitization, accessibility helpers | 323 |
| `HealthIntelligencePresentationPolicy.swift` | Surface-specific copy / stale / fallback gating | 310 |
| `HealthIntelligencePresentationModels.swift` | Shared presentation models | 167 |
| `HealthIntelligenceCardPresentationFactory.swift` | Card fragment builders | 558 |
| `App/Dependencies/*.swift` | **Added** — 10 domain construction bundles | see [AppContainer bundles](#appcontainer-bundles-2026-07-05) |
| `AppContainer+Construction.swift` | DEBUG utilities only (was ~1,004 LOC) | **68** |
| `AppContainer+FeatureFactories.swift` | Journey/Plan model wiring inlined | unchanged public API |

Tab presentation builders (surface-specific layout; still large — P1 stretch):

| File | LOC (approx.) |
|------|---------------|
| `TodayHealthIntelligencePresentationBuilder.swift` | 695 |
| `PlanHealthIntelligencePresentationBuilder.swift` | 920 |
| `JourneyHealthIntelligencePresentationBuilder.swift` | 1,110 |
| **Combined** | **2,725** |

### Shared core responsibilities

| Module | Owns |
|--------|------|
| `HealthIntelligenceSectionLoaderCore` | Snapshot + availability fetch; journey/plan connection classification; weekly-review load when flag on; `resolveUIState` input assembly; connect-only gating |
| `HealthIntelligencePresentationCore` | Recovery/workout/adaptive-nutrition card content; weekly-review building blocks; text sanitization; connect CTA copy; shared accessibility labels; UI-state CTA normalization |
| `HealthIntelligencePresentationPolicy` | Per-surface fallback messages, stale labels, partial-signal notes (Journey), limited-recovery copy, sync-failure section messaging |
| `HealthIntelligencePresentationModels` | Shared equatable section/card state types consumed by tab builders |
| `HealthIntelligenceCardPresentationFactory` | Reusable card row/fragment assembly |

### Surface-specific responsibilities (intentionally remain in tab builders)

| Surface | Still owns |
|---------|------------|
| **Today** | Daily mission composition; `TodayHealthIntegrationNextStepResolver` supplemental CTAs; unavailable/loading section shells; per-card loading placeholders; `nil` section when HI UI off |
| **Plan** | Confidence / assumptions / data-quality / signal grid; missing-data action rows; synthetic snapshot for disconnected plan; always-builds section (composition policy hides legacy) |
| **Journey** | Recovery timeline rows; 30-day workout history grouping; milestones + progress metrics; weekly-review card shell + detail; connect-only empty sub-card shells; `nil` section when HI UI off |

### AppContainer bundles (2026-07-05)

Under `Fitness Coach/App/Dependencies/`:

| File | Constructs |
|------|------------|
| `AuthDependencies.swift` | Auth, onboarding prefs, refresh bus |
| `AnalyticsDependencies.swift` | Domain analytics loggers |
| `PersistenceDependencies.swift` | SwiftData, account sync core, log services |
| `HealthDependencies.swift` | HealthKit, sync, training insights, `HealthActivityQueryService` |
| `HealthIntelligenceDependencies.swift` | HI engine, snapshot, weekly review |
| `CoachDependencies.swift` | Coach timeline stores, backfill, correction memory |
| `AIDependencies.swift` | LLM client, `AIService` |
| `SyncDependencies.swift` | Restore, cross-device, deletion, export |
| `SettingsDependencies.swift` | `ThemeStore` |
| `TodayDependencies.swift` | `ReviewService`, `FitnessActionCenter` |

`AppContainer+Construction.swift` retains DEBUG-only wiring. Feature factories: `AppContainer+FeatureFactories.swift`.

### Fast-Core status

| Item | Status |
|------|--------|
| BW-101 / TD-TEST-001 | **Fix applied** — `TEST_HOST` + `BUNDLE_LOADER`; Firebase/GoogleSignIn SPM in app target only |
| Runner | `./Scripts/run_fast_core_tests.sh` (resolve → build-for-testing → serial Fast-Core) |
| Mac verification | **Pending** — cloud agents have no Xcode; expect `TEST BUILD SUCCEEDED` then `TEST SUCCEEDED` on standard Mac host |

### Fixture cleanup (PH-004)

| Alias | Status |
|-------|--------|
| `CoachFoodFixtures` → `FoodLogFixtures` | **Complete** |
| `DailyNutritionSummaryTestFixtures` → `DailyLogFixtures` | **Complete** |
| `ProfileTestFixtures` → `ProfileFixtures` | **In progress** — ~70 files migrated; ~31 onboarding/profile-heavy files remain |

### Coach decomposition tail (TD-COACH-001)

| Item | Status |
|------|--------|
| `CoachPhotoFlowCoordinator` | Wired in `CoachModel.init` (runtime + processing hooks) |
| Production legacy init | **Removed** — tests use `CoachModelTestFactory` or `CoachDependencies` overrides |
| Future | `CoachImagePickFlowController` UI extraction; transcript dual-memory consolidation |

### Remaining debt (HI + adjacent)

| ID | Item |
|----|------|
| TD-HI-001 | Weekly review presentation duplication (Journey vs HI) |
| TD-HI-002 (tail) | Delete `*CompositionPolicy.swift` when `healthIntelligenceUIEnabled` permanent-on |
| TD-HI-003 | `NormalizedWorkout` ↔ `HealthWorkoutRecord` shim at query boundary |
| P1 stretch | Tab builder LOC ≤1,500 combined; loader mock consolidation |
| TD-TEST-001 | Mac verify Fast-Core green |
| PH-004 | Finish `ProfileTestFixtures` migration |

---

## Consolidation v2 deliverables (checklist)

| Item | Status | Notes |
|------|--------|-------|
| `HealthIntelligenceSectionLoaderCore` | **Added** | Shared snapshot/availability fetch, journey connection classification, weekly-review load, UI-state gating |
| `TodayHealthIntelligenceSectionLoader` | **Added** | Today HI load path extracted from `TodayModel` |
| Tab `*SectionLoader` duplication | **Reduced** | Journey/Plan/Today loaders delegate to core |
| Tab `*PresentationBuilder` duplication | **Reduced** | Today/Plan/Journey builders delegate to `HealthIntelligencePresentationCore` + `HealthIntelligenceSectionLoaderCore` |
| `AppContainer+Construction.swift` | **Reduced** | Domain bundles under `App/Dependencies/`; Construction holds DEBUG utilities only (~68 LOC) |
| Golden parity gate | **Added** | `HealthIntelligencePresentationParityTests` — fixtures A–E across Today/Plan/Journey |
| Legacy composition policy files | **Kept (flag-off)** | `TodayReadOnlyCompositionPolicy`, `PlanDashboardCompositionPolicy`, `JourneyDashboardCompositionPolicy` still gate legacy vs HI sections while `healthIntelligenceUIEnabled` can be off |
| Training Insights repository routing | **Done** | `TrainingInsightsModel` reads via `HealthActivityQueryService` |
| Fast-Core test plan | **Unblocked (BW-101 closed)** | `TEST_HOST` + `BUNDLE_LOADER`; run `./Scripts/run_fast_core_tests.sh` on Mac/Xcode (serial Fast-Core) |

---

## Removed (safe, tested replacements exist)

| Item | Removed in | Replacement |
|------|------------|-------------|
| `PlanConfidenceEngine` | Group 1 cleanup | `HealthIntelligenceBaseline.planConfidence` via `HealthIntelligenceEngine` |
| `HealthSyncService.syncDay` / `HealthSyncResult` | Group 1 cleanup | `syncToday()` / `syncLastNDays(_:)` |
| Journey snapshot-based presentation overloads | Group 2 cleanup | Record-based `recoveryTimeline(from recoveryDays:)`, `workoutHistory(from workoutRecords:)`, etc. |
| `TodayReadOnlyCompositionPolicy.showsLegacyHealthIntelligenceStack` | Consolidation v2 | Retired split-section layout; always returned `false`; zero production references |
| `TodayReadOnlyCompositionPolicy.showsLegacyNextBestAction` | Consolidation v2 | Next-best-action folded into mission hero / HI section; always returned `false`; parity + composition tests cover replacement |
| Training Insights direct HK reads | Consolidation v2 | `TrainingInsightsModel` now reads via `HealthActivityQueryService` (repository routing default); legacy reader fallback only when `isRepositoryReadRoutingEnabled` is off |

---

## Deprecated (compatibility kept — do not remove yet)

| Item | Location | Future removal condition |
|------|----------|--------------------------|
| `HealthDataRepository.normalizedSamples(for:)` | `HealthDataRepository.swift` | All callers use prefetched bundle / `HealthNormalizedSampleDeriver` |
| HealthKit reader fallback in `HealthActivityQueryService` | `HealthActivityQueryService.swift` | `isRepositoryReadRoutingEnabled` flag retired; all callers migrated |
| `isRepositoryReadRoutingEnabled` feature flag | `HealthIntelligenceFeatureFlags.swift` | Default-true routing stable; reader fallback deleted |
| Journey `workoutReader` fallback | `JourneyModel.fetchHealthWorkouts` | All `JourneyModel` instances receive `healthActivityQuery` |
| Workout calorie `max(manual, HealthKit)` merge | `TodayModel`, `DailyReviewSummaryBuilder` | HI workout display owns Today activity calories |
| Legacy dashboard sections + composition policy files | `*CompositionPolicy.swift` | `healthIntelligenceUIEnabled` permanently on; legacy UI removed. **Active methods kept:** `showsLegacyPlanConfidenceSection`, `showsLegacyInsightsSection`, `showsLegacyWeeklyReviewSection`, and all `showsHealthIntelligenceSection` / activity / recovery gating |
| FITPILOT_* legacy env keys | `HealthIntelligenceFeatureFlags` | Documented migration to FORMA_* only |
| `NormalizedWorkout+HealthWorkoutRecord` shim | `Health/Compatibility/` | **Blocked** — see [Blocked deletions](#blocked-deletions) below. Requires `HealthActivityQueryService` and all `HealthWorkoutRecord` consumers to migrate to `NormalizedWorkout` first |

---

## Compatibility adapters kept

| Adapter | Purpose |
|---------|---------|
| `HealthActivityQueryService` | App-facing query façade; routes to repository by default |
| `CoachAIActivityContextResolver` | Snapshot-first, query fallback for Coach context |
| `HealthTrainingService` | Onboarding/settings auth gate (not data plane) |
| `NoOpHealthIntelligenceSnapshotService` | Previews and flag-off model defaults |
| `NoOpHealthIntelligenceEngine` | Journey preview defaults |
| Legacy Today/Journey/Plan composition policy files | Hide duplicate sections when HI UI enabled; required while `healthIntelligenceUIEnabled` can be off |
| `NormalizedWorkout+HealthWorkoutRecord` | Maps repository `NormalizedWorkout` → app-query `HealthWorkoutRecord` at `HealthActivityQueryService` repository-routing boundary |

---

## Blocked deletions

### `NormalizedWorkout+HealthWorkoutRecord` shim (audited 2026-07-05)

**Verdict: not safe to delete.** The shim has one production caller and many downstream dependents on its output type.

| Check | Result |
|-------|--------|
| Production references to `asHealthWorkoutRecord` | **1** — `HealthActivityQueryService.readWorkouts` (repository-routing path) |
| Test references to `asHealthWorkoutRecord` | **0** (tests use `HealthWorkoutRecord` mocks directly) |
| `HealthActivityQueryService` public API | Still returns `[HealthWorkoutRecord]` — app-facing query boundary unchanged |
| `HealthDataRepository` | Returns `[NormalizedWorkout]` — HI canonical storage type |
| Legacy HK reader path | Returns `[HealthWorkoutRecord]` via `HealthKitWorkoutReading` — no shim involved |

**Production consumers still typed on `HealthWorkoutRecord`** (via query service, aggregators, or direct readers):

- `DailyTrainingActivity` — Today workout count / calorie burn
- `TrainingInsightsAggregator` / `TrainingInsightsModel` — weekly summaries, consistency, coach notes
- `JourneyHealthIntelligenceSectionLoader` — workout history inputs for HI presentation
- `JourneyTrainingSummaryBuilder` / `JourneyTimelineBuilder` / `JourneyDashboardBuilder` — training summaries and analytics
- `CoachContextPacketV2Builder` / `CoachTimelineBackfillService` — Coach training context
- `JourneyModel.fetchHealthWorkouts` — still uses direct `workoutReader` (separate from shim, same output type)
- `SystemHealthKitWorkoutReader` / `MockHealthKitWorkoutReader` — HK ingestion returns `HealthWorkoutRecord`

**Why inlining the mapping is not sufficient:** Moving `asHealthWorkoutRecord` into `HealthActivityQueryService` would delete the file but preserve the dual-type boundary. Removal criteria require callers to consume `NormalizedWorkout` directly.

**Unblock sequence (future PR):**

1. Extend or replace `HealthActivityQueryService` workout APIs to expose `NormalizedWorkout` (or a single shared query record type).
2. Migrate aggregators/builders listed above; preserve calorie rounding (`activeEnergyKcal` → `activeCalories`) and training-day semantics via characterization tests.
3. Retire `HealthWorkoutRecord` at the query boundary once Coach, Journey, Today, and Training Insights paths are migrated.
4. Delete shim only when `rg asHealthWorkoutRecord` returns zero production matches.

**Direct HealthKit access note:** `HealthKitWorkoutReading` still returns `HealthWorkoutRecord` on the legacy reader fallback path inside `HealthActivityQueryService`. That path is separate from the shim and remains required while `isRepositoryReadRoutingEnabled` can be off.

---

## Architecture (current canonical path)

```
HealthKitManager (single shared instance in AppContainer)
    → HealthDataRepository (cache + normalize)
        → HealthSyncService / HealthIntelligenceContextBuilder
        → HealthIntelligenceSnapshotService (cache + coalesce)
            → HealthIntelligenceEngine
    → HealthActivityQueryService (repository routing default; maps NormalizedWorkout → HealthWorkoutRecord at boundary)
        → Today / Journey loader / Coach fallback / ReviewService / Training Insights
```

**Not duplicate stacks:** `NextBestActionEngine` (Today Mission Control) vs `HealthNextBestActionEngine` (HI snapshot) serve different surfaces.

---

## Remaining cleanup risks

| Risk | Severity | Notes |
|------|----------|-------|
| Dual workout types (`NormalizedWorkout` vs `HealthWorkoutRecord`) | Medium | Shim required at repository→query boundary; see [Blocked deletions](#blocked-deletions-normalizedworkouthealthworkoutrecord-shim-audited-2026-07-05) |
| Multiple HealthKitManager defaults in test/preview inits | Low | Production AppContainer shares one instance for repo + sync permission + training auth |
| `storeRecoverySummary` never called in production | Low | Journey loader reads recovery from intelligence snapshots; recovery cache slot unused |
| Stale Phase 6–10 audit doc | Low | Historical; engines are implemented — see banner on `PHASE_6_10_ENGINE_AUDIT.md` |
| Test mock proliferation | Low | Many per-file `*MockRepository` types; consolidate when touching tests |
| Settings health cache on account delete | Medium | `SettingsDeleteDataActionHandler` TODO — not HI-specific but affects cache lifecycle |

---

## Verification commands

### Fast-Core (full plan — Mac/Xcode required)

```bash
./Scripts/run_fast_core_tests.sh
```

### HI consolidation gate (focused — Fast-Core subset)

```bash
export DESTINATION='platform=iOS Simulator,name=iPhone 17'
xcodebuild -resolvePackageDependencies -project "Fitness Coach.xcodeproj" -scheme "Fitness Coach"
xcodebuild build-for-testing -project "Fitness Coach.xcodeproj" -scheme "Fitness Coach" -destination "$DESTINATION"
xcodebuild test-without-building -project "Fitness Coach.xcodeproj" -scheme "Fitness Coach" \
  -destination "$DESTINATION" -testPlan Fast-Core -parallel-testing-enabled NO \
  -only-testing:"Fitness CoachTests/HealthIntelligenceSectionLoaderCoreTests" \
  -only-testing:"Fitness CoachTests/TodayHealthIntelligenceSectionLoaderTests" \
  -only-testing:"Fitness CoachTests/JourneyHealthIntelligenceSectionLoaderTests" \
  -only-testing:"Fitness CoachTests/PlanHealthIntelligenceSectionLoaderTests" \
  -only-testing:"Fitness CoachTests/HealthIntelligencePresentationParityTests" \
  -only-testing:"Fitness CoachTests/TodayHealthIntelligencePresentationBuilderTests" \
  -only-testing:"Fitness CoachTests/PlanHealthIntelligencePresentationBuilderTests" \
  -only-testing:"Fitness CoachTests/JourneyHealthIntelligencePresentationBuilderTests" \
  -only-testing:"Fitness CoachTests/HealthIntelligenceCompositionTests" \
  -only-testing:"Fitness CoachTests/TodayHealthIntelligenceCompositionTests" \
  -only-testing:"Fitness CoachTests/JourneyHealthIntelligenceCompositionTests" \
  -only-testing:"Fitness CoachTests/PlanDashboardHealthIntelligenceTests" \
  -only-testing:"Fitness CoachTests/TrainingInsightsAggregatorTests"
```

### Coach decomposition tail gate (behavior-neutral)

```bash
xcodebuild test-without-building -project "Fitness Coach.xcodeproj" -scheme "Fitness Coach" \
  -destination "$DESTINATION" -testPlan Fast-Core -parallel-testing-enabled NO \
  -only-testing:"Fitness CoachTests/CoachModelDecompositionCharacterizationTests" \
  -only-testing:"Fitness CoachTests/CoachMealPhotoAnalysisTests" \
  -only-testing:"Fitness CoachTests/CoachImagePickFlowTests"
```

### Full CI regression

```bash
xcodebuild test -scheme "Fitness Coach CI" -destination "platform=iOS Simulator,name=iPhone 17"
```

**Cloud agent note:** iOS tests not executed in Linux CI sandbox (no `xcodebuild`). Commands above are the Mac verification contract for this sprint.

Key test files after cleanup:

- `HealthSyncServiceTests.swift`
- `HealthActivityQueryServiceRepositoryRoutingTests.swift`
- `HealthIntelligenceSectionLoaderCoreTests.swift`
- `TodayHealthIntelligenceSectionLoaderTests.swift`
- `HealthIntelligenceCompositionTests.swift`
- `HealthIntelligencePresentationParityTests.swift`
- `TodayHealthIntelligenceCompositionTests.swift`
- `PlanDashboardHealthIntelligenceTests.swift`
- `JourneyHealthIntelligenceCompositionTests.swift`
- `HealthIntelligencePhase11IntegrationTests.swift`
- `TrainingInsightsAggregatorTests.swift`
