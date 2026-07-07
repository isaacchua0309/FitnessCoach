# Technical Debt Register

**Last updated:** 2026-07-05  
**Purpose:** Track intentional gaps that are not safe to delete or fix in a dead-code pass. Each item has an owner domain, reason, and unblock criteria.

**Related:** [DeadCodeAudit.md](../DeadCodeAudit.md), [BuildWarningsRegister.md](./BuildWarningsRegister.md), [ProjectHygieneRegister.md](./ProjectHygieneRegister.md), [PRODUCTION_READINESS_MAINTAINABILITY_CONTEXT_PACKET.md](../Archive/ContextPackets/PRODUCTION_READINESS_MAINTAINABILITY_CONTEXT_PACKET.md) §15

---

## How to use

| Status | Meaning |
|--------|---------|
| **Open** | Not started; blocks or defers a ship milestone |
| **Deferred** | Known gap; acceptable for current release with documented workaround |
| **Blocked** | Waiting on external input (legal, ops, design) |

When closing an item, remove the source `TD-*` comment and update this register in the same PR.

---

## P0 — App Store / ship blockers

| ID | Domain | Item | Location | Reason deferred | Unblock |
|----|--------|------|----------|-----------------|---------|
| TD-LEGAL-001 | Legal | Hosted Terms & Privacy Policy URLs are `nil` | `FormaLegalCopy.swift` (`FormaLegalURLs`) | Legal pages not published yet | Publish URLs; set `FormaLegalURLs.terms` and `.privacyPolicy` |
| TD-LEGAL-002 | Legal | Legal links open in-app sheet instead of Safari | `FormaLegalCopy.swift` (`FormaLegalDocumentLink.url`) | Depends on TD-LEGAL-001 | Wire published URLs; verify Safari handoff in Settings and sign-in |
| TD-SETTINGS-001 | Settings | Support email may be placeholder | `SettingsSupportConfiguration.swift` | `FormaProductCopy.Legal.supportEmail` needs ops confirmation | Confirm production support inbox; verify `SettingsSupportConfiguration.isConfigured` |

---

## P1 — Feature gaps (intentional stubs)

| ID | Domain | Item | Location | Reason deferred | Unblock |
|----|--------|------|----------|-----------------|---------|
| TD-SETTINGS-002 | Settings / Privacy | User data export row gated but not wired | `SettingsExportDataActionHandler.swift`, `SettingsDataExportCapability` | `AccountDataExportService` exists; UI flow not shipped | Implement export presentation + share sheet; enable `SettingsDataExportCapability` |
| TD-DATA-001 | Data | `WeightLogService` has no delete API | `WeightLogService.swift` | Tombstone sync path not implemented | Add delete + mutation tracker wiring per account persistence phase docs |

---

## P2 — Accessibility / theme

| ID | Domain | Item | Location | Reason deferred | Unblock |
|----|--------|------|----------|-----------------|---------|
| TD-THEME-001 | Design system | Increased-contrast palette variants not implemented | `ThemeAccessibilityAdaptationPolicy.increasedContrastFollowUp` | `FormaAbTest.Theme.supportsIncreasedContrastPaletteVariants` is false by design | Implement palette branching on `colorSchemeContrast`; flip AB flag |
| TD-THEME-002 | Design system | Reduce-transparency compositing not implemented | `ThemeAccessibilityAdaptationPolicy.reduceTransparencyFollowUp` | `FormaAbTest.Theme.supportsReduceTransparencyCompositing` is false by design | Opaque fallbacks in `ThemeResolver`; flip AB flag |

---

## P3 — Structural / consolidation (not dead code)

