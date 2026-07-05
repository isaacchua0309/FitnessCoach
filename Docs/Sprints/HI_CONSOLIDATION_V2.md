# Health Intelligence Consolidation v2 — Execution Map

**Sprint:** Health Intelligence Consolidation v2  
**Status:** In progress (Phase 1 landed in PR #178)  
**Last updated:** 2026-07-05  
**Owner domain:** Health Intelligence / Application StateBuilders  
**Related:** [../HealthIntelligence/CLEANUP_STATUS.md](../HealthIntelligence/CLEANUP_STATUS.md), [../TechnicalDebt/TechnicalDebtRegister.md](../TechnicalDebt/TechnicalDebtRegister.md) (TD-HI-002), [../Architecture/DependencyInjectionMap.md](../Architecture/DependencyInjectionMap.md), [../Testing/TestCommandCheatsheet.md](../Testing/TestCommandCheatsheet.md)

---

## 1. Sprint goal

Finish **behavior-neutral** consolidation of Health Intelligence presentation and loading across Today, Plan, and Journey by:

1. Reducing duplicated tab presentation logic so tab builders are thin layout adapters over a shared module.
2. Owning common loading and UI-state gating in `HealthIntelligenceSectionLoaderCore` and tab `*SectionLoader` types.
3. Retiring legacy HI compatibility paths only after characterization tests prove parity.
4. Unblocking AppContainer maintainability by extracting domain construction files.
5. Closing or nearly closing **TD-HI-002** without changing engines, permissions, flags, Coach AI, persistence, or user-visible output.

**Hard rule:** Refactor-only. No product behavior changes.

---

## 2. Current evidence and hotspots

### Evidence (confirmed in repo)

| Signal | Value | Source |
|--------|-------|--------|
| Triplicated HI presentation builders | ~2,800 LOC combined (pre-sprint) | `CODE_DEPTH_ANTI_PATTERNS_BLOAT_CONTEXT_PACKET.md`, TD-HI-002 |
| Shared presentation core exists | `HealthIntelligencePresentationCore` (610 LOC) | `Application/StateBuilders/HealthIntelligence/` |
| Section loaders were triplicated | Today inline in `TodayModel`; Journey/Plan dedicated loaders | TD-HI-002 |
| `AppContainer+Construction.swift` was dense | 1,004 LOC pre-sprint | `DependencyInjectionMap.md` |
| Deprecated HI paths documented | 9 rows in `CLEANUP_STATUS.md` § Deprecated | Do not delete without parity tests |
| Fast-Core blocked on some hosts | BW-101: test target cannot resolve `FirebaseCore` / GoogleSignIn | `BuildWarningsRegister.md` |
| HI test surface | 39 `*HealthIntelligence*Tests*` files + 3 test-support helpers | `Fitness CoachTests/` |

### Hotspots (priority order)

| Rank | Hotspot | Why it matters |
|------|---------|----------------|
| 1 | `JourneyHealthIntelligencePresentationBuilder.swift` (1,123 LOC) | Largest tab builder; weekly review, timeline, milestones, progress |
| 2 | `PlanHealthIntelligencePresentationBuilder.swift` (931 LOC) | Confidence, assumptions, data-quality, synthetic snapshot |
| 3 | `TodayHealthIntelligencePresentationBuilder.swift` (702 LOC) | Daily mission, next-best-action bridge, integration status |
| 4 | Legacy `*CompositionPolicy.swift` | Hides duplicate sections when HI UI enabled; blocks deprecated-path removal |
| 5 | Per-test `*MockRepository` proliferation | Loader tests duplicate mocks; increases maintenance cost |
| 6 | `AppContainer+Construction.swift` residual wiring | Journey/Plan model factories, persistence, coach, AI still in one file |

### Phase 1 outcome (PR #178)

| Deliverable | Status |
|-------------|--------|
| `HealthIntelligenceSectionLoaderCore` | Landed (160 LOC) |
| `TodayHealthIntelligenceSectionLoader` | Landed (175 LOC) |
| Journey/Plan loaders delegate to core | Landed |
| Tab builders delegate `resolveUIState` / integration input | Landed |
| `AppContainer+Analytics/Health/SyncDependencies` | Landed (−392 LOC from Construction) |
| Characterization tests for loader core + Today loader | Landed |

---

## 3. P0 scope (must complete for sprint success)

| # | Work item | Acceptance |
|---|-----------|------------|
| P0-1 | **Shared loader core owns common fetch/gating** | Today, Journey, Plan loaders call `HealthIntelligenceSectionLoaderCore` for snapshot+availability, connection classification, weekly-review load, UI-state resolution |
| P0-2 | **Today HI load extracted from `TodayModel`** | `TodayHealthIntelligenceSectionLoader` is the only load path; model wires analytics from loader result |
| P0-3 | **AppContainer construction split** | Health, sync, analytics bundles live in dedicated `AppContainer+*Dependencies.swift` files; public `AppContainer` API unchanged |
| P0-4 | **Characterization tests before legacy deletion** | New loader-core and Today-loader tests green; existing presentation/composition tests unchanged in intent |
| P0-5 | **Docs updated** | `CLEANUP_STATUS.md`, `TechnicalDebtRegister.md`, `DependencyInjectionMap.md`, this execution map |
| P0-6 | **Fast-Core status documented** | Either Fast-Core runs locally, or exact blocker (BW-101) recorded with repro command |

---

## 4. P1 scope (stretch / follow-up in same sprint if safe)

| # | Work item | Acceptance |
|---|-----------|------------|
| P1-1 | **Slim Journey presentation builder** | Move journey-specific card fragments (weekly review shell, recovery timeline rows, workout history rows) into `HealthIntelligencePresentationCore` or `HealthIntelligencePresentationModels` where tab-agnostic |
| P1-2 | **Slim Plan presentation builder** | Extract confidence/data-quality/signal mapping helpers shared with Journey where identical |
| P1-3 | **Slim Today presentation builder** | Move daily-mission and supplemental-action helpers that are pure mapping into core |
| P1-4 | **Consolidate loader test mocks** | Shared `HealthIntelligenceLoaderTestSupport` replaces per-file `*MockRepository` duplicates |
| P1-5 | **Retire 6+ deprecated CLEANUP_STATUS rows** | Only after parity tests; target ≤3 deprecated rows remaining |
| P1-6 | **Extract Journey/Plan factories from Construction** | `AppContainer+Construction.swift` ≤700 LOC if safely achievable |
| P1-7 | **Unblock Fast-Core on CI** | Resolve BW-101 or document permanent workaround in `BuildWarningsRegister.md` |

---

## 5. Explicit exclusions

Do **not** change in this sprint:

| Area | Exclusion |
|------|-----------|
| User-visible UI | Copy, layout order, card visibility, navigation |
| HI engines | `HealthIntelligenceEngine`, sub-engines, snapshot formulas |
| HealthKit | Permission prompts, read routing behavior, sync semantics |
| Feature flags | Defaults, production snapshot, runtime wiring |
| Weekly Progress | Formulas, recommendations, unified weekly review product loop |
| Coach AI | Prompts, routes, schemas, `CoachContextPacketV2` contracts |
| Account persistence | Restore, sync, deletion, export |
| SwiftData | Schemas, migrations, migration-only entities |
| Nutrition / Plan math | `FormaCalculationEngine`, targets, confidence scoring formulas |
| New product features | Notifications, analytics backends, new cards |
| Firebase Analytics | No new logging; no sensitive data in logs |
| TD-HI-001 | Weekly review presentation across Journey + HI (separate sprint) |

---

## 6. Current file-size baseline

Counts from `wc -l` on branch `cursor/health-intelligence-consolidation-v2-f6aa` (2026-07-05). **Pre-sprint** = `main` at sprint start.

| File | Pre-sprint (`main`) | Current | Δ | Sprint target |
|------|---------------------|---------|---|---------------|
| `TodayHealthIntelligencePresentationBuilder.swift` | 728 | **702** | −26 | Contribute to combined ≤1,500 |
| `PlanHealthIntelligencePresentationBuilder.swift` | 937 | **931** | −6 | Contribute to combined ≤1,500 |
| `JourneyHealthIntelligencePresentationBuilder.swift` | 1,134 | **1,123** | −11 | Contribute to combined ≤1,500 |
| **Three tab builders combined** | **2,799** | **2,756** | −43 | **≤1,500** (stretch; requires ~1,256 LOC extraction) |
| `HealthIntelligencePresentationCore.swift` | 610 | **610** | 0 | May grow; owns extracted card builders |
| `HealthIntelligencePresentationPolicy.swift` | 331 | **331** | 0 | Stable; surface-specific copy gating only |
| `AppContainer+Construction.swift` | 1,004 | **612** | −392 | **≤700** (achieved) |

### Related files (not in baseline table but tracked)

| File | Current LOC | Role |
|------|-------------|------|
| `HealthIntelligenceSectionLoaderCore.swift` | 160 | Shared loader/gating (new in v2) |
| `TodayHealthIntelligenceSectionLoader.swift` | 175 | Today load path (new in v2) |
| `AppContainer+AnalyticsDependencies.swift` | 62 | Extracted analytics bundle |
| `AppContainer+HealthDependencies.swift` | 159 | Extracted health/training bundle |
| `AppContainer+SyncDependencies.swift` | 199 | Extracted sync/restore/deletion bundle |

### Net duplication metric

| Metric | Pre-sprint | Current | Target |
|--------|------------|---------|--------|
| Tab builder LOC | 2,799 | 2,756 | ≤1,500 |
| Shared HI presentation module (`Core` + `Policy` + `SectionLoaderCore`) | 941 | 1,101 | Net **decrease** in total HI presentation LOC |
| Total HI presentation stack (builders + shared) | 3,740 | 3,857 | Lower than pre-sprint after P1 extractions |

---

## 7. Existing tests

### Fast-Core HI presentation / loader (run first)

| Test class | Covers |
|------------|--------|
| `HealthIntelligenceSectionLoaderCoreTests` | Shared fetch, connection, weekly review, connect-only gating |
| `TodayHealthIntelligenceSectionLoaderTests` | Today loader + fallback analytics context |
| `TodayHealthIntelligencePresentationBuilderTests` | Today section/cards/mission/NBA mapping |
| `PlanHealthIntelligencePresentationBuilderTests` | Plan confidence, data quality, assumptions |
| `PlanHealthIntelligenceSectionLoaderTests` | Plan loader integration |
| `JourneyHealthIntelligencePresentationBuilderTests` | Journey section, timeline, weekly review |
| `JourneyHealthIntelligenceSectionLoaderTests` | Journey loader, recovery days, workouts |
| `HealthIntelligenceCompositionTests` | Cross-surface composition invariants |
| `TodayHealthIntelligenceCompositionTests` | Today legacy vs HI section visibility |
| `JourneyHealthIntelligenceCompositionTests` | Journey legacy vs HI section visibility |
| `PlanDashboardHealthIntelligenceTests` | Plan dashboard HI gating |

### Model integration

| Test class | Covers |
|------------|--------|
| `TodayModelHealthIntelligenceTests` | Today model HI section state |
| `JourneyModelHealthIntelligenceTests` | Journey model HI refresh |
| `PlanModelHealthIntelligenceTests` | Plan model HI section load |

### Engine / pipeline (do not break)

| Test class | Covers |
|------------|--------|
| `HealthIntelligenceEngineTests` | Engine output |
| `HealthIntelligenceBaselineTests` | Baseline / plan confidence |
| `HealthIntelligenceContextBuilderTests` | Context assembly |
| `HealthIntelligenceUIStateTests` | UI state mapper |
| `HealthIntelligencePhase11*IntegrationTests` | Flag/sync/theme integration |
| `HealthIntelligencePhase1618*Tests` | Date/time hardening |
| `HealthIntelligencePipelineIntegrationTests` | End-to-end pipeline |
| `HealthIntelligenceProductionHardeningTests` | Production guards |

### Coach HI (adjacent — out of scope for deletion)

| Test class | Covers |
|------------|--------|
| `CoachHealthIntelligenceContextBuilderTests` | Coach HI context |
| `CoachContextHealthIntelligenceDefaultOnTests` | Coach HI default-on |
| `CoachAIHealthIntelligenceIntegrationTests` | Coach + HI integration |

### Test support

- `HealthIntelligencePipelineTestSupport.swift`
- `HealthIntelligencePhase11IntegrationTestSupport.swift`
- `HealthIntelligencePhase1618TestSupport.swift`

### Verification command

```bash
export DESTINATION='platform=iOS Simulator,name=iPhone 17'

xcodebuild test -scheme "Fitness Coach" -destination "$DESTINATION" -testPlan Fast-Core \
  -only-testing:"Fitness CoachTests/HealthIntelligenceSectionLoaderCoreTests" \
  -only-testing:"Fitness CoachTests/TodayHealthIntelligenceSectionLoaderTests" \
  -only-testing:"Fitness CoachTests/JourneyHealthIntelligenceSectionLoaderTests" \
  -only-testing:"Fitness CoachTests/PlanHealthIntelligenceSectionLoaderTests" \
  -only-testing:"Fitness CoachTests/TodayHealthIntelligencePresentationBuilderTests" \
  -only-testing:"Fitness CoachTests/JourneyHealthIntelligencePresentationBuilderTests" \
  -only-testing:"Fitness CoachTests/PlanHealthIntelligencePresentationBuilderTests" \
  -only-testing:"Fitness CoachTests/HealthIntelligenceCompositionTests" \
  -only-testing:"Fitness CoachTests/TodayHealthIntelligenceCompositionTests" \
  -only-testing:"Fitness CoachTests/JourneyHealthIntelligenceCompositionTests"
```

**Fast-Core blocker (BW-101):** On hosts where `xcodebuild build-for-testing` fails with `Unable to resolve module dependency: 'FirebaseCore'`, the full Fast-Core plan cannot run until SPM/Firebase test-target wiring is fixed. App target `xcodebuild build` succeeds. See [../TechnicalDebt/BuildWarningsRegister.md](../TechnicalDebt/BuildWarningsRegister.md).

---

## 8. Characterization strategy

### Principles

1. **Freeze behavior, not implementation.** Tests assert section states, card fields, visibility flags, and analytics contexts — not private helper names.
2. **Add before delete.** No deprecated path from `CLEANUP_STATUS.md` is removed until a test proves the replacement path produces identical presentation output for the same inputs.
3. **Pure builders only in unit tests.** Presentation builder tests use fixtures (`HealthIntelligenceSnapshot+Preview`, `WeeklyProgressFixtures`, loader mocks) — no HealthKit, no SwiftData.
4. **Composition policies are characterization boundaries.** `*CompositionPolicyTests` document which legacy sections hide when HI UI is enabled; keep green through refactors.
5. **Loader vs builder separation.** Loader tests assert `*BuildInput` / `*LoadResult`; builder tests assert `*SectionState` from fixed inputs.

### Required suites before each deletion

| Legacy path (CLEANUP_STATUS) | Gate tests |
|------------------------------|------------|
| Legacy composition policies | `TodayHealthIntelligenceCompositionTests`, `JourneyHealthIntelligenceCompositionTests`, `PlanDashboardHealthIntelligenceTests` |
| `HealthActivityQueryService` reader fallback | `HealthActivityQueryServiceRepositoryRoutingTests` |
| Workout calorie `max(manual, HealthKit)` merge | `TodayModelHealthIntelligenceTests`, `DailyReviewSummaryBuilderTests` |
| `normalizedSamples(for:)` | Repository routing + pipeline integration tests |
| Journey `workoutReader` fallback | `JourneyHealthIntelligenceSectionLoaderTests`, `JourneyModelHealthIntelligenceTests` |

### Regression signal

- If a refactor changes any `*SectionState` equatable output or composition-policy boolean, the PR is **not** behavior-neutral — revert or update fixtures with explicit review.

---

## 9. PR / commit boundaries

Keep commits small and reviewable. Suggested sequence:

| PR / commit | Scope | Files (representative) |
|-------------|-------|------------------------|
| **PR-1** ✅ Phase 1 | Loader core + Today loader + loader delegation + AppContainer split | `HealthIntelligenceSectionLoaderCore`, `TodayHealthIntelligenceSectionLoader`, `AppContainer+*Dependencies`, docs | 
| **PR-2** | Journey builder slimming | `JourneyHealthIntelligencePresentationBuilder` → core/models; extend `JourneyHealthIntelligencePresentationBuilderTests` |
| **PR-3** | Plan builder slimming | `PlanHealthIntelligencePresentationBuilder` → core; extend `PlanHealthIntelligencePresentationBuilderTests` |
| **PR-4** | Today builder slimming | `TodayHealthIntelligencePresentationBuilder` → core; daily-mission helpers |
| **PR-5** | Test mock consolidation | `TestingSupport/HealthIntelligenceLoaderTestSupport.swift`; dedupe loader mocks |
| **PR-6** | Deprecated path retirement (batch) | One CLEANUP_STATUS row per commit; composition + parity tests required |
| **PR-7** | Construction residual extract (optional) | Move `buildJourneyDependencies` / `buildPlanDependencies` to `AppContainer+FeatureFactories` or dedicated file |

**Commit message pattern:** `HI v2: <verb> <component> — behavior-neutral`

Do not mix engine changes, flag changes, or legacy deletions in the same commit as presentation extractions.

---

## 10. Rollback plan

### Per-PR rollback

1. Revert the merge commit on `main` (or close PR without merge).
2. No feature flags to flip — refactors are compile-time only.
3. Run Fast-Core HI subset (§7) on a Mac with Xcode to confirm green.

### Partial rollback (single file)

| Component | Rollback action |
|-----------|-----------------|
| `HealthIntelligenceSectionLoaderCore` | Revert core; restore inline logic in Journey/Plan loaders and presentation `resolveUIState` |
| `TodayHealthIntelligenceSectionLoader` | Revert loader; restore `TodayModel.refreshHealthIntelligenceSection` inline fetch |
| `AppContainer+*Dependencies` | Revert split; restore bundles + `build*` methods into `AppContainer+Construction.swift` |
| Deleted legacy path | **Do not partial-revert** — restore from git history only with characterization tests re-added |

### Risk notes

- Rollback of loader extraction is low risk (isolated to Application layer).
- Rollback of deprecated-path deletion may restore duplicate UI if composition policies were removed — treat deletions as non-reversible without a dedicated restore PR.

---

## 11. Final success metrics

| Metric | Baseline | Current (Phase 1) | Target | Status |
|--------|----------|-------------------|--------|--------|
| Three tab HI builders combined | 2,799 LOC | 2,756 LOC | **≤1,500 LOC** | ❌ Not met (−43 so far; ~1,256 LOC still to extract) |
| Net duplicated HI presentation LOC | High (3× ~930 LOC builders) | Modest reduction | **Net decrease** vs baseline | 🟡 In progress |
| `HealthIntelligencePresentationCore` growth | 610 LOC | 610 LOC | May grow if it absorbs shared card builders | ✅ Acceptable |
| `AppContainer+Construction.swift` | 1,004 LOC | **612 LOC** | **≤700 LOC** | ✅ Met |
| TD-HI-002 | Open | Mostly closed | Closed or tiny follow-up doc | 🟡 Mostly closed |
| Deprecated rows in `CLEANUP_STATUS` | 9 | 9 | **≤3 remaining** | ❌ Not started (deferred to P1) |
| Fast-Core HI subset | Unknown on cloud agent | Blocked (BW-101) | Runs locally or blocker documented | 🟡 Documented |
| User-visible behavior | — | Unchanged | Zero diffs in UI QA | ✅ Required |
| HI engine output | — | Unchanged | `HealthIntelligenceEngineTests` green | ✅ Required |

### Sprint done definition

The sprint is **complete** when:

1. P0 scope (§3) is merged to `main`.
2. Combined tab builders ≤1,500 LOC **or** a documented decision records why further extraction risks behavior drift (with test evidence).
3. Deprecated CLEANUP_STATUS rows ≤3, each with a tracked unblock in TD register or CLEANUP_STATUS.
4. Fast-Core HI subset passes on a standard Mac/Xcode host, or BW-101 is closed.
5. TD-HI-002 marked **Closed** in `TechnicalDebtRegister.md`.

### Realistic assessment (2026-07-05)

- **Achievable in v2:** Loader consolidation, AppContainer split, Today load extraction, TD-HI-002 near-close.
- **Stretch:** Combined builders ≤1,500 LOC requires aggressive P1 extraction from Journey (~600+ LOC) and Plan (~400+ LOC) into core without blurring tab-specific layout ownership.
- **Blocked without follow-up:** Deprecated-path count ≤3 depends on `healthIntelligenceUIEnabled` permanent-on decision (product/flag sprint, not this refactor alone).

---

## Revision history

| Date | Change |
|------|--------|
| 2026-07-05 | Initial execution map; Phase 1 metrics from PR #178 |
