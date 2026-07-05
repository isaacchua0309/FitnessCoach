# Weekly Progress Loop Context Packet

> **Implementation note (2026-07):** Weekly Progress Loop **v1 is implemented** on branch `cursor/unified-weekly-review-presentation-027b`. Post-implementation documentation lives in [`Docs/WeeklyProgress/WeeklyProgressLoopV1.md`](Docs/WeeklyProgress/WeeklyProgressLoopV1.md). The audit below remains as the pre-sprint baseline record.

**Generated:** 2026-07-05  
**Sprint scope target:** Weekly Progress Loop v1 — Learned Maintenance, Unified Weekly Review, and Plan Recommendations  
**Branch audited:** `feature/account-persistence-restore` (working tree)  
**Method:** Static code + docs audit only. No code changes. Claims tagged **Confirmed**, **Likely**, or **Unknown**.

**Primary sources read:**
- `PRD.md` (§9.11 Maintenance Calculator, §9.12 Daily Review, §9.13 Weekly Review)
- `FULL_APP_PRODUCT_LOOP_GAP_CONTEXT_PACKET.md`
- `USER_DATA_STORAGE_CONTEXT_PACKET.md`
- `ACCOUNT_PERSISTENCE_EXECUTION_MAP.md`
- `ACCOUNT_PERSISTENCE_PHASE_READINESS.md`
- `ACCOUNT_PERSISTENCE_RESTORE_CONTEXT_PACKET.md`
- `ACCOUNT_PERSISTENCE_IMPLEMENTATION_PLAN.md`
- `Docs/JourneyArchitecture.md`
- `Docs/FormaCalculationSpec.md` (referenced by `EnergyCalculator`, `FormaCalculationConstants`)
- `Docs/AccountPersistence/PHASE_2` through `PHASE_5`
- `Docs/PersistenceCleanupNotes.md` (via `WeeklyReviewEntity` header comment)
- `Docs/HealthIntelligence/HEALTH_SUMMARY_SYNC_CONTRACT.md` (referenced by `WeeklyHealthReviewSyncPayload`)
- `Fitness Coach/Health/HealthIntelligenceFeatureFlags.swift`

**Note:** `Docs/AccountPersistence/PHASE_6_ACCOUNT_DELETION_AND_PRIVACY.md` — **not found** in repo.

---

## 1. Executive Summary

### What the app tells a user after 7 days of logging

**Confirmed (Journey habit path — always available when `hasMeaningfulJourneyData`):**
- Rolling **7-day** habit rows (not calendar week): food days, protein days, water days, calorie adherence days, weight delta, training days — built by `JourneyWeeklyPatternBuilder` / `JourneyWeeklyReviewBuilder` from `DailyLog` + `WeightEntry` + HealthKit workout day-starts.
- Transformation hero narrative (`JourneyHeroBuilder`), momentum/streak copy (`JourneyStreakBuilder`), optional goal projection ETA if ≥3 weight logs spanning ≥7 days (`JourneyGoalProjectionBuilder`).
- Plan tab shows static “when to adjust” rules (`PlanAdjustmentRulesStateBuilder.genericRules()`), a trend hint if weight stable ≥7 days with ≥3 weights, and “next review in N days” (`PlanReviewStateBuilder`) — **not** a data-driven plan verdict.

**Likely (HI weekly review path — flag-dependent):**
- If `HealthIntelligenceFeatureFlags.healthIntelligenceUIEnabled` **and** `healthIntelligenceWeeklyReviewEnabled` **and** Apple Health connected: `WeeklyReviewCard` with title/summary, confidence label, stats grid; tap opens `WeeklyReviewDetailView` sheet.
- `FormaAbTestSnapshot.allEnabled` sets HI UI + weekly review **true**, but `HealthIntelligenceFeatureFlags.swift` documents production env defaults: UI **`false`**, weekly review **`false`** — **App Store behavior Unknown** without build verification.

**Not told:**
- Learned maintenance kcal from real intake + weight trend (**Confirmed** absent).
- “Your plan is working” / “adjust calories by ±100” recommendation (**Confirmed** absent).
- Water-weight / scale-spike education in Journey UI (**Confirmed** — `hasSuddenSpike` computed in `JourneyModel` but **not rendered** in any `Features/Journey/Components/*` view).

### After 14 days

**Confirmed:**
- `PlanConfidenceStateBuilder` uses `recentWeightWindowDays = 14` and `consistentFoodLogDays = 5` for confidence score.
- `JourneyMonthlyRecapBuilder` has full month window when calendar month has data.
- `ProgressProjectionCalculator` / `WeightTrendCalculator` use 7-day average comparison for trend direction.
- Still **no** learned maintenance; Plan review section may show “ready” headline if `PlanReviewStateBuilder.isReviewDue` (7 days since profile anchor) **and** `hasEnoughData` — but no linked weekly review ritual or maintenance output.

### After 28 days

**Confirmed:**
- `WeeklyReviewService.composeReview` uses `context.metricsLast28Days` for recovery summaries.
- `JourneyModel.makeDashboardState` loads `maturityLogs` from 365-day window (not 28-specific).
- PRD prefers 14–28 days for maintenance accuracy — **no implementation** uses 28-day maintenance window.

### Core questions

| Question | Answer | Confidence |
|----------|--------|------------|
| Can app answer “is my plan working?” | **No** unified answer; habit rows + optional HI copy only | Confirmed |
| Maintenance from real data? | **No** | Confirmed |
| Weekly review as clear ritual? | **No** — fragmented, passive, no notification | Confirmed |
| Journey / Plan / Today / Daily Review / HI unified? | **No** — 3+ parallel systems | Confirmed |
| Plan recommendations from trend? | **No** — static rules + optional stable-weight hint | Confirmed |
| Scale panic prevention? | **Minimal** outside Coach | Confirmed |
| Restored/synced data feeds weekly progress? | **Yes** for nutrition/weight logs via readers; HI cache separate | Confirmed |
| Analytics measure weekly review? | **Partial** HI events; Release no-op loggers | Confirmed |

### Verdict

**Current Weekly Progress Loop strength: Weak**

**Why:** Infrastructure for weekly *display* exists (Journey habit rows, HI `WeeklyReviewEngine`, weight trend math, Plan confidence/review sections), but the **product loop is not closed**: no learned maintenance, no plan recommendation, no canonical weekly ritual, calendar vs rolling week mismatch, HI weekly review off by default in documented production flags, `WeeklyReviewEntity.estimatedMaintenance` dead, daily review read but not shown on Today, and no extrinsic trigger. Users who log 7+ days see **activity consistency**, not **plan effectiveness**.

### Sprint recommendation

**Yes — proceed with Weekly Progress Loop v1 as the next sprint.**

| Option | Verdict |
|--------|---------|
| 1. Weekly Progress Loop v1 | **Recommended** — closes trust gap after account persistence; reuses existing builders |
| 2. Journey v2 | Subset of #1; cosmetic without maintenance + plan recommendation |
| 3. Plan Auto-Adjustment | Depends on learned maintenance first |
| 4. Notifications / Habit Loop | **Fast-follow** after weekly destination exists |
| 5. Analytics first | Wire in parallel with #1, not instead of |
| 6. Something else | Training Logger — smaller retention impact for all cutters |

---

## 2. Current Weekly Progress Architecture Overview

### Pipeline diagram (text)

