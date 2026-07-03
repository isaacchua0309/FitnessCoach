# Health Intelligence — Phase 19 QA Test Matrix

**Status:** Manual QA matrix for Health Intelligence across Today, Coach, Journey, and Plan.  
**Audience:** QA, release engineering, and engineers validating rollout.  
**Last updated:** 2026-07-03

**Related docs:**
- [PHASE_11_15_UI_INTEGRATION.md](./PHASE_11_15_UI_INTEGRATION.md) — surface integration & flags
- [PHASE_6_10_IMPLEMENTATION.md](./PHASE_6_10_IMPLEMENTATION.md) — engine contract
- [PHASE_1_5_IMPLEMENTATION.md](./PHASE_1_5_IMPLEMENTATION.md) — sync, cache, permissions
- [HEALTH_SUMMARY_SYNC_CONTRACT.md](./HEALTH_SUMMARY_SYNC_CONTRACT.md) — remote summary sync

---

## 1. How to use this matrix

Each test case (TC-01 … TC-30) includes:

| Field | Purpose |
|-------|---------|
| **Preconditions** | Device state, flags, permissions, cache, auth |
| **Steps** | Reproducible manual actions |
| **Expected Today / Coach / Journey / Plan** | Per-surface UI and behavior |
| **Expected logs / errors** | Analytics events, OSLog, user-visible errors |
| **Pass / fail criteria** | Objective acceptance checks |

### Recommended test build configuration

Enable the full rollout stack unless a case explicitly says otherwise:

| Flag | Env key | Recommended QA value |
|------|---------|----------------------|
| Foundation | `FORMA_HEALTH_INTELLIGENCE_ENABLED` | `1` |
| Engines | `FORMA_HEALTH_INTELLIGENCE_ENGINES_ENABLED` | `1` |
| UI | `FORMA_HEALTH_INTELLIGENCE_UI_ENABLED` | `1` |
| Coach context | `FORMA_HEALTH_INTELLIGENCE_COACH_CONTEXT_ENABLED` | `1` |
| Weekly review | `FORMA_HEALTH_INTELLIGENCE_WEEKLY_REVIEW_ENABLED` | `1` |
| Local sync | `FORMA_HEALTH_INTELLIGENCE_SYNC_ENABLED` | `1` |
| Remote summary sync | `FORMA_HEALTH_SUMMARY_REMOTE_SYNC_ENABLED` | Case-specific |
| Repository reads | `FORMA_HEALTH_INTELLIGENCE_REPOSITORY_READS_ENABLED` | `1` |

Set flags via Xcode scheme environment variables or Info.plist entries (see `HealthIntelligenceFeatureFlags.swift`).

### Global invariants (every case)

These must hold unless the case explicitly tests a crash regression:

1. **No tab-blocking failures** — Today, Journey, and Plan dashboards reach `.loaded` even when Health Intelligence load fails.
2. **No HealthKit in SwiftUI** — UI surfaces only presentation state; no raw HK types in views.
3. **No fabricated medical metrics** — No raw HRV ms, BPM, or baseline comparison strings in user-facing copy.
4. **No fake chart axes** — Empty or limited states show placeholders / messages, not invented values.
5. **Nil-safe snapshots** — Missing snapshot must not crash; fallbacks render instead.
6. **Privacy-safe analytics** — Events must not include raw HealthKit values, workout titles, or food text.

### UI state resolution reference

`HealthIntelligenceUIStateMapper` resolves kinds in priority order:

`loading` → `syncFailed` → `healthKitUnavailable` → `noHealthPermission` → `partialPermission` → `staleData` → `remoteSyncDisabled` → `notEnoughBaseline` → `noWorkoutHistory` → `noSleepData` → `noHeartData` → `ready` → `unknown`

**Stale UI threshold:** last successful local sync > **24 hours** (`HealthIntelligenceUIStatePolicy.defaultStaleInterval`).  
**Minimum baseline days:** **7** (`minimumBaselineDays`).  
**Foreground sync throttle:** **15 minutes** (`HealthCachePolicy.todayFreshnessInterval`).

### Analytics events reference

| Event | When |
|-------|------|
| `health_intelligence_snapshot_loaded` | Tab HI refresh succeeds |
| `health_intelligence_snapshot_failed` | Tab HI refresh fails |
| `today_recovery_card_viewed` | Today recovery card appears (once per context) |
| `today_next_best_action_tapped` | Today NBA tapped |
| `coach_health_context_used` | Coach sends prompt with HI context |
| `journey_recovery_timeline_viewed` | Journey timeline loaded |
| `journey_workout_history_viewed` | Journey workout history loaded |
| `weekly_review_card_viewed` | Journey weekly review card loaded |
| `weekly_review_detail_opened` | Weekly review detail opened |
| `plan_health_confidence_viewed` | Plan confidence card loaded |
| `health_permission_cta_tapped` | Connect / manage permissions CTA tapped |

View-once events reset when snapshot context updates for that surface.

---

## 2. Test case index

| ID | Scenario | Primary risk |
|----|----------|--------------|
| TC-01 | Fresh install | Onboarding + first sync |
| TC-02 | Existing user upgrade | Migration + cache reuse |
| TC-03 | Apple Health denied | Permission fallbacks |
| TC-04 | Apple Health fully connected | Happy path |
| TC-05 | Partial permission: steps only | Partial insight + missing signals |
| TC-06 | Partial permission: workouts only | Workout without steps |
| TC-07 | Partial permission: sleep missing | Recovery limited estimate |
| TC-08 | Partial permission: HRV missing | Heart partial / limited |
| TC-09 | HealthKit unavailable / simulator | Device unavailable path |
| TC-10 | No workout history | Empty workout states |
| TC-11 | Multiple workouts in one day | Aggregation / grouping |
| TC-12 | Workout crossing midnight | Date boundary attribution |
| TC-13 | Stale cached health data | Stale labels |
| TC-14 | Local sync failure | Sync failed + cache |
| TC-15 | Remote summary sync disabled | Opt-out / capability off |
| TC-16 | Remote summary sync enabled | Upload after local sync |
| TC-17 | Remote sync failure | Local HI unaffected |
| TC-18 | Unauthenticated user | Anonymous / no cloud sync |
| TC-19 | User logs meal after workout | Nutrition + HI coherence |
| TC-20 | User logs water after workout | Hydration + HI coherence |
| TC-21 | Coach asks about workout | Anti-hallucination |
| TC-22 | Coach asks about recovery | Limited estimate wording |
| TC-23 | Weekly review generation | Journey review card |
| TC-24 | Plan confidence with missing data | Graceful degradation |
| TC-25 | Theme change without app kill | Theme reactivity |
| TC-26 | Offline mode | Cache fallback |
| TC-27 | App foreground refresh | Throttled today sync |
| TC-28 | Background refresh | Not implemented — verify N/A |
| TC-29 | Timezone / day boundary | Date rollover |
| TC-30 | Deleting / revoking permission | Permission regression |