| ID | Domain | Item | Location | Reason deferred | Unblock |
|----|--------|------|----------|-----------------|---------|
| TD-HI-001 | Health Intelligence | Weekly review presentation duplicated across Journey + HI | `JourneyWeeklyReviewBuilder`, `WeeklyReviewPresentationBuilder` | Distinct product surfaces; consolidation is P1 refactor | Shared weekly UX contract per PRDX P1 |
| TD-HI-002 | Health Intelligence | `*SectionLoader` / HI presentation duplication | Today / Journey / Plan HI loaders + presentation builders | **Mostly closed** — shared `HealthIntelligenceSectionLoaderCore` + `HealthIntelligencePresentationCore`; golden parity gate (`HealthIntelligencePresentationParityTests`) landed; dead Today composition stubs removed | Delete `*CompositionPolicy.swift` files and legacy dashboard sections only when `healthIntelligenceUIEnabled` is permanently on |
| TD-HI-003 | Health Intelligence | Dual workout types at query boundary | `HealthWorkoutRecord`, `NormalizedWorkout`, `NormalizedWorkout+HealthWorkoutRecord` | Repository stores `NormalizedWorkout`; app query layer and 30+ callers still use `HealthWorkoutRecord`. Shim maps at `HealthActivityQueryService` repository-routing path only. | Migrate `HealthActivityQueryService` workout APIs + Today/Journey/Coach/Training Insights builders to `NormalizedWorkout`; delete shim when `asHealthWorkoutRecord` has zero production references |
| TD-COACH-001 | Coach | `CoachModel` god-file split | `CoachModel.swift` (was ~1,600 LOC) | **Mostly closed** — v1 coordinators + `CoachDependencies`; `CoachPhotoFlowCoordinator` wired in `CoachModel`; production legacy init removed (`CoachModelTestFactory` in tests) | Future: `CoachImagePickFlowController` UI extraction; transcript dual-memory consolidation |
| TD-BACKEND-001 | Backend | Monolithic `functions/src/index.ts` | Firebase Functions | Route modularization deferred | Extract `routes/` per PRDX P1 |
| TD-TEST-001 | Testing | Fast-Core SPM / host wiring | `Fitness CoachTests`, `Fitness Coach.xcodeproj` | **Mostly closed** — TEST_HOST + BUNDLE_LOADER; no duplicate Firebase SPM link in test target; serial Fast-Core plan | Mac verify: `./Scripts/run_fast_core_tests.sh` → `TEST SUCCEEDED` |

---

## Closed — Coach decomposition v1 (2026-07-05)

| ID | Item | Resolution |
|----|------|------------|
| TD-COACH-001 (core) | Monolithic `CoachModel` (~1,600 LOC) | **Split** into 11 coordinators + `CoachDependencies` assembly. `CoachModel` ~350 LOC orchestration layer. Behavior-neutral per characterization tests. Docs: `Docs/Coach/CoachArchitecture.md`, `CoachModelDecompositionV1.md`. |
| TD-COACH-001 (tail) | Legacy test init + photo-flow coordinator | **Closed 2026-07-05** — removed `CoachModel+LegacyInitialization.swift`; tests use `CoachModelTestFactory` or `CoachDependencies` overrides; `CoachPhotoFlowCoordinator` runtime wired in `CoachModel.init` |

---

## Closed — Code Bloat Reduction v2 (2026-07-05)

| ID | Item | Resolution |
|----|------|------------|
| TD-AI-001 | Deprecated `AIContext` transport struct | **Deleted** `Infrastructure/AI/AIContext.swift`. Production Coach path already used `CoachContextPacketV2`. Extracted `TodayAISummary` for nutrition AI summaries. Six test stubs migrated to `CoachContextPacketV2`. |
| TD-COPY-001 | `FormaProductCopy` monolith | **Split** into 9 domain extension files under `Domain/Copy/`. Strings unchanged. Guarded by `FormaProductCopyEquivalenceTests`. |

## Closed — Health Intelligence consolidation v2 (2026-07-05)

| ID | Item | Resolution |
|----|------|------------|
| TD-HI-002 (core) | `*SectionLoader` / HI presentation duplication | **Mostly closed** — `HealthIntelligenceSectionLoaderCore`, `TodayHealthIntelligenceSectionLoader`, tab loader delegation, presentation core/policy delegation, `HealthIntelligencePresentationParityTests`, dead Today composition stubs removed |
| TD-TEST-001 (fix) | Fast-Core SPM / host wiring | **Fix applied** — BW-101 closed; `TEST_HOST` + `BUNDLE_LOADER`; `Scripts/run_fast_core_tests.sh`; Mac verify pending |

Partial progress (not closed):

| ID | Item | Status |
|----|------|--------|
| TD-HI-002 (tail) | `*CompositionPolicy.swift` + legacy dashboard sections | **Open** — kept while `healthIntelligenceUIEnabled` can be off |
| TD-HI-003 | `NormalizedWorkout+HealthWorkoutRecord` shim | **Open** — audited 2026-07-05; not safe to delete |
| TD-TEST-001 | Fast-Core Mac verification | **Mostly closed** — awaiting `./Scripts/run_fast_core_tests.sh` → `TEST SUCCEEDED` on Mac |
| PH-004 | Test fixture alias migration | **In progress** — `FoodLogFixtures` / `DailyLogFixtures` canonical; ~31 files still on `ProfileTestFixtures` |

