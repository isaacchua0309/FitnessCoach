# PRDX v1 — Implementation Map

**Sprint:** Production Readiness + Developer Experience Refactor v1  
**Generated:** 2026-07-04  
**Status:** Planning only — **no code changes in this deliverable**  
**Sources:** `../ContextPackets/PRODUCTION_READINESS_MAINTAINABILITY_CONTEXT_PACKET.md`, `../ContextPackets/WEEKLY_PROGRESS_LOOP_CONTEXT_PACKET.md`, `../ContextPackets/FULL_APP_PRODUCT_LOOP_GAP_CONTEXT_PACKET.md`, `../ContextPackets/USER_DATA_STORAGE_CONTEXT_PACKET.md`, `ACCOUNT_PERSISTENCE_IMPLEMENTATION_PLAN.md`, plus live code verification on `main`.

**Governing constraints (non-negotiable):**

| Rule | Implication |
|------|-------------|
| No user-facing behavior change | Runtime flag defaults stay as-is until product signs off on a `production` snapshot flip |
| No Coach behavior change | No `CoachModel`, pipeline, routing, context-packet, or AI contract edits |
| No Weekly Progress behavior change | No `JourneyWeeklyReviewBuilder`, `WeeklyReviewPresentationBuilder`, `WeeklyReviewService`, or Plan review/maintenance work |
| No new product features | No export UI, notifications, learned maintenance, widgets, or new screens |
| No destructive migrations | No schema version bumps; entity file moves only if zero `@Model` registration change |
| Preserve account persistence 1–6 | Do not change `AccountPersistenceFeatureFlags` values or sync/restore/deletion orchestration semantics |
| Small, reviewable diffs | One concern per commit; compiler-enforced cleanup preferred |
| Tests before risky refactors | Add/extend tests in the commit *before* structural moves |
| Every deletion justified | `rg` reference search + test run recorded in PR |

---

## 1. P0 Refactor Tasks

P0 = infrastructure, documentation, and production-safety prep with **zero or explicitly non-UI** runtime impact.

### P0-1 — Define flag snapshots without changing runtime defaults

**Goal:** End the `allEnabled` vs documented production-defaults contradiction without changing what users see today.

| Item | Detail |
|------|--------|
| **Work** | Add `FormaAbTestSnapshot.production` and `FormaAbTestSnapshot.internalDebug` (rename conceptual role of `allEnabled`). Add `FormaAbTest.resolvedSnapshot(for:)` that still returns `allEnabled` in **both** DEBUG and Release for this sprint. |
| **Document** | Table in `FormaAbTest.swift` + `Docs/PRDX_V1_FLAG_MATRIX.md` mapping each flag → production intended value, current runtime value, and Weekly Progress / HI impact. |
| **Align docs** | Update `HealthIntelligenceFeatureFlags.swift` header table to point at `production` snapshot, not env-only story. |
| **Tests** | `FormaAbTestProductionSnapshotTests` — assert `production` matches `PHASE_20_RELEASE_READINESS.md` safe defaults (HI UI off, weekly review off, remote sync off, debug fetches off, developer tools off). Keep `testDefaultsAreAllEnabled` but rename to clarify it tests **current runtime**, not ship intent. |
| **Behavior change** | **None** if runtime resolver unchanged. |
| **Justification** | Confirmed contradiction between `allEnabled`, HI docs, and `PHASE_20_RELEASE_READINESS.md`. |

**Production snapshot values (target — do not wire yet):**

| Namespace | Flag | `production` | Rationale |
|-----------|------|--------------|-----------|
| HI | `uiEnabled` | `false` | PHASE_20 |
| HI | `weeklyReviewEnabled` | `false` | Weekly Progress sprint owns ritual; avoid HI card surfacing change |
| HI | `remoteSummarySyncEnabled` | `false` | PHASE_20 |
| HI | `today/journey/planDebugFetchEnabled` | `false` | Internal only |
| HI | `coachContextEnabled` | `true` | Coach accuracy; no UI change |
| HI | `enginesEnabled` / `foundationEnabled` | `true` | Background engines OK |
| Coach | `pipelineTrace*` / `*DebugLog` | `false` | Privacy |
| Settings | `developerSectionVisible` | `false` | Ship |
| Settings | `dataDeletionEnabled` | `true` | Phase 6 implemented |
| Build | `internalBuildEnabled` | `false` | Ship |
| Account persistence | *all current `AccountPersistenceFeatureFlags`* | **unchanged** | Preserve phases 1–6 |