---

## 3. Detailed test cases

---

### TC-01 — Fresh install

**Preconditions**
- New install (no Forma profile cache, no HI disk cache).
- Signed-in user with completed onboarding profile.
- Flags: full rollout stack enabled (see §1).
- Apple Health **not yet connected**.
- Device: physical iPhone preferred; note simulator limitations in TC-09.

**Steps**
1. Complete onboarding through profile creation.
2. Land on Today tab; wait for dashboard load.
3. Open Journey, Plan, and Coach tabs sequentially.
4. Observe Settings → Apple Health / training integration state.
5. Pull to refresh Today (if available) or background/foreground app once.

**Expected Today behavior**
- Dashboard reaches `.loaded` without crash.
- HI section visible when UI flag on: connect-health fallback or building state.
- Recovery card shows connect / unavailable copy (title e.g. **"Connect Apple Health"**).
- Fallback banner or NBA supplemental action: **"Connect Apple Health"** CTA.
- Legacy Activity / NBA sections hidden when HI section replaces them.
- No stale label (no prior sync timestamp).

**Expected Coach behavior**
- Coach loads and accepts messages.
- HI context status: **`unavailable`** or suppressed awareness if connect-health NBA active.
- Coach must **not** claim recovery/workout facts from Apple Health.
- Prompt includes instruction: do not assume missing health data.

**Expected Journey behavior**
- Dashboard `.loaded`; HI section may appear after async load.
- Connect-health CTA card with **"Connect Apple Health"** message.
- Recovery timeline, workout history, milestones, progress in empty / limited states.
- Weekly review absent or **"Not enough data yet"** / building state.
- No error-phase sub-cards unless explicit sync failure.

**Expected Plan behavior**
- Dashboard `.loaded`.
- Plan confidence card: degraded **"Still learning"** / limited fit (not hidden).
- Core signals grid shows 5 signals (workouts, steps, sleep, heart, weight) mostly **missing**.
- Assumptions rows show **"Not enough data yet"** where applicable.
- **Connect Apple Health** missing-data action present.

**Expected logs / errors**
- `health_intelligence_snapshot_loaded` or `_failed` per surface (failure acceptable on first launch).
- `HealthSyncLogger` initial sync may start if permission granted later.
- No crash logs; no PII in analytics properties.
- `failure_reason` may be `unavailable` when no permission.

**Pass / fail criteria**
- **PASS:** All four tabs load; no crash; connect CTAs consistent; Coach does not invent health data.
- **FAIL:** Crash on nil snapshot; tab stuck loading; raw metrics in copy; Coach claims synced workouts/recovery.

---

### TC-02 — Existing user upgrade

**Preconditions**
- User on prior app version with existing profile, food logs, and optional Apple Health history.
- Local HI cache may exist (7–90 days) from prior sync.
- Upgrade to build with HI UI flags **newly enabled** (`FORMA_HEALTH_INTELLIGENCE_UI_ENABLED=1`).
- Apple Health previously connected on old build.

**Steps**
1. Install upgrade over existing app (preserve data).
2. Launch app; open Today → Journey → Plan → Coach.
3. Compare legacy sections vs new HI sections.
4. Verify food logs, weight logs, and plan targets unchanged.
5. Force-quit and relaunch once.

**Expected Today behavior**
- HI section appears; legacy NBA/Activity hidden per composition policy when HI visible.
- Cached recovery/activity may show immediately if cache warm.
- No duplicate cards (legacy + HI for same insight).
- Theme and layout stable after relaunch.

**Expected Coach behavior**
- If coach context flag newly on: `coach_health_context_used` on first health-related message.
- Context reflects cached snapshot if available (`available`, `partial`, or `stale`).
- Legacy activity query still works as fallback.

**Expected Journey behavior**
- HI section populates from cache + fresh load in parallel with dashboard.
- Dashboard `.loaded` even if HI load slow or fails.
- Weekly review loads from cache if previously generated; otherwise building state.
- Recovery timeline uses cached day snapshots when present.

**Expected Plan behavior**
- HI confidence replaces legacy Apple Health confidence card (composition policy).
- Profile assumptions section (age/height) remains separate from HI assumptions card.
- Confidence not empty-hidden; shows degraded or loaded state from snapshot/cache.

**Expected logs / errors**
- Snapshot loaded events with `cachedDayCount` > 0 when cache exists.
- No migration error alerts to user.
- Optional one-time initial sync log on first launch after upgrade.

**Pass / fail criteria**
- **PASS:** User data preserved; HI surfaces appear; no duplicate legacy+HI; no crash on cached snapshot.
- **FAIL:** Data loss; blank tabs; duplicate insights; crash decoding old cache.

---

### TC-03 — Apple Health denied

**Preconditions**
- User denied all HealthKit read permissions (or never granted).
- `TrainingInsightsStore.integrationState.isConnected == false`.
- HI UI + Coach context flags on.
- Profile and meal logging functional.

**Steps**
1. Open Today; note HI section.
2. Tap connect-health CTA if shown (may route to Plan/Settings depending on wiring).
3. Ask Coach: "How was my recovery today?"
4. Open Journey and Plan HI sections.
5. Deny permission again if iOS prompt appears.

**Expected Today behavior**
- UI kind: **`noHealthPermission`**.
- Recovery placeholder / connect copy; no recovery score from HK.
- Fallback banner: **"Link Apple Health to unlock recovery and activity insights."**
- NBA supplemental: **Connect Apple Health**.
- Workout card hidden unless empty no-workout state not applicable.
- Daily Mission and Adaptive Nutrition still work from logs.

**Expected Coach behavior**
- Status: **`unavailable`**.
- Response uses food/plan context only.
- Must say recovery/workout data is **unavailable**, not "you didn't work out."
- No fabricated step counts or HRV.

**Expected Journey behavior**
- Connect-health CTA at section top.
- Sub-cards empty with permission messaging.
- No fabricated timeline scores (unknown days OK).
- Workout history: insufficient history / no-health-data empty kind.