```
USER LOGS (daily)
│
├─ FoodEntryEntity ──► FoodLogService / FoodLogReading
├─ WaterEntryEntity ──► WaterLogService
├─ WeightEntryEntity ──► WeightLogService / WeightLogReading
├─ DailyLogEntity ──► DailyLogService / DailyLogReading (rolled-up totals + frozen targets)
├─ DailyReviewEntity ──► ReviewService.getDailyReview / generateDailyReview
└─ HealthKit ──► HealthKitManager ──► HealthDataRepository / HealthCacheStore

TODAY TAB
│
├─ TodayModel.loadDashboard()
│   ├─ reads DailyLog, FoodEntry, Weight, DailyReview (read only)
│   └─ TodayPresentationBuilder.dashboard() ──► TodayDashboardState
│       ├─ mission, nextBestAction, meals, macroHydration, activity
│       ├─ EndOfDayWrapUpEngine (evening, deterministic) ──► TodayEndOfDayWrapUpSection
│       └─ dailyReview input IGNORED in builder (gap)
│
└─ TodayCrossDeviceRefreshPolicy ──► reload on .food, .water, .weight, .dailyReview, .plan

JOURNEY TAB (primary weekly surface)
│
├─ JourneyModel.refresh() / makeDashboardState()
│   ├─ Rolling 7-day logs: weekStart = asOf - 6 days (NOT calendar week)
│   ├─ WeightTrendCalculator.trend() ──► ProgressWeightSummary (hasSuddenSpike unused in UI)
│   ├─ ProgressProjectionCalculator.projection()
│   ├─ JourneyDashboardBuilder.weeklyReview() ──► JourneyWeeklyReviewState
│   ├─ JourneyPresentationBuilder.buildDashboard()
│   │   ├─ JourneyWeeklyPatternBuilder ──► JourneyWeeklyHabitState (habit rows)
│   │   ├─ JourneyGoalProjectionBuilder, JourneyHeroBuilder, JourneyStreakBuilder, ...
│   │   └─ JourneyDashboardState
│   └─ JourneyHealthIntelligenceSectionLoader (parallel, flag-gated)
│       ├─ WeeklyReviewService.getLatestCompletedWeeklyReview()
│       ├─ WeeklyReviewEngine.evaluate() ──► WeeklyHealthReview
│       └─ WeeklyReviewPresentationBuilder ──► WeeklyReviewCardState + Detail
│
└─ JourneyCrossDeviceRefreshPolicy ──► reload on .journey, .today, .food, .water, .weight, .dailyReview, .plan, .profile

PLAN TAB
│
├─ PlanModel ──► PlanPresentationBuilder
│   ├─ PlanProjectionBuilder (static TDEE maintenanceCalories)
│   ├─ PlanConfidenceStateBuilder (engagement score, not trend verdict)
│   ├─ PlanAdjustmentRulesStateBuilder (generic rules + stable trend hint)
│   ├─ PlanReviewStateBuilder (7-day review cadence from profile.updatedAt)
│   └─ PlanAdjustPlanCTAStateBuilder (static CTA, no recommendation)
│
└─ PlanEditWizard ──► manual target changes via FitnessActionCenter.updatePlan

COACH (shallow)
│
└─ CommandIntent.dailyReview ──► FitnessActionCenter.generateDailyReview ──► ReviewService

SYNC / RESTORE
│
├─ AccountSyncCoordinator / AccountIncrementalPuller ──► Food, Water, Weight, DailyLog, DailyReview entities
├─ AccountRestoreCoordinator ──► populate SwiftData ──► JourneyModel re-reads
├─ CrossDeviceSyncCoordinator ──► AccountDataRefreshEventBus ──► tab refresh policies
└─ HealthSummarySyncService ──► WeeklyHealthReviewSyncPayload (opt-in health cloud, not nutrition restore)
```

### Data flow table

| Flow | Source entity | Service | Builder | Output state | UI surface | Refresh trigger | Missing link |
|------|---------------|---------|---------|--------------|------------|-----------------|--------------|
| Daily logs → Journey | `DailyLogEntity` | `DailyLogReading` | `JourneyDashboardBuilder` | `JourneyWeeklyReviewState` | `JourneyWeeklyReviewSection` | `JourneyModel.refresh`, cross-device bus, pull-to-refresh | → maintenance estimate |
| Weight → Journey trend | `WeightEntryEntity` | `WeightLogReading` | `WeightTrendCalculator`, `JourneyGoalProjectionBuilder` | `JourneyGoalProjectionState` | `JourneyGoalProjectionSection` | same | spike not shown |
| Food → weekly habits | `FoodEntryEntity` via `DailyLog` | `DailyLogReading` | `JourneyWeeklyPatternBuilder` | `JourneyWeeklyHabitState` | `JourneyWeeklyReviewSection` | same | not calendar week |
| HI weekly review | Health cache + logs | `WeeklyReviewService` | `WeeklyReviewEngine`, `WeeklyReviewPresentationBuilder` | `WeeklyReviewCardState` | `JourneyHealthIntelligenceSection` | `forceWeeklyReviewRefresh` on pull | requires HK + flags |
| Plan targets → review | `UserProfileEntity` | `UserProfileReading` | `PlanReviewStateBuilder` | `PlanReviewState` | `PlanReviewSection` | `PlanCrossDeviceRefreshPolicy` | not tied to Journey weekly |
| Daily review | `DailyReviewEntity` | `ReviewService` | `DailyReviewSummaryBuilder` | `DailyReview` model | **None** (Coach only) | sync | Today reads but discards |
| Profile TDEE | `UserProfileEntity` | `TargetService` | `PlanProjectionBuilder` | static `maintenanceCalories` | Plan rationale/hero | profile change | not learned |

---

## 3. Weekly Review Inventory

| Weekly Review System | Exists? | Files | Trigger | Data Used | Persisted? | UI Surface | Gap |
|---------------------|---------|-------|---------|-----------|------------|------------|-----|
| Journey habit rows | **Yes** | `JourneyWeeklyReviewBuilder.swift`, `JourneyWeeklyPatternBuilder.swift`, `JourneyWeeklyReviewSection.swift` | `JourneyModel.refresh()` | Rolling 7d `DailyLog`, `WeightEntry`, HK workouts | **No** (in-memory) | Journey `.weeklyReview` section | Legacy; comment says pending HI removal |
| HI `WeeklyReviewEngine` | **Yes** | `WeeklyReviewEngine.swift`, `WeeklyReviewService.swift` | Journey load; completed calendar week only | Nutrition summaries, HK metrics, recovery, weights | **Health cache** JSON (`cacheStore.storeWeeklyReview`) | `WeeklyReviewCard`, `WeeklyReviewDetailView` | Flag + HK gated |
| `WeeklyReviewEntity` | **Schema only** | `WeeklyReviewEntity.swift` | **None** | N/A | V1 migration orphan | **None** | `estimatedMaintenance` never written |
| `ReviewService` weekly | **No** | — | — | — | — | — | Daily only |
| Plan review section | **Yes** | `PlanReviewStateBuilder.swift` | Plan dashboard load | 7d logs, weights, profile anchor | No | `PlanReviewSection` | Not a weekly recap |
| Plan adjustment rules | **Yes** | `PlanAdjustmentRulesStateBuilder.swift` | Plan dashboard load | Weights for trend hint | No | `PlanAdjustmentRulesSection` | Generic copy, not recommendation |
| End-of-day wrap-up | **Yes** | `EndOfDayWrapUpEngine.swift` | Hour ≥ 20 | Same-day logs | No | `TodayEndOfDayWrapUpSection` | Daily not weekly |
| Coach weekly | **Unknown** | Coach intents | User chat | Coach context | — | Coach | Out of scope |

### Weekly review questions