**Follow-up (not P0):** Separate PR `PRDX-v1-flags-wire-release` to switch Release resolver to `production` after device QA sign-off.

---

### P0-2 — Logging redaction contract (Release safety, no new logging)

**Goal:** Ensure no PII reaches Release OSLog if any `#if DEBUG` guard is wrong.

| Item | Detail |
|------|--------|
| **Work** | Extract shared `FormaLogRedactor` from patterns in `CoachContextPacketV2DebugRedactor.swift` (UID truncation, token stripping, numeric-only macro summaries). Audit every `Logger(` / `OSLog` call **outside** `#if DEBUG` blocks under `Fitness Coach/`. |
| **Work** | Add `FormaReleaseLoggingPolicy` enum documenting which subsystems may log in Release (sync phase, deletion phase — metadata only). |
| **Tests** | `FormaLogRedactorTests` (unit); `ReleaseLoggingGuardTests` — static grep-style test listing files with `Logger` not behind `#if DEBUG` (allowlist file). |
| **Behavior change** | **None** if only redacting or removing accidental Release logs. |
| **Files** | `Infrastructure/Diagnostics/FormaLogRedactor.swift`, audit targets in `AccountSyncLogger`, `AccountRestoreLogger`, `AccountDeletionCoordinatorLogger`, `FormaAIBackendClient`. |

---

### P0-3 — Analytics sink infrastructure (opt-in, default off)

**Goal:** Make Release analytics pluggable without turning on telemetry until explicitly enabled.

| Item | Detail |
|------|--------|
| **Work** | Introduce `FormaAnalyticsConfiguration` with `isProductionSinkEnabled` default **`false`**. Keep `NoOp*AnalyticsLogger` as Release default. Add `CompositeAnalyticsLogger` or single `ConfigurableAnalyticsLogger` that delegates to OSLog (DEBUG) + optional sink. |
| **Work** | Stub `FirebaseAnalyticsAnalyticsLogger` **or** document why SPM product stays unlinked until privacy review — **do not** emit events when flag false. |
| **Tests** | `AnalyticsSinkConfigurationTests` — Release default is NoOp; enabling flag routes to capturing sink in tests. Extend `CapturingAnalyticsLoggers.swift`. |
| **Behavior change** | **None** while sink disabled. Enabling sink is **telemetry**, not UI — gate behind explicit flag + privacy review (post-P0). |
| **Files** | `AppContainer.swift` (logger construction only), `Infrastructure/Diagnostics/`, `Domain/*/AnalyticsLogging.swift` (no event changes). |

---

### P0-4 — CI workflow (no app logic)

**Goal:** Repeatable pre-merge signal.

| Item | Detail |
|------|--------|
| **Work** | Add `.github/workflows/prdx-ci.yml`: Job 1 `functions` — `npm ci`, `npm run lint`, `npm test` (non-emulator suites). Job 2 iOS — `xcodebuild test -scheme "Fitness Coach CI" -destination "platform=iOS Simulator,name=iPhone 17" -parallel-testing-enabled NO`. |
| **Work** | Document local equivalents in `Fitness CoachTests/TESTING.md`. |
| **Behavior change** | **None**. |
| **Note** | Emulator suites (`accountPersistenceFirestoreRules.test.ts`) — optional Job 3 or `continue-on-error` until emulator service added (P1). |

---

### P0-5 — Documentation hygiene (zero runtime)

| Item | Detail |
|------|--------|
| **Work** | Add staleness banner to `../ContextPackets/USER_DATA_STORAGE_CONTEXT_PACKET.md` — V7+ `ownerUID`, account sync, deletion implemented; link `ACCOUNT_PERSISTENCE_IMPLEMENTATION_PLAN.md`. |
| **Work** | Add `Docs/PRDX_V1_SPRINT.md` — this map + safety rules + ownership. |
| **Work** | Remove or deprecate unused `FormaAbTest.Settings.dataExportEnabled` (**Confirmed** zero call sites outside `FormaAbTest.swift`). Settings already uses `AccountDataExportPolicy.isEnabled`. |
| **Behavior change** | **None**. |
| **Deletion justification** | `rg FormaAbTest.Settings.dataExportEnabled` → definition only. |

