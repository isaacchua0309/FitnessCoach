# PRDX Platform Infrastructure v1

**Sprint:** Production Readiness + Developer Experience — platform contracts  
**Last updated:** 2026-07-05  
**Related:** [PRDX_V1_FLAG_MATRIX.md](../Architecture/PRDX_V1_FLAG_MATRIX.md), [DependencyInjectionMap.md](../Architecture/DependencyInjectionMap.md), [TestCommandCheatsheet.md](../Testing/TestCommandCheatsheet.md)

---

## Goal

Make platform contracts explicit and testable without changing user-visible behavior.

Concrete outcomes:

- CI can run Fast-Core and `functions` checks on pull requests.
- Feature flags distinguish **runtime** (`allEnabled`) from **production intent** (`FormaAbTestSnapshot.production`) with tests.
- Logging and analytics have documented, testable Release-safe defaults (NoOp analytics, redaction, allowlist guard).
- `AppContainer` init-time wiring is split into typed dependency bundles with a thin construction delegate layer.

---

## Non-goals

- No Release production flag flip (`FormaAbTest.snapshot()` must keep resolving `allEnabled` in Release for this sprint)
- No Firebase Analytics SDK integration or production analytics sink wiring
- No Health Intelligence, Auth, or Coach feature refactors (models, coordinators, presentation builders, routing)
- No account sync / restore / deletion semantic changes
- No broad Swift 6 concurrency burn-down

---

## Implementation status (honest)

> **Do not treat this sprint as shipped until PRs are merged to `main` and CI is green.**

As of **2026-07-05**, most deliverables below are **implemented on stacked `cursor/*-38a8` feature branches** (open draft PRs). They are **not** on `main` yet. Local verification requires checking out the latest stack tip (e.g. `cursor/finalize-appcontainer-construction-38a8`) or merging the PR chain.

| Area | Status | Notes |
|------|--------|-------|
| Fast-Core SPM / serial runner | Implemented on branch | PR #180 — `Fitness CoachTests` SPM linkage, strip-duplicate-frameworks phase, `Scripts/run-fast-core-serial.sh` |
| PR CI workflow | Implemented on branch | `.github/workflows/prdx-ci.yml` — `functions` + `ios-fast-core` jobs |
| `FormaAbTest.resolvedSnapshot(for:)` | Implemented on branch | Not present on `main` today |
| Production intent snapshot tests | Implemented on branch | `FormaAbTestResolvedSnapshotTests`, `FormaAbTestProductionSnapshotTests` |
| PRDX flag matrix | Implemented on branch | `Docs/Architecture/PRDX_V1_FLAG_MATRIX.md` |
| `FormaLogRedactor` | Implemented on branch | PR #184 |
| Release logging guard | Implemented on branch | PR #187 — allowlist JSON + `ReleaseLoggingGuardTests` |
| Analytics sink scaffolding | Implemented on branch | PR #189 — `FormaAnalyticsConfiguration`, composite loggers; Release remains NoOp |
| `dataExportEnabled` dead-flag cleanup | Implemented on branch | PR #182 — removed from `FormaAbTest`; export uses `AccountDataExportPolicy` |
| AppContainer dependency bundles | Implemented on branch | PRs #191–#196 — `Fitness Coach/App/Dependencies/*.swift`; `AppContainer+Construction.swift` → **145 LOC** delegate layer |
| **Merged to `main`** | **Partial** | `FormaAbTest.swift` on `main` documents production intent concept but lacks `resolvedSnapshot(for:)` and sprint tests |

---

## P0 deliverables

