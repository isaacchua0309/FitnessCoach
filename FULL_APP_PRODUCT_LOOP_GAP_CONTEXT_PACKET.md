# Full App Product Loop and Retention Gap Context Packet

**Generated:** 2026-07-05  
**Branch audited:** `feature/account-persistence-restore` (working tree with account persistence phases 1–6 in flight)  
**Scope:** Non-Coach application surfaces, loops, retention, trust, and day-to-day usefulness. Coach mentioned only where it affects the broader loop.  
**Method:** Static code + docs audit only. No runtime behavior changes. Claims tagged **Confirmed**, **Likely**, or **Unknown**.

**Primary sources read:**
- `PRD.md`
- `USER_DATA_STORAGE_CONTEXT_PACKET.md`
- `ACCOUNT_PERSISTENCE_EXECUTION_MAP.md`
- `ACCOUNT_PERSISTENCE_PHASE_READINESS.md`
- `ACCOUNT_PERSISTENCE_RESTORE_CONTEXT_PACKET.md`
- `ACCOUNT_PERSISTENCE_IMPLEMENTATION_PLAN.md`
- `Docs/AccountPersistence/PHASE_2_CLOUD_SCHEMA_AND_RULES.md`
- `Docs/AccountPersistence/PHASE_3_LOCAL_FIRST_SYNC_ENGINE.md`
- `Docs/AccountPersistence/PHASE_4_FRESH_INSTALL_RESTORE.md`
- `Docs/AccountPersistence/PHASE_5_CROSS_DEVICE_REFRESH.md`
- `Docs/JourneyArchitecture.md`
- `Docs/FormaCalculationSpec.md` (referenced by `TargetService`)
- `Docs/HealthIntelligence/*` (release readiness, sync contract — not fully inlined)

**Note:** `Docs/AccountPersistence/PHASE_6_ACCOUNT_DELETION_AND_PRIVACY.md` was **not found** in repo; Phase 6 behavior inferred from `AccountDeletionCoordinator.swift`, `SettingsAccountDeletionFlowView.swift`, and implementation plan docs.

---

## 1. Executive Summary

### What the app currently does well (**Confirmed**)

FitPilot AI / Forma is a four-tab iOS fitness app (`MainTabView` → Today, Coach, Journey, Plan) with a polished onboarding wizard, deterministic plan math (`FormaCalculationEngine` / `PlanCalculationBridge`), and a feature-rich **Today Mission Control** dashboard. Users can log food (manual sheets + optional photo scan), water, and weight; see macro/calorie progress; get deterministic next-best-action guidance (`NextBestActionEngine`); and receive end-of-day wrap-up (`EndOfDayWrapUpEngine`). **Journey** narrates transformation, goal projection, weekly habit rows, milestones, and story timeline. **Plan** explains targets, confidence, rationale, and supports a multi-step edit wizard. Account persistence work (UID hardening, Firestore schema, sync outbox, restore pipeline, cross-device refresh, account deletion backend) is substantially implemented on the current branch.

### Day 1 experience (**Likely**)

Fresh install → welcome/auth gate (`AuthGateView` / `AuthGateRouteView`) → 14-step onboarding (`OnboardingStep.flow`) collecting body stats, goal, pace, activity, optional Apple Health → animated plan generation/reveal → sign-in on save step → `MainTabView` with Today populated from generated profile and empty logs. User sees calorie mission hero, quick actions (log meal, scan, weight, training sheet), and coaching nudges. Logging friction is lower via Coach chat than manual sheets, but Today still exposes parallel manual logging UI.

### Day 7 experience (**Likely**)

If the user logs most days: Today shows meaningful mission state, victory section, and evening wrap-up. Journey shows transformation hero, goal projection (if ≥3 weight logs over ≥7 days — `JourneyGoalProjectionBuilder`), weekly habit rows (`JourneyWeeklyReviewBuilder`), and possibly Health Intelligence weekly review cards **only if** `FormaAbTest.HealthIntelligence.weeklyReviewEnabled` is true (defaults **true** in `FormaAbTestSnapshot.allEnabled`, but HI UI is separately gated). **No push notifications** bring the user back. Weekly “maintenance from real data” (PRD §9.11) is **not implemented** — maintenance shown in Plan is formula-based TDEE (`EnergyCalculator.tdeeKcal`), not learned from intake + weight trend. User may feel progress visually but lacks a authoritative “is my plan working?” answer.

### After reinstall / new device (**Confirmed** with persistence branch)

With `AccountPersistenceFeatureFlags.restoreOnLoginEnabled = true` and sync engine enabled: sign-in triggers `AccountRestoreCoordinator` / `AccountRestoreView` blocking UI, then tabs populate from cloud pull into UID-scoped SwiftData. `TodayView` / `JourneyView` show `AccountRestorePendingStateView` while restore is pending. **Without** completed persistence ship: historical audit docs describe empty Today/Journey after reinstall — branch code aims to fix this. Health summaries remain opt-in upload-only for remote read (**Confirmed** in phase readiness docs). Theme/consent UserDefaults may not restore (**Likely**).

### Loop inventory

| Loop | Status | Notes |
|------|--------|-------|
| **Daily tracking** | **Strong** | Today dashboard + Coach logging + cross-device refresh |
| **Weekly review** | **Partial** | Two parallel systems; no learned maintenance; no scheduled trigger |
| **Habit / reminder** | **Weak** | In-app nudges only; zero `UserNotifications` usage |
| **Progress / trust** | **Moderate** | Journey projection + weight trend math exist; panic-prevention coaching thin outside Coach |
| **Trust / data** | **Improving** | Sync/restore built; consumer sync status UX thin; export stub |
| **Training** | **Hidden** | `TrainingInsightsView` sheet only; HealthKit-dependent; no manual strength logger UI |

### Biggest user-facing gaps (**Confirmed** unless noted)

1. **No notification / habit loop** — nothing schedules local or push reminders.
2. **No learned maintenance estimate** from real intake + weight trend (PRD §9.11 “Should Have”).
3. **Weekly review split** — Journey habit rows (`JourneyWeeklyReviewSection`) vs HI `WeeklyReviewCard` / `WeeklyReviewDetailView`; no unified “your week” ritual.
4. **No dedicated Daily Review screen** — `ReviewService` persists reviews; UI is end-of-day wrap-up on Today only.
5. **Training surface hidden** — not a tab; no manual workout logger outside Coach.
6. **Duplicate logging surfaces** — Today manual meal/weight sheets parallel Coach conversational logging.
7. **Sync/pending state invisible** on main tabs except restore-pending blocker and subtle cross-device refresh capsule (**Likely**).
8. **Data export not implemented** — `SettingsExportDataActionHandler.perform()` returns `false` with TODO.
9. **Analytics no-op in Release** — `#else` branch uses `NoOp*AnalyticsLogger` in `AppContainer.swift` (**Confirmed**).

### Biggest architectural gaps

1. **Product analytics pipeline absent** — typed events exist but Release sinks are no-ops; no Firebase Analytics / third-party SDK (**Confirmed**).
2. **Maintenance intelligence not in domain layer** — only static TDEE previews (`PlanBodyBaselineMaintenanceEstimator`); `WeeklyReviewEntity.estimatedMaintenance` field exists but no population path found (**Confirmed**).
3. **Plan auto-adjustment not closed-loop** — Plan shows “when to adjust” copy (`PlanAdjustmentRulesSection`) but no automatic recommendation from trend (**Confirmed**).
4. **Widget extension absent** — no WidgetKit targets (**Confirmed**).
5. **Coach-adjacent data without non-Coach consumer** — daily review AI narrative generated in `ReviewService` but not surfaced as first-class UI.

### Biggest retention risks

1. **D1→D7 drop without extrinsic reminders** (no notifications).
2. **Scale panic** when Journey/Plan cannot explain water weight without opening Coach.
3. **Week-2 motivation cliff** if weekly review feels like static rows, not a compelling recap + next step.
4. **Trust erosion** if users cannot see sync/backup status after persistence ships.
5. **Cannot measure sprint impact** until analytics ship beyond DEBUG OSLog.

### Biggest clarity / motivation risks

1. Today has many sections — 5-second comprehension depends on mission hero + next action (**Likely** good, not verified on device).
2. Missing vs zero data distinction exists in engines (`TodayMealsEmptyKind`, `TodayEndOfDayRowStatus.notLogged`) but user clarity **Unknown** on device.
3. Onboarding does not set expectations about water weight / weekly trends explicitly in all paths (**Likely** — some copy in `FormaProductCopy` but not a dedicated education step).