**Expected Plan behavior**
- Confidence degraded (**Still learning** / Limited fit).
- All 5 core signals shown; workouts/steps/sleep/heart likely **missing**.
- **Connect Apple Health** action card.
- Assumptions use profile targets where set; health rows limited.

**Expected logs / errors**
- `health_data_state` reflects disconnected in analytics.
- `health_permission_cta_tapped` if CTA tapped (`cta_surface`: today/journey/plan).
- No HealthKit authorization success logs.

**Pass / fail criteria**
- **PASS:** Graceful CTAs on all surfaces; Coach anti-hallucination holds; tabs load.
- **FAIL:** Error wall blocking tab; Coach claims definitive recovery; fake metric values in charts.

---

### TC-04 — Apple Health fully connected

**Preconditions**
- All required HealthKit read types granted (steps, workouts, sleep, heart, weight, active energy, exercise minutes).
- ≥ 7 days cached health data.
- Recent successful local sync (< 24h).
- User with regular workouts and meal logging (≥ 3 days/week).
- Weekly review flag on; ≥ 7 days logs + activity.

**Steps**
1. Open Today; verify all HI cards.
2. Complete a workout sync (or wait for sync); refresh Today.
3. Open Journey HI; scroll timeline, workouts, weekly review.
4. Open Plan HI; review confidence, signals, assumptions.
5. Ask Coach about today's training load and recovery.

**Expected Today behavior**
- UI kind: **`ready`**.
- Recovery card: status title, guidance, optional score (if confidence moderate/high).
- Daily Mission coherent with recovery + nutrition progress.
- Workout card when `hasWorkout == true`; duration/demand labels, no raw HR.
- Adaptive Nutrition when adjustment actionable.
- No fallback banner; no stale label.

**Expected Coach behavior**
- Status: **`available`**.
- `availableSignals` populated; `missingSignals` empty or minimal.
- Coach cites recovery/workout qualitatively; sanitised (no raw HRV/bpm).
- `coach_health_context_used` logged.

**Expected Journey behavior**
- Weekly review card **loaded** with title, summary, wins (if review generated).
- Recovery timeline **loaded** (7 days default); known status colors.
- Workout history **loaded** (30-day window), grouped by date.
- Milestones and progress metrics populated.
- No connect CTA.

**Expected Plan behavior**
- Confidence **loaded** with score % and label (Strong/Reasonable fit).
- 5 core signals mostly **available**.
- Assumptions rows populated with real values.
- Data quality: **Strong** or **Moderate**.
- Missing-data actions empty or only optional (nutrition/weight if not logged).

**Expected logs / errors**
- `health_intelligence_snapshot_loaded` all surfaces with `missing_signal_count` ≈ 0.
- View events: recovery, timeline, workout history, plan confidence, weekly review.
- Sync phase `succeeded` in sync state store.

**Pass / fail criteria**
- **PASS:** Happy-path cards on all surfaces; Coach accurate and sanitized; analytics fire once per context.
- **FAIL:** Missing cards with full permissions; raw medical numbers in UI; Coach overclaims certainty.

---

### TC-05 — Partial permission: steps only

**Preconditions**
- Apple Health connected with **Step Count** readable only.
- Workout, sleep, heart, weight denied or unavailable.
- Some step history in cache (≥ 1 day).

**Steps**
1. Open Today, Journey, Plan.
2. Note partial permission messaging.
3. Ask Coach: "How many steps did I take today?"

**Expected Today behavior**
- UI kind: **`partialPermission`** (if steps readable but training/sleep/heart incomplete).
- `canShowInsight` may be **true** (steps in activity).
- Confidence note: **"Partial data"** on recovery if shown.
- Partial fallback hidden when insight visible; NBA may offer **Manage Health permissions**.
- Activity/steps reflected in mission or recovery where available.

**Expected Coach behavior**
- Status: **`partial`**.
- May discuss steps if present in context.
- Must not claim workout or sleep facts.
- Missing signals listed in prompt metadata.

**Expected Journey behavior**
- **`partialSignalsNote`**: e.g. **"Missing signals: workouts, sleep, heart."**
- Timeline may show limited estimate days; **limitedTimelineNote** possible.
- Workout history empty (connected-no-workouts or educational empty).
- Trends for steps/recovery partial only.

**Expected Plan behavior**
- Connection state: **partial**.
- Steps signal **available** or **limited**; workouts/sleep/heart **missing**.
- **Manage Health permissions** action; granular sleep/HRV actions suppressed.
- Confidence moderate/limited; not empty-hidden.

**Expected logs / errors**
- Analytics `missing_signal_count` > 0.
- No errors; permission status reflects partial in context builder.

**Pass / fail criteria**
- **PASS:** Steps surfaced; other signals marked missing; no false workout/sleep claims.
- **FAIL:** App treats as fully connected; Coach invents workouts; Plan hides all signals.

---

### TC-06 — Partial permission: workouts only

**Preconditions**
- Workout type readable; steps denied or zero.
- At least one workout in last 30 days synced.
- Sleep/heart denied.

**Steps**
1. Open Today after a workout day.
2. Open Journey workout history.
3. Open Plan signals grid.
4. Ask Coach: "Was today's workout hard?"

**Expected Today behavior**
- Workout card **loaded** when today has workout.
- Recovery may be **limited estimate** (missing sleep/heart).
- Partial permission NBA or note possible.
- No step-based activity claims in recovery if steps nil.

**Expected Coach behavior**
- Status: **`partial`**.
- May discuss workout qualitatively if in snapshot.
- Must not infer low activity from missing steps.
- Limited confidence wording for recovery questions.

**Expected Journey behavior**
- Workout history **loaded** with sessions.
- Recovery timeline partial; limited labels on days missing sleep/heart.
- Partial signals note includes sleep, heart, steps as missing.

**Expected Plan behavior**
- Workouts signal **available** or **limited**.
- Steps **missing**.
- Assumptions: workout rows may populate; average steps **limited**.

**Expected logs / errors**
- `has_workout_today` true in Today analytics when applicable.
- Journey `journey_workout_history_viewed` fires.

**Pass / fail criteria**
- **PASS:** Workouts visible without steps; recovery stays limited; Coach safe.
- **FAIL:** Crash when steps nil; Coach says user was inactive due to missing steps.

---

### TC-07 — Partial permission: sleep missing

**Preconditions**
- Steps + workouts granted; **Sleep Analysis** denied or empty.
- Recovery engine marks `.sleep` in `missingSignals`.