| Deliverable | Intent | Primary artifacts |
|-------------|--------|-------------------|
| Fast-Core unblocked | `Fitness CoachTests` compiles and Fast-Core runs serially without SPM duplicate-framework crashes | `Fitness Coach.xcodeproj/project.pbxproj`, `Scripts/run-fast-core-serial.sh`, `TestPlans/Fast-Core.xctestplan` |
| PR CI workflow | Gate PRs with functions lint/test + iOS Fast-Core | `.github/workflows/prdx-ci.yml` |
| `FormaAbTest.resolvedSnapshot(for:)` | Explicit runtime vs production-intent resolution without flipping Release runtime | `Fitness Coach/Configuration/FormaAbTest.swift` |
| Production intent snapshot tests | Guard `FormaAbTestSnapshot.production` against checklist drift | `FormaAbTestResolvedSnapshotTests.swift`, `FormaAbTestProductionSnapshotTests.swift`, `FormaAbTestProductionCriticalFlagsTests.swift` |
| PRDX flag matrix | Document runtime vs intent per flag | `Docs/Architecture/PRDX_V1_FLAG_MATRIX.md`, `FeatureFlagRegistry.md` |
| `FormaLogRedactor` | Shared secret/UID/query redaction | `Fitness Coach/Infrastructure/Diagnostics/FormaLogRedactor.swift`, `LogRedactor.swift` delegates |
| Release logging guard tests | Fail CI when new Release-reachable logging lacks allowlist entry | `ReleaseLoggingGuard.swift`, `ReleaseLoggingAllowlist.json`, `ReleaseLoggingGuardTests.swift`, `ReleaseLoggingAllowlist.md` |

---

## P1 deliverables

| Deliverable | Intent | Primary artifacts |
|-------------|--------|-------------------|
| AppContainer dependency bundles | Move init-time construction into typed bundles; keep public `AppContainer` API stable | `Fitness Coach/App/Dependencies/*.swift`, thin `AppContainer+Construction.swift` |
| Analytics sink scaffolding | Explicit configuration + composite routing; **no** production adapter | `FormaAnalyticsConfiguration.swift`, `AnalyticsLoggerFactory.swift`, `CompositeAnalyticsLoggers.swift`, `AnalyticsInfrastructureTests.swift` |
| Dead flag cleanup (`Settings.dataExportEnabled`) | Remove unused `FormaAbTest` field; document export policy source of truth | `FormaAbTest.swift`, production checklists, guard test in `FormaAbTestProductionSnapshotTests` |

### AppContainer bundle ownership (`Fitness Coach/App/Dependencies/`)

| File | Owns |
|------|------|
| `AuthDependencies.swift` | Auth session, onboarding prefs, refresh bus |
| `AnalyticsDependencies.swift` | Analytics configuration + domain loggers |
| `HealthDependencies.swift` | HealthKit, cache, sync, training platform |
| `PersistenceDependencies.swift` | SwiftData, account sync core, log services |
| `HealthIntelligenceDependencies.swift` | HI engine, snapshot, weekly review wiring |
| `CoachPlatformDependencies.swift` | Coach timeline/transcript/backfill platform (not `CoachDependencies` feature assembly) |
| `AIDependencies.swift` | LLM client, `AIService`, DEBUG wiring logs |
| `SyncDependencies.swift` | Restore, cross-device sync, deletion, export |
| `SettingsDependencies.swift` | `ThemeStore` |
| `TodayDependencies.swift` | `ReviewService`, `FitnessActionCenter` |

`AppContainer+Construction.swift` retains legacy `typealias *Bundle` names and `build*Dependencies()` delegates only. Journey/Plan model wiring lives in `AppContainer+FeatureFactories.swift`.

---

## Behavior guarantees

| Guarantee | How enforced |
|-----------|----------------|
| Runtime remains `allEnabled` | `FormaAbTest.resolvedSnapshot(for: .release)` → `allEnabled`; `FormaAbTest.snapshot()` unchanged for live app |
| Release analytics remains NoOp | `FormaAnalyticsConfiguration.releaseDefault`, `AnalyticsLoggerFactory` + `AnalyticsInfrastructureTests` |
| User-visible behavior unchanged | No feature model/coordinator refactors; DI extraction only moves construction |
| Account persistence semantics unchanged | `SyncDependencies` / `PersistenceDependencies` are wiring moves only; account test suites are regression gates |