| Question | Answer | Confidence |
|----------|--------|------------|
| One canonical weekly review? | **No** | Confirmed |
| Multiple fragmented systems? | **Yes** — habit rows + HI card + Plan review cadence | Confirmed |
| Auto-generated? | **On Journey load** only; no scheduler | Confirmed |
| Persisted? | HI → health cache; Journey habits → recompute | Confirmed |
| Shown in Journey? | **Yes** (both systems) | Confirmed |
| Shown on Today? | **No** | Confirmed |
| Reachable from notifications? | **No** (`UserNotifications` absent) | Confirmed |
| Completion state? | **No** | Confirmed |
| History view? | **No** | Confirmed |
| Useful without HealthKit? | **Partial** — habit rows yes; HI card no | Confirmed |
| Useful without Coach? | **Yes** for habit rows | Confirmed |

---

## 4. Journey Weekly Progress Audit

### Architecture references

| Symbol | Path |
|--------|------|
| `JourneyView` | `Fitness Coach/Features/Journey/JourneyView.swift` |
| `JourneyModel` | `Fitness Coach/Features/Journey/Model/JourneyModel.swift` |
| `JourneyViewState` | `Fitness Coach/Features/Journey/Model/JourneyViewState.swift` |
| `JourneyDashboardState` | `Fitness Coach/Features/Journey/Model/JourneyDashboardState.swift` |
| `JourneyProductLayout` | `Fitness Coach/Features/Journey/Model/JourneyProductLayout.swift` |
| `JourneyCrossDeviceRefreshPolicy` | `Fitness Coach/Features/Journey/Model/JourneyCrossDeviceRefreshPolicy.swift` |

### Journey element table

| Journey Element | Current Behavior | Data Source | Calculation | User Value | Gap |
|----------------|------------------|-------------|-------------|------------|-----|
| Transformation hero | Variant by streak/progress | `JourneyBaseline`, streaks | `JourneyHeroBuilder.resolveVariant` | Motivation | No plan-working verdict |
| Goal projection | ETA or insufficient | `WeightEntry` | `JourneyGoalProjectionBuilder` min 3 weights, 7d span; `ProgressProjectionCalculator` | Directional hope | Hidden if insufficient |
| Weight trend | Stored in `ProgressWeightSummary` | `WeightTrendCalculator.trend` | 7-day avg vs prior 7-day | **Not shown** to user | UI gap |
| 7-day average | Computed | `WeightTrendCalculator.averageWeight(days: 7)` | Rolling | Not surfaced | Gap |
| Weekly habit rows | Win-sorted rows | `JourneyLogMetrics` on 7d logs | Thresholds: protein 0.9, water 0.8, calorie ±10% | Consistency feedback | Not plan effectiveness |
| Protein/calorie/water consistency | Day dots | `JourneyWeeklyPatternBuilder` | Per-day goal met | Visual streak | — |
| Training consistency | HK workout days or locked CTA | `JourneyTrainingSummaryBuilder` | Expected days from profile | Training awareness | Hidden when HI on |
| Milestones | Next milestone CTA | `JourneyNextMilestoneBuilder` | Log behaviors | Gamification | Cosmetic |
| Story timeline | Events | `JourneyTimelineBuilder` | Log history | Narrative | — |
| Monthly recap | Month summary | `JourneyMonthlyRecapBuilder` | Calendar month logs | Longer horizon | — |
| Streaks | Logging/protein/water | `StreakCalculator`, `JourneyStreakBuilder` | Consecutive days | Habit reinforcement | No push |
| Chapters / XP | 200 XP/chapter | `JourneyChapterBuilder` | Behaviors | Gamification | — |
| HI section | Weekly card + recovery + workouts | `JourneyHealthIntelligenceSectionLoader` | `WeeklyReviewService` | Richer review | Flag + HK |
| Weekly Review card | Tap → sheet | `WeeklyHealthReview` | `WeeklyReviewEngine` | Structured wins/risks | Duplicates habit rows |
| Plan CTA | `JourneyCTA.updateGoal` → Plan tab | `JourneyCTARouter` | — | Opens Plan | No recommendation payload |
| Empty state | `JourneyStartingEmptyStateView` | `hasMeaningfulJourneyData` | — | Onboarding | — |
| Partial restore | `AccountRestorePendingStateView` | `AccountRestoreSessionState` | — | Blocks false empty | No partial preview |
| Cross-device refresh | Debounced 200ms reload | `AccountDataRefreshEventBus` | — | Fresh data | No stale label on habit section |

### Journey questions

| Question | Answer |
|----------|--------|
| “Am I making progress?” | **Partial** — hero + projection + habits, not maintenance-based |
| “Is my plan working?” | **No** |
| Distinguishes scale noise from trend? | **Code yes** (`WeightTrendCalculator` 7d avg); **UI no** |
| Explains weight spikes? | **No** (`hasSuddenSpike` not rendered) |
| Enough confidence rules? | **Projection yes**; habits show data without minimum gates |
| Hides projection when insufficient? | **Yes** (`JourneyGoalProjectionBuilder`) |
| Recommends action? | **CTAs** to log/coach/plan, not calorie adjustment |
| Connects to Plan edits? | **Weak** — `updateGoal` only |
| Refreshes after restore/sync? | **Yes** (`JourneyCrossDeviceRefreshPolicy`) |
| Stale/partial warnings? | **HI only** (`staleDataLabel`, `partialSignalsNote`) |

---

## 5. Learned Maintenance Audit

### Maintenance source table

| Maintenance Source | Formula Type | Uses Real Intake? | Uses Weight Trend? | Confidence? | UI Surface | Gap |
|-------------------|--------------|------------------|-------------------|-------------|------------|-----|
| Onboarding / Plan TDEE | Mifflin–St Jeor + PAL + steps/training bonuses | **No** | **No** | Plan confidence score (engagement) | Plan rationale, projection cards | Static |
| `PlanBodyBaselineMaintenanceEstimator` | Same as TDEE preview | **No** | **No** | None | Plan edit wizard | — |
| `PlanProjectionBuilder` | `result.tdeeKcal` / `preview.estimatedTDEE` | **No** | **No** | — | Plan dashboard | — |
| `WeeklyReviewEntity.estimatedMaintenance` | PRD energy-balance (intended) | **Would** | **Would** | — | **None** | **Never populated** |
| `WeeklyReviewEngine` | Adherence + recovery | Partial (calorie hit days) | Weight change kg only | `WeeklyReviewConfidence` | HI weekly card | **No kcal maintenance** |
| Coach | **Unknown** shallow | Likely | Likely | — | Chat | Out of scope |
| `MaintenanceEstimateCalculator` | — | — | — | — | — | **Does not exist** |

### PRD formula (not implemented)

From `PRD.md` §9.11 and `FormaCalculationConstants.kcalPerKgFat = 7700`:

```
estimated_daily_deficit = weight_lost_kg × 7700 / days
learned_maintenance = average_daily_calories + estimated_daily_deficit
```

### Learned maintenance questions

| Question | Answer | Confidence |
|----------|--------|------------|
| Learned maintenance exists? | **No** | Confirmed |
| `WeeklyReviewEntity.estimatedMaintenance` populated? | **No** — entity unused per file header | Confirmed |
| Maintenance in Plan? | **Formula TDEE only** (`PlanProjectionBuilder.maintenanceCalories`) | Confirmed |
| Maintenance in Journey? | **No** | Confirmed |
| Formula vs learned labeled? | **No** distinction | Confirmed |
| Compare target vs learned maintenance? | **No** | Confirmed |
| Accounts for weight noise? | **No** in maintenance path | Confirmed |
| Minimum days before estimate? | PRD 7/14/28 — **not enforced** (no estimator) | Confirmed |
| Confidence levels for maintenance? | **No** | Confirmed |
| Explains uncertainty? | **No** for maintenance | Confirmed |