---

### P0-6 — Compiler-enforced dead-flag cleanup

| Item | Detail |
|------|--------|
| **Work** | After P0-5, delete unused `dataExportEnabled` from `FormaAbTestSnapshot` **only if** no tests reference it; else mark `@available(*, deprecated)` with fixit to `AccountDataExportPolicy`. |
| **Do NOT delete** | `AIContext.swift` — still referenced in test mock `LLMClient` stubs (**Confirmed** 6+ test files). |
| **Behavior change** | **None**. |

---

## 2. P1 Refactor Tasks

P1 = structural maintainability after P0 gates are green. Each task requires **parity tests** (same outputs given same inputs).

### P1-1 — `AppContainer` domain extraction (composition only)

| Item | Detail |
|------|--------|
| **Work** | Extract `SyncDependencies`, `HealthDependencies`, `AnalyticsDependencies` structs built in `AppContainer` private factory methods. `AppContainer` retains public surface; no call-site changes in features. |
| **Tests** | `AppContainerAccountDataRemoteStoreWiringTests` + new `AppContainerCompositionTests` asserting same instance graph. |
| **Risk** | Medium — touch init order. |
| **Excluded** | Changing what gets constructed or lifecycle hooks. |

---

### P1-2 — Health Intelligence section loader deduplication (non–Weekly Progress)

| Item | Detail |
|------|--------|
| **Work** | Move shared logic from `TodayHealthIntelligencePresentationBuilder`, `JourneyHealthIntelligenceSectionLoader`, `PlanHealthIntelligenceSectionLoader`, `CoachHealthIntelligenceSnapshotLoader` into `Application/StateBuilders/HealthIntelligence/HealthIntelligenceSectionLoaderCore.swift`. Callers keep existing public builder APIs. |
| **Tests** | Existing `TodayHealthIntelligencePresentationBuilderTests`, `JourneyHealthIntelligence*`, `PlanHealthIntelligence*`, `CoachHealthIntelligence*` must pass unchanged. Add golden/fixture parity test comparing old vs new output for 3 fixture snapshots. |
| **Excluded** | `JourneyWeeklyReviewBuilder`, `WeeklyReviewPresentationBuilder`, `WeeklyReviewService`, `WeeklyReviewEngine` — **Weekly Progress boundary**. |

---

### P1-3 — `FormaProductCopy` mechanical split

| Item | Detail |
|------|--------|
| **Work** | Split `Domain/Copy/FormaProductCopy.swift` (4,326 LOC) into domain files with `typealias`/`enum` nesting preserved at root for source compatibility. No copy string changes. |
| **Tests** | `EmptyStateCopyTests`, `Onboarding*Copy*`, any guardrail tests referencing `FormaProductCopy`. |
| **Risk** | Low if mechanical. |

---

### P1-4 — Migration-only SwiftData entities → `LegacyEntities/` folder

| Item | Detail |
|------|--------|
| **Work** | Move `ChatMessageEntity`, `WeeklyReviewEntity`, `WorkoutEntryEntity`, `ExerciseSetEntity`, `DebugRecordEntity` to `Infrastructure/Persistence/SwiftData/LegacyEntities/`. **Do not** remove from `FormaSchemaV1`/`V2` versioned schema type lists. |
| **Tests** | `FormaSchemaV7MigrationTests`, `FormaSchemaV8MigrationTests`, `CoachV2SwiftDataMigrationTests`. |
| **Deletion justification** | N/A — move only. |
| **Excluded** | Removing entities from disk or active schema. |

---

### P1-5 — `WeightLogService.deleteWeightEntry` + tests (API only, no UI)

| Item | Detail |
|------|--------|
| **Work** | Add local delete matching remote `deleteWeightEntry` contract; mirror `FoodLogService` delete patterns; enqueue outbox tombstone via existing `AccountLocalMutationTracker` if food/water already do. **Do not** add Settings or Today UI. |
| **Tests** | `WeightLogServiceTests` (new or extend), `AccountSyncUploaderTests` tombstone path. |
| **Behavior change** | **None** until a caller invokes delete (no new callers in this sprint). |
| **Account persistence** | Completes Phase 1 gap noted in storage docs; aligns with sync delete path (**Confirmed** remote delete exists). |

