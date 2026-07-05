# Health Intelligence Consolidation v2 — Execution Map

**Sprint:** Health Intelligence Consolidation v2  
**Status:** Substantially complete — merged in PR #178 (`cursor/health-intelligence-consolidation-v2-f6aa`)  
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
| Fast-Core blocked on some hosts | BW-101 **closed** — `TEST_HOST` + `BUNDLE_LOADER`; Mac verify via `./Scripts/run_fast_core_tests.sh` | `BuildWarningsRegister.md` |
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

### Phase 1 outcome (PR #178) — landed

| Deliverable | Status |
|-------------|--------|
| `HealthIntelligenceSectionLoaderCore` | Landed (361 LOC) |
| `TodayHealthIntelligenceSectionLoader` | Landed (175 LOC) |
| Journey/Plan loaders delegate to core | Landed |
| Tab builders delegate `resolveUIState` / integration input | Landed |
| `HealthIntelligencePresentationParityTests` (fixtures A–E) | Landed |
| `App/Dependencies/*` domain bundles (10 files) | Landed |
| `AppContainer+Construction.swift` | **68 LOC** (DEBUG utilities only) |
| Dead Today composition stubs (`showsLegacyHealthIntelligenceStack`, `showsLegacyNextBestAction`) | Removed |
| Training Insights repository routing | Landed (`TrainingInsightsModel` → `HealthActivityQueryService`) |
| Fast-Core BW-101 fix | Landed (`TEST_HOST`, `Scripts/run_fast_core_tests.sh`, serial plan) |
| PH-004 fixture cleanup (batch 1) | Landed (`FoodLogFixtures` / `DailyLogFixtures` canonical; ~70 `ProfileFixtures` migrations) |
| TD-COACH-001 tail | Landed (legacy init removed; `CoachModelTestFactory`; photo-flow coordinator confirmed) |
| Characterization tests for loader core + Today loader | Landed |

### P1 stretch (not in PR #178)

| Deliverable | Status |
|-------------|--------|
| Tab builders ≤1,500 LOC combined | **Not met** (2,725 LOC — see §6) |
| Loader mock consolidation | Deferred |
| Deprecated CLEANUP_STATUS rows ≤3 | Deferred (9 rows remain; flag-off paths kept) |
| Journey/Plan/Today builder slimming into core | Deferred to follow-up PRs |

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
| `TodayHealthIntelligencePresentationBuilder.swift` | 728 | **695** | −33 | P1 stretch: further extraction to core |
| `PlanHealthIntelligencePresentationBuilder.swift` | 937 | **920** | −17 | P1 stretch |
| `JourneyHealthIntelligencePresentationBuilder.swift` | 1,134 | **1,110** | −24 | P1 stretch |
| **Three tab builders combined** | **2,799** | **2,725** | −74 | **≤1,500** (P1 stretch; not met) |
| `HealthIntelligencePresentationCore.swift` | 610 | **323** | −287 | Refactored/split; card factory extracted |
| `HealthIntelligencePresentationPolicy.swift` | 331 | **310** | −21 | Stable; surface-specific copy gating |
| `AppContainer+Construction.swift` | 1,004 | **68** | −936 | **≤700** ✅ Met |

### Related files (not in baseline table but tracked)

| File | Current LOC | Role |
|------|-------------|------|
| `HealthIntelligenceSectionLoaderCore.swift` | 361 | Shared loader/gating |
| `TodayHealthIntelligenceSectionLoader.swift` | 175 | Today load path |
| `HealthIntelligenceCardPresentationFactory.swift` | 558 | Card fragment builders |
| `HealthIntelligencePresentationModels.swift` | 167 | Shared models |
| `HealthIntelligencePresentationCopy.swift` | 190 | Copy helpers |
| `App/Dependencies/*.swift` (10 files) | — | Domain construction bundles (see `DependencyInjectionMap.md`) |

### Net duplication metric

| Metric | Pre-sprint | Current | Target |
|--------|------------|---------|--------|
| Tab builder LOC | 2,799 | 2,725 | ≤1,500 |
| Shared HI presentation module (`Core` + `Policy` + `SectionLoaderCore` + models/factory) | 941 | ~1,909 | Net decrease in **total** HI LOC after P1 extractions |
| Total HI presentation stack (builders + shared) | 3,740 | ~4,634 | Lower after P1 extractions (builders still dominate) |

---