### Verdict

**Current product loop strength: Moderate**

**Why:** The daily loop (open → see targets → log → feedback on Today) is credible and well-engineered. Onboarding → Plan → Today forms a coherent Day 0 path. Account persistence work addresses the former “data dies on reinstall” trust breaker. However, the **weekly loop, habit loop, and learned-progress loop are incomplete**: no notifications, no maintenance-from-data, fragmented weekly review, hidden training, and no production analytics. The app tracks well but does not yet **reliably bring users back** or **prove the plan is working** without Coach. It is past “not yet credible” for daily tracking, but not **Strong** until week-over-week retention mechanics and progress trust close.

---

## 2. Current App Surface Inventory

| Surface | File Paths | Purpose | Current Capabilities | Missing Capabilities | Product Risk |
|--------|------------|---------|----------------------|----------------------|--------------|
| **Auth** | `Fitness Coach/Features/Auth/AuthGateView.swift`, `AuthGateCoordinator.swift`, `Views/AuthGateRouteView.swift`, `PublicWelcomeView.swift`, `ExistingUserSignInView.swift` | Route unauthenticated users | Welcome, existing-user sign-in, Google auth, profile bootstrap, conflict/mismatch screens | Social auth beyond Google **Unknown** | Auth friction before onboarding (`requiresSignInBeforeOnboarding` default true) |
| **Onboarding** | `Features/Onboarding/OnboardingView.swift`, `Model/OnboardingModel.swift`, `OnboardingStep.swift`, `Domain/Onboarding/*`, `Application/UseCases/Onboarding/*` | First-run profile + plan | 14-step wizard, draft persistence, Apple Health step, plan generation/reveal, save+sign-in | Diet preferences/common foods optional & light; no explicit “how tabs work together” step | Drop-off before save; aggressive goal safety relies on `PlanSafetyValidator` |
| **Today** | `Features/Today/TodayView.swift`, `Model/TodayModel.swift`, `TodayActionCoordinator.swift`, `Application/StateBuilders/Today/*` | Daily mission control | Macros, water, meals, weight, activity, next-best-action, quick actions, end-of-day wrap-up, optional HI section, pull-to-refresh, cross-device refresh | Dedicated daily review screen; sync status banner; offline copy | Duplication with Coach logging; cognitive load |
| **Coach (shallow)** | `Features/Coach/CoachView.swift`, `CoachModel.swift` | Conversational logging & coaching | Primary low-friction log path; routes from Today quick actions | Excluded from deep audit | Users may not discover Coach as primary logger |
| **Journey / Progress** | `Features/Journey/JourneyView.swift`, `Model/JourneyModel.swift`, `Application/StateBuilders/Journey/*`, `Docs/JourneyArchitecture.md` | Narrative progress dashboard | Transformation hero, goal projection, milestones, weekly habit rows, story timeline, chapters/XP, optional HI weekly review card | Unified weight trend chart surface; learned maintenance; plan-adjust CTA wired to recommendation | Progress feels aesthetic vs actionable |
| **Plan** | `Features/Plan/PlanView.swift`, `Model/PlanModel.swift`, `UI/PlanEditWizard*`, `Application/StateBuilders/Plan/*`, `Domain/PlanCalculation/*` | Strategy & targets | TDEE-based targets, edit wizard, confidence, rationale, assumptions, adjustment rules copy, settings entry | Auto-adjust from real trend; learned vs initial maintenance distinction in UI | Users may not understand formula maintenance |
| **Training** | `Features/TrainingInsights/TrainingInsightsView.swift`, `Domain/Training/*`, `Infrastructure/Health/HealthTrainingService.swift` | Workout insights sheet | HealthKit workout read, weekly summary, consistency note, gate for disconnected Health | Manual workout log UI; strength trends; tab visibility | Training invisible to most users |
| **Settings** | `Features/Settings/SettingsRootView.swift`, `Model/SettingsPresentationBuilder.swift`, `UI/*` | Preferences & account hub | Account, units, theme, body details, macros, Apple Health, legal, support, developer tools | Export; production-visible delete depends on flags | Privacy rows hidden when flags off |
| **Privacy & Data** | `Application/Privacy/AccountDeletionCoordinator.swift`, `Features/Settings/UI/SettingsAccountDeletionFlowView.swift`, `SettingsDeleteDataActionHandler.swift` | Deletion & legal | Full deletion orchestration (remote, auth, local wipe); confirmation phrase `DELETE`; legal docs | Export; remote-only delete scope disabled | Phase 6 backend exists; export still TODO |
| **Health integration** | `Health/HealthKit/HealthKitManager.swift`, `Health/Intelligence/*`, `Health/Repository/HealthDataRepository.swift` | HealthKit + HI engines | Steps, workouts, sleep, recovery, training load, baselines, optional cloud summary sync | Full non-Coach workout logging; HI weekly review flag-gated | Over-engineered vs surfaced value if flags off |
| **Notifications** | *None* | Re-engagement | In-app weight reminder flags (`TodayEmptyStateFormatting.shouldShowWeightReminder`) | Entire notification stack | **Critical retention gap** |
| **Restore / sync states** | `Application/Restore/*`, `Application/Sync/*`, `Features/Auth/Views/AccountRestoreView.swift`, `AccountRestorePendingStateView.swift` | Account persistence | Restore blocking UI, pending tab state, outbox upload, cross-device refresh, realtime listener | User-visible “last synced”; pending upload indicator on Today | Silent sync failures invisible |
| **Empty / error / loading** | `DesignSystem/Components/FormaScreenLoadingView.swift`, `FormaScreenErrorView.swift`, per-feature `*EmptyStateView.swift` | Non-happy paths | Skeleton (Today), shared error with retry, empty → Plan/Today CTAs | Offline-specific copy; partial restore warnings on dashboards | False empty after restore delay |

---

## 3. End-to-End User Loop Map

### 3.1 Day 0 / First Install Loop

| Stage | Detail | Confidence |
|-------|--------|------------|
| **Entry point** | `Fitness_CoachApp` → `AuthGateView` | Confirmed |
| **User action** | Complete welcome → onboarding OR existing-user sign-in | Confirmed |
| **App response** | `OnboardingModel` advances `OnboardingStep.flow`; `OnboardingPlanGenerationExecutor` builds targets; `OnboardingCompletionPolicy` routes to `MainTabView` | Confirmed |
| **Data read** | `OnboardingDraftStore`, `PlanTargetCalculating`, optional `TrainingIntegrationProviding` | Confirmed |
| **Data written** | `UserProfileEntity` via `OnboardingProfileCommitter`; optional cloud profile upload | Confirmed |
| **Feedback/reward** | Plan reveal animation (`OnboardingPlanRevealStepView`), land on Today | Confirmed |
| **Failure points** | Cloud profile conflict (`ProfilePlanConflictView`); Apple Health denied (non-blocking); generation failure state | Confirmed |
| **Missing states** | Explicit “data will sync when you sign in” before save; tab tour | Likely gap |

### 3.2 Daily Tracking Loop

| Stage | Detail | Confidence |
|-------|--------|------------|
| **Entry point** | Today tab (default tab in `MainTabView`) | Confirmed |
| **User action** | Log food/water/weight via sheets or Coach; pull-to-refresh | Confirmed |
| **App response** | `TodayActionCoordinator` mutates via `FitnessActionCenter`; `TodayModel.load()` rebuilds `TodayDashboardState` via `TodayPresentationBuilder` | Confirmed |
| **Data read** | `DailyLogReading`, `FoodLogReading`, `WeightLogReading`, `UserProfileReading`, `HealthActivityQueryService` | Confirmed |
| **Data written** | SwiftData entities + `AccountLocalMutationTracker` / outbox for sync | Confirmed |
| **Feedback/reward** | Mission hero status, next-best-action, daily victory, smart coach banner, transient banners on error | Confirmed |
| **Failure points** | Mutation errors → `FormaTransientBanner`; restore pending blocks dashboard | Confirmed |
| **Missing states** | Obvious “pending upload” on mutations; offline queue visibility | Confirmed gap |

### 3.3 Progress Loop

