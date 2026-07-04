# Release test plan

Manual QA script for a **release candidate (RC)** build on a **physical device** (simulator acceptable only where noted). Pair with automated suites in [ProductionReadinessChecklist.md](./ProductionReadinessChecklist.md).

**Prerequisites**

- RC installed from TestFlight or local Release archive
- Test account with existing cloud data (for restore / cross-device sections)
- Second device or simulator signed into the **same** Firebase UID (for cross-device)
- `FORMA_AI_BACKEND_URL` resolves to production gateway — [ReleaseAI.md](../ReleaseAI.md)

**Pass / fail:** Each scenario must complete without crash, data loss, or misleading empty states unless the expected result explicitly allows it.

---

## 1. Onboarding

| Step | Action | Expected result |
|------|--------|-----------------|
| 1.1 | Fresh install → launch | Public welcome / sign-in entry; no crash |
| 1.2 | Complete onboarding (new user path) | Profile + plan saved; lands on main tabs |
| 1.3 | Force-quit mid-onboarding → relaunch | Resumes or restarts safely; no corrupt profile |
| 1.4 | Deny notifications (if prompted) | App continues; no blocking modal loop |

**Automated overlap:** `OnboardingCompletion*`, `OnboardingModel*`, `WelcomeOnboardingHandoff` (Integration plan).

---

## 2. Sign-in

| Step | Action | Expected result |
|------|--------|-----------------|
| 2.1 | Sign in with **Apple** | Session active; main shell or restore gate |
| 2.2 | Sign out → sign in with **Google** (if enabled) | Session active; profile reconciled |
| 2.3 | Sign in with **email** (if enabled) | Session active |
| 2.4 | Expired token simulation (optional) | Re-auth or friendly error — not silent failure |
| 2.5 | Sign out | Returns to public entry; no stale PII on screen |

**Automated overlap:** `ExistingUserSignIn*`, `AuthProfileRouteSafety*`, `SignOutHygiene`.

---

## 3. Restore

| Step | Action | Expected result |
|------|--------|-----------------|
| 3.1 | Delete app → reinstall → sign in (account with cloud data) | Blocking or inline restore; Today/Journey not falsely empty |
| 3.2 | Wait for background backfill | Older daily logs appear |
| 3.3 | Log new food during restore window | Local entry kept; not overwritten by stale remote row |

**Reference:** [PHASE_4_FRESH_INSTALL_RESTORE.md](../AccountPersistence/PHASE_4_FRESH_INSTALL_RESTORE.md)

---

## 4. Food / water / weight logging

| Step | Action | Expected result |
|------|--------|-----------------|
| 4.1 | Today → log water | Count updates; persists after tab switch |
| 4.2 | Today → log food (Coach estimate path) | Entry on Today; macros update |
| 4.3 | Log weight | Journey / Plan weight context updates where applicable |
| 4.4 | Edit or delete a log (Coach or Today) | Mutation reflected; no duplicate rows |
| 4.5 | Change system date to yesterday (if test build allows) | Correct day bucket — no "today" mis-attachment |

**Automated overlap:** `FoodLog*`, `DailyLogServiceTests`, `FitnessActionCenterTests`, [TodayMealLogging.md](../TodayMealLogging.md).

---

## 5. Coach estimate / log

| Step | Action | Expected result |
|------|--------|-----------------|
| 5.1 | "2 eggs for breakfast" | Food draft or confirmation sheet |
| 5.2 | Confirm log | Appears on Today |
| 5.3 | Nutrition estimate question | Structured estimate card (not wall of text) |
| 5.4 | Meal advice follow-up | Coaching reply within timeout |
| 5.5 | (Optional) Meal photo | Analysis sheet; `needsUserReview` flow |

**Backend smoke:** [ReleaseAI.md](../ReleaseAI.md) § Manual validation.

---

## 6. Today refresh

| Step | Action | Expected result |
|------|--------|-----------------|
| 6.1 | Pull to refresh (if available) | Data reloads; no duplicate entries |
| 6.2 | Background app → foreground | Today dashboard refreshes |
| 6.3 | Log on Coach → switch to Today | New log visible without kill |

