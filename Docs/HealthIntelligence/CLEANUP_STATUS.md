# Health Intelligence — Cleanup Status

Last updated: July 2026 (Health Intelligence consolidation v2 — `NormalizedWorkout+HealthWorkoutRecord` audit).

This document tracks **removed**, **deprecated**, and **remaining** cleanup items for Apple Health / Health Intelligence. Use it before deleting additional legacy paths.

---

## Consolidation v2 (2026-07-05)

| Item | Status | Notes |
|------|--------|-------|
| `HealthIntelligenceSectionLoaderCore` | **Added** | Shared snapshot/availability fetch, journey connection classification, weekly-review load, UI-state gating |
| `TodayHealthIntelligenceSectionLoader` | **Added** | Today HI load path extracted from `TodayModel` |
| Tab `*SectionLoader` duplication | **Reduced** | Journey/Plan/Today loaders delegate to core |
| Tab `*PresentationBuilder` duplication | **Reduced** | Today/Plan/Journey builders delegate to `HealthIntelligencePresentationCore` + `HealthIntelligenceSectionLoaderCore` |
| `AppContainer+Construction.swift` | **Reduced** | Domain bundles under `App/Dependencies/`; Construction holds DEBUG utilities only (~68 LOC) |
| Golden parity gate | **Added** | `HealthIntelligencePresentationParityTests` — fixtures A–E across Today/Plan/Journey |
| Legacy composition policy files | **Kept (flag-off)** | `TodayReadOnlyCompositionPolicy`, `PlanDashboardCompositionPolicy`, `JourneyDashboardCompositionPolicy` still gate legacy vs HI sections while `healthIntelligenceUIEnabled` can be off |
| Fast-Core test plan | **Blocked (BW-101)** | `build-for-testing` fails: test target cannot resolve `FirebaseCore` / GoogleSignIn modules on CI host without full Xcode + SPM resolution |

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

```bash
xcodebuild test -scheme "Fitness Coach CI" -destination "platform=iOS Simulator,name=iPhone 17"
```

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