| Stage | Detail | Confidence |
|-------|--------|------------|
| **Entry point** | Journey tab; Today goal connection row | Confirmed |
| **User action** | View transformation, projection, weekly rows; optional weekly review detail sheet | Confirmed |
| **App response** | `JourneyModel` → `JourneyPresentationBuilder` / `JourneyDashboardBuilder` | Confirmed |
| **Data read** | Weight logs, daily logs, profile, `TrainingInsightsStore`, optional HI snapshot | Confirmed |
| **Data written** | Read-only (no Journey mutations) | Confirmed |
| **Feedback/reward** | Goal projection ETA, milestone CTAs, chapter XP | Confirmed |
| **Failure points** | `JourneyStartingEmptyStateView` when insufficient data; projection hidden until 3 weights / 7 days | Confirmed |
| **Missing states** | Learned maintenance; “plan working?” summary; panic explanations on scale spikes outside Coach | Confirmed gap |

### 3.4 Weekly Review Loop

| Stage | Detail | Confidence |
|-------|--------|------------|
| **Entry point** | Journey `JourneyWeeklyReviewSection` + optional `WeeklyReviewCard` | Confirmed |
| **User action** | Scroll Journey; tap weekly review detail | Confirmed |
| **App response** | `JourneyWeeklyReviewBuilder` habit rows; `WeeklyReviewEngine` + `WeeklyReviewPresentationBuilder` for HI card | Confirmed |
| **Data read** | 7-day logs, weights, workouts, recovery summaries | Confirmed |
| **Data written** | `WeeklyReviewEntity` exists; HI service cache **Likely** | Likely |
| **Feedback/reward** | Win-sorted habit rows; HI insights/focus lists | Confirmed |
| **Failure points** | No food logs → `noFoodLogsSummary` copy | Confirmed |
| **Missing states** | Auto Sunday trigger; notification; maintenance estimate; plan change recommendation; review history list | Confirmed gap |

### 3.5 Habit Loop

| Stage | Detail | Confidence |
|-------|--------|------------|
| **Entry point** | *None scheduled* — user self-opens app | Confirmed |
| **User action** | Respond to in-app next-best-action or weight empty-state nudge | Confirmed |
| **App response** | `NextBestActionEngine`, `HealthNextBestActionEngine` (weight after 17:00) | Confirmed |
| **Data read** | Same-day logs | Confirmed |
| **Data written** | On user action only | Confirmed |
| **Feedback/reward** | CTA completion → updated dashboard | Confirmed |
| **Failure points** | No extrinsic trigger → user forgets | Confirmed |
| **Missing states** | Entire reminder notification system; deep links from notifications | Confirmed gap |

### 3.6 Recovery / Training Loop

| Stage | Detail | Confidence |
|-------|--------|------------|
| **Entry point** | Today activity section → `TrainingInsightsView` sheet; HI recovery cards when enabled | Confirmed |
| **User action** | Connect Apple Health; view workouts | Confirmed |
| **App response** | `TrainingInsightsAggregator`, `RecoveryEngine`, `TrainingLoadEngine` | Confirmed |
| **Data read** | HealthKit workouts, steps, sleep | Confirmed |
| **Data written** | Health cache JSON; optional cloud health summary (opt-in) | Confirmed |
| **Feedback/reward** | Recovery card, adaptive nutrition card on Today | Confirmed (flag-gated) |
| **Failure points** | Health denied → `TrainingInsightsGateView` | Confirmed |
| **Missing states** | Manual workout path in non-Coach UI; nutrition adjustment surfacing on Plan | Likely gap |

---

## 4. Today Dashboard Audit

### Architecture (**Confirmed**)

| Layer | Paths |
|-------|-------|
| View | `TodayView.swift`, `TodayReadOnlyView.swift`, 20+ component files under `Features/Today/Components/` |
| Model | `TodayModel.swift`, `TodayActionCoordinator.swift`, `TodayDashboardState.swift` |
| State builders | `TodayPresentationBuilder.swift`, `TodayMissionControlStateBuilder.swift`, `TodayGoalsBuilder.swift`, `TodayFocusBuilder.swift` |
| Engines | `NextBestActionEngine`, `SmartCoachEngine`, `DailyVictoryEngine`, `EndOfDayWrapUpEngine`, `TodayMealsGroupingEngine` |
| Section order | `TodayDashboardSectionOrder` — header → missionHero → nextBestAction → quickActions → meals → macroHydration → activity → dailyVictory → smartCoach → endOfDayWrapUp (+ optional HI above mission) |

### Today Element Table

| Today Element | Current Behavior | Data Source | User Value | Gap | Recommended Improvement |
|--------------|------------------|------------|------------|-----|-------------------------|
| Mission hero | Calorie phase/status, protein remaining, weight summary | `DailyLog`, profile targets, weight logs | At-a-glance day status | May not explain *why* over/under | Add one-line “because” copy from deterministic rules |
| Next best action | Time-aware CTA (breakfast/lunch/protein/water/workout) | Food entries, macros, water %, workout summary | Clear next step | Duplicated when HI enabled (`TodayReadOnlyCompositionPolicy`) | Single NBA source of truth |
| Quick actions | Log meal, scan food, weight, training sheet, coach routes | `TodayQuickActionPolicy` | Speed logging | Overlaps Coach | Default to Coach route for meal log |
| Meals timeline | Grouped entries, edit/delete sheets | `FoodLogReading` | Accountability | Manual form friction | Emphasize Coach prefill |
| Macro/hydration card | Calorie + macro rings, water quick-add | `DailyNutritionSummaryBuilder` | Track targets | Water behavior not pedagogical | Short pacing hint |
| Weight card | Latest weight in mission | `WeightLogReading` | Trend anchor | No 7-day avg on Today | Show smoothed trend hint |
| Activity | Steps/workout summary; opens Training sheet | `HealthActivityQueryService`, `TrainingInsightsStore` | Training awareness | Hidden if HI replaces section | Clear “connect Health” CTA |
| Daily victory | Celebrates target hits | `DailyVictoryEngine` | Positive reinforcement | Only when conditions met | Softer partial-win states |
| Smart coach banner | Contextual nudge copy | `SmartCoachEngine` | Lightweight coaching | Not full daily review | Link to review when available |
| End-of-day wrap-up | Evening rows for calories/protein/water/workout | `EndOfDayWrapUpEngine` | Day closure | Not persisted review history; no AI narrative UI | Surface `ReviewService` output |
| HI section | Recovery, workout, adaptive nutrition cards | `HealthIntelligenceSnapshotServing` | Training-aware guidance | Flag-gated; adds complexity | Ship criteria + default on |
| Loading | `TodayDashboardSkeletonView` | — | Perceived performance | — | — |
| Empty | `TodayEmptyStateView` → Plan | Profile missing | Recovery path | — | — |
| Error | `FormaScreenErrorView` + retry | — | Recoverable | — | — |
| Restore pending | `AccountRestorePendingStateView` | `AccountRestoreSessionState` | Blocks false empty | No partial data preview | Progressive reveal |
| Cross-device refresh | Capsule `ProgressView` overlay | `CrossDeviceSyncCoordinator` | Fresh data | Easy to miss | “Updated from your other device” toast |

### Today Questions

| Question | Answer | Confidence |
|----------|--------|------------|
| Can user understand their day in 5 seconds? | **Likely yes** if mission hero visible; **Unknown** on small devices with HI enabled | Likely |
| Does Today show next best action? | **Yes** — `NextBestActionEngine` / HI NBA when enabled | Confirmed |
| Does Today explain on-track status? | **Partial** — `TodayMissionStatus` + status lines | Confirmed |
| Distinguishes missing vs zero data? | **Partial** — `TodayMealsEmptyKind`, end-of-day `notLogged` | Confirmed in code |
| Handles partial restore/offline? | **Partial** — restore pending only; no offline banner | Confirmed gap |
| Water/weight/protein behavior obvious? | **Partial** — progress bars yes; education thin | Likely |
| Manual logging duplicates Coach? | **Yes** — `TodayLogMealSheet`, `TodayLogWeightSheet` | Confirmed |
| Shows sync/pending when needed? | **No** user-facing pending upload state | Confirmed |

---

## 5. Journey / Progress Audit

### Architecture (**Confirmed**)

- **View:** `JourneyView.swift`, `JourneyDashboardContent.swift`, section components
- **Model:** `JourneyModel.swift`, `JourneyViewState.swift`, `JourneyDashboardState.swift`
- **Builders:** 17 files under `Application/StateBuilders/Journey/` — key: `JourneyDashboardBuilder`, `JourneyHeroBuilder`, `JourneyGoalProjectionBuilder`, `JourneyStreakBuilder`, `JourneyWeeklyReviewBuilder`, `JourneyWeeklyPatternBuilder`, `WeeklyReviewPresentationBuilder`
- **Weight trend:** `WeightTrendCalculator` (7-day average, spike detection ≥1.0 kg)
- **Projection:** `ProgressProjectionCalculator` via `JourneyGoalProjectionBuilder` (min 3 weights, 7-day span)