---

## PRDX Platform Infrastructure v1 (2026-07-05)

Platform-contract sprint: explicit flags, logging, analytics routing, test CI, and `AppContainer` bundle extraction **without** user-visible behavior changes.

**Merge status:** Items below are **closed on the PRDX v1 branch stack** (`cursor/finalize-appcontainer-construction-38a8` and predecessors; PRs #180–#196). They remain **open on `main`** until that stack merges and CI is green. Re-open any ID if post-merge Fast-Core or focused PRDX tests regress.

| ID | Linked | Title | Status | Resolution |
|----|--------|-------|--------|------------|
| PH-001 / BW-101 | [BW-101](./BuildWarningsRegister.md#remaining--ios) | Fast-Core test plan blocked by package/test target resolution | **Closed** *(branch stack)* | `Fitness CoachTests` SPM products re-linked for compile; **Strip Duplicate SPM Frameworks** build phase prevents runtime duplicate ObjC classes. Documented serial runner: `Scripts/run-fast-core-serial.sh`. PR CI: `.github/workflows/prdx-ci.yml` (`ios-fast-core` job). See [TestCommandCheatsheet.md](../Testing/TestCommandCheatsheet.md). |
| PRDX-FLAGS-001 | [PRDX_V1_FLAG_MATRIX.md](../Architecture/PRDX_V1_FLAG_MATRIX.md) | Runtime feature flag snapshot contradicts production intent | **Closed** *(branch stack)* | `FormaAbTest.resolvedSnapshot(for:)` + `FormaRuntimeEnvironment.productionIntent`; `FormaAbTestSnapshot.production`; tests: `FormaAbTestResolvedSnapshotTests`, `FormaAbTestProductionSnapshotTests`. **Runtime intentionally unchanged** — Release still resolves `allEnabled` until a separate release flip PR. |
| PRDX-LOGGING-001 | [ReleaseLoggingAllowlist.md](../Architecture/ReleaseLoggingAllowlist.md) | Release logging policy scattered and unaudited | **Closed** *(branch stack)* | `FormaLogRedactor.swift`; `LogRedactor` delegates; machine allowlist `ReleaseLoggingAllowlist.json`; `ReleaseLoggingGuard` + `ReleaseLoggingGuardTests`; contract in `LoggingAndPrivacyContract.md`. |
| PRDX-ANALYTICS-001 | [AnalyticsReadinessChecklist.md](../Architecture/AnalyticsReadinessChecklist.md) | Analytics sink routing not explicit | **Closed** *(branch stack)* | `FormaAnalyticsConfiguration` presets; `AnalyticsLoggerFactory` configuration + composite resolve; `CompositeAnalyticsLoggers.swift`; `AnalyticsInfrastructureTests` (Release NoOp default, no Firebase Analytics). |
| PRDX-CONTAINER-001 | [DependencyInjectionMap.md](../Architecture/DependencyInjectionMap.md) | AppContainer construction root too dense | **Closed** *(branch stack)* | Init-time wiring moved to `Fitness Coach/App/Dependencies/*.swift` (10 bundles). `AppContainer+Construction.swift` reduced to **145 LOC** thin delegates (from ~1005 LOC). Journey/Plan wiring in `AppContainer+FeatureFactories.swift`. `AppContainerConstructionTests` added. |
| PRDX-FLAGS-002 | [FeatureFlagRegistry.md](../Architecture/FeatureFlagRegistry.md) | Unused `Settings.dataExportEnabled` flag | **Closed** *(branch stack)* | Zero call sites confirmed; removed from `FormaAbTest` / `FormaAbTestSnapshot`; export gated by `AccountDataExportPolicy.isEnabled`. Guard: `FormaAbTestProductionSnapshotTests` asserts field absent. |

**Sprint execution doc:** [PRDX_PLATFORM_INFRASTRUCTURE_V1.md](../Sprints/PRDX_PLATFORM_INFRASTRUCTURE_V1.md)

**Explicitly not closed by this sprint:** TD-HI-002 (HI loader extraction), TD-COACH-001 (remaining Coach decomposition), auth/account feature refactors, Release `production` snapshot wiring.

---

## Migration-only code (do not delete)

These SwiftData entities remain registered for lightweight migration. **Not technical debt** — documented retention.

| Entity | File | Notes |
|--------|------|-------|
| `WeeklyReviewEntity` | `Entities/WeeklyReviewEntity.swift` | V1 → V2 migration only |
| `ChatMessageEntity` | `Entities/ChatMessageEntity.swift` | V1 → V2 migration only |
| `WorkoutEntryEntity` | `Entities/WorkoutEntryEntity.swift` | V2 → V3 migration only |
| `ExerciseSetEntity` | `Entities/ExerciseSetEntity.swift` | V2 → V3 migration only |
| `DebugRecordEntity` | `Entities/DebugRecordEntity.swift` | V1 → V2 migration only |

See `Docs/PersistenceCleanupNotes.md` and entity file headers.

---

## Intentional stubs (keep — not debt)

| Symbol | Location | Purpose |
|--------|----------|---------|
| `NoOp*AnalyticsLogger` | `Infrastructure/Diagnostics/` | Release analytics sink until production backend wired |
| `NoOpCloudUserProfileStore` | `Infrastructure/Cloud/` | In-memory / preview builds |
| `StubTrainingIntegrationProvider` | `TestingSupport/` | Previews and tests |
| `NoOpCoachTimelineRecorder` | Coach platform | Fallback when timeline disabled |
| `LocalNoAPIGuard` | Coach pipeline | Offline / no-API guard responses |
| `MockLLMClient` | AI infrastructure | `AppContainer(inMemory: true)` |
| `HealthIntelligenceSnapshot+Preview` | `Health/Models/` | Tests and Canvas previews |

---

## Stale documentation (updated, not deleted)

| Document | Status | Canonical replacement |
|----------|--------|----------------------|
| `USER_DATA_STORAGE_CONTEXT_PACKET.md` | Stale vs V7+ account persistence | `Docs/Architecture/SourceOfTruthMap.md`, `Docs/AccountPersistence/` — archived at `Docs/Archive/ContextPackets/` |
| `arch.md`, `rules.mdc` | Legacy snapshots | `Docs/Architecture.md` — `arch.md` at `Docs/Archive/SprintReports/` |
| `Docs/Coach/archive/COACH_FULL_CONTEXT_PACKET_PRE_V2_2026-07-04.md` | Intentional archive | `Docs/Coach/COACH_FULL_CONTEXT_PACKET.md` |

---

## Revision history

| Date | Change |
|------|--------|
| 2026-07-05 | **PRDX Platform Infrastructure v1** — closed PH-001/BW-101, PRDX-FLAGS-001/002, PRDX-LOGGING-001, PRDX-ANALYTICS-001, PRDX-CONTAINER-001 on branch stack (pending `main` merge) |
| 2026-07-05 | **TD-COACH-001 tail** — removed production legacy init; `CoachPhotoFlowCoordinator` wiring confirmed; `CoachModelTestFactory` for tests |
| 2026-07-05 | **HI consolidation v2 docs** — TD-HI-002 mostly closed; final status in `CLEANUP_STATUS.md`, `HI_CONSOLIDATION_V2.md` |
| 2026-07-05 | **PH-004 fixture migration (batch 1)** — `FoodLogFixtures` / `DailyLogFixtures` canonical; `ProfileTestFixtures` ~101 → ~31 files |
| 2026-07-05 | **Fast-Core / BW-101** — TD-TEST-001 mostly closed; SPM parity + strip-duplicate-frameworks; `Scripts/run_fast_core_tests.sh` + `run-fast-core-serial.sh` |
| 2026-07-05 | **NormalizedWorkout shim audit** — TD-HI-003 opened; shim deletion blocked pending `HealthWorkoutRecord` → `NormalizedWorkout` query-boundary migration |
| 2026-07-05 | **Health Intelligence consolidation v2** — TD-HI-002 mostly closed; `HealthIntelligenceSectionLoaderCore`, `TodayHealthIntelligenceSectionLoader`, AppContainer dependency file split |
| 2026-07-05 | **Coach decomposition v1** — TD-COACH-001 partially closed; architecture docs added |
| 2026-07-05 | **Code Bloat Reduction v2 finalized** — closed TD-AI-001, TD-COPY-001; doc archive; fixture consolidation; account-test polling; build/hygiene registers |
| 2026-07-05 | Added links to BuildWarningsRegister + ProjectHygieneRegister |
| 2026-07-05 | Closed TD-AI-001 — deleted `AIContext.swift`; migrated 6 test stubs to `CoachContextPacketV2`; extracted `TodayAISummary` |
| 2026-07-04 | Initial register created during dead-code cleanup pass (Batch 6) |