### Data already available to build learned maintenance (**Confirmed**)

| Input | Source |
|-------|--------|
| Daily calorie intake | `DailyLog.totals.calories` / `DailyLogEntity` |
| Daily targets (frozen) | `DailyLog.targets.calorieTarget` |
| Weight entries | `WeightEntryEntity` via `WeightLogReading` |
| 7/14/28-day windows | `JourneyLogMetrics.rollingWeekDayStarts`, `WeightTrendCalculator.averageWeight` |
| Goal direction | `UserProfile.goalWeightKg`, `JourneyBaseline.goalDirection` |
| Static TDEE prior | `PlanCalculationResult.tdeeKcal` from profile |
| Energy constant | `FormaCalculationConstants.kcalPerKgFat` (7700) |

---

## 6. Weight Trend and Scale-Panic Audit

### Weight trend feature table

| Weight Trend Feature | Current Logic | Data Required | Shown Where | Trust Risk | Gap |
|---------------------|---------------|---------------|-------------|------------|-----|
| Latest weight | `WeightTrendCalculator.latestWeight` | ≥1 entry | Today mission `TodayWeightSummary` | Low | No 7d avg on Today |
| 7-day average | `averageWeight(days: 7, endingOn:)` | Entries in window | **Nowhere in UI** | Medium | Not surfaced |
| Week-over-week change | Current 7d avg − prior 7d avg | 2 windows | **Nowhere** | Medium | — |
| Trend direction | ±0.2 kg band (`stableBandKg`) | ≥2 entries | Plan adjustment hint only | Low | Journey doesn't show |
| Sudden spike detection | Day-over-day ≥ **1.0 kg** (`spikeThresholdKg`) | ≥2 entries | **Nowhere** (`hasSuddenSpike` in model only) | **High** | No panic copy |
| Goal projection | Weekly rate from first/last weight | ≥3 weights, 7d span | `JourneyGoalProjectionSection` | Medium if early data | — |
| Plan stable hint | Stable ≥7 days, ≥3 weights | `PlanAdjustmentRulesStateBuilder.trendHint` | `PlanAdjustmentRulesSection` | Low | Generic copy |
| Water-weight disclaimer | — | — | **Nowhere** in Journey/Plan/Today | **High** | PRD gap |

### Weight trend questions

| Question | Answer |
|----------|--------|
| Uses 7-day average? | **Yes** in `WeightTrendCalculator` |
| Detects sudden spikes? | **Yes** — threshold **1.0 kg** |
| UI surfaces spike explanations? | **No** |
| Explains water weight? | **No** in non-Coach UI |
| Prevents overreacting to one weigh-in? | **Weak** — no user-facing spike handling |
| Requires 3+ weights / 7+ days for projection? | **Yes** (`JourneyGoalProjectionBuilder`) |
| Shows confidence? | **Projection** has `ProgressProjection.confidence`; not maintenance |
| Connects trend to plan recommendation? | **No** |
| Today smoothed trend? | **No** — latest weight in mission |
| Journey smoothed trend? | **No** — projection uses rate, not displayed avg |

---

## 7. Plan Recommendation and Adjustment Audit

### Plan feature table

| Plan Feature | Current Behavior | Uses Real Progress? | Safety Guardrail | UI Surface | Gap |
|-------------|------------------|--------------------|--------------------|------------|-----|
| Adjustment rules | 4 static bullets | **No** | — | `PlanAdjustmentRulesSection` | Not personalized |
| Trend hint | Stable weight ≥7d message | **Partial** (weight only) | Min 3 weights | Same section | No calorie delta |
| Plan confidence | Score 0–100 from logs/weight/HK | **Engagement** not outcome | `PlanSafetyValidator` on plan result | `PlanConfidenceSection` | Misleading as “plan working” |
| Next review | Due after 7d from `profile.updatedAt` | Food ≥3d + recent weight | — | `PlanReviewSection` | No review content |
| Adjust Plan CTA | Static copy | **No** | — | `PlanAdjustPlanCTASection` | No recommendation context |
| Target regeneration | User-initiated wizard | Profile form | `PlanSafetyValidator`, max deficit 25% TDEE | `PlanEditWizard` | Manual only |
| Projection | Static TDEE, target, deficit | **No** trend | Safety validator | `PlanMissionControlHeroSection` | — |
| `TargetService.updateCurrentTargets` | Writes profile + syncs today targets | — | — | Wizard save | — |

### Plan questions

| Question | Answer |
|----------|--------|
| Suggests when to adjust? | **Generic rules** only |
| Losing too fast/slow detection? | **No** automated |
| Compare target to learned maintenance? | **No** |
| Recommend ±100 kcal? | **No** |
| Hold steady vs adjust? | **No** |
| Requires enough data? | `PlanReviewStateBuilder` gates “ready” headline only |
| CTA to edit wizard? | **Yes** — `PlanAdjustPlanCTAStateBuilder` |
| Auto-apply changes? | **No** |
| Changes confirmed? | **Yes** — wizard review step |
| Target changes synced? | **Yes** — `FitnessActionCenter.updatePlan` → cloud |
| Today/Journey refresh after plan change? | **Yes** — refresh bus + `syncTodayTargetsFromProfile` |
| Historical daily targets preserved? | **Likely** — targets snapshotted on `DailyLog` at day level |

---

## 8. Daily Review Audit

| Daily Review Feature | Exists? | Trigger | Persisted? | UI Surface | Gap |
|---------------------|---------|---------|------------|------------|-----|
| `ReviewService.generateDailyReview` | **Yes** | `FitnessActionCenter.generateDailyReview`; Coach `CommandIntent.dailyReview` | `DailyReviewEntity` + `CloudDailyReviewDocument` sync | **Coach response only** | No Today/Journey UI |
| `DailyReviewSummaryBuilder` | **Yes** | Inside `ReviewService.buildSummary` | — | — | — |
| `TodayModel` read | **Yes** | Today load | — | **Not rendered** — `TodayPresentationBuilder` ignores `inputs.dailyReview` | **Confirmed gap** |
| End-of-day wrap-up | **Yes** | Hour ≥ `endOfDayStartHour` (20) | No | `TodayEndOfDayWrapUpSection` | Deterministic, not AI review |
| Daily review history | **No** | — | Entities exist | — | — |
| Feed into weekly review | **No** | — | — | — | — |

### Daily review questions

| Question | Answer |
|----------|--------|
| Generates daily reviews? | **Yes** |
| Entry point for yesterday? | **Coach only** |
| Visible outside Coach? | **No** (wrap-up ≠ full review) |
| Part of Today? | **Read but not shown** |
| Part of Journey? | **No** |
| Persisted and synced? | **Yes** (`DailyReviewEntity`, cloud mapper) |
| Structured or prose? | **Both** — `DailyReviewSummary` + AI sections |
| Analytics events? | `TodayAnalyticsEvent.endOfDayWrapViewed` only; no `daily_review_opened` |

---

## 9. Health Intelligence Weekly Review Audit

### Feature flags (**Confirmed** — `HealthIntelligenceFeatureFlags.swift`)

| Flag | `FormaAbTest` default (`allEnabled`) | Documented production env default |
|------|--------------------------------------|-----------------------------------|
| `foundationEnabled` | true | true |
| `enginesEnabled` | true | true |
| `uiEnabled` | true | **false** |
| `weeklyReviewEnabled` | true | **false** |
| `coachContextEnabled` | true | true |

### HI weekly feature table