**Steps**
1. Open Today recovery card.
2. Open Journey recovery timeline.
3. Ask Coach: "Did I sleep enough last night?"

**Expected Today behavior**
- UI kind may be **`noSleepData`** when sleep permitted but data missing in recovery+baseline; if denied, **`partialPermission`**.
- Recovery confidence note: limited / partial data.
- `missingDataNote` on recovery referencing missing sleep (sanitized copy).
- No sleep duration numbers invented.

**Expected Coach behavior**
- Status: **`partial`**.
- Must say sleep data **unavailable** or limited—not invent hours slept.
- Suggest enabling sleep in Apple Health when relevant.

**Expected Journey behavior**
- Timeline days may show **limited estimate** labels.
- Partial signals note includes **sleep**.
- No fabricated sleep bars in progress metrics.

**Expected Plan behavior**
- Sleep signal **missing** or **limited**.
- Sleep listed in assumptions as unavailable when baseline missing.
- Optional **Improve sleep sync** action (unless partial-permissions umbrella action shown).

**Expected logs / errors**
- Missing signal count includes sleep.
- No sleep duration in analytics payload.

**Pass / fail criteria**
- **PASS:** Sleep gaps explicit everywhere; recovery limited not definitive.
- **FAIL:** Coach states sleep hours; recovery score shown as high confidence without sleep.

---

### TC-08 — Partial permission: HRV missing

**Preconditions**
- Sleep + steps available; **HRV** and/or **Resting Heart Rate** denied or empty.
- Heart permission partially granted.

**Expected Coach behavior**
- Status: **`partial`**.
- No raw HRV ms or BPM in Coach reply.
- Heart questions answered with "unavailable" or qualitative limited estimate.

**Expected Today behavior**
- UI kind: **`noHeartData`** when heart permitted but missing in recovery+baseline.
- Recovery card avoids risky metric language (HRV, bpm, baseline).
- Limited estimate label when confidence low.

**Expected Journey behavior**
- Recovery day explanations sanitized (no HRV strings).
- Partial signals note includes **heart**.

**Expected Plan behavior**
- Heart signal **limited** or **missing**.
- Qualitative heart copy only in signals grid.
- Optional **Add heart variability data** action (if not superseded by manage-permissions card).

**Expected logs / errors**
- No HRV/RHR numeric values in logs or analytics.

**Pass / fail criteria**
- **PASS:** No raw heart metrics in UI/Coach; missing heart explicit in Plan/Journey.
- **FAIL:** HRV "42 ms" or bpm appears anywhere user-facing.

---

### TC-09 — HealthKit unavailable / simulator

**Preconditions**
- Simulator **or** device reporting `availability.isHealthDataAvailable == false`.
- HI flags on.

**Steps**
1. Launch on simulator (HealthKit limited) or device with Health unavailable.
2. Open all four surfaces.
3. Attempt connect-health flow.

**Expected Today behavior**
- UI kind: **`healthKitUnavailable`**.
- Safe unavailable recovery card.
- Message: Health not available on device; continue logging reassurance.
- Secondary action: **Continue logging**.

**Expected Coach behavior**
- Status: **`unavailable`**.
- No Apple Health claims.

**Expected Journey behavior**
- Connect/status section with unavailable messaging.
- Empty sub-cards; no error crash.

**Expected Plan behavior**
- Degraded confidence; signals missing.
- Fallback message may show unavailable copy.
- Plan dashboard still loaded.

**Expected logs / errors**
- `health_data_state` unavailable.
- No HealthKit query success logs.

**Pass / fail criteria**
- **PASS:** Graceful unavailable path on all surfaces; no crash.
- **FAIL:** Infinite loading; unhandled HK errors surfaced as alerts.

---

### TC-10 — No workout history

**Preconditions**
- Apple Health connected with workout permission.
- Zero workout days in 28-day baseline; no workout today.
- Steps/activity may be present.

**Steps**
1. Open Today.
2. Open Journey workout history.
3. Open Plan confidence.
4. Ask Coach: "What workouts did I do this week?"

**Expected Today behavior**
- UI kind: **`noWorkoutHistory`** (when baseline conditions met).
- Empty workout card: **"No workouts yet"** / workout insights copy.
- Other cards may still show (steps/recovery).
- Supplemental NBA may suggest **Open Plan** per copy.

**Expected Coach behavior**
- Status: **`partial`** or **`unavailable`** depending on other signals.
- Must say workout history **unavailable** or empty—not "you didn't exercise" as definitive medical fact without data.

**Expected Journey behavior**
- Workout history phase **empty**; kind **connectedNoWorkouts**.
- Message: **"Apple Health is connected, but Forma has not synced workouts yet."**
- Milestones may be empty; educational empty states.

**Expected Plan behavior**
- Workouts signal **limited** or **missing**.
- Confidence reduced; improvement hints mention workouts.
- Assumptions: workouts/week **limited**.

**Expected logs / errors**
- `has_workout_today` false.
- Journey workout history viewed **not** fired (empty phase).

**Pass / fail criteria**
- **PASS:** Educational empty states; no fake workout rows; Coach honest about missing history.
- **FAIL:** Empty chart with fabricated workout counts; Coach lists fake sessions.

---

### TC-11 — Multiple workouts in one day

**Preconditions**
- Apple Health shows ≥ 2 workouts on the same calendar day (e.g. run + strength).
- Full permissions; sync succeeded today.

**Steps**
1. Sync health data.
2. Open Today workout card.
3. Open Journey workout history for that date.
4. Ask Coach: "How many workouts did I do today?"

**Expected Today behavior**
- Workout card reflects aggregated day summary (`workoutCount`, total duration/calories).
- Single card—not duplicate workout cards.
- Demand/intensity labels when engine provides them.

**Expected Coach behavior**
- Context includes workout summary with count > 1 when snapshot aggregates.
- No duplicate contradictory workout entries in prompt.

**Expected Journey behavior**
- Workout history **group** for that date contains **multiple items**.
- Items sorted; duration labels per session.
- Milestones (streak/consistency) use distinct workout days correctly.

**Expected Plan behavior**
- Workout days / load assumptions reflect multi-session day as one day with load.
- No double-counting days in assumptions.

**Expected logs / errors**
- Normal snapshot loaded events.
- No aggregation errors in console.

**Pass / fail criteria**
- **PASS:** Grouped UI on Journey; aggregated Today card; correct day count in milestones.
- **FAIL:** Only one workout shown; duplicate groups; crash on multiple records.

---

### TC-12 — Workout crossing midnight