---

### P1-6 — Backend `aiGateway` route modularization

| Item | Detail |
|------|--------|
| **Work** | Extract handlers from `functions/src/index.ts` to `functions/src/routes/*.ts`; `index.ts` re-exports only. Zero HTTP behavior change. |
| **Tests** | Full `npm test`; `aiGateway.contract.test.ts` must pass unchanged. |

---

### P1-7 — Firestore emulator CI job

| Item | Detail |
|------|--------|
| **Work** | Add `firebase emulators:exec` wrapper for `accountPersistenceFirestoreRules.test.ts` + nutrition contract tests. |
| **Tests** | Currently **31 failures** without emulator (**Confirmed** audit run). |

---

### P1-8 — Test harness stability (developer experience)

| Item | Detail |
|------|--------|
| **Work** | Document serial test requirement; add `Scripts/run-fast-core-serial.sh`; investigate duplicate Firebase class linker flags (no fix required if documented). |
| **Tests** | N/A — infra. |

---

## 3. Explicit Exclusions

### Product / UX (do not touch in PRDX v1)

| Exclusion | Reason |
|-----------|--------|
| Weekly Progress Loop v1 (learned maintenance, unified weekly review, plan recommendations) | Separate sprint per `../ContextPackets/WEEKLY_PROGRESS_LOOP_CONTEXT_PACKET.md`; **no** `JourneyWeeklyReview*` / `WeeklyReview*` / `PlanAdjustment*` behavior changes |
| Coach AI behavior (routing, prompts, context packet, meal photo, intents) | User rule + `CoachRoutingTests` safety net |
| `CoachModel` split / image pipeline extraction | Coach boundary |
| Onboarding flow, steps, or copy | Out of scope |
| Notifications / widgets / retention loops | New features |
| Data export implementation | `AccountDataExportPolicy.accountDataExportEnabled = false` — foundation only |
| Legal URL / support email TODOs | App Store prep, not maintainability |
| Light/System theme ship (`AppThemeShippingPolicy`) | Visual QA gate |
| Today daily-review screen / end-of-day UX changes | Product loop, not PRDX |
| Training tab / manual workout UI | Product |
| Learned maintenance / `WeeklyReviewEntity.estimatedMaintenance` | Weekly Progress |
| `hasSuddenSpike` Journey UI | Weekly Progress |

### Technical (do not touch in PRDX v1)

| Exclusion | Reason |
|-----------|--------|
| SwiftData schema version bump (`FormaSchemaV10`) | No destructive migrations |
| Remove migration-only entity **files** | Migration risk |
| Delete `AIContext.swift` | Test mock dependencies (**Confirmed**) |
| Change `AccountPersistenceFeatureFlags` constants | Preserve phases 1–6 behavior |
| Change sync/restore/deletion coordinator logic | Preserve phases 1–6 |
| Wire `FormaAbTestSnapshot.production` as Release default | User-facing HI/Journey/Coach-adjacent surfacing — separate gated PR |
| Remove `NoOp*AnalyticsLogger` as default | Until sink privacy review |
| Design system card unification | Low score; visual regression |
| Firebase Analytics SDK link + live events | Privacy review gate |
| `pullRecentDataEnabled` flip | Account persistence semantics |

---

## 4. Risk Matrix