### Journey Element Table

| Journey Element | Current Behavior | Calculation | Data Source | Trust Risk | Gap |
|----------------|------------------|-------------|------------|------------|-----|
| Transformation hero | Start vs current weight narrative | `JourneyHeroBuilder` | Profile + weight logs | Low | — |
| Goal projection | ETA to goal weight | `ProgressProjectionCalculator` | Weight trend | Medium if <7 days data | Needs data sufficiency UI |
| Weekly habit rows | Food/protein/water/training/calorie/weight wins | `JourneyWeeklyReviewBuilder` | 7-day `DailyLog` | Low | Not a full “review” experience |
| HI weekly review card | Nutrition/recovery/workout insights | `WeeklyReviewEngine` | HI inputs | Medium if flag off | Disabled by default in some HI docs; tied to `weeklyReviewEnabled` |
| Milestones | Next milestone CTA | `JourneyNextMilestoneBuilder` | Logs + profile | Low | — |
| Story timeline | Event chronology | `JourneyTimelineBuilder` | Logs | Low | — |
| Chapters / XP | Gamified progression | `JourneyChapterBuilder` (200 XP/chapter) | Behaviors | Low | May feel cosmetic |
| Streaks | Logging/protein/water/workout streaks | `StreakCalculator` | Logs | Low | No push to maintain streak |
| Monthly recap | Month summary | `JourneyMonthlyRecapBuilder` | Logs | Low | — |
| Starting empty | “Go to Today” when no meaningful data | `hasMeaningfulJourneyData` | — | Low | — |
| Restore | Reload on cross-device refresh | `JourneyCrossDeviceRefreshPolicy` | Sync bus | Medium if stale | No “partial week” warning |

### Journey Questions

| Question | Answer | Confidence |
|----------|--------|------------|
| Explains whether plan is working? | **No** — shows trends/habits, not maintenance adherence vs expectation | Confirmed |
| Uses trend vs daily noise? | **Yes** for projection — 7-day averages in `WeightTrendCalculator` | Confirmed |
| Estimates maintenance? | **No** learned estimate in Journey | Confirmed |
| Enough confidence rules? | **Partial** — projection requires min data; HI weekly has confidence footer | Confirmed |
| Requires 7/14/28 days before claims? | **Partial** — projection min 7 days; HI `WeeklyReviewPolicy` thresholds | Confirmed |
| Helps users avoid panic? | **Limited** — spike flag exists in calculator but thin Journey copy | Likely gap |
| Action recommendations? | CTAs to Coach/Plan/Today; not calorie adjustment | Confirmed |
| Connects to Plan adjustments? | **No** automatic link | Confirmed |
| Rebuilds after restore? | **Yes** — reload from readers post-restore | Confirmed (branch) |
| Partial data warnings? | **Insufficient** | Likely gap |

---

## 6. Plan and Target Calibration Audit

### Architecture (**Confirmed**)

- **Calculation:** `FormaCalculationEngine`, `EnergyCalculator`, `PlanMacroCalculator`, `WaterCalculator`, `PlanSafetyValidator`
- **Bridge:** `PlanCalculationBridge` / `TargetService.generateInitialTargets`
- **Maintenance preview:** `PlanBodyBaselineMaintenanceEstimator` — TDEE from BMR + activity + steps + training days
- **Edit flow:** `PlanEditWizard`, `PlanEditWizardFlow` (goal → body → activity → review → confirm)
- **Presentation:** `PlanPresentationBuilder`, `PlanProjectionBuilder`, `PlanConfidenceStateBuilder`, `PlanAdjustmentRulesStateBuilder`

### Plan Area Table

| Plan Area | Current Logic | Data Source | Safety Guardrail | Gap | Recommended Improvement |
|----------|---------------|------------|------------------|-----|-------------------------|
| Calorie target | TDEE − deficit from pace choice | Profile inputs | `PlanSafetyValidator`, max deficit caps | Not updated from real weight trend | Learned adjustment |
| Macro targets | Protein prioritized for cut | `PlanMacroCalculator` | Minimum protein rules | — | — |
| Water target | Body weight × activity × workout day | `WaterCalculator` | — | Personalization limited vs PRD climate/sweat | Training-day bump in Today only |
| Activity level | Enum + training defaults resolver | Profile / form | — | Steps/training editable in wizard | — |
| Aggressiveness | `WeightLossPaceChoice` maps to deficit | Onboarding + Plan edit | Safety validator + warnings | User education on water weight | Onboarding expectation step |
| Plan update flow | Wizard saves via `FitnessActionCenter` | Local + sync | Regeneration preview sheet | — | — |
| Cloud sync | Profile `users/{uid}/profile/current` | Firestore | Rules-tested in Phase 2 docs | Historical daily targets frozen in `DailyLog` at day creation **Likely** | Document behavior |
| Today/Journey refresh | `dailyLogService.syncTodayTargetsFromProfile()` on target update | Profile change | — | — | — |

### Plan Questions

| Question | Answer | Confidence |
|----------|--------|------------|
| Calorie targets explainable? | **Yes** — `PlanRationaleSection`, `PlanExplanationBuilder` | Confirmed |
| Aggressive deficits guarded? | **Yes** — `PlanSafetyValidator` | Confirmed |
| Protein targets appropriate? | **Yes** — calculation spec | Confirmed |
| Water targets personalized? | **Moderate** — weight + activity | Confirmed |
| Plan change UX clear? | **Yes** — multi-step wizard + review | Confirmed |
| Learns from weight trend? | **No** | Confirmed |
| Adjust from maintenance estimate? | **No** — no learned maintenance | Confirmed |
| Initial vs learned estimate? | **Only initial TDEE** shown | Confirmed |
| Historical logs frozen? | Daily logs store snapshot targets **Likely** | Likely |

---

## 7. Onboarding Audit

### Flow (**Confirmed** — `OnboardingStep.flow`)

`introProof` → `heightWeight` → `targetWeight` → `weightLossPace` → `targetEncouragement` → `birthday` → `activityLevel` → `appleHealth` → `almostThere` → `formaProof` → `review` → `generatingPlan` → `planReveal` → `savePlan`

### Onboarding Step Table

| Onboarding Step | Current Input | Why It Matters | Validation | Gap |
|----------------|---------------|----------------|------------|-----|
| introProof | Marketing proof | Motivation | — | — |
| heightWeight | Height, weight, units | TDEE baseline | `OnboardingHeightWeightValues` | — |
| targetWeight | Goal weight | Direction + pace | `OnboardingTargetWeightValues` | — |
| weightLossPace | Pace choice / advanced | Deficit aggressiveness | Pace validator | Water weight expectations not explicit |
| targetEncouragement | Emotional copy | Motivation | — | — |
| birthday | Birth date → age | BMR | `OnboardingBirthdayValues` | Sex collected elsewhere in flow |
| activityLevel | Activity enum | TDEE multiplier | Required confirmation flag | Training/steps defaulted from level |
| appleHealth | HealthKit permission | Steps/workouts | Non-blocking | — |
| almostThere / formaProof | Marketing | Trust | — | — |
| review | Summary | Confirm inputs | — | No common foods capture |
| generatingPlan / planReveal | Animated plan | Reward | — | — |
| savePlan | Google sign-in | Account persistence | Inline errors | Auth required before main app |

### Onboarding Questions

| Question | Answer | Confidence |
|----------|--------|------------|
| Enough data for credible targets? | **Yes** for formula TDEE | Confirmed |
| Explains why each input matters? | **Partial** — activity explanation builder | Likely |
| Avoids friction? | **Moderate** — 14 steps | Confirmed |
| Sets water weight / weekly trend expectations? | **No dedicated step** | Confirmed gap |
| Captures diet preferences/common foods? | **Optional** `dietPreference` string only | Confirmed |
| Training/steps accurate? | **Defaults from activity** unless edited | Confirmed |
| Aggressive goals safe? | **Validator + warnings** | Confirmed |
| Explains Today/Journey/Plan together? | **No** | Confirmed gap |

---

## 8. Training / Workout Audit

### Training Feature Table