| HI Weekly Feature | Current Behavior | Requires HealthKit? | Requires Food Logs? | UI Surface | Gap |
|------------------|------------------|---------------------|---------------------|------------|-----|
| `WeeklyReviewService` | Cache-first; completed calendar week | **Yes** for full compose (`healthConnection == .connected`) | Yes for nutrition stats | Journey HI section | Off by default in prod docs |
| `WeeklyReviewEngine` | Wins, risks, focus, confidence | Partial — nutrition from app logs | Yes for protein/calorie days | Detail sheet | No maintenance kcal |
| `WeeklyReviewCard` | Summary + confidence | Same | Same | Journey | Duplicates habit section |
| `WeeklyReviewDetailView` | Stats grid, insights, focus | Same | Same | Sheet from `JourneyView` | No plan CTA |
| Remote sync | `WeeklyHealthReviewSyncPayload` | Opt-in health summary | Aggregates only | — | Not nutrition restore |
| Recovery / training in review | `RecoveryEngine`, workout counts | **Yes** | No | Detail | — |

### HI questions

| Question | Answer |
|----------|--------|
| Enabled by default? | **FormaAbTest yes**; **documented prod env no** — verify build |
| Without HealthKit? | Habit rows work; HI weekly **nil** (`JourneyHealthIntelligenceSectionLoader` returns early) |
| Duplicates Journey weekly? | **Yes** — parallel habit rows + HI card |
| Calculates maintenance? | **No** |
| Plan recommendations? | **No** |
| Enough data gates? | **Yes** — `WeeklyReviewPolicy` |
| Persists? | **Health cache** only |
| Cross-device? | Health summary sync optional; **recomputed** on device |
| Right foundation for v1? | **Partial** — use engine for wins/risks; **new domain service** for maintenance + plan policy |

---

## 10. Data Sufficiency and Confidence Policy Audit

| Confidence Rule | Location | Requirement | User-Facing? | Gap |
|----------------|----------|-------------|--------------|-----|
| Goal projection min data | `JourneyGoalProjectionBuilder` | ≥3 weights, ≥7d span | **Yes** — insufficient state | — |
| HI weekly moderate | `WeeklyReviewPolicy` | ≥4 health days, ≥4 nutrition days | **Yes** — confidence footer | — |
| HI weekly high | `WeeklyReviewPolicy` | + ≥2 weight records, ≥3 recovery days | **Yes** | — |
| HI weight change | `WeeklyReviewPolicy.minWeightRecords` | 2 records | In stats | — |
| Plan confidence | `PlanConfidenceStateBuilder` | 14d weight, 5 food days for max score | **Yes** — score display | Not outcome confidence |
| Plan review ready | `PlanReviewStateBuilder` | 7d since anchor, 3 food days, recent weight | **Yes** — headline | No review body |
| Plan adjustment trend | `PlanAdjustmentRulesStateBuilder` | ≥3 weights; stable ≥7d for hint | **Yes** | — |
| Weight trend direction | `WeightTrendCalculator` | ≥2 entries for direction | **No** | — |
| Maintenance confidence | — | PRD 7/14/28 days | **No** | **Missing entirely** |
| Spike detection | `WeightTrendCalculator` | ≥2 entries; Δ≥1.0kg | **No** | — |

### Policy questions

| Question | Answer |
|----------|--------|
| Claims blocked when insufficient? | **Projection yes**; habit rows still show with 1 food day |
| Claims with weak data? | HI returns low confidence; habits still celebrate partial wins |
| User told why insufficient? | **Projection yes**; maintenance N/A |
| Consistent across surfaces? | **No** — rolling vs calendar week, different thresholds |
| Reusable confidence policy? | **No** shared `ConfidencePolicy` type |
| Maintenance policy for v1? | **Propose:** 7d min → low; 14d → moderate; 28d → high; block kcal claim below 7 food+weight days |

---

## 11. Sync, Restore, and Cross-Device Freshness Audit

| Data Type | Cloud Synced? | Restored? | Used by Weekly Progress? | Refresh Trigger | Gap |
|----------|---------------|-----------|--------------------------|-----------------|-----|
| Profile / targets | **Yes** | **Yes** | Plan projection, targets in logs | `.profile`, `.plan` events | — |
| `DailyLogEntity` | **Yes** | **Yes** | Journey all builders | `.today`, cross-device | — |
| `FoodEntryEntity` | **Yes** | **Yes** | Habit rows, HI nutrition | `.food` | — |
| `WaterEntryEntity` | **Yes** | **Yes** | Habit rows | `.water` | — |
| `WeightEntryEntity` | **Yes** | **Yes** | Trend, projection, habits | `.weight` | — |
| `DailyReviewEntity` | **Yes** | **Yes** | **Not displayed** | `.dailyReview` | UI gap |
| Weekly review (HI) | Health opt-in (`healthWeeklyReviews`) | **No** as source of truth | HI card | Journey refresh | Recompute preferred |
| `WeeklyReviewEntity` | **No** (dead) | **No** | **No** | — | Remove or repurpose |
| HealthKit raw | Device only | **No** | HI weekly | HK sync | — |
| Sync metadata | **Yes** | **Yes** | Diagnostics only | — | No consumer UI |

### Sync questions

| Question | Answer |
|----------|--------|
| Journey rebuilds after restore? | **Yes** — `JourneyModel.refresh` reads restored SwiftData |
| Weekly review updates after cross-device? | **Yes** — debounced reload |
| Maintenance uses restored data? | **N/A** — no calculator |
| Shows stale weekly progress? | **HI only** (`staleDataLabel`) |
| Pending mutations accounted? | **Yes** — merge policy preserves newer local (Phase 3 docs) |
| Deleted entries handled? | **Yes** — tombstones in sync engine |
| Weekly review synced or recomputed? | **HI: cache + recompute**; Journey habits: **always recompute** |
| Should weekly review persist? | **Recommend recompute** from logs for nutrition; optional cache for HI aggregates |

**Account persistence flags** (**Confirmed** — `AccountPersistenceFeatureFlags.swift`):
- `restoreOnLoginEnabled = true`
- `foregroundCrossDeviceRefreshEnabled = true`
- `pullRecentDataEnabled = false` (bounded pull separate from restore)

---

## 12. UI Surface Audit

| Surface | Weekly Progress Currently Shown? | What It Shows | What It Should Show (v1) | Gap |
|--------|----------------------------------|---------------|--------------------------|-----|
| **Today** | **Partial** | End-of-day wrap-up; mission weight | Weekly teaser + spike hint | No weekly/maintenance |
| **Journey** | **Yes** | Habit rows + optional HI card + projection | **Unified weekly hero** + maintenance + plan rec | Fragmented |
| **Plan** | **Partial** | Static rules, confidence, review due | Learned maintenance + hold/adjust rec | No learned data |
| **Settings** | **No** | — | — | — |
| **WeeklyReviewDetailView** | **Yes** (HI) | Wins/risks/stats | + maintenance + plan CTA | Incomplete |
| **Notifications** | **No** | — | Sunday deep link | Missing entirely |
| **Coach** | **Shallow** | Daily review command | — | — |

### UI journey questions

| Question | Recommendation |
|----------|----------------|
| Weekly review mainly in Journey? | **Yes** |
| Today weekly teaser? | **P1** — “Your week is ready” |
| Plan shows learned maintenance? | **Yes** — P0 |
| Plan hold/adjust recommendation? | **Yes** — P0 |
| Separate weekly detail screen? | **Upgrade existing** `WeeklyReviewDetailView` |
| Daily → weekly feed? | **P1** — aggregate daily summaries |
| Merge HI into same UI? | **Yes** — single builder path |
| Sunday / 7-day user journey? | Notification → Journey weekly detail → optional Plan edit |

