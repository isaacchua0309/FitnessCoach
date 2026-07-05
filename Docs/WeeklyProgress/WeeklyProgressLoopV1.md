# Weekly Progress Loop v1

**Status:** Implemented (domain + Journey/Plan/Today surfaces)  
**Related:** [ANALYTICS.md](./ANALYTICS.md), [WEEKLY_PROGRESS_LOOP_CONTEXT_PACKET.md](../../WEEKLY_PROGRESS_LOOP_CONTEXT_PACKET.md), [JourneyArchitecture.md](../JourneyArchitecture.md), [PHASE_5_CROSS_DEVICE_REFRESH.md](../AccountPersistence/PHASE_5_CROSS_DEVICE_REFRESH.md)

---

## 1. Sprint scope

**Sprint title:** Weekly Progress Loop v1

**Goal:** Close the week-2 trust gap — *“Is my plan working?”* — with a unified weekly ritual, learned maintenance estimate, and safe plan recommendations **without** Coach changes, HealthKit dependency, auto-apply targets, or push notifications.

**In scope (P0):**

- `WeeklyProgressSummary` domain model and `WeeklyProgressSummaryBuilder`
- `MaintenanceEstimateCalculator` (PRD §9.11 energy-balance formula + conservative blend)
- `WeeklyProgressConfidencePolicy` (shared sufficiency gates)
- `PlanRecommendationPolicy` (hold / adjust / wait / consistency-first)
- `UnifiedWeeklyReviewPresentationBuilder` (Journey hero + detail + Plan blocks)
- Journey weekly progress hero (`WeeklyProgressHeroSection`)
- `WeeklyReviewDetailView` as canonical “your week” detail sheet
- Plan weekly recommendation section (`PlanWeeklyRecommendationStateBuilder`)
- Today yesterday daily-review teaser (outside Coach)
- Sync/restore freshness microcopy (`WeeklyProgressFreshnessBuilder`)
- Typed analytics contract (`WeeklyProgressAnalyticsLogging`)