| Training Feature | Supported? | Data Source | Stored Where | Shown Where | Gap |
|-----------------|------------|-------------|--------------|-------------|-----|
| HealthKit workouts | **Yes** | `HealthKitManager`, `SystemHealthKitWorkoutReader` | Health cache; not primary SwiftData workout entity for HK | Today activity, Journey workout history, Training sheet | — |
| Manual workouts | **Coach only** | Coach intent `logWorkout` | `WorkoutEntryEntity` / exercise sets **Likely** | Coach context | No Training UI for manual log |
| Strength sets | **Coach path** | Parsed workout draft | SwiftData entities | Coach | No trend charts in Journey |
| Calorie burn estimates | **Partial** | HI engines | Snapshot | HI cards | Credibility **Unknown** |
| Recovery | **Yes** | `RecoveryEngine` | HI snapshot | Today/Journey HI cards | Flag-gated |
| Training load | **Yes** | `TrainingLoadEngine` | HI snapshot | HI / Coach context | Not on Plan |
| Training day nutrition adj. | **Partial** | `WaterCalculator` workout day | Targets | Plan water | Not surfaced on Today |
| Journey integration | **Yes** | `JourneyTrainingSummaryBuilder` | — | Journey sections | Read-only |
| Today integration | **Yes** | Activity section → sheet | — | Today | Sheet not tab |
| Plan integration | **Yes** | Assumptions / activity | Profile | Plan | — |

### Training Questions

| Question | Answer | Confidence |
|----------|--------|------------|
| Log workouts meaningfully? | **Only via Coach or HealthKit** | Confirmed |
| Stored locally/cloud? | HK in cache; Coach workouts in SwiftData + sync **Likely** | Likely |
| Strength trends visible? | **No** dedicated UI | Confirmed |
| Workout calories credible? | **Unknown** without device testing | Unknown |
| Training affects nutrition/water? | **Limited** explicit surfacing | Likely |
| Recovery affects app? | **Yes** when HI enabled | Confirmed |
| Training a real tab? | **No** — sheet only | Confirmed |
| Ready for feature sprint? | **Needs product decision** — infra exists, UX missing | Confirmed |

---

## 9. Daily Review and Weekly Review Audit

### Review Type Table

| Review Type | Exists? | Trigger | Data Used | Persisted? | User Value | Gap |
|------------|---------|---------|-----------|------------|------------|-----|
| Daily review (AI) | **Backend yes** | `ReviewService.generateDailyReview` — Coach/command **Likely** | Logs, workouts, steps, weight | `DailyReviewEntity` + cloud sync | High if surfaced | **No dedicated UI screen** |
| Daily wrap-up (deterministic) | **Yes** | Evening hour (`EndOfDayWrapUpEngine`) | Same-day logs | No | Medium | Not a habit ritual |
| Journey weekly habit | **Yes** | Journey load | 7-day logs | No | Medium | Rows only |
| HI weekly review | **Yes** | `WeeklyReviewService` on Journey load | Nutrition, recovery, workouts, weight | Cache **Likely** | High | Flag-gated; no push |
| Weekly maintenance entity field | **Schema only** | — | — | `WeeklyReviewEntity.estimatedMaintenance` | — | Never populated **Confirmed** |

### Review Questions

| Question | Answer | Confidence |
|----------|--------|------------|
| Daily review habit-worthy? | **Not yet** — buried in wrap-up / Coach | Confirmed |
| Weekly review exists? | **Yes** (two variants) | Confirmed |
| Explains progress? | **Partial** — habits yes; maintenance no | Confirmed |
| Maintenance from real data? | **No** | Confirmed |
| Safe plan change recommendations? | **No** automated recommendations | Confirmed |
| Enough data before claims? | **HI engine has thresholds**; Journey rows work with any food days | Confirmed |
| Structured vs text? | **Structured** in HI; rows in Journey | Confirmed |
| Review history? | **No** consumer history UI | Confirmed |

---

## 10. Notifications and Habit Loop Audit

**Confirmed:** No `import UserNotifications`, no `UNUserNotificationCenter`, no WidgetKit, no notification permission flow. `SettingsProductionVisibility.prohibitedTitleTerms` bans “daily reminders” and “coach check-ins” placeholder copy.

### Notification Table

| Notification | Exists? | Trigger | Deep Link | Personalization | Risk | Gap |
|-------------|---------|---------|----------|-----------------|------|-----|
| Morning weigh-in | **No** | — | — | — | — | Entire feature |
| Water reminders | **No** | — | — | — | — | Entire feature |
| Meal logging | **No** | — | — | — | — | Entire feature |
| Daily review | **No** | — | — | — | — | Entire feature |
| Weekly review | **No** | — | — | — | — | Entire feature |
| In-app weight nudge | **Partial** | Empty state / NBA after 17:00 | Today | Time-based | Low | Only when app open |

### Notification Questions

| Question | Answer |
|----------|--------|
| Brings users back at right time? | **No** |
| Useful vs annoying? | **N/A** |
| Tied to missing actions? | **In-app only when open** |
| Deep links? | **App URL scheme exists** (`AppURLSchemes.plist`) but not for notifications |
| Supportive copy? | In-app engines use neutral copy **Likely** |
| Habit loop without Coach? | **Weak** — no extrinsic triggers |

---

## 11. Sync / Restore / Data Trust UX Audit

### Data Trust Surface Table

| Data Trust Surface | Current Behavior | User Clarity | Gap |
|-------------------|------------------|--------------|-----|
| Restore on login | Full-screen `AccountRestoreView` with phases | **High** during restore | — |
| Restore pending on tabs | `AccountRestorePendingStateView` spinner | **Medium** — blocks content | No partial preview |
| Cross-device refresh | Silent pull + brief overlay | **Low** | Needs confirmation toast |
| Pending upload | Outbox in `AccountSyncOutboxStore` | **None** in consumer UI | Critical for trust |
| Offline | Local-first writes work | **Not explained** | Offline banner |
| Privacy settings | Legal docs; delete flow when enabled | **Medium** | Export hidden |
| Account deletion | `SettingsAccountDeletionFlowView` + typed `DELETE` | **High** when flag on | Export missing |
| Apple Health sync | Last sync in settings **Likely** | **Medium** | — |
| Conflict handling | LWW merge policy | **Invisible** | — |
| Stale data | No timestamp on dashboards | **Low** | “Last updated” |

### Data Trust Questions

| Question | Answer | Confidence |
|----------|--------|------------|
| User knows data saved? | **Only during restore** | Confirmed |
| User knows sync pending? | **No** | Confirmed |
| User knows restore complete? | **Yes** — transitions to tabs | Confirmed |
| Trust reinstall? | **After Phase 4–5 ship: Likely yes** | Likely |
| Manage/delete/export? | Delete yes (flag); export no | Confirmed |
| Errors recoverable? | Restore retry UI exists | Confirmed |
| Offline clear? | **No** | Confirmed |

---

## 12. Empty, Loading, Error, Offline, and Partial States Audit

| Surface | Empty State | Loading State | Error State | Offline State | Partial Restore State | Gap |
|--------|-------------|---------------|-------------|---------------|----------------------|-----|
| Auth | N/A | `LaunchLoadingView` | Profile error views | — | — | — |
| Onboarding | N/A | `OnboardingLoadingView` overlay | Inline step errors | — | Draft resume **Likely** | — |
| Today | `TodayEmptyStateView` → Plan | Skeleton | `FormaScreenErrorView` | None | `pendingAccountRestore` only | No offline/pending upload |
| Journey | `JourneyEmptyStateView`; in-scroll starting empty | `FormaScreenLoadingView` | Error + retry | None | Pending restore | Partial week unlabeled |
| Plan | `PlanEmptyStateView` → create profile | `FormaScreenLoadingView` | Error + retry | None | — | — |
| Training | Gate / empty connected views | Loading | Error + retry | — | — | — |
| Settings | — | — | Inline error section | — | — | Delete unavailable alert |
| Privacy/Data | Row hidden when unavailable | Deletion progress UI | Retry on deletion failure | — | — | Export stub |
| Review | Wrap-up `noLogsMessage` | — | — | — | — | No review screen |
| Health | Permission not determined UI | — | Denied → Settings link | — | — | — |
| Notifications | N/A | N/A | N/A | N/A | N/A | **Missing entirely** |
| Sync/restore | — | `AccountRestoreView` | `AccountRestoreFailedView` | Local-first **silent** | Pending tab blocker | No global sync indicator |

**Cross-cutting issues:** No offline copy (**Confirmed**); no retry on mutation failures beyond transient banner (**Confirmed**); false empty possible if restore slow before pending state attaches (**Likely**).