---

## 7. Journey refresh

| Step | Action | Expected result |
|------|--------|-----------------|
| 7.1 | Open Journey tab | Sections load (timeline, consistency, etc.) |
| 7.2 | Log food → return to Journey | Streak / nutrition sections update |
| 7.3 | Scroll collapsible analytics | No crash; read-only surfaces stay read-only |

**Reference:** [JourneyArchitecture.md](../JourneyArchitecture.md)

---

## 8. Plan edit

| Step | Action | Expected result |
|------|--------|-----------------|
| 8.1 | Open Plan tab | Targets and rationale visible |
| 8.2 | Edit calorie or macro target | Saves; Today rings update |
| 8.3 | Conflict with cloud profile (optional) | Conflict UI — not silent overwrite |

**Automated overlap:** `PlanModel*`, `PlanRationale*`, `ProfilePlanConflict*`.

---

## 9. Settings / account deletion

| Step | Action | Expected result |
|------|--------|-----------------|
| 9.1 | Settings → Privacy & Data | Account status rows visible |
| 9.2 | Delete account → wrong confirmation | Blocked |
| 9.3 | Delete account → type `DELETE` | Progress; signed out; data removed per [PHASE_6](../AccountPersistence/PHASE_6_ACCOUNT_DELETION_AND_PRIVACY.md) |
| 9.4 | Delete local device data only | Local wipe; can sign in again and restore cloud |

**Use a disposable test account for 9.3.**

---

## 10. HealthKit denied / allowed

| Step | Action | Expected result |
|------|--------|-----------------|
| 10.1 | **Deny** Health access during connect | No crash; CTA or limited state on Today/Journey/Plan |
| 10.2 | **Allow** read access (workouts / steps as configured) | Training sections populate where enabled |
| 10.3 | Revoke in iOS Settings → Health → Forma | App handles denied state on next launch |
| 10.4 | Partial permission (allow steps, deny workouts) | Partial permission UI — not fabricated metrics |

**Deep matrix:** [PHASE_19_QA_TEST_MATRIX.md](../HealthIntelligence/PHASE_19_QA_TEST_MATRIX.md) (TC-01 … TC-30).

---

## 11. Offline

| Step | Action | Expected result |
|------|--------|-----------------|
| 11.1 | Enable airplane mode | App remains usable for local logging |
| 11.2 | Log water + food offline | Entries visible on Today |
| 11.3 | Coach prompt offline | Friendly failure — no crash |
| 11.4 | Disable airplane mode | Sync/upload resumes; cross-device sees data (Phase 5) |

---

## 12. Reinstall

| Step | Action | Expected result |
|------|--------|-----------------|
| 12.1 | Delete app → reinstall → same account sign-in | Restore flow (§3) |
| 12.2 | Verify plan targets | Match cloud profile after restore |
| 12.3 | Verify theme / settings prefs | Restored or sane defaults |

---

## 13. Cross-device

| Step | Action | Expected result |
|------|--------|-----------------|
| 13.1 | **Device A:** log distinct meal | Success locally |
| 13.2 | **Device B:** same account — foreground app | Entry appears after refresh / realtime hint |
| 13.3 | **Device B:** pull-to-refresh (if enabled) | Same entry without reinstall |
| 13.4 | **Device A:** edit entry | **Device B:** sees update after refresh |

**Reference:** [PHASE_5_CROSS_DEVICE_REFRESH.md](../AccountPersistence/PHASE_5_CROSS_DEVICE_REFRESH.md)

---

## Test session log

| Scenario | Device / OS | Build | Tester | Pass | Notes |
|----------|-------------|-------|--------|------|-------|
| Onboarding | | | | | |
| Sign-in | | | | | |
| Restore | | | | | |
| Logging | | | | | |
| Coach | | | | | |
| Today / Journey / Plan | | | | | |
| Settings / deletion | | | | | |
| HealthKit | | | | | |
| Offline | | | | | |
| Reinstall | | | | | |
| Cross-device | | | | | |