---

## 13. Analytics Readiness for Weekly Progress

**Release sink (**Confirmed**):** `AppContainer.swift` `#else` → `NoOpJourneyAnalyticsLogger`, `NoOpPlanAnalyticsLogger`, `NoOpHealthIntelligenceAnalyticsLogger`. **No `FirebaseAnalytics`** in codebase.

### Event table

| Event | Exists? | Debug Only? | Release Sink? | Needed For Sprint? |
|------|---------|-------------|---------------|-------------------|
| `journey_weekly_consistency_viewed` | **Yes** | DEBUG OSLog | **No-op** | Yes |
| `journey_weekly_review_viewed` | **Deprecated** enum only | — | — | Replace |
| `weekly_review_card_viewed` | **Yes** (`HealthIntelligenceAnalyticsLogging`) | DEBUG | **No-op** | Yes |
| `weekly_review_detail_opened` | **Yes** | DEBUG | **No-op** | Yes |
| `weekly_review_completed` | **No** | — | — | **Add** |
| `maintenance_estimate_shown` | **No** | — | — | **Add** |
| `maintenance_estimate_insufficient_data` | **No** | — | — | **Add** |
| `plan_recommendation_shown` | **No** | — | — | **Add** |
| `plan_recommendation_tapped` | **No** | — | — | **Add** |
| `plan_adjust_started` | **Yes** (`PlanAnalyticsEvent`) | DEBUG | **No-op** | Extend with `entry_point=weekly_review` |
| `today_end_of_day_wrap_viewed` | **Yes** | DEBUG | **No-op** | Related |
| `daily_review_opened` | **No** | — | — | P1 |

### Analytics questions

| Question | Answer |
|----------|--------|
| Measure retention impact? | **No** in Release |
| Release analytics no-op? | **Yes** |
| Where to add events? | `JourneyAnalyticsLogging`, `PlanAnalyticsLogging`, new `WeeklyProgressAnalyticsLogging` |
| Privacy-safe properties? | Bucket counts (`weekly_completion_bucket` exists); no raw weights |
| Production backend? | **None** in app — **Unknown** if external |
| OSLog-only acceptable? | DEBUG only today; sprint needs non-noop or Firebase |

---

## 14. Weekly Progress Product Requirements

| Requirement | Current | Target v1 |
|-------------|---------|-----------|
| **Trust: enough data before claims** | Partial | **Yes** — block maintenance <7d |
| **Trust: show confidence** | HI only | **Yes** — unified |
| **Trust: explain uncertainty** | Partial | **Yes** |
| **Trust: water weight** | No | **Yes** — spike copy |
| **Trust: no overreact to one weigh-in** | No UI | **Yes** |
| **Trust: no weak plan recs** | N/A | **Yes** |
| **Trust: formula vs learned label** | No | **Yes** |
| **Motivation: highlight wins** | Partial (habits + HI wins) | **Yes** |
| **Motivation: progress despite noise** | Weak | **Yes** |
| **Motivation: one next action** | Journey CTAs generic | **Yes** — specific rec |
| **Motivation: ritual feel** | No | **Partial** — hero card |
| **Motivation: logging worth it** | Partial | **Yes** — maintenance proof |
| **Action: hold/adjust/consistency** | No | **Yes** |
| **Action: CTA Plan wizard** | Generic adjust CTA | **Yes** — with context |
| **Action: log missing data** | Partial CTAs | **Yes** |
| **Safety: no aggressive auto changes** | Manual wizard | **Yes** |
| **Safety: insufficient data block** | Partial | **Yes** |
| **Safety: water disclaimer** | No | **Yes** |
| **Retention: weekly ready state** | Passive | **Yes** |
| **Retention: notification destination** | No | **P1** |
| **Retention: analytics** | No-op Release | **Yes** |

---

## 15. Proposed Learned Maintenance Formula Candidates

**Do not implement in this packet — design options only.**

### Formula A — Simple energy balance (PRD-aligned)

```
avgIntake = mean(DailyLog.totals.calories) over window W
deltaKg = weightEnd - weightStart  (or 7d avg delta)
dailyEnergyBalance = -(deltaKg × FormaCalculationConstants.kcalPerKgFat) / W_days
learnedMaintenance = round(avgIntake + dailyEnergyBalance)
```

| Aspect | Detail |
|--------|--------|
| Required inputs | `DailyLog`, `WeightEntry` |
| Minimum data | 7 days with ≥5 food-logged days + ≥3 weight entries |
| Confidence | low: 7–13d; moderate: 14–27d; high: 28d+ |
| Failure cases | Weight gain during cut with low intake → noisy; single spike |
| Pros | Matches PRD; explainable; uses existing constants |
| Cons | Sensitive to water weight; needs disclaimer |
| Implementation files | New `Domain/Analytics/MaintenanceEstimateCalculator.swift`; consume in `WeeklyReviewPresentationBuilder` |
| Tests | `MaintenanceEstimateCalculatorTests.swift` |

### Formula B — Conservative TDEE blend

```
energyBalanceMaint = Formula A result
staticTDEE = profile PlanCalculationResult.tdeeKcal
learned = round(blend(staticTDEE, energyBalanceMaint, α))
α = f(confidence)  // e.g. 0.3 low, 0.6 moderate, 1.0 high
```

| Aspect | Detail |
|--------|--------|
| Minimum data | Same as A, but moderate confidence requires 14d |
| Pros | Smoother early weeks; leverages onboarding prior |
| Cons | Harder to explain; may mask real signal |
| Implementation | `MaintenanceEstimateCalculator` + `PlanBodyBaselineMaintenanceEstimator` bridge |

### Formula C — Trend bucket (low data)

No kcal output when confidence low. Classify:

- `likelyTooAggressive` — losing faster than pace + low intake vs static TDEE
- `likelyOnTrack` — weight trend aligns with goal at current intake
- `likelyTooSlow` — flat/up trend during cut with adherence
- `insufficientData`

| Pros | Safest UX week 1–2; avoids false precision |
| Cons | Less satisfying for data-keen users |
| Implementation | `PlanRecommendationPolicy.swift` |

### v1 recommendation

**Use Formula A for display when confidence ≥ moderate (14d), Formula C below 14d, optionally blend per Formula B at moderate confidence.** Single domain type: `MaintenanceEstimate` with `valueKcal: Int?`, `confidence`, `method: .learned | .formula | .insufficient`.

---

## 16. Recommended Sprint Scope

### Sprint title

**Weekly Progress Loop v1**

### Sprint goal

Close the “is my plan working?” loop with a unified Journey weekly ritual, learned maintenance estimate, and safe plan recommendation — without Coach changes or auto-apply.

### User problem

“I've logged faithfully but I don't know if my calories are right, whether the scale means anything, or what to change.”

### P0 features

1. **`MaintenanceEstimateCalculator`** — PRD energy-balance + confidence gates (`FormaCalculationConstants.kcalPerKgFat`)
2. **`WeeklyProgressSummary`** domain model — maintenance, trend verdict, recommendation enum, confidence
3. **`UnifiedWeeklyReviewPresentationBuilder`** — merges `JourneyWeeklyReviewBuilder` + `WeeklyReviewPresentationBuilder` outputs
4. **Journey weekly hero card** — primary ritual surface (new or upgraded section above habit rows)
5. **`WeeklyReviewDetailView` upgrade** — maintenance block, spike/water copy, plan recommendation, confidence footer
6. **`PlanRecommendationPolicy`** — hold steady / consider ±100 / insufficient data; never auto-apply
7. **Plan dashboard maintenance + rec block** — learned vs formula TDEE labels
8. **CTA to `PlanEditWizard`** with `PlanAdjustPlanEntryPoint.weeklyReview` (new constant)
9. **`WeeklyProgressConfidencePolicy`** — shared thresholds (7/14/28)
10. **Weight spike surfacing** — use `WeightTrendCalculator.hasSuddenSpike` + `FormaProductCopy` education
11. **Analytics event contract** — typed events; wire to non-noop logger or Firebase if ready