---

## 13. Navigation and Information Architecture Audit

### Current structure (**Confirmed**)

- **Tabs:** Today | Coach | Journey | Plan (`AppTab` in `MainTabView.swift`)
- **Settings:** Modal from Plan (`SettingsRootView`)
- **Training:** Sheet from Today/Plan/Journey — not a tab
- **Legacy tab IDs:** `"progress"` / `"training"` → Journey; `"profile"` → Plan

### Navigation Table

| Navigation Area | Current Behavior | Gap | Recommended Improvement |
|----------------|------------------|-----|-------------------------|
| Tab labels | SF Symbols + short labels | “Journey” may be vague vs “Progress” | User test naming |
| Core loop mapping | Today=act, Journey=reflect, Plan=strategize | Coach competes as primary surface | Onboarding tab tour |
| Training discoverability | Buried in activity section | Low discovery | Consider Journey entry or tab |
| Manual logging | Today sheets + Coach | Duplication | Deprecate sheets or badge “Advanced” |
| Deep links | `onOpenURL` in `Fitness_CoachApp` | Limited routes **Likely** | Notification deep links when added |
| Restore/auth routes | `AuthGateRouteView` comprehensive | — | — |
| Reviews | No route | No weekly/daily review destinations | Add Journey review detail as ritual |

### Navigation Questions

| Question | Answer |
|----------|--------|
| Organized around core loop? | **Mostly yes** |
| Today/Journey/Plan clear? | **Moderate** — Coach is equally prominent |
| Training too hidden? | **Yes** |
| Too many manual logging surfaces? | **Yes** |
| Important actions discoverable? | **Coach/Today yes; weekly review no** |

---

## 14. Visual Design and Theme Consistency Audit

### Design system (**Confirmed** — 70+ files under `DesignSystem/`)

- **Theme:** `ThemeStore`, `ResolvedAppTheme`, palettes, light/dark/system (`FormaAbTest.Theme`)
- **Tokens:** `FormaTokens`, feature layouts (`FormaMainTabLayout`, `TodayLayout`, `JourneyLayout`, `PlanLayout`)
- **Components:** `FormaCardChrome`, `FormaScreenLoadingView`, `FormaScreenErrorView`, `FormaEmptyStateCard`, `FormaTransientBanner`

### Design Area Table

| Design Area | Current Behavior | Gap | Risk |
|-------------|------------------|-----|------|
| Color palettes | Multiple palettes + accessibility adaptations | — | Low |
| Theme switching | Live via `ThemeStore` + environment | — | Low |
| Typography | `FormaTokens.Typography` | — | Low |
| Cards/charts | Consistent card chrome; Journey/Plan charts **Likely** consistent | Chart readability **Unknown** | Medium on device |
| Destructive actions | Delete account confirmation flow styled | — | Low |
| Loading/empty | Shared components | Offline not styled | Low |
| Dynamic Type | Theme settings accessibility file exists | Full matrix **Unknown** | Medium |
| Cross-screen consistency | Preview matrix files exist | HI vs legacy section duplication | Medium |

### Design Questions

| Question | Answer | Confidence |
|----------|--------|------------|
| Polished enough to trust? | **Likely yes** — extensive design system | Likely |
| Charts/cards consistent? | **Likely** | Likely |
| Theme live across screens? | **Yes** | Confirmed |
| Destructive/privacy clear? | **Yes** for deletion | Confirmed |
| Key numbers readable? | **Unknown** on device | Unknown |

---

## 15. Metrics and Analytics Readiness Audit

### Implementation (**Confirmed**)

- Typed events per surface: `TodayAnalyticsLogging`, `JourneyAnalyticsLogging`, `PlanAnalyticsLogging`, `OnboardingAnalyticsLogging`, `SettingsAnalyticsLogging`, `HealthIntelligenceAnalyticsLogging`
- **DEBUG:** `OSLog*AnalyticsLogger` in `AppContainer`
- **RELEASE:** `NoOp*AnalyticsLogger` — events discarded
- No Firebase Analytics / Amplitude / Mixpanel in Swift codebase
- Domain calculators: `StreakCalculator`, `WeightTrendCalculator`, `ProgressProjectionCalculator` — product metrics, not telemetry

### Metric Table

| Metric | Tracked? | Source | Gap |
|--------|----------|--------|-----|
| Onboarding completion | Event exists | `OnboardingAnalyticsLogging` | Release no-op |
| First meal logged | `today_log_meal_saved` | Today analytics | Release no-op |
| First daily review completed | **No dedicated event** | — | Missing event |
| Logs per day | **Not aggregated** | — | Needs pipeline |
| Food photos uploaded | Coach events **Likely** | Coach analytics | Release no-op |
| DAU | **No** | — | Needs SDK |
| Weekly review completion | Journey view events partial | `journey_weekly_consistency_viewed` | No completion event |
| Retention D1/D7/D30 | **No** | — | Needs backend |
| Protein target hit rate | **Not telemetry** | Domain only | — |
| Calorie adherence | **Not telemetry** | Domain only | — |
| Correction rate | Coach accuracy observability | `CoachAccuracyObservability` | Coach-only |
| Estimate acceptance | Coach events | Coach | Release no-op |
| Clarification rate | **Unknown** | — | — |
| Hallucinated food detection | **Unknown** | — | — |
| Coaching satisfaction | **No** | — | — |

### Analytics Questions

| Question | Answer |
|----------|--------|
| Can evaluate sprint retention impact? | **No in Release** |
| Analytics no-op in release? | **Yes** |
| Privacy-safe events? | **Yes** — bucketed properties, no raw weights in Journey |
| Missing instrumentation? | **Production pipeline + PRD funnel events** |

---

## 16. Feature Gap Scoring

Scoring: 1–5 (5 = highest/best for impact; complexity 5 = hardest). **Score** = weighted: (User + Retention + Trust) − Complexity − DependencyRisk + Revenue, capped 1–15.

| Sprint Candidate | User Impact | Retention Impact | Trust Impact | Revenue/Premium | Engineering Complexity | Dependency Risk | Score |
|-----------------|-------------|------------------|--------------|-----------------|------------------------|-----------------|-------|
| **Weekly Review + Maintenance Estimate** | 5 | 5 | 5 | 4 | 3 | 2 | **14** |
| **Notifications / Habit Loop** | 4 | 5 | 3 | 3 | 3 | 2 | **12** |
| **Privacy/Data Trust UX** | 3 | 3 | 5 | 2 | 2 | 1 | **12** |
| **Today Dashboard v2** | 4 | 4 | 3 | 3 | 3 | 1 | **12** |
| **Journey / Progress v2** | 4 | 4 | 4 | 3 | 4 | 2 | **11** |
| **Plan Auto-Adjustment** | 4 | 3 | 5 | 4 | 4 | 3 | **11** |
| **Analytics Instrumentation** | 2 | 4 | 2 | 2 | 2 | 1 | **9** |
| **Onboarding Calibration v2** | 3 | 3 | 4 | 2 | 2 | 1 | **9** |
| **Training Logger v1** | 3 | 3 | 2 | 3 | 4 | 2 | **8** |
| **HealthKit Intelligence v2** | 3 | 3 | 3 | 3 | 5 | 4 | **7** |
| **Design System Polish** | 2 | 2 | 3 | 2 | 3 | 1 | **7** |

---

## 17. Recommended Next Sprint

### Sprint title

**Weekly Progress Loop v1 — Learned Maintenance, Unified Weekly Review, and Plan Recommendations**

### Why this sprint is best now

Account persistence phases 1–6 (when complete) fix **data survival** — users can log across devices and reinstall without losing history. The next bottleneck is **why keep logging on day 7+**: the PRD’s weekly review and maintenance estimate (“Should Have”) remain unshipped as a cohesive user-facing loop. Infrastructure already exists (`WeeklyReviewEngine`, `JourneyWeeklyReviewBuilder`, `WeightTrendCalculator`, `ReviewService`, `PlanAdjustmentRulesStateBuilder`) but is **fragmented and incomplete**. This sprint converts restored data into **trustworthy progress feedback** and a recurring weekly ritual — directly addressing retention, clarity, and motivation without reopening Coach internals.

### Why not the other candidates