**Preconditions**
- Apple Health workout starting before midnight and ending after (e.g. 11:30 PM – 12:30 AM).
- Sync after workout completes.

**Steps**
1. Record or import cross-midnight workout in Health.
2. Sync Forma.
3. Check Today (workout day), Journey history date label, weekly review stats if applicable.
4. Change device timezone once (see TC-29 interaction) and recheck attribution.

**Expected Today behavior**
- Workout attributed to engine's chosen calendar day (typically start date or Health record date).
- Card appears on expected day after sync—not duplicated on two days.

**Expected Coach behavior**
- Workout context matches same calendar day as Today snapshot.
- No duplicate "two workouts on consecutive days" hallucination from one session.

**Expected Journey behavior**
- Single history item on one date group.
- Date label matches attribution policy.
- Timeline recovery for adjacent days remains independent.

**Expected Plan behavior**
- Workout day counts don't double-count one session across two days.

**Expected logs / errors**
- No date parsing exceptions.
- Sync attributes workout to one normalized day in cache.

**Pass / fail criteria**
- **PASS:** Exactly one history entry; consistent Today/Journey/Coach day attribution.
- **FAIL:** Duplicate entries on two dates; missing workout on expected day.

---

### TC-13 — Stale cached health data

**Preconditions**
- Cached health data ≥ 1 day present.
- `lastSuccessfulLocalSyncAt` > **24 hours** ago (manipulate via waiting or debug clock).
- Apple Health still connected.
- No active sync in progress.

**Steps**
1. Open Today with stale cache.
2. Open Journey and Plan.
3. Note stale banners/labels.
4. Trigger manual refresh or foreground sync (TC-27).

**Expected Today behavior**
- UI kind: **`staleData`**.
- Stale banner: **"May be out of date"**.
- Insight cards still visible (`canShowInsight` true).
- Recovery may show stale label on card.

**Expected Coach behavior**
- Status: **`stale`**.
- Coach mentions outdated sync **only when relevant** to user question.

**Expected Journey behavior**
- **`staleDataLabel`** at section top (same copy family as Today).
- Loaded cards show cached summaries.
- No full-section error state.

**Expected Plan behavior**
- **`staleDataLabel`** banner when applicable.
- Confidence/signals still visible from cache.

**Expected logs / errors**
- Analytics reflects cached day count > 0.
- Stale resolved after successful sync (TC-27).

**Pass / fail criteria**
- **PASS:** Cached data shown with stale indicator; no crash; refresh clears stale kind.
- **FAIL:** Stale data hidden entirely; false "just synced" without refresh; tab error state.

---

### TC-14 — Local sync failure

**Preconditions**
- Apple Health connected; cached data exists from prior successful sync.
- Induce local sync failure: airplane mode during sync, revoke network for HK if applicable, or debug inject `syncPhase == .failed` / repository error.
- `explicitErrorMessage` or failed phase set while cache non-empty.

**Steps**
1. Trigger sync (foreground refresh or pull refresh).
2. Observe Today/Journey/Plan during and after failure.
3. Relaunch app offline with cache intact.

**Expected Today behavior**
- During sync: **`loading`** if `syncPhase == .syncing`.
- After failure with cache: **`syncFailed`** + `canShowInsight` true.
- Label: **"Last refresh failed — showing cached data"**.
- Cards remain populated from cache; no blank axes.

**Expected Coach behavior**
- Status: **`partial`** or **`stale`** if insight still usable; **`unavailable`** if no cache.
- Instruction mentions stale/failed sync only when relevant.

**Expected Journey behavior**
- Cached timeline/workouts/review remain visible.
- Stale label + optional **`syncFailureSectionMessage`** on progress.
- Full **error** section only when **no** cached insight (`canShowInsight` false).

**Expected Plan behavior**
- Cached confidence/signals with stale/sync-failed label.
- Fallback message if insight not renderable.

**Expected logs / errors**
- `health_intelligence_snapshot_failed` possible on load error.
- `HealthSyncLogger` warn/error for failed sync; `lastSuccessfulSyncAt` preserved.
- `failure_reason`: `syncFailed` in analytics when applicable.

**Pass / fail criteria**
- **PASS:** Cached summaries remain; stale/failed labels shown; tabs load.
- **FAIL:** All cards flip to error empty; crash; fabricated fresh values.

---

### TC-15 — Remote summary sync disabled

**Preconditions**
- `FORMA_HEALTH_SUMMARY_REMOTE_SYNC_ENABLED=0` **or** user opted out of remote sync.
- Local sync enabled and working.
- Authenticated user.

**Steps**
1. Complete successful local health sync.
2. Monitor network for remote upload (proxy/Charles) — should be none.
3. Open all HI surfaces.
4. Check Settings for sync consent state if exposed.

**Expected Today behavior**
- Normal local HI behavior unaffected.
- UI kind **`remoteSyncDisabled`** only when: capability on + user opted out + no cache/insight (edge case).
- With local cache: **`ready`** or other local-driven kinds.

**Expected Coach behavior**
- Unaffected by remote sync off.
- No cloud summary dependency in prompts.

**Expected Journey behavior**
- Local weekly review and timeline unaffected.

**Expected Plan behavior**
- Unaffected; local signals drive confidence.

**Expected logs / errors**
- No remote upload API calls.
- `NoopHealthSummaryRemoteSyncClient` path in in-memory/test builds.
- Local sync success logs only.

**Pass / fail criteria**
- **PASS:** Local HI fully functional; zero remote summary uploads.
- **FAIL:** Remote upload despite flag off; UI blocked waiting for cloud.

---

### TC-16 — Remote summary sync enabled

**Preconditions**
- `FORMA_HEALTH_SUMMARY_REMOTE_SYNC_ENABLED=1`.
- User authenticated (non-anonymous).
- User consent **opted in** to health summary sync.
- Local sync succeeds.

**Steps**
1. Perform local sync (initial or foreground).
2. Verify remote sync scheduled after local success.
3. Confirm upload payload contains summaries only (no raw HK samples) per contract doc.
4. Open HI surfaces — should not block on remote completion.

**Expected Today behavior**
- Immediate local UI; no spinner waiting for cloud.
- Same as TC-04 after local sync regardless of remote timing.

**Expected Coach behavior**
- Unaffected by remote sync completion timing.

**Expected Journey behavior**
- Unaffected; weekly review local cache first.

**Expected Plan behavior**
- Unaffected.