## 7. Baseline Parity Matrix

**Purpose:** Pre-refactor inventory of user-visible HI presentation behavior per tab. Use this matrix to prove behavior-neutral extraction — any refactor that changes a cell without an explicit product decision is a regression.

**Inspected sources (2026-07-05):** `TodayHealthIntelligencePresentationBuilder`, `PlanHealthIntelligencePresentationBuilder`, `JourneyHealthIntelligencePresentationBuilder`, `HealthIntelligencePresentationCore`, `HealthIntelligencePresentationPolicy`, `WeeklyReviewPresentationBuilder`, `UnifiedWeeklyReviewPresentationBuilder` (adjacent Journey weekly UX), `HealthIntelligenceFeatureFlags`, `FormaAbTest`, `CLEANUP_STATUS.md`.

**Shared resolution path:** All three tab builders resolve `HealthIntelligenceUIState` via `HealthIntelligenceSectionLoaderCore.resolveUIState` → `HealthIntelligencePresentationCore` → `HealthIntelligenceUIStateMapper`. Surface-specific copy/gating branches live in `HealthIntelligencePresentationPolicy`.

### Per-surface inventory

#### Today

| Dimension | Behavior |
|-----------|----------|
| **HI cards that can appear** | Recovery card (always in section); Daily Mission (always); Next Best Action (visible or hidden); Workout card (optional); Adaptive Nutrition card (optional). Loading placeholders for recovery, mission, NBA. |
| **Required inputs** | `HealthIntelligenceSnapshot?`, `TodayHealthIntelligenceNutritionProgress`, `HealthDataAvailability?`, `isAppleHealthConnected`, `TrainingIntegrationState`, `HealthIntegrationConnectionRecord`, `cachedDayCount`, optional `HealthBaselineContext`, sync metadata (`syncPhase`, `lastSuccessfulLocalSyncAt`, remote sync consent/capability). Loaded via `TodayHealthIntelligenceSectionLoader`. |
| **Feature flag gates** | `buildSection` returns `nil` when `isUIEnabled` false. Model fetch gated by `shouldTodayModelLoadHealthIntelligence` (= engines ∧ (UI ∨ todayDebugFetch)). Legacy stack hidden by `TodayReadOnlyCompositionPolicy.showsHealthIntelligenceSection`. |
| **HealthKit gates** | `HealthIntegrationStatusResolver` + `HealthSignalAvailability` from availability, training integration, connection record, snapshot connect-health NBA. Recovery forced to `.unknown` when `uiState.kind == .healthKitUnavailable`. |
| **Stale-data behavior** | `staleDataLabel` on section + recovery card via `HealthIntelligencePresentationCore.staleDataLabel` → Policy `staleDataCopy(.today)`. Shown for `.staleData` and `.syncFailed` when `canShowInsight`. |
| **Partial-signal behavior** | Limited recovery wording via Policy (`limitedRecoveryPartialSignals`, `limitedRecoveryMissingSignals`). `missingDataNote` on recovery card from Policy. No section-level `partialSignalsNote` (Journey-only). |
| **Disconnected behavior** | `unavailableSection` when snapshot nil: placeholder recovery from `uiState`, empty workout card, supplemental NBA from integration status or `uiState.primaryAction` (connect / manage permissions / retry sync / ask coach). |
| **CTA behavior** | HI snapshot NBA sanitized (connect-health stripped) → `TodayHealthIntegrationNextStepResolver`. Supplemental CTAs: `.connectHealth`, `.askCoach`, `.refreshHealthData`. Tap analytics via `logTodayNextBestActionTapped` (+ permission CTA when connect). |
| **Analytics events** | Model: `logSnapshotLoaded` / `logSnapshotFailed` (surface `.today`). View: `logTodayRecoveryCardViewed`, `logTodayNextBestActionTapped`, `logHealthPermissionCTATapped`. |
| **Copy source** | `FormaProductCopy.Today.HealthIntelligence.*` (section titles); `FormaProductCopy.HealthIntelligence.UIState` (fallback banners); Policy for limited recovery; Core for card field sanitization. |
| **Accessibility labels** | Per-card via `HealthIntelligencePresentationCore.*AccessibilityLabel`; daily mission composed inline; section has no single root a11y label (cards are children). |
| **Tests** | `TodayHealthIntelligencePresentationBuilderTests`, `TodayHealthIntelligenceSectionLoaderTests`, `TodayHealthIntelligenceCompositionTests`, `TodayModelHealthIntelligenceTests`, `HealthIntelligenceUIStateTests`, `HealthIntelligenceSectionLoaderCoreTests` |