### P1 features

1. Daily review teaser on Today (link to yesterday's `DailyReview`)
2. Sync freshness microcopy on weekly card (“Updated after sync”)
3. Today weekly teaser when week complete
4. Review history shell (list past weeks)
5. `AppRoute` / deep link destination for future notifications

### Excluded

- Push notifications (fast-follow)
- Coach pipeline changes
- Auto-apply plan targets
- `WeeklyReviewEntity` resurrection (prefer recompute)
- Training logger
- Data export

### Likely files

| Area | Paths |
|------|-------|
| New domain | `Fitness Coach/Domain/Analytics/MaintenanceEstimateCalculator.swift`, `WeeklyProgressSummary.swift`, `PlanRecommendationPolicy.swift`, `WeeklyProgressConfidencePolicy.swift` |
| Builders | `WeeklyReviewPresentationBuilder.swift`, `JourneyPresentationBuilder.swift`, `PlanPresentationBuilder.swift`, `PlanAdjustmentRulesStateBuilder.swift` |
| Journey UI | `JourneyView.swift`, `JourneyDashboardContent.swift`, `WeeklyReview/WeeklyReviewDetailView.swift`, new hero component |
| Plan UI | `PlanDashboardContent.swift`, new recommendation section |
| Today UI | `TodayEndOfDayWrapUpSection.swift` (P1 teaser) |
| Analytics | `JourneyAnalyticsLogging.swift`, `PlanAnalyticsLogging.swift`, `AppContainer.swift` |
| Copy | `FormaProductCopy.swift` |
| Tests | `MaintenanceEstimateCalculatorTests.swift`, extend `WeeklyReviewPresentationBuilderTests.swift`, `PlanRecommendationPolicyTests.swift` |

### Test strategy

- Unit: maintenance calculator fixtures (7/14/28d, insufficient, spike week, maintain goal)
- Unit: recommendation policy never exceeds `PlanSafetyValidator` max delta
- Snapshot: unified weekly presentation personas
- Integration: `JourneyModel` with restored 30-day logs → maintenance + rec
- Manual: `JourneyPreviewData` personas across goal directions

### Risks

| Risk | Mitigation |
|------|------------|
| HI + habit duplication | Single builder; deprecate duplicate section gradually |
| False maintenance from water weight | Confidence + disclaimer + Formula C fallback |
| Rolling vs calendar week confusion | **Pick calendar week** for v1 ritual (align `WeeklyReviewWeekPolicy`) |
| Prod HI flags off | **Do not depend on HI** for core loop |

### Success criteria

- User with 14+ days logs sees maintenance estimate with confidence label
- User receives exactly one primary weekly review path on Journey
- Plan shows hold/adjust recommendation with wizard CTA
- Zero recommendations when <7 food-logged days or <3 weights
- Analytics events fire in DEBUG; contract ready for Release sink

### Phase breakdown

| Phase | Deliverable | Est. |
|-------|-------------|------|
| 1 | `MaintenanceEstimateCalculator` + confidence policy + tests | 2–3d |
| 2 | `WeeklyProgressSummary` + `PlanRecommendationPolicy` | 2d |
| 3 | Unified presentation builder | 2–3d |
| 4 | Journey hero + detail UI + spike copy | 2–3d |
| 5 | Plan maintenance/rec section + wizard entry point | 2d |
| 6 | Analytics + QA | 1–2d |

---

## 17. Alternative Sprint Options

| Sprint | User Impact | Retention Impact | Trust Impact | Complexity | Dependency Risk | Score |
|--------|-------------|------------------|--------------|------------|-----------------|-------|
| **Weekly Progress Loop v1** | 5 | 5 | 5 | 3 | 2 | **15** |
| Notifications / Habit Loop | 4 | 5 | 3 | 3 | 2 | 12 |
| Journey v2 (cosmetic) | 3 | 3 | 3 | 4 | 1 | 9 |
| Plan Auto-Adjustment | 4 | 3 | 4 | 4 | 4 | 10 |
| Analytics Production Wiring | 2 | 4 | 2 | 2 | 1 | 9 |
| Today Dashboard v2 | 3 | 3 | 2 | 3 | 1 | 8 |
| Training Logger v1 | 3 | 2 | 2 | 4 | 2 | 7 |

**Why Weekly Progress Loop first:** Account persistence (phases 1–6) solves data survival; the next retention cliff is **week 2 trust** (“is this working?”). Notifications without a compelling weekly destination push users to the same fragmented experience. Plan auto-adjust without maintenance is unsafe. Analytics should instrument this sprint, not replace it.

---

## 18. P0/P1/P2 Gap Table

| Priority | Gap | Evidence | User Impact | Recommended Fix |
|---------|-----|----------|-------------|-----------------|
| **P0** | No learned maintenance | PRD §9.11; no `MaintenanceEstimateCalculator`; `WeeklyReviewEntity` dead | Cannot answer plan effectiveness | Sprint P0 |
| **P0** | Fragmented weekly review | `JourneyWeeklyReviewSection` + `WeeklyReviewCard`; rolling vs calendar week | Confusion, no ritual | Unified builder + calendar week |
| **P0** | No plan recommendation | `PlanAdjustPlanCTAStateBuilder` static only | No action after review | `PlanRecommendationPolicy` |
| **P0** | Scale spike not surfaced | `hasSuddenSpike` in `JourneyModel` only | Scale panic, quit | Spike copy in weekly detail |
| **P0** | Cannot measure weekly loop | Release `NoOp*AnalyticsLogger` | Can't validate sprint | Analytics contract + sink |
| **P0** | “Is plan working?” unanswered | No maintenance vs target compare | Week 2 drop-off | Plan + Journey rec block |
| **P1** | Daily review invisible | `TodayModel` reads `dailyReview`; builder ignores | Missed daily habit | Today teaser |
| **P1** | No weekly notification | No `UserNotifications` | No extrinsic return | Fast-follow sprint |
| **P1** | Sync freshness invisible | No outbox UI on Journey | Trust after persistence | Microcopy on weekly card |
| **P1** | HI prod flags off | `HealthIntelligenceFeatureFlags` docs UI/weekly false | HI card absent in prod | Non-HI core path |
| **P2** | `WeeklyReviewEntity` orphan | Persistence cleanup notes | Schema confusion | Remove or migrate in cleanup |
| **P2** | Review history | No list UI | Long-term engagement | History shell |
| **P2** | Today 7d weight avg | `WeightTrendCalculator` unused | Daily noise | Today trend hint |

---

## 19. Files Reviewed

### Journey
- `Fitness Coach/Features/Journey/JourneyView.swift`
- `Fitness Coach/Features/Journey/Model/JourneyModel.swift`
- `Fitness Coach/Features/Journey/Model/JourneyDashboardState.swift`
- `Fitness Coach/Features/Journey/Model/JourneyViewState.swift`
- `Fitness Coach/Features/Journey/Model/JourneyProductLayout.swift`
- `Fitness Coach/Features/Journey/Model/JourneyDashboardTypes.swift`
- `Fitness Coach/Features/Journey/Model/JourneyCTA.swift`
- `Fitness Coach/Features/Journey/Model/JourneyCrossDeviceRefreshPolicy.swift`
- `Fitness Coach/Features/Journey/Model/JourneyLogMetrics.swift`
- `Fitness Coach/Features/Journey/Components/JourneyDashboardContent.swift`
- `Fitness Coach/Features/Journey/Components/JourneyWeeklyReviewSection.swift`
- `Fitness Coach/Features/Journey/Components/HealthIntelligence/JourneyHealthIntelligenceSection.swift`
- `Fitness Coach/Application/StateBuilders/Journey/JourneyPresentationBuilder.swift`
- `Fitness Coach/Application/StateBuilders/Journey/JourneyDashboardBuilder.swift`
- `Fitness Coach/Application/StateBuilders/Journey/JourneyWeeklyReviewBuilder.swift`
- `Fitness Coach/Application/StateBuilders/Journey/JourneyWeeklyPatternBuilder.swift`
- `Fitness Coach/Application/StateBuilders/Journey/JourneyGoalProjectionBuilder.swift`
- `Fitness Coach/Application/StateBuilders/Journey/JourneyHeroBuilder.swift`
- `Fitness Coach/Application/StateBuilders/Journey/JourneyHealthIntelligenceSectionLoader.swift`
- `Docs/JourneyArchitecture.md`

### Weekly Review
- `Fitness Coach/Health/Intelligence/WeeklyReviewEngine.swift`
- `Fitness Coach/Health/Intelligence/WeeklyReviewService.swift`
- `Fitness Coach/Health/Intelligence/WeeklyReviewWeekPolicy.swift`
- `Fitness Coach/Application/StateBuilders/Journey/WeeklyReviewPresentationBuilder.swift`
- `Fitness Coach/Features/Journey/Components/WeeklyReview/WeeklyReviewCard.swift`
- `Fitness Coach/Features/Journey/Components/WeeklyReview/WeeklyReviewDetailView.swift`
- `Fitness Coach/Health/Sync/Remote/WeeklyHealthReviewSyncPayload.swift`
- `Fitness Coach/Infrastructure/Persistence/SwiftData/Entities/WeeklyReviewEntity.swift`

### Daily Review
- `Fitness Coach/Data/Repositories/ReviewService.swift`
- `Fitness Coach/Application/StateBuilders/Reviews/DailyReviewSummaryBuilder.swift`
- `Fitness Coach/Features/Today/Model/EndOfDayWrapUpEngine.swift`
- `Fitness Coach/Features/Today/Components/TodayEndOfDayWrapUpSection.swift`
- `Fitness Coach/Infrastructure/Persistence/SwiftData/Entities/DailyReviewEntity.swift`

### Plan
- `Fitness Coach/Application/StateBuilders/Plan/PlanPresentationBuilder.swift`
- `Fitness Coach/Application/StateBuilders/Plan/PlanProjectionBuilder.swift`
- `Fitness Coach/Application/StateBuilders/Plan/PlanBodyBaselineMaintenanceEstimator.swift`
- `Fitness Coach/Application/StateBuilders/Plan/PlanAdjustmentRulesStateBuilder.swift`
- `Fitness Coach/Application/StateBuilders/Plan/PlanAdjustPlanCTAStateBuilder.swift`
- `Fitness Coach/Application/StateBuilders/Plan/PlanConfidenceStateBuilder.swift`
- `Fitness Coach/Application/StateBuilders/Plan/PlanReviewStateBuilder.swift`
- `Fitness Coach/Application/Services/TargetService.swift`
- `Fitness Coach/Domain/PlanCalculation/EnergyCalculator.swift`
- `Fitness Coach/Domain/PlanCalculation/FormaCalculationConstants.swift`
- `Fitness Coach/Domain/Plan/PlanAnalyticsLogging.swift`

### Today
- `Fitness Coach/Features/Today/Model/TodayModel.swift`
- `Fitness Coach/Application/StateBuilders/Today/TodayPresentationBuilder.swift`
- `Fitness Coach/Application/StateBuilders/Today/TodayMissionControlStateBuilder.swift`
- `Fitness Coach/Features/Today/Model/TodayCrossDeviceRefreshPolicy.swift`

### Health Intelligence
- `Fitness Coach/Health/HealthIntelligenceFeatureFlags.swift`
- `Fitness Coach/Configuration/FormaAbTest.swift`
- `Fitness Coach/Domain/HealthIntelligence/HealthIntelligenceAnalyticsLogging.swift`
- `Fitness Coach/Features/HealthIntelligence/HealthIntelligenceAnalyticsCoordinator.swift`

### Persistence / entities
- `Fitness Coach/Infrastructure/Persistence/SwiftData/Entities/DailyLogEntity.swift` (referenced)
- `Fitness Coach/Infrastructure/Persistence/SwiftData/Entities/WeightEntryEntity.swift` (referenced)
- `Fitness Coach/Infrastructure/Cloud/AccountData/CloudDailyReviewDocument.swift` (referenced)

### Sync / restore
- `Fitness Coach/Infrastructure/Cloud/AccountPersistenceFeatureFlags.swift`
- `Fitness Coach/Application/Sync/AccountSyncCoordinator.swift` (referenced)
- `Fitness Coach/Application/Sync/CrossDeviceSyncCoordinator.swift` (referenced)
- `Fitness Coach/Application/Restore/AccountRestoreCoordinator.swift` (referenced)
- `Fitness Coach/Application/Sync/AccountDataRefreshEventBus.swift` (referenced)

### Analytics
- `Fitness Coach/Domain/Journey/JourneyAnalyticsLogging.swift`
- `Fitness Coach/Features/Journey/Model/JourneyAnalyticsCoordinator.swift`
- `Fitness Coach/App/AppContainer.swift` (DEBUG vs Release loggers)
- `Fitness Coach/Infrastructure/Diagnostics/NoOpJourneyAnalyticsLogger.swift` (referenced)

### Tests
- `Fitness CoachTests/WeeklyReviewEngineTests.swift`
- `Fitness CoachTests/WeeklyReviewPresentationBuilderTests.swift`
- `Fitness CoachTests/JourneyWeeklyReviewBuilderTests.swift`
- `Fitness CoachTests/PlanAdjustmentRulesStateTests.swift`
- `Fitness CoachTests/JourneyRevampQAChecklistTests.swift`

### Docs
- `PRD.md`
- `FULL_APP_PRODUCT_LOOP_GAP_CONTEXT_PACKET.md`
- `ACCOUNT_PERSISTENCE_*` (execution map, readiness, restore, implementation plan)
- `Docs/FormaCalculationSpec.md` (referenced)
- `Docs/AccountPersistence/PHASE_2`–`PHASE_5`

---

## 20. Unknowns / Needs Manual Verification

| Item | Why unknown |
|------|-------------|
| Actual App Store HI flag values | `FormaAbTest.allEnabled` vs `HealthIntelligenceFeatureFlags` env doc conflict |
| Real user weekly review open rate | No production analytics |
| Visual clarity of habit rows vs HI card | Device QA only |
| Whether users understand Journey vs Plan roles | User research |
| Account persistence fully deployed | Branch in flight |
| Weekly review cloud sync in production | Health opt-in only |
| Cross-device refresh latency | Runtime |
| Firebase Analytics deployment | Not in Swift codebase |
| Coach daily review usage rate | Out of scope |
| `pullRecentDataEnabled = false` impact on week window completeness | Config vs restore path |
| Whether `journey_weekly_review_viewed` deprecated event still emitted | `JourneyAnalyticsCoordinator` — grep shows `logWeeklyConsistencyViewed` not deprecated name |

---

*End of Weekly Progress Loop Context Packet. Use with ChatGPT for sprint scoping and with Cursor for implementation prompts.*