| ID | Task | Regression Risk | Behavior Risk | Account Persist Risk | Coach Risk | Weekly Progress Risk | Mitigation | Rollback |
|----|------|-----------------|---------------|----------------------|------------|----------------------|------------|----------|
| R1 | P0-1 Flag snapshots (define only) | Low | **None** if runtime unchanged | Low | Low | Low | Runtime stays `allEnabled`; production snapshot tested in isolation | Revert struct additions |
| R2 | P0-2 Log redactor | Low | Low | Low | Low | Low | Allowlist test; no new Release logs | Revert redactor |
| R3 | P0-3 Analytics infra | Medium | Low (disabled) | Low | Low | Low | Default off; capturing tests | Flag off |
| R4 | P0-4 CI | Low | None | Low | Low | Low | Optional required check | Disable workflow |
| R5 | P0-5 Docs / dead flag | Low | None | Low | Low | Low | Compiler after flag removal | Git revert |
| R6 | P1-1 AppContainer split | **High** | Low | **High** | Medium | Low | Init-order test; run Integration plan | Revert struct extract |
| R7 | P1-2 HI loader dedupe | Medium | Medium (HI cards) | Low | Medium | **High** if weekly touched | **Exclude weekly loaders**; parity fixtures | Revert loader |
| R8 | P1-3 FormaProductCopy split | Low | Low | Low | Low | Low | Guardrail tests | Revert move |
| R9 | P1-4 LegacyEntities move | Medium | None | Medium | Low | Low | Migration tests | Revert paths |
| R10 | P1-5 Weight delete API | Medium | None (no UI) | Medium | Low | Low | Tests before merge; no UI wire | Remove API |
| R11 | P1-6 Backend routes | Medium | Low | Low | Medium | Low | Contract tests | Revert modules |
| R12 | P1-7 Emulator CI | Low | None | Medium | Low | Low | Isolated job | Skip job |
| **RX** | **Wire production flags (excluded)** | Medium | **High** | Low | Medium | **High** | Device QA matrix | Flag revert |

---

## 5. Files to Touch

### P0 files

| Area | Paths |
|------|-------|
| Flags | `Fitness Coach/Configuration/FormaAbTest.swift`, `Fitness Coach/Health/HealthIntelligenceFeatureFlags.swift` |
| Logging | `Fitness Coach/Infrastructure/Diagnostics/FormaLogRedactor.swift` (new), audit `AccountSyncLogger.swift`, `AccountRestoreLogger.swift`, `AccountDeletionCoordinatorLogger.swift`, `FormaAIBackendClient.swift`, `CoachFoodEstimateDebugLogger.swift` |
| Analytics | `Fitness Coach/App/AppContainer.swift` (logger wiring only), `Fitness Coach/Infrastructure/Diagnostics/*Analytics*`, `Fitness CoachTests/TestingSupport/CapturingAnalyticsLoggers.swift` |
| CI | `.github/workflows/prdx-ci.yml` (new), `Fitness CoachTests/TESTING.md` |
| Docs | `../ContextPackets/USER_DATA_STORAGE_CONTEXT_PACKET.md`, `Docs/PRDX_V1_SPRINT.md` (new), `Docs/PRDX_V1_FLAG_MATRIX.md` (new) |
| Tests | `Fitness CoachTests/FormaAbTestProductionSnapshotTests.swift` (new), `Fitness CoachTests/FormaLogRedactorTests.swift` (new), `Fitness CoachTests/ReleaseLoggingGuardTests.swift` (new), `Fitness CoachTests/AnalyticsSinkConfigurationTests.swift` (new) |

### P1 files

| Area | Paths |
|------|-------|
| DI | `Fitness Coach/App/AppContainer.swift` |
| HI loaders | `Fitness Coach/Application/StateBuilders/HealthIntelligence/` (new), `.../Today/TodayHealthIntelligencePresentationBuilder.swift`, `.../Journey/JourneyHealthIntelligenceSectionLoader.swift`, `.../Plan/PlanHealthIntelligenceSectionLoader.swift`, `.../Coach/CoachHealthIntelligenceSnapshotLoader.swift` |
| Copy | `Fitness Coach/Domain/Copy/FormaProductCopy.swift` → split under `Fitness Coach/Domain/Copy/` |
| Persistence | `Fitness Coach/Infrastructure/Persistence/SwiftData/LegacyEntities/*` (moves) |
| Weight | `Fitness Coach/Data/Repositories/WeightLogService.swift`, `Fitness CoachTests/WeightLogServiceTests.swift` (new) |
| Backend | `functions/src/index.ts`, `functions/src/routes/*.ts` (new) |

### Do-not-touch list (PRDX v1)