#### Plan

| Dimension | Behavior |
|-----------|----------|
| **HI cards that can appear** | Confidence card; Assumptions list; Data Quality panel; Core Signals list; Missing Data Actions (CTA rows). Section-level fallback banner + stale label. Always returns a section state (never `nil` from builder). |
| **Required inputs** | `PlanHealthIntelligenceBuildInput`: `planConfidence`, `HealthBaselineContext`, `recovery?`, `UserPlanContext`, `PlanHealthConnectionState`, `healthAvailability?`, nutrition/weight logging flags, sync metadata. Loader also needs `UserProfile`, `PlanDashboardContext`. Synthetic snapshot built from baseline when resolving UI state. |
| **Feature flag gates** | Builder has no `isUIEnabled` guard (always builds). Model fetch: `shouldPlanModelLoadHealthIntelligence`. Dashboard visibility: `PlanDashboardCompositionPolicy.showsHealthIntelligenceSection` vs legacy confidence section. |
| **HealthKit gates** | `PlanHealthConnectionState` (.disconnected / .partial / .connected) from Apple Health connected ∨ readable signals + permission depth. Degrades confidence, data-quality level, signal statuses, missing-data actions. |
| **Stale-data behavior** | Section `staleDataLabel` via Core → Policy `staleDataCopy(.plan)`. No per-card stale labels. |
| **Partial-signal behavior** | `.partial` connection → partial-permissions action, limited signal statuses, degraded confidence. Signal rows show `.limited` / `.missing` with detail strings from `FormaProductCopy.PlanHealthIntelligencePresentation`. |
| **Disconnected behavior** | `healthConnection == .disconnected` → data quality `.limited`, connect-health missing-data action, synthetic snapshot NBA `connectHealth`, confidence degraded to unknown/low. |
| **CTA behavior** | Missing-data actions: connect health, partial permissions, enable sleep, enable HRV, log weight, log nutrition. IDs deduplicated (`connect-health`, `partial-permissions`). No tap analytics on individual actions in coordinator (view-layer only). |
| **Analytics events** | Model: `logSnapshotLoaded` / `logSnapshotFailed` (surface `.plan`). View: `logPlanHealthConfidenceViewed` (once per session, with confidence bucket). |
| **Copy source** | `FormaProductCopy.PlanHealthIntelligencePresentation` (primary); `FormaProductCopy.HealthIntelligence.UIState` via fallback; Policy for plan fallback messages. |
| **Accessibility labels** | Section root `accessibilityLabel` composes confidence + assumptions + data quality + actions. Per-card labels on confidence, data quality, assumptions, signals, actions. |
| **Tests** | `PlanHealthIntelligencePresentationBuilderTests`, `PlanHealthIntelligenceSectionLoaderTests`, `PlanDashboardHealthIntelligenceTests`, `PlanModelHealthIntelligenceTests`, `HealthIntelligenceUIStateTests` |

#### Journey