**Expected logs / errors**
- Remote sync scheduled after `succeeded` / `partialSuccess` local phase.
- Upload success/failure logged server-side; local UI never blocked.
- Payload conforms to `HEALTH_SUMMARY_SYNC_CONTRACT.md` (no raw metrics).

**Pass / fail criteria**
- **PASS:** Remote upload occurs post-local-sync; UI never blocked; privacy contract upheld.
- **FAIL:** Raw HK in payload; UI waits for remote; crash on remote failure.

---

### TC-17 — Remote sync failure

**Preconditions**
- Remote sync enabled + opted in.
- Simulate server 500 / network drop during **remote** upload only.
- Local sync already succeeded; cache populated.

**Steps**
1. Trigger local sync success.
2. Force remote upload failure.
3. Use Today/Journey/Plan/Coach normally.

**Expected Today behavior**
- Identical to post-local-sync success (TC-04).
- No user-visible remote error banner (remote is best-effort).

**Expected Coach behavior**
- No change vs successful remote.

**Expected Journey behavior**
- No change vs successful remote.

**Expected Plan behavior**
- No change vs successful remote.

**Expected logs / errors**
- Remote sync error logged internally.
- Local `lastSuccessfulSyncAt` unchanged and valid.
- No `health_intelligence_snapshot_failed` solely due to remote failure.

**Pass / fail criteria**
- **PASS:** Local HI unaffected; silent remote retry/degrade.
- **FAIL:** User error alert; local cache cleared; HI sections empty.

---

### TC-18 — Unauthenticated user

**Preconditions**
- User in anonymous / signed-out / pre-auth state (per app auth gate).
- HI UI flags on for surfaces reachable in this state (may be limited to onboarding/welcome).

**Steps**
1. Launch app without signing in (if app allows browsing).
2. Attempt to view Today/Journey/Plan HI.
3. Attempt Coach if available.
4. Verify remote summary sync does not run.

**Expected Today behavior**
- If tab unavailable: N/A; else HI may show connect/building states without cloud profile.
- Nutrition/hydration from local logs only if logs exist.

**Expected Coach behavior**
- HI context likely **`unavailable`** without profile/snapshot.
- Coach still responds using non-health context.

**Expected Journey behavior**
- If Journey reachable: HI limited or hidden; dashboard may be `.empty` without profile.

**Expected Plan behavior**
- Plan typically `.empty` without profile.

**Expected logs / errors**
- No remote summary upload (requires auth UID).
- No PII in analytics for anonymous session.

**Pass / fail criteria**
- **PASS:** No crash; no remote sync; graceful empty/unavailable states.
- **FAIL:** Remote upload without auth; crash on nil profile in HI loader.

---

### TC-19 — User logs meal after workout

**Preconditions**
- Today has synced workout in HI snapshot.
- User has not logged lunch yet; protein target set.

**Steps**
1. Note Today HI: workout card + adaptive nutrition state before meal.
2. Log a meal meeting partial protein target.
3. Return to Today; observe Daily Mission / Adaptive Nutrition updates.
4. Ask Coach: "What should I eat after my workout?"

**Expected Today behavior**
- Daily Mission updates with nutrition progress.
- Adaptive Nutrition card may appear/update with protein/water guidance.
- Workout card unchanged unless sync refreshes.
- HI section does not crash on nutrition progress change.

**Expected Coach behavior**
- Uses workout + nutrition context when available.
- Post-workout nutrition advice qualitative; aligns with snapshot nutrition fields when present.

**Expected Journey behavior**
- No immediate change until day rollup; progress metrics update on refresh/week boundary.

**Expected Plan behavior**
- Nutrition signal **available** after ≥ 3 logging days; **limited** before.
- Assumptions unchanged intraday unless targets recompute.

**Expected logs / errors**
- Normal Today refresh logs.
- No duplicate snapshot_failed on nutrition-only update.

**Pass / fail criteria**
- **PASS:** Today mission/nutrition reflects new log; Coach coherent; no crash.
- **FAIL:** Stale mission forever; Coach contradicts logged meal; HI section disappears.

---

### TC-20 — User logs water after workout

**Preconditions**
- Workout synced today; hydration targets configured.
- Water below target before log.

**Steps**
1. Note Adaptive Nutrition / mission hydration hints if shown.
2. Log water toward target.
3. Refresh Today.
4. Ask Coach: "How much water should I drink after training?"

**Expected Coach behavior**
- May reference hydration advice from workout summary when confidence sufficient.
- With low confidence: general guidance without fabricated ml from missing signals.

**Expected Today behavior**
- Adaptive Nutrition or mission updates water remaining/increase ml suggestion.
- Recovery/workout cards stable.

**Expected Journey behavior**
- Water hit days in weekly review only after week rollup—not necessarily immediate.

**Expected Plan behavior**
- Unaffected intraday unless nutrition logging thresholds change.

**Expected logs / errors**
- Standard Today load; no errors.

**Pass / fail criteria**
- **PASS:** Hydration progress reflected on Today; Coach safe wording.
- **FAIL:** Crash linking water log to HI; incorrect zero hydration forever.

---

### TC-21 — Coach asks about workout

**Preconditions**
- Coach context flag on.
- Known state: (A) workout today, (B) no workout history, (C) permission denied — run sub-scenarios.

**Steps**
1. **A:** Ask "What workout did I do today?"
2. **B:** Ask same with TC-10 preconditions.
3. **C:** Ask same with TC-03 preconditions.
4. Inspect prompt context in debug if available.

**Expected Coach behavior**
- **A:** Describes workout from snapshot (title/type qualitative); sanitized text.
- **B:** Says workout data unavailable / no synced workouts—not "you did not work out."
- **C:** Says Apple Health not connected / unavailable; suggests connecting.
- All: `healthIntelligenceRules` enforced; `coach_health_context_used` logged when context injected.

**Expected Today / Journey / Plan behavior**
- No change from respective permission/sync states during Coach session.

**Expected logs / errors**
- `coach_health_context_used` with appropriate `health_context_status`.
- No raw workout titles in analytics (privacy rule).

**Pass / fail criteria**
- **PASS:** Three sub-scenarios match anti-hallucination rules exactly.
- **FAIL:** Coach invents workout in B/C; raw metrics in reply; claims no workout when data unavailable vs empty.

---

### TC-22 — Coach asks about recovery

**Preconditions**
- Coach context on.
- Sub-scenarios: (A) full recovery, (B) limited estimate missing sleep/HRV, (C) unavailable.