**Explicitly excluded:** See [§15 What is explicitly excluded](#15-what-is-explicitly-excluded).

---

## 2. User problem

After the first week of logging, users ask:

- *Is my calorie target right?*
- *Did the scale jump mean I gained fat?*
- *Should I change my plan or keep going?*

Before v1, Journey showed habit consistency rows and optional Health Intelligence weekly cards, but **did not** answer plan effectiveness with learned maintenance, safe calorie deltas, or scale-noise education. Plan showed static TDEE and generic adjustment rules. Daily reviews existed in persistence but were invisible outside Coach.

---

## 3. Current gaps solved

| Gap (pre-v1) | v1 solution |
|--------------|-------------|
| No learned maintenance | `MaintenanceEstimateCalculator` from real intake + weight trend |
| Fragmented weekly surfaces | `UnifiedWeeklyReviewPresentationBuilder` + Journey hero |
| No plan recommendation | `PlanRecommendationPolicy` + Plan weekly section |
| Scale spikes hidden | `WeightTrendCalculator.hasSuddenSpike` surfaced with education copy |
| Daily review invisible on Today | `TodayYesterdayReviewSection` via `DailyReviewEntity` |
| No confidence policy | `WeeklyProgressConfidencePolicy` shared across surfaces |
| Unsafe auto-apply risk | Recommendations open `PlanEditWizard` only; **no target mutation without save** |
| HI-only weekly path | Core loop uses `DailyLog` + `WeightEntry` only — **no HealthKit required** |

---

## 4. WeeklyProgressSummary architecture

### Canonical model

`Fitness Coach/Domain/WeeklyProgress/WeeklyProgressSummary.swift`

`WeeklyProgressSummary` is the **single source of truth** for a completed week window. It is built from restored local data (not Coach, not HI cache) and consumed by Journey, Plan, Today analytics context, and tests.

Key fields:

- **Window:** `startDate`, `endDate`, `foodLoggedDays`, `totalDays`
- **Verdict / action:** `verdict` (`WeeklyProgressVerdict`), `nextAction` (`WeeklyProgressNextAction`), user-facing `headline` / `summary` / `primaryInsight`
- **Maintenance:** embedded `MaintenanceEstimate`
- **Weight:** `startingWeightKg`, `endingWeightKg`, `weightChangeKg`, `weeklyWeightChangeKg`, `hasSuddenSpike`
- **Confidence:** top-level `confidence` mirrors maintenance sufficiency

### Builder pipeline

```
DailyLog + WeightEntry + UserProfile (+ optional HK workout day-starts)
        │
        ▼
WeeklyProgressSummaryBuilder.buildSummary(asOf:profile:dailyLogs:weightEntries:trainingDayStarts:)
        │
        ├─ resolveWeekRange() → completed calendar week (preferred) or rolling 7 days
        ├─ JourneyLogMetrics → food/protein/water/training aggregates
        ├─ WeightTrendCalculator → spike detection, averages
        ├─ MaintenanceEstimateCalculator.estimate()
        ├─ resolveVerdict() + copy assembly
        └─ WeeklyProgressSummary
```

**Week window policy:**

1. **Preferred:** most recent **completed calendar week** with ≥1 food-logged day (`WeeklyReviewWeekPolicy.latestCompletedWeekStart`).
2. **Fallback:** rolling seven-day window ending on `asOf` when no completed week qualifies.

**Calendar span vs week window:** `MaintenanceEstimateInput.calendarSpanDays` uses the full logging-history span for confidence tiers (7 / 14 / 28 day thresholds), while week-window math for aggregates stays on the resolved 7-day range.

### Presentation layer

`UnifiedWeeklyReviewPresentationBuilder` maps `WeeklyProgressSummary` (+ optional HI weekly review, habit rows, profile) → `UnifiedWeeklyReviewState` for UI and `WeeklyProgressDetailState` for the detail sheet.

Journey stores `weeklyProgressSummary` on `JourneyDashboardState`. Plan builds via `PlanWeeklyRecommendationStateBuilder` using the same builder protocol (`WeeklyProgressSummaryBuilding`) for parity tests.

---

## 5. MaintenanceEstimateCalculator formula

**File:** `Fitness Coach/Domain/WeeklyProgress/MaintenanceEstimateCalculator.swift`

### Formula A — energy balance (PRD §9.11)

```
dailyEnergyBalance = -(weightChangeKg × 7700) / windowDays
learnedMaintenance   = averageDailyCalories + dailyEnergyBalance
```

- `7700` = `FormaCalculationConstants.kcalPerKgFat`
- Display rounded to nearest **25 kcal**
- Clamped to plausible adult range **1200–4500 kcal/day**

### Formula B — conservative blend (medium confidence)

When static TDEE is available and confidence is `.medium`:

```
blended = 0.60 × learned + 0.40 × staticTDEE
method  = .conservativeBlend
```

### Methods (`MaintenanceEstimateMethod`)

| Method | When | Shows kcal? |
|--------|------|-------------|
| `.unavailable` | Blocking insufficient data | No |
| `.trendBucketOnly` | Low confidence or ineligible for kcal display | No — trend direction only |
| `.learnedEnergyBalance` | Medium/high + eligible | Yes |
| `.conservativeBlend` | Medium + static TDEE available | Yes |

**Important:** Learned maintenance kcal is **not shown** unless `sufficiency.isEligibleForKcalMaintenanceDisplay` **and** `estimatedMaintenanceKcal != nil`. Plan labels formula TDEE as **“Initial estimate”** and learned value as **“Learned maintenance”** (`FormaProductCopy.PlanMissionControl`).

---

## 6. Confidence / data sufficiency policy

**File:** `Fitness Coach/Domain/WeeklyProgress/WeeklyProgressConfidencePolicy.swift`

### Blocking thresholds (→ `.unavailable`)

| Requirement | Minimum |
|-------------|---------|
| Calendar span | 7 days |
| Food-logged days | 5 |
| Weight entries | 3 |

### Confidence tiers (from `calendarSpanDays`)

| Level | Span |
|-------|------|
| `.low` | 7–13 days |
| `.medium` | 14–27 days |
| `.high` | 28+ days |

High confidence is downgraded to medium if logging consistency &lt; 70%.

### Eligibility flags (`WeeklyProgressDataSufficiency`)

| Flag | Rule |
|------|------|
| `isEligibleForKcalMaintenanceDisplay` | confidence `.medium` or `.high` **and** logging ratio ≥ 70% |
| `isEligibleForPlanRecommendation` | confidence ≠ `.unavailable` **and** logging ratio ≥ 60% |
| `canRecommendPreciseCalorieAdjustment` | plan-eligible + medium/high confidence + no weight-noise reason |

### Non-blocking reasons

- `.inconsistentLogging` — hurts precise deltas; may trigger “improve consistency first”
- `.weightTrendTooNoisy` — paired with `hasSuddenSpike`; blocks precise calorie suggestions

User-facing copy comes from `WeeklyProgressConfidencePolicy.confidenceCopy` / `insufficientDataCopy`.

---

## 7. Weight spike / water-weight handling

**Detection:** `WeightTrendCalculator` — day-over-day increase ≥ **1.0 kg** (`spikeThresholdKg`) sets `hasSuddenSpike`.

**Policy response:**

1. `WeeklyProgressConfidencePolicy` adds `.weightTrendTooNoisy` reason.
2. `MaintenanceEstimateCalculator` sets `shouldShowWaterWeightDisclaimer = true`.
3. `PlanRecommendationPolicy` returns `.waitBecauseScaleIsNoisy` — **no calorie delta**, no plan CTA pressure.
4. `UnifiedWeeklyReviewPresentationBuilder` builds `WeeklyWeightTrendBlockState` with spike title/body from `FormaProductCopy.WeightSpikeEducation`.

**Product rule:** A sudden scale jump is **not treated as fat gain**. Copy explains water weight / noise and recommends holding steady before changing targets.

---

## 8. PlanRecommendationPolicy

**File:** `Fitness Coach/Domain/WeeklyProgress/PlanRecommendationPolicy.swift`

Deterministic, non-AI policy mapping `WeeklyProgressSummary` + profile context → `WeeklyPlanRecommendation`.

### Recommendation kinds

| Kind | Typical trigger |
|------|-----------------|
| `.notEnoughData` | Insufficient confidence / logging |
| `.improveConsistencyFirst` | Inconsistent logging or `needsConsistencyFirst` verdict |
| `.waitBecauseScaleIsNoisy` | Spike / noisy verdict |
| `.holdSteady` | On track |
| `.considerSmallIncrease` | Losing too fast (e.g. +100 or +150 kcal) |
| `.considerSmallDecrease` | Losing too slow with good adherence (−100 kcal) |
| `.reviewPlanManually` | Low confidence aggressive signal — CTA without numeric delta |

### Safety rules

- **The app does not auto-change plan targets.** Every recommendation includes: *“Forma will not change your plan automatically — review and confirm any update.”*
- Suggested deltas respect plan calorie floor via `PlanRecommendationInput.calorieFloorKcal`.
- Low confidence **never** emits a `suggestedCalorieDelta` (manual review only).
- Confirmed changes go through existing `PlanEditWizard` → `FitnessActionCenter.updatePlan` — same path as manual plan edits.

---

## 9. Journey weekly hero UI

**Files:**

- `Fitness Coach/Features/Journey/Components/WeeklyProgress/WeeklyProgressHeroCard.swift`
- `Fitness Coach/Features/Journey/Components/JourneyDashboardContent.swift`
- `Fitness Coach/Features/Journey/Model/JourneyProductLayout.swift`

### Section order

`weeklyProgress` is section **#4** (after goal projection, before Health Intelligence):

```
header → transformation → goalProjection → weeklyProgress → healthIntelligence → …
```

Legacy `weeklyReview` habit rows remain but **collapse** when the hero is visible (`JourneyDashboardCompositionPolicy.collapsesLegacyWeeklyHabitRows`).

### Hero contents

`WeeklyProgressHeroCard` shows:

- Week title + date range
- Headline + summary
- Insufficient-data callout when needed
- Maintenance block (`WeeklyMaintenanceBlockView`)
- Plan recommendation block (when policy allows)
- Weight trend / spike block
- Up to 3 habit rows
- Primary/secondary CTAs (`WeeklyProgressCTA`)
- Freshness microcopy banner

Tap / CTA routes to `WeeklyReviewDetailView` sheet. Analytics: `WeeklyProgressAnalyticsCoordinator.logCardViewed`, maintenance block viewed, plan recommendation shown.

---

## 10. WeeklyReviewDetailView behavior

**File:** `Fitness Coach/Features/Journey/Components/WeeklyReview/WeeklyReviewDetailView.swift`

Canonical full-week ritual surface. Presentation modes: `.loading`, `.empty`, `.loaded(WeeklyProgressDetailState)`.

**Loaded sections (typical):**

- Report header (week range, confidence)
- Maintenance block (learned vs insufficient)
- Plan recommendation block + safety notes
- Weight trend + spike education
- Consistency / habit detail
- Optional HI insights (when loader provides them — supplemental, not required)
- Freshness message when sync/restore active
- Primary CTA (e.g. review plan, keep logging) wired through `WeeklyProgressCTAHandler`

**Analytics:** `logReviewOpened`, `logReviewCompleted`, `logWeightSpikeExplanationShown`, plan recommendation tapped.

Detail state is built by `UnifiedWeeklyReviewPresentationBuilder.buildDetail` — same domain summary as the hero, expanded layout.

---

## 11. Plan recommendation section

**Files:**

- `Fitness Coach/Application/StateBuilders/Plan/PlanWeeklyRecommendationStateBuilder.swift`
- Plan dashboard UI sections consuming `PlanWeeklyRecommendationState`

Plan dashboard shows:

- **Formula maintenance** — static TDEE from `PlanCalculationBridge` (“Initial estimate”)
- **Learned maintenance** — only when eligible (see §6)
- **Weekly recommendation** — title, message, optional `suggestedCalorieDelta`, safety copy
- **Review plan CTA** — opens `PlanEditWizard` at `.reviewChanges` via `showEditPlanFromWeeklyReview(entryPoint:)` — **does not apply deltas**

Entry points: `PlanAdjustPlanEntryPoint.weeklyReview`, `.journeyRecommendation`.

Adjustment rules section (`PlanAdjustmentRulesStateBuilder`) adds static “wait for weekly signal” copy aligned with the same safety message.

---

## 12. Daily review teaser

**Files:**

- `Fitness Coach/Application/StateBuilders/Today/TodayPresentationBuilder.swift` — `yesterdayReview(from:)`
- `Fitness Coach/Features/Today/Components/TodayYesterdayReviewSection.swift`
- `Fitness Coach/Features/Today/Model/TodayActionCoordinator.swift`
- `Fitness Coach/Data/Repositories/ReviewService.swift` — reads `DailyReviewEntity`

### Behavior

For **yesterday** (relative to today’s `DailyLog` date):

1. `TodayModel.makeYesterdayReviewInput` loads yesterday’s log, food count, and `DailyReview` via `dailyReviewReader.getDailyReview(for:)`.
2. `DailyReviewSummaryBuilder.hasEnoughLogsForReview` gates visibility (food, water, workout, or weight signal).
3. If `DailyReview` exists → **View review** CTA with `teaserLines` (summary + section snippets).
4. If eligible but no review → **Generate yesterday’s review** CTA (`FitnessActionCenter.generateDailyReview`).
5. Sheet: `TodayDailyReviewSheet` — **no Coach required** for viewing; generate uses `ReviewService` (deterministic summary + optional AI text).

**Does not duplicate end-of-day wrap-up:** yesterday review covers **prior day**; `EndOfDayWrapUpEngine` covers **today** after 8 PM.

**Coach independence:** View path sets `presentedDailyReview` directly. Coach opens only on generate **failure** fallback.

---

## 13. Sync / restore / cross-device freshness behavior

Weekly progress **recomputes from local SwiftData** after restore or cross-device pull — it does not trust a separate weekly-review cloud document.

### Data dependencies (account persistence)

| Entity | Used for |
|--------|----------|
| `DailyLogEntity` | Intake aggregates, targets |
| `FoodEntryEntity` | Food-day counts |
| `WeightEntryEntity` | Trend, maintenance |
| `DailyReviewEntity` | Today teaser only |
| `UserProfileEntity` | TDEE, targets, goal direction |

### Refresh triggers

| Surface | Policy file | Relevant domains |
|---------|-------------|------------------|
| Journey | `JourneyCrossDeviceRefreshPolicy` | `.journey`, `.food`, `.water`, `.weight`, `.dailyReview`, `.plan`, `.profile`, … |
| Today | `TodayCrossDeviceRefreshPolicy` | `.today`, `.food`, `.water`, `.weight`, `.dailyReview`, `.plan`, `.profile` |
| Plan | `PlanCrossDeviceRefreshPolicy` | `.profile`, `.plan`, … |

`AccountDataRefreshEventBus` → debounced reload (200 ms) → tab models re-call builders.

### Freshness microcopy

`WeeklyProgressFreshnessBuilder` shows non-blocking messages when:

- Account restore in progress
- Cross-device refresh running
- Pending uploads &gt; 0
- Recently restored (within 5 min)
- Just refreshed (within 2 min)

Copy lives in `FormaProductCopy.WeeklyReviewPresentation.Freshness`.

**Note:** Phase 5 cross-device sync makes **nutrition logs and daily reviews** consistent across devices; weekly progress is always **derived**, not uploaded as a standalone artifact. See [PHASE_5_CROSS_DEVICE_REFRESH.md](../AccountPersistence/PHASE_5_CROSS_DEVICE_REFRESH.md).

---

## 14. Analytics event contract

**Domain:** `Fitness Coach/Domain/WeeklyProgress/WeeklyProgressAnalyticsLogging.swift`  
**Coordinator:** `Fitness Coach/Features/Journey/Model/WeeklyProgressAnalyticsCoordinator.swift`  
**Full reference:** [ANALYTICS.md](./ANALYTICS.md)

### Events

| Event | When |
|-------|------|
| `weekly_progress_card_viewed` | Journey hero appears (once per surface session) |
| `weekly_review_opened` | Detail sheet opened |
| `weekly_review_completed` | User finishes detail flow |
| `maintenance_estimate_shown` | Learned maintenance block viewed |
| `maintenance_estimate_insufficient_data` | Formula-only / insufficient state |
| `maintenance_confidence_low` | Low confidence alongside shown estimate |
| `plan_recommendation_shown` | Recommendation block viewed |
| `plan_recommendation_tapped` | User taps plan CTA |
| `plan_edit_started_from_weekly_review` | Wizard opened from weekly context |
| `weight_spike_explanation_shown` | Spike education viewed |
| `daily_review_teaser_viewed` | Today yesterday section viewed |
| `daily_review_opened_from_today` | Teaser opened review sheet |
| `weekly_progress_stale_or_syncing` | Freshness / sync state |
| `weekly_progress_restore_pending` | Restore blocking |

### Privacy

Properties are **bucketed only** — no raw weight, calories, food names, review text, or UID. See `WeeklyProgressAnalyticsContextBuilder`.

### Sink status

| Build | Logger |
|-------|--------|
| DEBUG | `OSLogWeeklyProgressAnalyticsLogger` (when trace flag on) |
| Release | `NoOpWeeklyProgressAnalyticsLogger` |

**Production analytics sink may still need separate wiring** (e.g. Firebase Analytics adapter implementing `WeeklyProgressAnalyticsLogging`). The contract and tests are ready; Release currently no-ops by design.

---

## 15. What is explicitly excluded

| Item | Notes |
|------|-------|
| **Auto-apply plan targets** | Recommendations never mutate `UserProfile.targets` without wizard save |
| **Coach pipeline changes** | No new Coach intents or context packet requirements |
| **HealthKit requirement** | Core loop uses app logs + weight only; HI section remains optional supplement |
| **Push notifications** | Future work — no `UserNotifications` scheduling in v1 |
| **`WeeklyReviewEntity` resurrection** | Orphan schema; weekly progress recomputes from daily data |
| **Training Logger** | Out of scope |
| **Production analytics backend** | Contract only; Release no-op until wired |
| **Review history browser** | No multi-week list UI in v1 |
| **Raw cloud weekly progress document** | Not synced; recompute on device |

---

## 16. Test coverage

Primary test files (run in `Fitness CoachTests`):

| Area | File |
|------|------|
| Maintenance formula | `MaintenanceEstimateCalculatorTests.swift` |
| Confidence policy | `WeeklyProgressConfidencePolicyTests.swift` |
| Summary assembly | `WeeklyProgressSummaryBuilderTests.swift` |
| Plan recommendations | `PlanRecommendationPolicyTests.swift` |
| Unified presentation | `UnifiedWeeklyReviewPresentationBuilderTests.swift` |
| Journey hero | `JourneyWeeklyProgressHeroTests.swift` |
| Plan integration | `PlanWeeklyRecommendationStateBuilderTests.swift`, `PlanEditWizardEntryPointTests.swift` |
| Spike copy | `WeightSpikeEducationCopyTests.swift` |
| Freshness | `WeeklyProgressFreshnessBuilderTests.swift` |
| Analytics | `WeeklyProgressAnalyticsTests.swift`, `WeeklyProgressAnalyticsLoggingTests.swift` |
| Today teaser | `TodayPresentationBuilderTests.swift` (presentation), `DailyReviewSummaryBuilderTests.swift` (teaser lines) |
| QA personas | `JourneyRevampQAChecklistTests.swift` |
| Cross-device refresh | `PlanCrossDeviceRefreshTests.swift`, `TodayCrossDeviceRefreshTests.swift` |

Shared fixtures: `UnifiedWeeklyReviewTestFixtures.swift`, `PlanWeeklyRecommendationTestFixtures.swift`.

**Key assertions across tests:**

- No auto-apply on `showEditPlanFromWeeklyReview`
- Learned maintenance hidden when insufficient
- Low confidence suppresses calorie deltas
- Journey and Plan presentation parity for recommendation blocks
- Analytics properties privacy-safe (bucketed, no raw telemetry)

---

## 17. Future work

| Priority | Item |
|----------|------|
| P1 | Push notifications — Sunday weekly review deep link |
| P1 | Wire `WeeklyProgressAnalyticsLogging` to production sink (Firebase or approved backend) |
| P1 | Multi-week review history |
| P2 | Today 7-day weight average in mission hero |
| P2 | Remove legacy Journey habit section after HI consolidation |
| P2 | Aggregate daily reviews into weekly narrative |
| P3 | Optional maintenance blend tuning from field data |
| P3 | `WeeklyReviewEntity` schema cleanup |

---

## Safety rules (quick reference)

1. **The app does not auto-change plan targets.**
2. **Recommendations require confirmation** through the existing Plan edit wizard (`PlanEditWizard` → `savePlanFromWizard`).
3. **Learned maintenance is not shown with insufficient data** (`isEligibleForKcalMaintenanceDisplay`).
4. **Scale spikes are not treated as fat gain** — wait/hold copy, no aggressive decrease.
5. **The feature does not require Coach.**
6. **The feature does not require HealthKit.**
7. **Notifications are future work.**
8. **Release analytics may still be no-op** until a production sink is wired.

---

## Key file index

```
Fitness Coach/Domain/WeeklyProgress/
  WeeklyProgressSummary.swift
  MaintenanceEstimateCalculator.swift
  WeeklyProgressConfidencePolicy.swift
  PlanRecommendationPolicy.swift
  WeeklyProgressAnalyticsLogging.swift

Fitness Coach/Application/StateBuilders/
  WeeklyProgress/WeeklyProgressSummaryBuilder.swift
  Journey/UnifiedWeeklyReviewPresentationBuilder.swift
  Journey/WeeklyProgressFreshnessBuilder.swift
  Plan/PlanWeeklyRecommendationStateBuilder.swift
  Today/TodayPresentationBuilder.swift
  Reviews/DailyReviewSummaryBuilder.swift

Fitness Coach/Features/
  Journey/Components/WeeklyProgress/WeeklyProgressHeroCard.swift
  Journey/Components/WeeklyReview/WeeklyReviewDetailView.swift
  Today/Components/TodayYesterdayReviewSection.swift
```