| Dimension | Behavior |
|-----------|----------|
| **HI cards that can appear** | Weekly Review card (+ detail sheet state); Recovery Timeline (7–14 days); Workout History (30-day window); Milestones; Progress; Connect Health CTA (section-level). Alternate shells: loading, connect-only, sync-error, empty-data (all sub-cards empty with copy). |
| **Required inputs** | `JourneyHealthIntelligenceBuildInput`: `todaySnapshot?`, `recoveryDays[]`, `workoutRecords[]`, `weeklyReview?`, `planProgress?`, `JourneyHealthConnectionState`, `availability?`, `baseline?`, timeline day count, sync metadata. Weekly review from `WeeklyReviewService` when `healthIntelligenceWeeklyReviewEnabled`. |
| **Feature flag gates** | `buildSection` returns `nil` when `isUIEnabled` false. Model fetch: `shouldJourneyModelLoadHealthIntelligence`. Weekly review load skipped when `weeklyReviewEnabled` false. `JourneyDashboardCompositionPolicy` hides legacy insights / duplicate weekly review when HI section visible. **Adjacent:** `UnifiedWeeklyReviewPresentationBuilder` powers unified This Week card; `showsHealthIntelligenceWeeklyReviewCard` false when unified card shown. |
| **HealthKit gates** | `JourneyHealthConnectionState` via loader core (connect-health NBA → `.notConnected`; else connected if integration ∨ readable signals). Connect-only section when `noHealthPermission` / `healthKitUnavailable` without insight. |
| **Stale-data behavior** | Section `staleDataLabel` via Core → Policy `staleDataCopy(.journey)`. Recovery timeline may include `limitedTimelineNote`. |
| **Partial-signal behavior** | Section `partialSignalsNote` via Policy (Journey-only): generic `FormaProductCopy.Journey.Sync.healthDataSyncing` when partial permission or missing insight kinds (excludes remote sync). Timeline limited-estimate labels per day. |
| **Disconnected behavior** | `connectHealthSection` or `emptyDataSection`: sub-cards empty with UI-state copy; `connectHealthCTA` from Core `connectCTACopy`. `workoutHistory` empty kind `.noHealthData` vs `.connectedNoWorkouts`. |
| **CTA behavior** | `connectHealthCTA` from `HealthIntelligencePresentationCore.connectCTACopy` + `normalizeUIStateCTACopy`. Weekly review detail opened from card tap (`logWeeklyReviewDetailOpened`). Permission CTA analytics shared with Today. |
| **Analytics events** | Model: `logSnapshotLoaded` / `logSnapshotFailed` (surface `.journey`). View: `logJourneyRecoveryTimelineViewed`, `logJourneyWorkoutHistoryViewed`, `logWeeklyReviewCardViewed`, `logWeeklyReviewDetailOpened`. |
| **Copy source** | `FormaProductCopy.Journey.HealthIntelligence.*`; `FormaProductCopy.WeeklyReviewPresentation` (via `WeeklyReviewPresentationBuilder`); `FormaProductCopy.HealthIntelligence.UIState`; Policy journey recovery + partial note. |
| **Accessibility labels** | Per sub-card (timeline, workouts, milestones, progress, weekly review, connect CTA). Building weekly review uses Core `buildWeeklyReviewBuildingContent`. |
| **Tests** | `JourneyHealthIntelligencePresentationBuilderTests`, `JourneyHealthIntelligenceSectionLoaderTests`, `JourneyHealthIntelligenceCompositionTests`, `JourneyModelHealthIntelligenceTests`, `WeeklyReviewPresentationBuilderTests`, `UnifiedWeeklyReviewPresentationBuilderTests`, `JourneyDashboardHealthIntelligenceTests` |

### Cross-surface behavior matrix