---

## File map

### CI and scripts

| Path | Change |
|------|--------|
| `.github/workflows/prdx-ci.yml` | **Added** — PRDX CI (`functions`, `ios-fast-core`) |
| `Scripts/run-fast-core-serial.sh` | **Added** — serial Fast-Core runner with simulator fallback |
| `Fitness Coach.xcodeproj/project.pbxproj` | **Modified** — Fast-Core test target SPM / strip-duplicate-frameworks |
| `TestPlans/Fast-Core.xctestplan` | **Modified** — new test classes |

### Flags and configuration

| Path | Change |
|------|--------|
| `Fitness Coach/Configuration/FormaAbTest.swift` | **Modified** — `FormaRuntimeEnvironment`, `resolvedSnapshot(for:)`, production intent docs |
| `Docs/Architecture/PRDX_V1_FLAG_MATRIX.md` | **Added** |
| `Docs/Architecture/FeatureFlagRegistry.md` | **Modified** — links matrix; `dataExportEnabled` removed |
| `Docs/Production/*Checklist.md` | **Modified** — align export/flag references |

### Logging and privacy

| Path | Change |
|------|--------|
| `Fitness Coach/Infrastructure/Diagnostics/FormaLogRedactor.swift` | **Added** |
| `Fitness Coach/Infrastructure/Diagnostics/LogRedactor.swift` | **Modified** — delegates to `FormaLogRedactor` |
| `Fitness CoachTests/Fixtures/ReleaseLoggingAllowlist.json` | **Added** |
| `Fitness CoachTests/TestingSupport/ReleaseLoggingGuard.swift` | **Added** |
| `Fitness CoachTests/ReleaseLoggingGuardTests.swift` | **Added** |
| `Docs/Architecture/ReleaseLoggingAllowlist.md` | **Added** |
| `Docs/Architecture/LoggingAndPrivacyContract.md` | **Modified** |
| Various debug log call sites | **Modified** — `#if DEBUG` hardening / redaction (see diff) |

### Analytics infrastructure

| Path | Change |
|------|--------|
| `Fitness Coach/App/FormaAnalyticsConfiguration.swift` | **Added** |
| `Fitness Coach/App/AnalyticsLoggerFactory.swift` | **Modified** — configuration + composite resolve |
| `Fitness Coach/Infrastructure/Diagnostics/CompositeAnalyticsLoggers.swift` | **Added** |
| `Fitness CoachTests/AnalyticsInfrastructureTests.swift` | **Extended** |
| `Docs/Architecture/AnalyticsReadinessChecklist.md` | **Modified** |

### AppContainer DI

| Path | Change |
|------|--------|
| `Fitness Coach/App/Dependencies/*.swift` (10 files) | **Added** — typed init-time bundles |
| `Fitness Coach/App/AppContainer+Construction.swift` | **Modified** — **145 LOC** thin delegates (was ~1005 LOC pre-sprint) |
| `Fitness Coach/App/AppContainer+FeatureFactories.swift` | **Modified** — Journey/Plan wiring inlined |
| `Fitness CoachTests/AppContainerConstructionTests.swift` | **Added/extended** |
| `Docs/Architecture/DependencyInjectionMap.md` | **Modified** |

### Tests (new or materially extended)

| Path |
|------|
| `Fitness CoachTests/FormaAbTestResolvedSnapshotTests.swift` |
| `Fitness CoachTests/FormaAbTestProductionSnapshotTests.swift` |
| `Fitness CoachTests/FormaLogRedactorTests.swift` |
| `Fitness CoachTests/ReleaseLoggingGuardTests.swift` |
| `Fitness CoachTests/AnalyticsInfrastructureTests.swift` |
| `Fitness CoachTests/AppContainerConstructionTests.swift` |