| Candidate | Why not now |
|-----------|-------------|
| Notifications / Habit Loop | Highest extrinsic retention lever, but ** stronger after** there is a compelling weekly destination to deep-link to; otherwise reminders point at the same incomplete weekly experience |
| Privacy/Data Trust UX | Mostly Phase 6 scope; deletion UI exists; export is small follow-up |
| Today Dashboard v2 | Incremental; Today already strong |
| Journey v2 alone | Overlaps with weekly review unification |
| Plan Auto-Adjustment alone | Needs learned maintenance first |
| Analytics | Critical but should instrument *this* sprint’s weekly funnel |
| Training Logger | Smaller audience vs all cutters |
| HI v2 | Flag complexity; coach-context heavy |
| Design polish | Does not close loop gaps |

### User problem solved

“I’ve been logging faithfully for a week but I don’t know if my plan is working, what to change, or why the scale moved — so I stop.”

### Core feature list

1. **Learned maintenance estimator** — domain service using PRD formula (avg intake + weight trend over 7–28 days, confidence gates, water-weight disclaimer) — populate `WeeklyReviewEntity.estimatedMaintenance` or successor model.
2. **Unified Weekly Review surface** — merge Journey habit rows + HI weekly insights into one Journey hero card with `WeeklyReviewDetailView` as the canonical Sunday/weekly ritual.
3. **Plan recommendation card** — safe, confidence-gated suggestion (“hold steady” / “consider +100 kcal”) wired from maintenance vs current target; CTA to `PlanEditWizard` review step.
4. **Weight trend education** — surface `WeightTrendCalculator.hasSuddenSpike` copy on Journey + optional Today hint (deterministic, non-Coach).
5. **Daily review entry point** — lightweight Today/Journey link to generate/view persisted `DailyReview` for yesterday (thin UI, uses `ReviewService`).
6. **Sync trust microcopy** — “Last saved” / “Syncing…” on Journey weekly card after persistence ship.
7. **Analytics events** — `weekly_review_viewed`, `weekly_review_completed`, `maintenance_estimate_shown`, `plan_recommendation_tapped` wired to non-noop logger or Firebase.

### Excluded features

- Push notifications (fast-follow sprint)
- Coach pipeline changes
- Manual training logger
- Full data export
- Widgets
- Plan auto-apply without user confirmation

### Likely files involved

| Area | Files |
|------|-------|
| New domain | `Domain/Analytics/MaintenanceEstimateCalculator.swift` (new), extend `WeightTrendCalculator` |
| Weekly review | `Health/Intelligence/WeeklyReviewEngine.swift`, `Application/StateBuilders/Journey/WeeklyReviewPresentationBuilder.swift`, `JourneyWeeklyReviewBuilder.swift`, `Features/Journey/Components/WeeklyReview/*` |
| Journey | `JourneyModel.swift`, `JourneyPresentationBuilder.swift`, `JourneyWeeklyPatternBuilder.swift` |
| Plan | `PlanAdjustmentRulesStateBuilder.swift`, `PlanAdjustPlanCTAStateBuilder.swift`, `PlanEditWizard` |
| Reviews | `Data/Repositories/ReviewService.swift`, `Application/StateBuilders/Reviews/DailyReviewSummaryBuilder.swift` |
| Today | `TodayEndOfDayWrapUpSection.swift`, `EndOfDayWrapUpEngine.swift` |
| Persistence | `WeeklyReviewEntity.swift`, sync mappers if cloud weekly review needed |
| Analytics | `JourneyAnalyticsLogging.swift`, `PlanAnalyticsLogging.swift`, `AppContainer.swift` logger wiring |
| Copy | `FormaProductCopy.swift` |
| Tests | `WeeklyReviewEngineTests.swift`, `JourneyWeeklyReviewBuilderTests.swift`, new maintenance calculator tests |

### Test strategy

- Unit: maintenance calculator fixtures (7/14/28 day windows, insufficient data, water-weight disclaimer triggers)
- Unit: weekly review merge presentation snapshots
- Unit: plan recommendation policy (never recommends > safety max delta)
- Integration: Journey load with restored 30-day logs populates maintenance + review
- UI: `JourneyRevampQAChecklistTests` extend for weekly ritual
- Manual: Sunday scenario personas from `JourneyPreviewData`

### Success criteria

- ≥70% of internal testers with 7+ days data see a maintenance estimate with stated confidence
- Weekly review detail opened ≥1× per user in week 2 (once analytics wired)
- Users can articulate “plan is working / needs adjustment” without opening Coach
- Zero recommendations issued with <7 days food+weight data
- Restore + cross-device: weekly card matches on two devices after sync

### Risks

- Duplicating HI weekly review while flag-gated — **mitigate** by single builder path
- False maintenance from water weight — **mitigate** with confidence + copy
- Scope creep into auto plan apply — **mitigate** recommend-only + wizard CTA

### Phase breakdown

| Phase | Deliverable | Days (est.) |
|-------|-------------|-------------|
| 1 | `MaintenanceEstimateCalculator` + tests + confidence policy | 2–3 |
| 2 | Unified `WeeklyReviewPresentationBuilder` consuming calculator | 2–3 |
| 3 | Journey UI merge + detail view enhancements | 2–3 |
| 4 | Plan recommendation block + edit wizard CTA | 2 |
| 5 | Daily review thin UI + sync microcopy | 1–2 |
| 6 | Analytics + QA matrix | 1–2 |

**Fast-follow sprint (2 weeks):** Notifications / Habit Loop deep-linking to weekly review + weigh-in reminder.

---

## 18. P0/P1/P2 Gap Table

| Priority | Gap | Evidence | User Impact | Suggested Sprint |
|---------|-----|----------|-------------|-----------------|
| **P0** | No learned maintenance / “is plan working?” | PRD §9.11; no `MaintenanceEstimateCalculator`; `WeeklyReviewEntity.estimatedMaintenance` unused | Users quit when scale disagrees with expectations | Weekly Progress Loop v1 |
| **P0** | No extrinsic habit loop (notifications) | Zero `UserNotifications` usage | D1→D7 retention collapse | Notifications fast-follow |
| **P0** | Production analytics no-op | `AppContainer` `#else NoOp*AnalyticsLogger` | Cannot measure retention fixes | Analytics instrumentation (parallel) |
| **P0** | Weekly review fragmented | `JourneyWeeklyReviewSection` vs `WeeklyReviewCard`; no ritual trigger | Week 2 motivation cliff | Weekly Progress Loop v1 |
| **P0** | Sync/pending invisible on dashboards | No outbox UI on Today/Journey | Trust erosion after persistence ship | Privacy/Data Trust UX microcopy |
| **P1** | Daily review not surfaced | `ReviewService` persists; only wrap-up UI | Missed coaching habit | Weekly Progress Loop v1 |
| **P1** | Training hidden / no manual logger | No Training tab; Coach-only workout log | Gym users underserved | Training Logger v1 |
| **P1** | Duplicate Today manual logging | `TodayLogMealSheet` vs Coach | Confusing primary path | Today Dashboard v2 |
| **P1** | Data export stub | `SettingsExportDataActionHandler` TODO | Compliance expectation | Privacy/Data Trust UX |
| **P1** | Onboarding lacks trend education | No water-weight step in `OnboardingStep.flow` | Scale panic week 1 | Onboarding Calibration v2 |
| **P2** | Widgets absent | No WidgetKit | Re-engagement surface | Post-notifications |
| **P2** | Plan auto-apply | Rules copy only | Power users want assist | Plan Auto-Adjustment |
| **P2** | HI flag matrix complexity | `HealthIntelligenceFeatureFlags` | Dev overhead | HI consolidation |
| **P2** | Review history UI | No list of past reviews | Long-term engagement | Journey v2 |

---

## 19. Files Reviewed

Grouped inventory of files inspected during this audit (representative; not every test file).

### App root / navigation
- `Fitness Coach/App/Fitness_CoachApp.swift`
- `Fitness Coach/App/AppContainer.swift`
- `Fitness Coach/App/MainTabView.swift`
- `Fitness Coach/App/AppRefreshCenter.swift`
- `Fitness Coach/App/Routing/AuthGateRoutingPolicy.swift`
- `Fitness Coach/App/Routing/OnboardingShellRouteResolver.swift`
- `Fitness Coach/Configuration/FormaAbTest.swift`
- `Fitness Coach/Infrastructure/Cloud/AccountPersistenceFeatureFlags.swift`