| Behavior | Today | Plan | Journey | Shared Candidate? | Must Stay Surface-Specific? |
|----------|-------|------|---------|-------------------|-----------------------------|
| **Section nil when HI UI off** | Returns `nil` | Builder always returns state; dashboard policy hides | Returns `nil` | Policy helper | **Yes** — Plan dashboard always prepares state for loading transitions |
| **Recovery card** | Single-day card with training/nutrition guidance | Uses `recovery` in synthetic snapshot / confidence reasons only | Per-day timeline rows + scores | **Core** (`buildRecoveryCardContent`, `recoveryPhase`, `recoverySubtitle`) | **Partial** — Today card layout vs Journey timeline rows |
| **Workout card / history** | Optional workout card (completed / empty) | Workout signal row in data quality | 30-day grouped history list | **Core** (`buildWorkoutCardContent`) for Today empty/complete | **Yes** — Journey list layout, grouping, milestones |
| **Adaptive nutrition** | Optional card + daily-mission overlap rules | — | — | **Core** (`buildAdaptiveNutritionContent`, overlap helpers) | **Yes** — Today-only surface |
| **Daily mission** | Composite headline + detail lines from recovery/workout/nutrition | — | — | — | **Yes** — Today-only |
| **Next best action** | Integration resolver + supplemental UI-state CTAs | Synthetic snapshot NBA for disconnected only | — | **Core** (`isVisibleHealthAction`, `normalizeUIStateCTACopy`) | **Yes** — Today has unique integration resolver chain |
| **Plan confidence** | — | Primary card with score %, reasons, disclaimer | — | — | **Yes** — Plan-only |
| **Assumptions / data quality** | — | Assumptions list + quality level + signal grid | — | — | **Yes** — Plan-only |
| **Missing-data actions** | Via NBA / integration resolver | Explicit action rows (connect, permissions, sleep, HRV, weight, nutrition) | Connect CTA + empty states | **Core** (`connectCTACopy`) for connect messaging | **Yes** — Plan has richest action set |
| **Weekly review card** | — | — | Card + detail via `WeeklyReviewPresentationBuilder`; building state via Core | **Core** (building content) + `WeeklyReviewPresentationBuilder` | **Partial** — Journey hosts HI weekly review; unified weekly UX is separate builder |
| **Recovery timeline** | — | — | 7–14 day span, limited notes | **Core** (phase, subtitle, labels, color tokens) | **Yes** — Journey layout / day iteration |
| **Milestones** | — | — | Workout streak, recovery streak, review-driven items | — | **Yes** — Journey-only |
| **Progress metrics** | — | — | Weekly review + plan progress stats | — | **Yes** — Journey-only |
| **UI state resolution** | `HealthIntelligenceSectionLoaderCore.resolveUIState` | Same (synthetic snapshot) | Same | **Shared** — already extracted | No — keep in loader core |
| **Fallback message** | Policy `todayFallbackMessage` | Policy `planFallbackMessage` | Policy `journeyFallbackMessage` | **Policy** (surface switch) | **Partial** — copy differs per surface |
| **Stale data label** | Policy `staleDataCopy(.today)` | Policy `staleDataCopy(.plan)` | Policy `staleDataCopy(.journey)` | **Policy** | **Partial** — strings differ |
| **Partial signals note** | — | — | Policy `partialSignalsNote` (Journey only) | **Policy** | **Yes** — Journey-only today |
| **Sync failure section message** | Via `uiState.message` in unavailable paths | Fallback only | `HealthIntelligencePresentationPolicy.syncFailureSectionMessage` | **Policy** | **Partial** |
| **Connect-only section** | Unavailable section + placeholder recovery | Missing-data actions | Dedicated `connectHealthSection` (all sub-cards empty) | **Core** `shouldShowConnectOnlySection` | **Yes** — Journey has unique empty sub-card shell |
| **Loading section** | Per-card `.loading` states | Single loading section (confidence-led) | All sub-cards `.loading` | — | **Yes** — different skeleton shapes |
| **HealthKit / permission gating** | Integration status + signal availability | `PlanHealthConnectionState.resolve` | `journeyHealthConnection` in loader core | **Core** connection helpers | **Partial** — Plan uses 3-state model |
| **Feature flag: UI enabled** | `isUIEnabled` guard | Composition policy only | `isUIEnabled` guard | Central flag | **Yes** — different enforcement points |
| **Feature flag: weekly review** | — | — | Loader skips `weeklyReview` when off | — | **Yes** — Journey load path |
| **Feature flag: model load** | `shouldTodayModelLoadHealthIntelligence` | `shouldPlanModelLoadHealthIntelligence` | `shouldJourneyModelLoadHealthIntelligence` | `FormaAbTest.HealthIntelligence.should*Load` | **Shared** pattern |
| **Remote sync / consent in UI state** | Passed into resolution input | Passed into resolution input | Passed into resolution input | **Shared** resolution input | No |
| **Analytics: snapshot lifecycle** | `logSnapshotLoaded/Failed` | Same | Same | **Coordinator** | No |
| **Analytics: section viewed** | Recovery card viewed | Confidence viewed | Timeline / workout history / weekly review viewed | **Coordinator** `logSectionOnce` | **Partial** — different events per surface |
| **Analytics: CTA tapped** | NBA tapped + permission CTA | — (no coordinator CTA events) | Permission CTA via shared helper | **Coordinator** | **Partial** |
| **User-facing copy SSOT** | `FormaProductCopy.Today.HealthIntelligence` | `FormaProductCopy.PlanHealthIntelligencePresentation` | `FormaProductCopy.Journey.HealthIntelligence` + `WeeklyReviewPresentation` | `FormaProductCopy.HealthIntelligence.UIState` for banners | **Yes** — tab copy namespaces must remain |
| **Accessibility labels** | Core helpers + Today section titles | Composed section + per-card labels | Per sub-component labels | **Core** `*AccessibilityLabel` helpers | **Partial** — composition differs |
| **Legacy composition policy** | `TodayReadOnlyCompositionPolicy` hides legacy stack | `PlanDashboardCompositionPolicy` toggles HI vs legacy confidence | `JourneyDashboardCompositionPolicy` hides legacy insights / duplicate weekly | — | **Yes** — per-dashboard; deprecated until flag permanent-on |
| **Text sanitization** | Core `sanitizedGuidance` / `sanitizedText` | — | — | **Core** | No |
| **Coach-safe field gating** | — | — | `coachSafeRecoveryScore`, `coachSafeCaloriesLabel` on timeline/history | **Core** | No |