### Documentation

| Path |
|------|
| `Docs/Testing/TestCommandCheatsheet.md` |
| `Docs/TechnicalDebt/BuildWarningsRegister.md` |
| `Docs/TechnicalDebt/ProjectHygieneRegister.md` |
| `Fitness CoachTests/TESTING.md` |

---

## Test plan

All commands assume repo root on **macOS with Xcode**. Documented / CI destination: `platform=iOS Simulator,name=iPhone 17`.

### Fast-Core (full sprint gate)

```bash
./Scripts/run-fast-core-serial.sh
```

Equivalent explicit command:

```bash
xcodebuild test \
  -scheme "Fitness Coach" \
  -destination "platform=iOS Simulator,name=iPhone 17" \
  -testPlan Fast-Core \
  -parallel-testing-enabled NO
```

### Functions (matches PRDX CI `functions` job)

```bash
npm --prefix functions ci
npm --prefix functions run lint
npm --prefix functions test
```

### Flag / production intent tests

```bash
xcodebuild test \
  -scheme "Fitness Coach" \
  -destination "platform=iOS Simulator,name=iPhone 17" \
  -only-testing:"Fitness CoachTests/FormaAbTestResolvedSnapshotTests" \
  -only-testing:"Fitness CoachTests/FormaAbTestProductionSnapshotTests" \
  -only-testing:"Fitness CoachTests/FormaAbTestProductionCriticalFlagsTests"
```

### Logging / redaction tests

```bash
xcodebuild test \
  -scheme "Fitness Coach" \
  -destination "platform=iOS Simulator,name=iPhone 17" \
  -only-testing:"Fitness CoachTests/FormaLogRedactorTests" \
  -only-testing:"Fitness CoachTests/ReleaseLoggingGuardTests"
```

### Analytics infrastructure tests

```bash
xcodebuild test \
  -scheme "Fitness Coach" \
  -destination "platform=iOS Simulator,name=iPhone 17" \
  -only-testing:"Fitness CoachTests/AnalyticsInfrastructureTests"
```

### AppContainer construction tests

```bash
xcodebuild test \
  -scheme "Fitness Coach" \
  -destination "platform=iOS Simulator,name=iPhone 17" \
  -only-testing:"Fitness CoachTests/AppContainerConstructionTests"
```

### App build smoke

```bash
xcodebuild build \
  -scheme "Fitness Coach" \
  -destination "platform=iOS Simulator,name=iPhone 17"
```

### SPM resolution (pre-flight, matches CI)

```bash
xcodebuild -resolvePackageDependencies -project "Fitness Coach.xcodeproj"
```

### CI parity reference

Workflow: `.github/workflows/prdx-ci.yml` — runs `functions` and `ios-fast-core` in parallel on `pull_request` and `workflow_dispatch`.

---

## Risks

| Risk | Mitigation |
|------|------------|
| CI simulator availability (`iPhone 17` missing on runner) | Document fallback in `run-fast-core-serial.sh`; install iOS 26.5 simulator on `macos-latest` or pin fallback device in workflow |
| Xcode SPM resolution failures | CI runs `-resolvePackageDependencies`; see BW-101 in `BuildWarningsRegister.md` |
| Over-broad Release logging allowlist | Require specific JSON entries + `ReleaseLoggingAllowlist.md` review; guard test fails on unlisted sites |
| Accidental feature flag flip | `FormaAbTestProductionSnapshotTests` + explicit non-goal; Release resolver must stay `allEnabled` until separate release PR |
| `AppContainer` init ordering regressions | Preserve init sequence in `AppContainer.swift`; `AppContainerConstructionTests` + account persistence Fast-Core suites |
| Stacked PR merge order | Merge bottom-up: Fast-Core/CI → flags/logging → analytics → DI bundles; resolve conflicts in `AppContainer+Construction.swift` delegates only |
| Draft PRs not on `main` | Treat sprint as **in progress** until merge + green CI on `main` |