**Steps**
1. Ask "How recovered am I today?"
2. Ask "Should I train hard today?"
3. Repeat for B and C preconditions.

**Expected Coach behavior**
- **A:** Qualitative recovery aligned with snapshot status; score only if confidence adequate in context (may be downgraded to moderate/limited in prompt).
- **B:** Uses **limited estimate** language; cites missing signals.
- **C:** Says recovery unavailable; uses feel-based guidance.
- Never diagnoses medical conditions.

**Expected Today behavior**
- Recovery card copy should align with Coach (same snapshot source).

**Expected Journey behavior**
- Timeline status consistent with recovery summary for today.

**Expected Plan behavior**
- Recovery trend assumption matches snapshot status.

**Expected logs / errors**
- Context includes `confidenceLabel`, `missingSignals`, `healthContextStatus`.

**Pass / fail criteria**
- **PASS:** Wording matches card status; limited/unavailable paths honest.
- **FAIL:** Coach gives definitive medical recovery score in C; contradicts Today card.

---

### TC-23 — Weekly review generation

**Preconditions**
- `FORMA_HEALTH_INTELLIGENCE_WEEKLY_REVIEW_ENABLED=1`.
- ≥ 7 days activity + meal logging; completed week boundary.
- Apple Health connected with mixed signals OK.

**Steps**
1. Open Journey; wait for HI section load.
2. Tap weekly review card when loaded.
3. Force refresh weekly review (pull refresh with force flag if debug available).
4. Revoke weekly review flag and relaunch — verify building/empty only.

**Expected Journey behavior**
- **Flag on:** Card phase **loaded** with title, summary, wins; detail sheet with stats grid.
- **No review yet:** Card **empty** — **"Not enough data yet"** + requirements copy when baseline insufficient; **"Weekly review building"** otherwise.
- Detail opens only when phase loaded + detail state present.
- Milestones may include weekly win items from review.

**Expected Today / Plan behavior**
- Today may reference weekly review in snapshot indirectly; no dedicated weekly review card.
- Plan progress assumptions may use weekly stats when loaded via shared services.

**Expected Coach behavior**
- May reference weekly patterns if in context; not required for this TC.

**Expected logs / errors**
- `weekly_review_card_viewed` once per context when loaded.
- `weekly_review_detail_opened` on tap.
- Generation errors logged; Journey dashboard still `.loaded`.

**Pass / fail criteria**
- **PASS:** Review generates when eligible; detail navigable; flag off disables generation without crash.
- **FAIL:** Crash on nil review; fake stats in grid; detail opens with empty phase.

---

### TC-24 — Plan confidence with missing data

**Preconditions**
- Apple Health disconnected **or** partial with many missing signals.
- Profile targets set (calorie/protein).
- Optional: no weight log, < 3 nutrition days.

**Steps**
1. Open Plan HI section.
2. Verify confidence card never hidden entirely.
3. Review 5 core signals + assumptions + missing actions.
4. Connect Apple Health mid-test; refresh Plan.

**Expected Plan behavior**
- Confidence phase always **loaded** (never empty-hidden stack).
- Label: **Still learning** / **Limited fit** with degraded score.
- Disclaimer: **"Coaching estimates only — not a medical assessment."**
- Signals show used vs missing grouping (**Optional improvements** section).
- Assumptions include limited rows + missing-signal assumptions (sleep/heart/weight).
- Missing actions: connect, manage permissions, log weight, log nutrition as applicable.
- After connect: confidence improves but Apple Health not mandatory for section visibility.

**Expected Today / Journey behavior**
- Reflect same permission state consistently (connect CTAs vs partial notes).

**Expected Coach behavior**
- Plan confidence in snapshot may feed context indirectly; Coach does not show Plan card UI.

**Expected logs / errors**
- `plan_health_confidence_viewed` with low confidence bucket.
- `health_intelligence_snapshot_loaded` surface plan.

**Pass / fail criteria**
- **PASS:** Plan always shows confidence + signals + assumptions; missing data as assumptions not errors.
- **FAIL:** Entire HI stack hidden when confidence empty; error banners blocking Plan dashboard.

---

### TC-25 — Theme change without app kill

**Preconditions**
- HI visible on Today, Journey, Plan with loaded cards.
- App Settings theme palette change available (e.g. Blossom Pink, dark mode).

**Steps**
1. Open Today HI section; note colors/typography.
2. Change theme in Settings; return to Today **without** force-quit.
3. Repeat on Journey and Plan HI sections.
4. Toggle dark/light mode from Control Center; recheck.

**Expected Today behavior**
- `.formaThemeReactive()` updates card colors, primary CTAs, text immediately.
- No stale color cache on banners/cards.

**Expected Journey behavior**
- Recovery timeline colors (status tokens) remap to theme.
- Connect CTA and banners reactive.

**Expected Plan behavior**
- Signal status dots and cards reactive.
- Section spacing/layout intact at large accessibility sizes (spot check).

**Expected Coach behavior**
- Chat UI theme updates; HI context unaffected.

**Expected logs / errors**
- None required; no relaunch needed.

**Pass / fail criteria**
- **PASS:** All HI sections match new theme instantly; no mixed old/new styling.
- **FAIL:** Requires app restart for theme; unreadable contrast; layout overflow after theme change.

---

### TC-26 — Offline mode

**Preconditions**
- Airplane mode **on** (no network).
- Local HI cache populated from prior online session.
- Apple Health local reads still work (HK is on-device).

**Steps**
1. Open Today, Journey, Plan offline.
2. Open Coach; ask recovery question.
3. Turn network on; foreground app (TC-27).

**Expected Today behavior**
- Shows cached HI if available; stale label if past 24h sync.
- Repository may serve stale cache on HK read issues with internal fallback log.
- Dashboard `.loaded`.

**Expected Coach behavior**
- Uses cached snapshot if loaded before offline.
- **`unavailable`** if snapshot never loaded this session.

**Expected Journey behavior**
- Cached timeline/workouts/review visible.
- Loader does not crash without network (HK local).

**Expected Plan behavior**
- Cached confidence/signals from last successful load.

**Expected logs / errors**
- Possible repository **"stale cache fallback"** logs.
- No network-required blocking for local HI render.

**Pass / fail criteria**
- **PASS:** Offline usable with cache; no crash; honest stale/unavailable labels.
- **FAIL:** Blank HI offline with valid cache; network error alerts blocking tabs.

---

### TC-27 — App foreground refresh

**Preconditions**
- Sync enabled; Apple Health connected.
- App backgrounded ≥ 15 minutes **or** first foreground of session.
- Note `lastSuccessfulLocalSyncAt`.