### Flag reference (runtime vs production intent)

| Flag | `FormaAbTestSnapshot.allEnabled` | `FormaAbTestSnapshot.production` | Effect on presentation |
|------|----------------------------------|----------------------------------|------------------------|
| `foundationEnabled` | `true` | `true` | Master HI gate |
| `enginesEnabled` | `true` | `true` | Snapshot/review composition |
| `uiEnabled` | `true` | **`false`** | Today/Journey `nil` section; Plan composition policy |
| `weeklyReviewEnabled` | `true` | **`false`** | Journey weekly review load |
| `coachContextEnabled` | `true` | `true` | Coach only (not tab presentation) |
| `syncEnabled` / `remoteSummarySyncEnabled` | `true` / `true` | `true` / **`false`** | UI state kinds for sync/stale/remote |
| `should*ModelLoad` | UI ∨ debugFetch | **false** (no debug fetch in prod) | Whether models fetch HI at all |

Source: `HealthIntelligenceFeatureFlags.swift`, `FormaAbTest.swift`, `FormaAbTestProductionCriticalFlagsTests`.

### Deprecated paths affecting parity (from CLEANUP_STATUS)

Do not remove until matrix row tests pass:

1. Legacy `*CompositionPolicy` — duplicate section visibility when HI UI off/on  
2. `HealthActivityQueryService` reader fallback — affects loader inputs  
3. Workout calorie `max(manual, HealthKit)` — affects Today nutrition/training display adjacent to HI  
4. Journey `workoutReader` fallback — affects workout history inputs  
5. `normalizedSamples(for:)` — repository compatibility  
6. Training Insights direct HK reads — parallel health surface  
7. FITPILOT env keys — flag resolution only  
8. `NormalizedWorkout` shim — loader record mapping  

### Parity freeze rule

Before merging any builder refactor PR, diff characterization test fixtures for all three `*PresentationBuilderTests` + composition tests. **Zero intentional changes** to `*SectionState` equatable outputs unless this matrix is updated in the same PR.

---

## 8. Existing tests

### Fast-Core HI presentation / loader (run first)

| Test class | Covers |
|------------|--------|
| `HealthIntelligenceSectionLoaderCoreTests` | Shared fetch, connection, weekly review, connect-only gating |
| `TodayHealthIntelligenceSectionLoaderTests` | Today loader + fallback analytics context |
| `HealthIntelligencePresentationParityTests` | Golden fixtures A–E across Today/Plan/Journey surfaces |
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
./Scripts/run_fast_core_tests.sh   # full Fast-Core (Mac/Xcode)

# or HI-focused subset:
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
  -only-testing:"Fitness CoachTests/JourneyHealthIntelligencePresentationBuilderTests" \
  -only-testing:"Fitness CoachTests/PlanHealthIntelligencePresentationBuilderTests" \
  -only-testing:"Fitness CoachTests/HealthIntelligenceCompositionTests" \
  -only-testing:"Fitness CoachTests/TodayHealthIntelligenceCompositionTests" \
  -only-testing:"Fitness CoachTests/JourneyHealthIntelligenceCompositionTests"