### Auth / onboarding
- `Fitness Coach/Features/Auth/AuthGateView.swift`
- `Fitness Coach/Features/Auth/Views/AuthGateRouteView.swift`
- `Fitness Coach/Features/Auth/Views/AccountRestoreView.swift`
- `Fitness Coach/Features/Auth/Components/AccountRestorePendingStateView.swift`
- `Fitness Coach/Features/Onboarding/OnboardingView.swift`
- `Fitness Coach/Features/Onboarding/Model/OnboardingStep.swift`
- `Fitness Coach/Features/Onboarding/Model/OnboardingFormState.swift`
- `Fitness Coach/Domain/Onboarding/OnboardingCompletionPolicy.swift`

### Today
- `Fitness Coach/Features/Today/TodayView.swift`
- `Fitness Coach/Features/Today/Components/TodayReadOnlyView.swift`
- `Fitness Coach/Features/Today/Model/TodayModel.swift`
- `Fitness Coach/Features/Today/Model/TodayActionCoordinator.swift`
- `Fitness Coach/Features/Today/Model/TodayDashboardState.swift`
- `Fitness Coach/Features/Today/Model/TodayDashboardSectionOrder.swift`
- `Fitness Coach/Features/Today/Model/NextBestActionEngine.swift`
- `Fitness Coach/Features/Today/Model/EndOfDayWrapUpEngine.swift`
- `Fitness Coach/Application/StateBuilders/Today/TodayPresentationBuilder.swift`

### Journey / Progress
- `Fitness Coach/Features/Journey/JourneyView.swift`
- `Fitness Coach/Features/Journey/Model/JourneyModel.swift`
- `Fitness Coach/Application/StateBuilders/Journey/JourneyDashboardBuilder.swift`
- `Fitness Coach/Application/StateBuilders/Journey/JourneyGoalProjectionBuilder.swift`
- `Fitness Coach/Application/StateBuilders/Journey/JourneyWeeklyReviewBuilder.swift`
- `Fitness Coach/Application/StateBuilders/Journey/JourneyWeeklyPatternBuilder.swift`
- `Fitness Coach/Application/StateBuilders/Journey/WeeklyReviewPresentationBuilder.swift`
- `Fitness Coach/Features/Journey/Components/WeeklyReview/WeeklyReviewDetailView.swift`
- `Docs/JourneyArchitecture.md`

### Plan
- `Fitness Coach/Features/Plan/PlanView.swift`
- `Fitness Coach/Features/Plan/Model/PlanModel.swift`
- `Fitness Coach/Features/Plan/Model/PlanEditWizardFlow.swift`
- `Fitness Coach/Application/StateBuilders/Plan/PlanPresentationBuilder.swift`
- `Fitness Coach/Application/StateBuilders/Plan/PlanBodyBaselineMaintenanceEstimator.swift`
- `Fitness Coach/Application/Services/TargetService.swift`
- `Fitness Coach/Domain/PlanCalculation/FormaCalculationEngine.swift`
- `Fitness Coach/Domain/PlanCalculation/PlanSafetyValidator.swift`

### Training
- `Fitness Coach/Features/TrainingInsights/TrainingInsightsView.swift`
- `Fitness Coach/Domain/Training/TrainingInsightsAggregator.swift`
- `Fitness Coach/Infrastructure/Health/HealthTrainingService.swift`

### Reviews
- `Fitness Coach/Data/Repositories/ReviewService.swift`
- `Fitness Coach/Application/StateBuilders/Reviews/DailyReviewSummaryBuilder.swift`
- `Fitness Coach/Health/Intelligence/WeeklyReviewEngine.swift`
- `Fitness Coach/Health/Intelligence/WeeklyReviewService.swift`

### Health
- `Fitness Coach/Health/HealthKit/HealthKitManager.swift`
- `Fitness Coach/Health/HealthIntelligenceFeatureFlags.swift`
- `Fitness Coach/Health/Intelligence/HealthIntelligenceEngine.swift`
- `Fitness Coach/Health/Intelligence/RecoveryEngine.swift`

### Settings / privacy
- `Fitness Coach/Features/Settings/SettingsRootView.swift`
- `Fitness Coach/Features/Settings/Model/SettingsPresentationBuilder.swift`
- `Fitness Coach/Features/Settings/Model/SettingsProductionVisibility.swift`
- `Fitness Coach/Features/Settings/Model/SettingsDeleteDataActionHandler.swift`
- `Fitness Coach/Features/Settings/UI/SettingsAccountDeletionFlowView.swift`
- `Fitness Coach/Features/Settings/Model/SettingsAccountDeletionViewModel.swift`
- `Fitness Coach/Application/Privacy/AccountDeletionCoordinator.swift`
- `Fitness Coach/Application/Privacy/AccountDeletionPolicy.swift`

### Sync / restore
- `Fitness Coach/Application/Sync/AccountSyncCoordinator.swift`
- `Fitness Coach/Application/Sync/CrossDeviceSyncCoordinator.swift`
- `Fitness Coach/Application/Restore/AccountRestoreCoordinator.swift`
- `Fitness Coach/Application/Restore/AccountRestoreSessionState.swift`

### Notifications
- *No Swift files — absence confirmed*

### Design system
- `Fitness Coach/DesignSystem/Theme/ThemeStore.swift`
- `Fitness Coach/DesignSystem/Tokens/FormaTokens.swift`
- `Fitness Coach/DesignSystem/Components/FormaScreenLoadingView.swift`
- `Fitness Coach/DesignSystem/Components/FormaScreenErrorView.swift`

### Analytics
- `Fitness Coach/Domain/Today/TodayAnalyticsLogging.swift`
- `Fitness Coach/Domain/Journey/JourneyAnalyticsLogging.swift`
- `Fitness Coach/Domain/Analytics/WeightTrendCalculator.swift`
- `Fitness Coach/Domain/Analytics/StreakCalculator.swift`
- `Fitness Coach/Infrastructure/Diagnostics/NoOpTodayAnalyticsLogger.swift`
- `Fitness Coach/Infrastructure/Diagnostics/OSLogTodayAnalyticsLogger.swift`

### Tests (sample)
- `Fitness CoachTests/JourneyRevampQAChecklistTests.swift`
- `Fitness CoachTests/WeeklyReviewEngineTests.swift`
- `Fitness CoachTests/AccountDeletionCoordinatorTests.swift`
- `Fitness CoachTests/SettingsProductionQATests.swift`

### Docs
- `PRD.md`
- `USER_DATA_STORAGE_CONTEXT_PACKET.md`
- `ACCOUNT_PERSISTENCE_EXECUTION_MAP.md`
- `ACCOUNT_PERSISTENCE_PHASE_READINESS.md`
- `ACCOUNT_PERSISTENCE_RESTORE_CONTEXT_PACKET.md`
- `ACCOUNT_PERSISTENCE_IMPLEMENTATION_PLAN.md`
- `Docs/AccountPersistence/PHASE_2_CLOUD_SCHEMA_AND_RULES.md`
- `Docs/AccountPersistence/PHASE_3_LOCAL_FIRST_SYNC_ENGINE.md`
- `Docs/AccountPersistence/PHASE_4_FRESH_INSTALL_RESTORE.md`
- `Docs/AccountPersistence/PHASE_5_CROSS_DEVICE_REFRESH.md`

---

## 20. Unknowns / Needs Manual Verification

| Item | Why unknown |
|------|-------------|
| Production feature flag overrides | `FormaAbTestSnapshot.allEnabled` is code default; Remote Config **not found** in Swift |
| Deployed Firebase rules vs `firestore.rules` in repo | May drift in production |
| Real user analytics / retention | No production telemetry pipeline |
| App Store build flag behavior | `FormaBuildConfiguration` internal vs release **needs device archive** |
| Visual polish on device | Static audit only |
| Chart readability / dynamic type | Requires on-device QA |
| Notification permission flows | N/A — not implemented |
| HI `weeklyReviewEnabled` in shipped build | Depends on build configuration |
| `pullRecentDataEnabled = false` impact | Bounded pull disabled; restore path may differ from foreground pull |
| Test coverage completeness | 465+ test files exist; coverage % **Unknown** |
| Coach daily review trigger rate | Out of scope — usage **Unknown** |
| Actual cross-device sync latency | Needs multi-device manual test |
| Cloud Functions account deletion deployment | `functions/src/accountDeletion/*` exists; prod deploy **Unknown** |
| Whether account deletion row visible in App Store build | Gated by `FormaAbTest.Settings.dataDeletionEnabled` + `SettingsFeatureAvailability` |
| False empty states during slow restore | Timing-dependent |
| Workout calorie credibility | HealthKit + engine estimates need validation |

---

*End of context packet. Paste into ChatGPT or similar to compare sprint candidates against product goals after account persistence phases 1–6.*