---

## Rollback plan

Each platform change is designed to revert independently via focused revert commits or PR rollback.

| Change area | Rollback | User impact if reverted alone |
|-------------|----------|-------------------------------|
| Fast-Core / SPM test target | Revert `project.pbxproj` + strip script + `run-fast-core-serial.sh` | Local/CI tests may fail to link; **app runtime unaffected** |
| PRDX CI workflow | Delete or disable `.github/workflows/prdx-ci.yml` | CI stops gating PRs; **app runtime unaffected** |
| `resolvedSnapshot(for:)` + production tests | Revert `FormaAbTest.swift` + new test files | Loses explicit intent API; runtime unchanged if `snapshot()` untouched |
| Flag matrix docs | Revert `PRDX_V1_FLAG_MATRIX.md` / registry edits | Documentation only |
| `FormaLogRedactor` | Revert `FormaLogRedactor.swift` + `LogRedactor` delegation | Prior redaction behavior restored; audit call sites |
| Release logging guard | Revert allowlist JSON, guard scanner, tests | Loses CI guard; does not add logging |
| Analytics scaffolding | Revert `FormaAnalyticsConfiguration`, factory changes, composites | Release returns to prior NoOp-only factory paths |
| `dataExportEnabled` removal | Revert `FormaAbTest` field + docs (not recommended — field was dead) | No runtime change if field remains unused |
| AppContainer bundles | Revert `Dependencies/*.swift`; restore monolithic `AppContainer+Construction.swift` | **Must** keep `AppContainer` public API identical; no feature behavior change if wiring copied faithfully |
| DEBUG log hardening | Revert per-file `#if DEBUG` / redaction edits | Potential Release log exposure if guards were fixing real gaps — re-audit before revert |

**Full sprint rollback:** revert the merge commit(s) on `main` in reverse order. Run Fast-Core + flag + logging + analytics + `AppContainerConstructionTests` after each revert step to localize regressions.

---

## Remaining dense areas (post-bundle extraction)

| Location | Contents | Notes |
|----------|----------|-------|
| `AppContainer+FeatureFactories.swift` | Feature `make*Model()` factories, Coach context-packet builder | Appropriate home for feature wiring |
| `SyncDependencies.swift` (~194 LOC) | Account restore / deletion / export construction | Largest bundle; still single domain |
| `HealthDependencies.swift` (~157 LOC) | HealthKit + sync platform | Cohesive health platform scope |
| `PersistenceDependencies.swift` (~147 LOC) | SwiftData + account sync core | Future extraction candidate only if tests stay green |

---

## Suggested merge sequence (when executing)

1. Fast-Core SPM fix + `run-fast-core-serial.sh` + CI workflow  
2. `FormaAbTest.resolvedSnapshot(for:)` + flag matrix + production snapshot tests  
3. `FormaLogRedactor` + Release logging guard  
4. Analytics sink scaffolding (NoOp preserved)  
5. `dataExportEnabled` dead-flag cleanup  
6. AppContainer dependency bundles (analytics → auth → health → sync → coach platform → finalize extraction)  

After each merge: run **Fast-Core** + the focused test slices listed above.

---

## Metrics (branch stack tip)

| Metric | Value |
|--------|-------|
| `AppContainer+Construction.swift` (pre-sprint) | ~1005 LOC |
| `AppContainer+Construction.swift` (post-extraction, branch) | **145 LOC** |
| Typed dependency bundle files | 10 under `Fitness Coach/App/Dependencies/` |

---

## References

- Planning map (historical): `Docs/Archive/SprintReports/PRDX_V1_IMPLEMENTATION_MAP.md`
- Open PR stack (2026-07-05): #180, #182, #184, #187, #189, #191–#196 (draft; verify on GitHub before merge)
