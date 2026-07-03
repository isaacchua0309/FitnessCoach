# Health Intelligence — Cleanup Status

Last updated: July 2026 (post hardening + observability passes).

This document tracks **removed**, **deprecated**, and **remaining** cleanup items for Apple Health / Health Intelligence. Use it before deleting additional legacy paths.

---

## Removed (safe, tested replacements exist)

| Item | Removed in | Replacement |
|------|------------|-------------|
| `PlanConfidenceEngine` | Group 1 cleanup | `HealthIntelligenceBaseline.planConfidence` via `HealthIntelligenceEngine` |
| `HealthSyncService.syncDay` / `HealthSyncResult` | Group 1 cleanup | `syncToday()` / `syncLastNDays(_:)` |
| Journey snapshot-based presentation overloads | Group 2 cleanup | Record-based `recoveryTimeline(from recoveryDays:)`, `workoutHistory(from workoutRecords:)`, etc. |

---

## Deprecated (compatibility kept — do not remove yet)

| Item | Location | Future removal condition |
|------|----------|--------------------------|
| `HealthDataRepository.normalizedSamples(for:)` | `HealthDataRepository.swift` | All callers use prefetched bundle / `HealthNormalizedSampleDeriver` |
| HealthKit reader fallback in `HealthActivityQueryService` | `HealthActivityQueryService.swift` | `isRepositoryReadRoutingEnabled` flag retired; Training Insights migrated |
| `isRepositoryReadRoutingEnabled` feature flag | `HealthIntelligenceFeatureFlags.swift` | Default-true routing stable; reader fallback deleted |
| Journey `workoutReader` fallback | `JourneyModel.fetchHealthWorkouts` | All `JourneyModel` instances receive `healthActivityQuery` |
| Training Insights direct HK reads | `TrainingInsightsModel` | Route through `HealthActivityQueryService` / repository |
| Workout calorie `max(manual, HealthKit)` merge | `TodayModel`, `DailyReviewSummaryBuilder` | HI workout display owns Today activity calories |
| Legacy dashboard sections + composition policies | `*CompositionPolicy.swift` | `healthIntelligenceUIEnabled` permanently on; legacy UI removed |
| FITPILOT_* legacy env keys | `HealthIntelligenceFeatureFlags` | Documented migration to FORMA_* only |
| `NormalizedWorkout+HealthWorkoutRecord` shim | `Health/Compatibility/` | All app queries consume `NormalizedWorkout` |

---

## Compatibility adapters kept

| Adapter | Purpose |
|---------|---------|
| `HealthActivityQueryService` | App-facing query façade; routes to repository by default |
| `CoachAIActivityContextResolver` | Snapshot-first, query fallback for Coach context |
| `HealthTrainingService` | Onboarding/settings auth gate (not data plane) |
| `NoOpHealthIntelligenceSnapshotService` | Previews and flag-off model defaults |
| `NoOpHealthIntelligenceEngine` | Journey preview defaults |
| Legacy Today/Journey/Plan composition policies | Hide duplicate sections when HI UI enabled |

---

## Architecture (current canonical path)

```
HealthKitManager (single shared instance in AppContainer)
    → HealthDataRepository (cache + normalize)
        → HealthSyncService / HealthIntelligenceContextBuilder
        → HealthIntelligenceSnapshotService (cache + coalesce)
            → HealthIntelligenceEngine
    → HealthActivityQueryService (repository routing default)
        → Today / Journey loader / Coach fallback / ReviewService
```

**Not duplicate stacks:** `NextBestActionEngine` (Today Mission Control) vs `HealthNextBestActionEngine` (HI snapshot) serve different surfaces.

---

## Remaining cleanup risks

| Risk | Severity | Notes |
|------|----------|-------|
| Training Insights bypasses repository | Medium | Direct `workoutReader.fetchWorkouts`; extra HK reads when routing flag off |
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
- `JourneyHealthIntelligencePresentationBuilderTests.swift`
- `HealthIntelligenceCompositionTests.swift`
- `HealthIntelligencePhase11IntegrationTests.swift`