```
Fitness Coach/Features/Coach/Model/CoachModel.swift
Fitness Coach/Application/UseCases/Coach/**
Fitness Coach/Application/StateBuilders/Coach/CoachContextPacketV2Builder.swift
Fitness Coach/Application/StateBuilders/Journey/JourneyWeeklyReviewBuilder.swift
Fitness Coach/Application/StateBuilders/Journey/JourneyWeeklyPatternBuilder.swift
Fitness Coach/Application/StateBuilders/Journey/WeeklyReviewPresentationBuilder.swift
Fitness Coach/Health/Intelligence/WeeklyReviewEngine.swift
Fitness Coach/Health/Intelligence/WeeklyReviewService.swift
Fitness Coach/Application/Sync/**
Fitness Coach/Application/Restore/**
Fitness Coach/Application/Privacy/AccountDeletionCoordinator.swift
Fitness Coach/Infrastructure/Cloud/AccountPersistenceFeatureFlags.swift
```

*Exception:* `AppContainer.swift` init may reference sync types but must not alter coordinator behavior.

---

## 6. Tests to Run

### Per-commit (minimum)

```bash
# Backend (every functions touch)
cd functions && npm ci && npm run lint && npm test

# iOS fast gate (every Swift touch)
xcodebuild test -scheme "Fitness Coach" \
  -destination "platform=iOS Simulator,name=iPhone 17" \
  -testPlan Fast-Core \
  -parallel-testing-enabled NO
```

### P0 merge gate

| Suite | Classes / area |
|-------|----------------|
| Flag snapshots | `FormaAbTestProductionSnapshotTests`, `HealthIntelligenceFeatureFlagsTests` |
| Logging | `FormaLogRedactorTests`, `ReleaseLoggingGuardTests` |
| Analytics | `AnalyticsSinkConfigurationTests`, `ThemeAnalyticsTests` (smoke) |
| Account persistence smoke | `AccountSyncCoordinatorTests`, `AccountRestoreCoordinatorTests`, `AccountDeletionCoordinatorTests` |
| Coach safety | `CoachRoutingTests` (unit methods only) |
| Weekly Progress safety | `JourneyWeeklyReviewBuilderTests`, `JourneyDashboardBuilderTests`, `WeeklyReviewServiceTests` |

### P1 merge gate (add)

| Suite | Reason |
|-------|--------|
| **Full** CI scheme | `xcodebuild test -scheme "Fitness Coach CI" -parallel-testing-enabled NO` |
| Integration plan | `AppContainerAccountDataRemoteStoreWiringTests`, `CrossDeviceEndToEndSyncTests`, `AccountRestoreEndToEndTests` |
| HI parity | `TodayHealthIntelligencePresentationBuilderTests`, `HealthIntelligenceFeatureFlagsTests`, `CoachHealthIntelligenceContextBuilderTests` |
| Migration | `FormaSchemaV7MigrationTests`, `FormaSchemaV8MigrationTests` |
| Backend contract | `aiGateway.contract.test.ts`, `coachContextV2Contract.test.ts` |
| Emulator (P1-7) | `accountPersistenceFirestoreRules.test.ts`, `nutritionSyncContract.test.ts` |

### Weekly Progress non-regression checklist (manual)

After any P1-2 HI loader work, verify **unchanged**:

- Journey `JourneyWeeklyReviewSection` habit row labels and thresholds (`JourneyWeeklyReviewBuilder`)
- HI `WeeklyReviewCard` hidden when `weeklyReviewEnabled == false` in **current runtime** snapshot
- Plan `PlanReviewStateBuilder` / `PlanAdjustmentRulesStateBuilder` output unchanged

---

## 7. Rollback Plan

| Layer | Trigger | Action |
|-------|---------|--------|
| **Flags** | Unexpected HI/Coach/Settings surfacing | Revert resolver to `allEnabled`; keep `production` struct for docs |
| **Analytics** | Unexpected telemetry | `FormaAnalyticsConfiguration.isProductionSinkEnabled = false` or revert sink commit |
| **Logging** | Missing critical diagnostics | Revert redactor; restore prior log lines behind `#if DEBUG` |
| **AppContainer** | Init crash / missing dependency | Revert composition commit as a unit |
| **HI loaders** | Card content diff | Revert P1-2; parity tests should catch before merge |
| **Backend routes** | Gateway 4xx/5xx regression | Redeploy prior `functions` bundle; revert TS modules |
| **CI** | Flaky blocking | Mark workflow non-required; keep local TESTING.md commands |
| **Account persistence** | Sync/restore/deletion regression | **Immediate full revert** of PR; run `AccountRestoreEndToEndTests` + `CrossDeviceEndToEndSyncTests` before re-attempt |