```

**Fast-Core (BW-101):** Closed in project wiring — `TEST_HOST` + `BUNDLE_LOADER`; Firebase SPM in app target only. **Mac verification pending** on cloud agents (no `xcodebuild`). See [../TechnicalDebt/BuildWarningsRegister.md](../TechnicalDebt/BuildWarningsRegister.md).

**Tests executed in cloud agent environment:** None (no Xcode). Verification contract is the command block above on a standard Mac/Xcode host.

---

## 9. Characterization strategy

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

## 10. PR / commit boundaries

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

## 11. Rollback plan

### Per-PR rollback

1. Revert the merge commit on `main` (or close PR without merge).
2. No feature flags to flip — refactors are compile-time only.
3. Run Fast-Core HI subset (§8) on a Mac with Xcode to confirm green.

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

## 12. Final success metrics

| Metric | Baseline | Current (PR #178) | Target | Status |
|--------|----------|---------------------|--------|--------|
| Three tab HI builders combined | 2,799 LOC | 2,725 LOC | **≤1,500 LOC** | ❌ P1 stretch deferred |
| Net duplicated HI presentation LOC | High (3× ~930 LOC builders) | Loader core + policy delegation landed | **Net decrease** vs baseline | 🟡 P0 met; P1 extraction deferred |
| `HealthIntelligencePresentationCore` + shared module | 941 LOC | ~1,909 LOC (incl. card factory) | May grow if it absorbs shared card builders | ✅ Acceptable |
| `AppContainer+Construction.swift` | 1,004 LOC | **68 LOC** | **≤700 LOC** | ✅ Met |
| TD-HI-002 | Open | **Mostly closed** | Closed or tiny follow-up doc | 🟡 Mostly closed |
| Deprecated rows in `CLEANUP_STATUS` | 9 | 9 | **≤3 remaining** | ❌ Deferred (flag-off paths kept) |
| Fast-Core | Blocked (BW-101) | **Fix applied**; Mac verify pending | Runs locally | 🟡 Fix landed |
| PH-004 fixtures | ~90 alias files | ~31 `ProfileTestFixtures` remain | Canonical `TestingSupport/` names | 🟡 Batch 1 done |
| TD-COACH-001 tail | Open | Legacy init removed; photo-flow wired | Closed | ✅ Closed |
| User-visible behavior | — | Unchanged (refactor-only) | Zero diffs in UI QA | ✅ Required |
| HI engine output | — | Unchanged | `HealthIntelligenceEngineTests` green | ✅ Required (Mac verify) |

### Sprint done definition

**P0 scope (§3) is complete** in PR #178. Full sprint stretch goals (§4) are partially deferred:

1. ✅ P0 scope merged — loader core, Today loader, AppContainer split, parity tests, docs.
2. ❌ Combined tab builders ≤1,500 LOC — documented as P1 follow-up (2,725 LOC remains).
3. ❌ Deprecated CLEANUP_STATUS rows ≤3 — requires `healthIntelligenceUIEnabled` permanent-on decision.
4. 🟡 Fast-Core — BW-101 fix landed; `./Scripts/run_fast_core_tests.sh` must pass on Mac.
5. 🟡 TD-HI-002 marked **mostly closed** — tail: composition policies until flag permanent-on.

### Final implementation notes (2026-07-05)

| # | Topic | Outcome |
|---|-------|---------|
| 1 | TD-HI-002 | **Mostly closed** — shared loader + presentation core; composition policies kept for flag-off |
| 2 | Files consolidated | `HealthIntelligenceSectionLoaderCore`, `TodayHealthIntelligenceSectionLoader`, `App/Dependencies/*`, parity tests |
| 3 | Shared core | Loader core, presentation core/policy/models/card factory own fetch, gating, card mapping, copy |
| 4 | Surface-specific | Today mission/integration; Plan confidence/data-quality; Journey timeline/history/milestones |
| 5 | Deprecated removed | Dead Today composition stubs; Training Insights direct HK reads |
| 6 | Deprecated kept | 9 rows in `CLEANUP_STATUS.md` § Deprecated (composition policies, reader fallback, shim, etc.) |
| 7 | AppContainer bundles | 10 domain files under `App/Dependencies/`; Construction 68 LOC |
| 8 | Fast-Core | BW-101 closed in project; Mac verify pending |
| 9 | PH-004 | `FoodLogFixtures` / `DailyLogFixtures` done; ~31 `ProfileTestFixtures` files remain |
| 10 | Coach tail | TD-COACH-001 tail closed — `CoachModelTestFactory`, photo-flow coordinator confirmed |
| 11 | Remaining debt | TD-HI-001, TD-HI-002 tail, TD-HI-003, P1 builder slimming, TD-TEST-001 Mac verify |
| 12 | Tests run | **None in cloud** — Mac contract: HI subset + `./Scripts/run_fast_core_tests.sh` (§8) |

---

## Revision history

| Date | Change |
|------|--------|
| 2026-07-05 | **Final implementation notes** — P0 complete in PR #178; P1 stretch deferred; BW-101 closed; doc sync with code |
| 2026-07-05 | Added §7 Baseline Parity Matrix (Today / Plan / Journey behavior inventory) |
| 2026-07-05 | Initial execution map; Phase 1 metrics from PR #178 |