**Steps**
1. Background app ≥ 15 minutes.
2. Foreground app; observe sync (debug overlay/logs if available).
3. Within 15 minutes, background and foreground again quickly.
4. Verify Today HI updates if new Health data exists.

**Expected Today behavior**
- First foreground: local today sync runs.
- Second foreground within throttle: sync skipped; UI stable (no flicker loop).
- If sync succeeds: stale labels clear; cards refresh.
- `syncPhase` transient **syncing** → **succeeded**.

**Expected Journey / Plan behavior**
- Refresh HI sections on model refresh after sync completes (parallel load).
- No tab blocking during sync.

**Expected Coach behavior**
- Next message uses updated snapshot if Coach reloads context.

**Expected logs / errors**
- `HealthSyncLogger`: **"foreground refresh skipped: throttled"** on second rapid foreground.
- Sync success updates `lastSuccessfulSyncAt`.
- Remote sync chained if enabled (TC-16).

**Pass / fail criteria**
- **PASS:** Foreground sync respects 15 min throttle; data refreshes when due.
- **FAIL:** Sync storm on every foreground; UI stuck in loading; tabs blocked.

---

### TC-28 — Background refresh (if implemented)

**Preconditions**
- Document current implementation state: **BGAppRefreshTask / background fetch NOT implemented** as of Phase 19.
- Only foreground refresh exists (`MainTabView` → `healthSyncStateStore.refreshOnAppForeground()`).

**Steps**
1. Background app for extended period **without** foregrounding.
2. Add new HealthKit data from another app/watch.
3. Foreground Forma after several hours.
4. Search codebase / logs for `BGTaskScheduler` — expect none.

**Expected Today behavior**
- No HI update until foreground (TC-27).
- After foreground: sync runs per throttle rules.

**Expected Coach / Journey / Plan behavior**
- Same — no background HI update.

**Expected logs / errors**
- No background task registration logs.
- Foreground sync logs present after resume.

**Pass / fail criteria**
- **PASS:** Documented N/A — no background HI refresh; foreground recovery works (TC-27).
- **FAIL (regression if implemented later):** Background refresh without throttling/privacy review.
- **Note:** Re-open this TC when background tasks ship; replace N/A with full expectations.

---

### TC-29 — Timezone / day boundary

**Preconditions**
- User traveling or manual timezone change (Settings → General → Date & Time).
- Health cache spanning UTC/local midnight.
- Workout near midnight (see TC-12).

**Steps**
1. Note Today date label and HI snapshot date before timezone change.
2. Change timezone forward/backward across midnight.
3. Relaunch app; open Today, Journey timeline, weekly review week range.
4. Log meal at local midnight boundary.

**Expected Today behavior**
- Snapshot date aligns with **`Calendar.current`** start-of-day in new timezone.
- Cards show correct "today" after relaunch.
- No duplicate or missing day mission.

**Expected Journey behavior**
- Timeline grid rebuilds for new reference day.
- Workout history date labels match local calendar.
- Weekly review week range labels update correctly.

**Expected Plan behavior**
- Baseline context `targetDate` matches new local today.

**Expected Coach behavior**
- "Today" references match post-relaunch snapshot date.

**Expected logs / errors**
- No date parsing crashes.
- Cache keys migrate or miss gracefully (may re-sync day).

**Pass / fail criteria**
- **PASS:** Consistent local-day attribution across surfaces after TZ change.
- **FAIL:** Wrong-day workouts; duplicate timeline days; crash on date fold.

---

### TC-30 — Deleting / revoking Apple Health permission

**Preconditions**
- Start from TC-04 fully connected state with populated HI.
- User revokes Forma access in **Health app → Sharing → Apps → Forma** (all or subset).

**Steps**
1. Revoke all permissions; return to Forma (foreground).
2. Open Today, Journey, Plan, Coach.
3. Revoke only sleep; repeat spot checks (TC-07).
4. Re-grant permissions; verify recovery without app reinstall.

**Expected Today behavior**
- Transitions to **`noHealthPermission`** or **`partialPermission`** / missing-signal kinds.
- Connect / manage permissions CTAs appear.
- Cached data may show with stale/failed sync until cache policy clears unavailable signals.
- No crash on permission downgrade.

**Expected Coach behavior**
- Status → **`unavailable`** or **`partial`** matching new permission set.
- Must not use stale snapshot as definitive if awareness suppressed post-revoke.

**Expected Journey behavior**
- Connect CTA or partial signals note.
- Previously loaded cards degrade to limited/empty—not crash.
- Timeline may retain historical cached days with stale indicator if sync fails.

**Expected Plan behavior**
- Signals flip to missing/limited appropriately.
- **Manage Health permissions** or **Connect Apple Health** actions shown.
- Confidence degrades; assumptions become limited.

**Expected logs / errors**
- Permission refresh on foreground sync.
- Possible `snapshot_failed` with `unavailable` during transition.
- `health_permission_cta_tapped` if user taps CTA.

**Pass / fail criteria**
- **PASS:** Graceful downgrade on revoke; re-grant restores HI without reinstall; no crash.
- **FAIL:** Crash on revoked permission; stale full-confidence UI after revoke; HealthKit uncaught errors.

---

## 4. Regression smoke checklist (run before release)

Run with **TC-04** preconditions plus spot checks:

- [ ] TC-03 denied permission CTAs
- [ ] TC-10 no workout empty states
- [ ] TC-13 stale label visible
- [ ] TC-14 sync failed + cache
- [ ] TC-21 / TC-22 Coach anti-hallucination
- [ ] TC-24 Plan degraded confidence
- [ ] TC-25 theme reactive
- [ ] TC-30 permission revoke

**Automation companion:** `Fitness CoachTests/HealthIntelligenceUIStateTests.swift`, `*PresentationBuilderTests.swift`, `HealthIntelligencePhase11IntegrationTests.swift`, `CoachHealthContextStatusTests.swift`.

**Manual-only:** HealthKit permission matrix, cross-midnight workouts, timezone travel, remote sync privacy audit.

---

## 5. Sign-off template

| Field | Value |
|-------|-------|
| Build / branch | |
| Tester | |
| Device(s) | |
| iOS version | |
| Flags enabled | |
| Date | |
| TC-01 – TC-30 result | Pass / Fail / N/A per row |
| Blocking defects | |
| Release recommendation | Ship / Hold |

---

*End of Phase 19 QA Test Matrix.*