**Release rollback:** All P0/P1 changes are code-only; App Store rollback is prior build. No migrations → no data rollback required.

---

## 8. Recommended Commit Sequence

Each commit = one PR preference; land in order.

| # | Commit title | Contents | Pre-commit tests |
|---|--------------|----------|------------------|
| 1 | `docs(prdx): add v1 sprint map and stale storage banner` | This file, `Docs/PRDX_V1_SPRINT.md`, `USER_DATA_STORAGE` banner | None |
| 2 | `feat(flags): add production and internal FormaAbTest snapshots` | P0-1 structs + `FormaAbTestProductionSnapshotTests`; runtime unchanged | Fast-Core |
| 3 | `docs(flags): add PRDX v1 flag matrix` | `Docs/PRDX_V1_FLAG_MATRIX.md` | None |
| 4 | `feat(logging): add FormaLogRedactor and release log guard` | P0-2 + tests | Fast-Core |
| 5 | `feat(analytics): add opt-in production sink configuration` | P0-3, default off | Fast-Core + analytics tests |
| 6 | `chore(flags): remove unused dataExportEnabled from FormaAbTest` | P0-5/6 dead flag | Fast-Core + Settings privacy tests |
| 7 | `ci: add PRDX workflow for functions and iOS Full` | P0-4 | CI self-check |
| 8 | `refactor(di): extract AppContainer dependency structs` | P1-1 | Integration + AppContainer tests |
| 9 | `refactor(hi): extract shared section loader core` | P1-2 (weekly excluded) | HI + Journey dashboard tests |
| 10 | `refactor(copy): split FormaProductCopy by domain` | P1-3 mechanical | Copy guardrails |
| 11 | `chore(persistence): move legacy SwiftData entities to LegacyEntities` | P1-4 | Migration tests |
| 12 | `feat(weight): add WeightLogService.deleteWeightEntry API` | P1-5, no UI | Weight + sync tests |
| 13 | `refactor(functions): extract aiGateway routes` | P1-6 | `npm test` |
| 14 | `ci: add Firestore emulator job for rules tests` | P1-7 | Emulator suite |

**Parallelization:** Commits 4–6 can run in parallel after commit 2 if coordinated. Commits 8–11 must be sequential per domain. Commit 12 independent after P0 green.

**Post-sprint (separate epic, not PRDX v1):**

- `feat(flags): wire Release to FormaAbTestSnapshot.production` — requires QA sign-off (risk RX)
- `feat(analytics): enable Firebase Analytics sink` — privacy review
- Weekly Progress Loop v1 — per `../ContextPackets/WEEKLY_PROGRESS_LOOP_CONTEXT_PACKET.md`

---

## Appendix A — Account Persistence Preservation Checklist

Before merging any PRDX commit, confirm **unchanged**:

- [ ] `AccountPersistenceFeatureFlags` constant values
- [ ] `AccountSyncCoordinator` upload/debounce/foreground behavior
- [ ] `AccountRestoreCoordinator` blocking restore UX when `restoreOnLoginEnabled`
- [ ] `CrossDeviceSyncCoordinator` + realtime listener gating
- [ ] `AccountDeletionCoordinator` step order: remote → auth → local wipe
- [ ] `ownerUID` scoping in log services (`UserDataOwnerScope`)
- [ ] Outbox `mutationId` idempotency

**Verification tests:** `AccountSyncCoordinatorTests`, `AccountSyncUploaderTests`, `AccountRestoreEndToEndTests`, `CrossDeviceEndToEndSyncTests`, `AccountDeletionEndToEndTests`, `AccountDeletionCoordinatorTests`.

---

## Appendix B — Success Criteria (PRDX v1 Done)

| Criterion | Measurable |
|-----------|------------|
| Production snapshot defined & tested | `FormaAbTestProductionSnapshotTests` green |
| Runtime behavior unchanged | Weekly Progress + Coach golden tests green; manual smoke on Today/Journey/Coach |
| Release logs privacy-safe | `ReleaseLoggingGuardTests` green |
| Analytics ready but off | Sink disabled; configuration tested |
| CI exists | Workflow runs on PR |
| No account persistence regression | Integration + E2E sync/restore/deletion green |
| Compiler-clean | **Unknown** baseline — record warning count on first macOS run |

---

*End of implementation map.*
