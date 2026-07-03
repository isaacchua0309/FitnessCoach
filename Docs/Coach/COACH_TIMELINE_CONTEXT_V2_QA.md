# Coach Timeline Context v2 — Manual QA Checklist

**Status:** Production QA (2026-07-03)  
**Schema version:** `CoachContextPacketV2.meta.schemaVersion == 2`  
**Related:** [COACH_TIMELINE_CONTEXT_V2_IMPLEMENTATION.md](./COACH_TIMELINE_CONTEXT_V2_IMPLEMENTATION.md)

---

## Before you start

### Prerequisites

| Requirement | Notes |
|-------------|-------|
| Build with Coach AI enabled | `aiCommandParsingEnabled = true` in `AppContainer` |
| Firebase backend reachable | Or use scenarios 4–5 to test offline/auth paths |
| Physical device recommended | Scenarios 26–30 (HealthKit) need a real iPhone |
| DEBUG build for tracing | `FormaPipelineTracer` events visible in Xcode console |
| Test account signed in | Firebase Auth session active |

### How to inspect logs

**iOS (Xcode console — filter by subsystem/category):**

| Category | What to look for |
|----------|------------------|
| `Forma` / `CoachContextPacketV2` | `CoachContextPacketV2 assembled` — `mode`, `timelineEvents`, `bytes`, `missingSignals` |
| `Forma` / `CoachTimelineBackfill` | Backfill success or `Coach timeline backfill failed` |
| `Forma` / `CoachTimelineRecorder` | `Coach timeline record failed` (should not appear in happy path) |
| `Forma` / `CoachContextCorrectnessValidator` | `CoachContextPacketV2 validation corrected issues` (warn only) |
| `FormaPipelineTracer` (DEBUG) | Stages: `.context`, `.coachSend`, `.classify`, `.httpRequest`, `.httpResponse`, `.error` |

**Redacted context fields on outbound AI requests:**

- `contextSchema` → `2`
- `timelineEvents` → count ≤ 20
- `context` → `redactedDebugDescription()` (no meal names or health values in release)

**Firebase (functions logs / emulator):**

- HTTP 400 with `Invalid context.meta.schemaVersion` → client sent wrong schema
- Successful requests should carry `context.meta.schemaVersion: 2`
- Malformed context returns safe error string (no stack trace to client)

### Pass / fail convention

| Result | Meaning |
|--------|---------|
| **PASS** | Expected result observed; no failure signals |
| **FAIL** | Any failure signal present |
| **BLOCKED** | Environment cannot run scenario (note reason) |

Record device model, iOS version, app build, and timezone for scenarios 35 and cross-screen checks.

---

## Basic

### 1. Open Coach fresh install

**Steps**

1. Delete app (or reset simulator content and settings).
2. Complete onboarding and sign in.
3. Navigate to Coach tab for the first time.

**Expected result**

- Coach loads with empty state or starter chips; no crash.
- First context build succeeds with `missingData.noTimelineHistory = true` (no prior timeline).
- `generationMode` is `live` or `degraded` (if Health denied), never stuck loading.
- Backfill runs silently; no blocking spinner beyond normal Coach load.

**Failure signals**

- Crash on Coach open or SwiftData migration failure.
- Blank screen with no input composer.
- Error banner referencing schema or context build failure.
- Coach permanently disabled despite AI being enabled.

**Logs to inspect**

- `CoachContextPacketV2 assembled` — `missingSignals` includes `noTimelineHistory`
- `Coach timeline backfill failed` (should not appear on fresh install with no logs)
- `FormaModelMigration` errors (if any)

---

### 2. Send greeting

**Steps**

1. Open Coach on a signed-in account.
2. Type `Hi` or tap a greeting starter chip.
3. Send the message.

**Expected result**

- User message appears in transcript immediately.
- Assistant replies with a greeting (no food logged, no pending confirmation).
- Timeline records `userMessage` and `assistantMessage` (best-effort).
- No pending confirmation bar.

**Failure signals**

- Message stuck in sending state indefinitely.
- Assistant claims food/water/weight was logged.
- Duplicate user messages in transcript.
- HTTP 400 on gateway (context validation failure).

**Logs to inspect**

- `FormaPipelineTracer` — `.coachSend` trace start/end
- `CoachContextPacketV2 assembled` — `chatMessages` ≥ 1 after send
- `.httpResponse` — status 200, not 400
- No `Coach timeline record failed` for `userMessage`

---

### 3. Ask "how am I doing today?"

**Steps**

1. Ensure at least one of: food logged today, water logged today, or Health connected.
2. Send: `How am I doing today?` or `Give me a status update`.

**Expected result**

- Response references **structured** today data (calories, protein, water, steps) from `context.today`, not invented values.
- Numbers align with Today tab within reasonable tolerance (±5 kcal).
- If Health denied, Coach states data is unavailable — does not claim zero steps/workouts.
- No mutation or pending confirmation triggered.

**Failure signals**

- Calorie/protein numbers disagree with Today tab by more than 5 kcal.
- Coach invents meals not in `recentMealsStructured` or timeline.
- Coach claims workouts when `missingData.workoutPermissionDeniedOrUnavailable` is true.
- Status command logs food or shows confirmation bar.

**Logs to inspect**

- `CoachContextPacketV2 assembled` — `today` section populated; check `missingSignals`
- `generationMode` — `live` or `degraded` (not invalid)
- Route: local status path or classify → status; no spurious `foodLogged` timeline event

---

### 4. Backend unavailable

**Steps**

1. Disable network (Airplane mode) or point app at unreachable backend (DEBUG config if available).
2. Send any AI-routed message, e.g. `Log 2 eggs and toast`.

**Expected result**

- User message appears in transcript.
- Assistant shows backend-unavailable copy (recoverable, not a crash).
- Timeline records `backendError` with retryable category.
- Local-only commands (if testable without network) still work where supported.
- User can retry after restoring network.

**Failure signals**

- App crash or unhandled exception.
- Infinite loading spinner with no timeout message.
- Silent failure (no assistant response at all).
- Food/water committed without user confirmation.

**Logs to inspect**

- `FormaPipelineTracer` — `.error` stage, `backendUnavailable` or network error
- `Coach timeline record` — `backendError` event type
- No successful `.httpResponse` 200 while offline

---

### 5. Auth expired

**Steps**

1. Sign in, open Coach, send a message successfully.
2. Invalidate Firebase Auth session (sign out on another device, revoke token, or wait for expiry in test environment).
3. Send another AI-routed message.

**Expected result**

- Session failure UI appears (`presentCoachSessionFailure`) with retry/sign-in affordance.
- Timeline records `authError`.
- No silent success with stale or empty AI response.
- Previously logged data on Today tab unchanged.

**Failure signals**

- Generic network error instead of auth-specific handling.
- Crash on 401/403 response.
- Coach continues sending requests without valid token indefinitely.
- User data deleted or corrupted.

**Logs to inspect**

- `FormaPipelineTracer` — `Coach session authentication failed`, `traceOutcome=authFailed`
- `FormaAIBackendClient` — `.authToken` stage failure
- Timeline `authError` event recorded
- HTTP response 401/403 on gateway

---

## Food

### 6. Log simple food

**Steps**

1. Send: `Log a banana` (or tap equivalent example).
2. Wait for food estimate and pending confirmation bar.
3. Tap **Confirm** on the confirmation bar.

**Expected result**

- Pending confirmation bar shows banana estimate with macros.
- After confirm: assistant confirms log; Today tab shows banana entry.
- Timeline: `foodEstimateCreated` (pending) → `pendingConfirmationCreated` → `pendingConfirmationConfirmed` → `foodLogged` (confirmed).
- `context.today.nutrition.caloriesConsumed` increases on next message.

**Failure signals**

- Food committed without confirmation.
- Today tab empty after confirm.
- Duplicate banana entries after single confirm.
- Coach says food logged before user confirms.

**Logs to inspect**

- `CoachContextPacketV2 assembled` after confirm — `timelineEvents` includes `foodLogged` with `status: confirmed`
- `CoachContextCorrectnessValidator` — no `caloriesMatchConfirmedFood` issue after refresh
- `FormaPipelineTracer` — mutation success after `executePendingConfirmation`

---

### 7. Log compound food

**Steps**

1. Send: `Log chicken rice bowl with egg and vegetables` (multi-component meal).
2. Review estimate card (multiple components if shown).
3. Confirm.

**Expected result**

- Estimate shows compound meal with reasonable total macros.
- Single food entry (or multi-component entry per app design) committed on confirm.
- Timeline `foodLogged` payload reflects meal name and macro totals.
- Today totals update correctly.

**Failure signals**

- Estimate missing components with no sanity warning.
- Macros clearly implausible (e.g. 50,000 kcal) without warning.
- Confirm logs wrong meal name or zero macros.
- Crash on multi-component formatter.

**Logs to inspect**

- `foodEstimateCreated` payload — `componentCount` if applicable
- `CoachContextPacketV2` — `recentMealsStructured` after confirm includes compound name
- Validator — `macrosNonNegative`, `caloriesMatchConfirmedFood`

---

### 8. Reject food estimate

**Steps**

1. Send a food log command, e.g. `Log oatmeal`.
2. When pending confirmation appears, tap **Reject** (or type `cancel` / `no`).

**Expected result**

- Pending bar dismisses; assistant acknowledges rejection.
- **No** food entry on Today tab.
- Timeline: `foodRejected`, `pendingConfirmationRejected`; no `foodLogged`.
- Next context build: rejected estimate **not** in `timeline.recentEvents` for AI facts.

**Failure signals**

- Food appears on Today despite reject.
- Coach later refers to oatmeal as logged.
- `foodLogged` timeline event with `confirmed` status after reject.
- Calories consumed increases.

**Logs to inspect**

- Timeline events — `foodRejected` + `pendingConfirmationRejected`, no `foodLogged`
- `CoachContextPacketV2TimelineSelector` — rejected excluded from context
- Today food query — empty for oatmeal

---

### 9. Edit food estimate

**Steps**

1. Send food log command and receive estimate.
2. Before confirming, edit quantity/name/macros on the confirmation draft (if UI supports pre-confirm edit).
3. Confirm edited estimate.

**Expected result**

- Committed entry matches edited values, not original estimate.
- Timeline `foodLogged` reflects edited macros; `userEditedBeforeConfirm` flagged if applicable.
- Today totals match edited entry.

**Failure signals**

- Original (pre-edit) values committed.
- Edit lost on confirm tap.
- Two entries created (original + edited).

**Logs to inspect**

- `foodLogged` payload — calories/macros match edited draft
- `FoodLogService` entry fields after confirm
- No duplicate `linkedEntryId` events within 60s tolerance

---

### 10. Confirm food estimate

**Steps**

1. Send: `Log greek yogurt`.
2. Confirm via confirmation bar (not typed confirm word).

**Expected result**

- Same as scenario 6 — explicit confirm-via-bar path.
- `pendingConfirmationConfirmed` with `userInputMethod` indicating bar tap.
- Entry visible on Today immediately after confirm.

**Failure signals**

- Bar tap ignored; no mutation.
- Double entry on single tap.
- Assistant message says logged but Today empty.

**Logs to inspect**

- `recordPendingConfirmationConfirmed` — `userInputMethod` populated
- `FitnessActionCenter.logFood` success path
- App refresh / `notifyDataChanged` fired

---

### 11. Ask "what did I eat earlier?"

**Steps**

1. Log and confirm at least one meal earlier in the session (or use backfilled history from prior day).
2. Send: `What did I eat earlier?` or `What did I have for lunch?`

**Expected result**

- Assistant lists confirmed meals from `recentMealsStructured` and/or confirmed `foodLogged` timeline events.
- Does **not** cite rejected or pending estimates.
- Meal names and approximate macros match Today / timeline.

**Failure signals**

- Coach cites rejected or pending meals as eaten.
- Coach invents meals not in structured context.
- Coach says "I don't know" when confirmed meals exist in context.

**Logs to inspect**

- `CoachContextPacketV2 assembled` — `recentMealsStructured` count ≥ 1
- `timeline.recentEvents` — confirmed `foodLogged` entries present
- Gateway prompt receives `schemaVersion: 2` with meal data

---

### 12. Ask "how much protein from lunch?"

**Steps**

1. Log and confirm a lunch with known protein (e.g. chicken breast ~30g protein).
2. Send: `How much protein did I get from lunch?`

**Expected result**

- Response cites protein from confirmed lunch entry (structured data).
- Number aligns with logged entry ±1g.
- Does not sum rejected/pending estimates.

**Failure signals**

- Wrong protein value vs Today entry.
- Coach guesses without referencing logged lunch.
- Includes protein from unconfirmed estimate.

**Logs to inspect**

- `recentMealsStructured` — lunch entry with `proteinGrams`
- `today.nutrition.proteinConsumed` aggregate
- No pending `foodEstimateCreated` in eligible timeline events

---

### 13. Delete a meal

**Steps**

1. Log and confirm a meal.
2. Send: `Delete the [meal name]` or use Coach delete flow with confirmation.
3. Confirm deletion on pending bar.

**Expected result**

- Meal removed from Today tab.
- Prior `foodLogged` timeline event marked `superseded`.
- New `foodDeleted` event with `supersedesEventId` pointing to prior event.
- Calories/protein on Today decrease accordingly.
- Coach no longer cites deleted meal as eaten.

**Failure signals**

- Meal still on Today after confirmed delete.
- Superseded `foodLogged` still appears in AI context as active.
- Wrong meal deleted.
- Totals unchanged after delete.

**Logs to inspect**

- `store.supersedeEvent` — prior event `status: superseded`
- `foodDeleted` event appended
- `CoachContextPacketV2` — deleted meal absent from `recentMealsStructured`
- Validator — `caloriesMatchConfirmedFood` passes after delete

---

### 14. Edit a meal

**Steps**

1. Log and confirm a meal.
2. Send: `Edit [meal] to [new calories/name]` or equivalent edit command.
3. Confirm edit on pending bar.

**Expected result**

- Entry updated on Today tab (same `linkedEntryId` or new entry per app policy).
- Prior `foodLogged` superseded; `foodEdited` event recorded.
- Coach cites updated values on follow-up question.

**Failure signals**

- Duplicate entries (old + new) both counting toward totals.
- Edit not applied; old values remain.
- Superseded entry still counted in context totals.

**Logs to inspect**

- `recordFoodEdited` with `supersedesEventId`
- `FoodLogService` entry updated fields
- Timeline selector excludes superseded `foodLogged`

---

### 15. Try double confirm

**Steps**

1. Send food log command; receive pending confirmation.
2. Tap **Confirm** rapidly twice, or confirm via bar then immediately type `yes` / `confirm`.

**Expected result**

- Exactly **one** food entry created on Today.
- Single `foodLogged` timeline event (deduped pending confirmation keys).
- No duplicate macros in daily totals.

**Failure signals**

- Two identical entries on Today.
- Duplicate `foodLogged` events with same `linkedEntryId`.
- Calories double-counted.

**Logs to inspect**

- `pendingConfirmationDedupeKey` — same key not recorded twice
- `FoodLogService.getFoodEntries` — single matching entry
- `recordedTimelinePendingConfirmationKeys` dedupe in `CoachModel`

---

## Water

### 16. Add 500ml water

**Steps**

1. Send: `Log 500ml water` or `Add 500 ml of water`.
2. Confirm if pending bar appears (water may auto-log depending on route).

**Expected result**

- Today hydration increases by 500 ml.
- Timeline `waterLogged` with `amountMl: 500`, `status: confirmed`.
- Coach confirms water logged in assistant message.

**Failure signals**

- Water not on Today tab.
- Wrong amount (e.g. 5000 ml).
- No timeline event recorded.

**Logs to inspect**

- `waterLogged` payload — `amountMl: 500`
- `today.hydration.waterConsumedMl` in next context packet
- `WaterLogService` entry count

---

### 17. Add 1.5L water

**Steps**

1. Send: `Log 1.5 liters of water` or `1500ml water`.
2. Complete confirmation if required.

**Expected result**

- 1500 ml added to Today hydration (cumulative with scenario 16 if same session).
- Parser normalizes liters to ml correctly.
- Timeline event reflects 1500 ml.

**Failure signals**

- Logged as 1.5 ml instead of 1500 ml.
- Parse failure with no user feedback.
- Integer overflow or negative water in context.

**Logs to inspect**

- `waterLogged` — `amountMl: 1500`
- Validator — `waterNonNegative`
- `today.hydration.waterRemainingMl` consistent with targets

---

### 18. Ask water remaining

**Steps**

1. After logging water (scenarios 16–17), send: `How much water do I have left today?`

**Expected result**

- Response uses `today.hydration.waterRemainingMl` and/or targets from structured context.
- Number matches Today tab water remaining.
- If no target set, Coach states what is known without inventing a goal.

**Failure signals**

- Remaining water disagrees with Today tab.
- Coach invents water intake not logged.
- Negative remaining without explanation.

**Logs to inspect**

- `today.hydration` — `waterConsumedMl`, `waterRemainingMl`
- `today.targets.waterTargetMl`
- `missingData` — no false `stepsMissing`-style flags for water

---

## Weight

### 19. Log weight

**Steps**

1. Send: `Log weight 72.5 kg` (adjust to plausible value).
2. Confirm if pending bar shown.

**Expected result**

- Weight entry saved (same-day upsert policy).
- Timeline `weightLogged` with `weightKg: 72.5`.
- `today.weight.weightKg` populated in next context build.
- Plan/Journey may reflect latest weight on next load.

**Failure signals**

- Weight not persisted across relaunch.
- Wrong unit conversion (lbs vs kg).
- Multiple conflicting entries for same day without upsert.

**Logs to inspect**

- `weightLogged` payload — `weightKg`
- `WeightLogService` same-day query
- `today.weight` in context packet

---

### 20. Ask latest weight

**Steps**

1. After logging weight (scenario 19), send: `What's my latest weight?`

**Expected result**

- Coach cites weight from `today.weight` or confirmed `weightLogged` timeline event.
- Matches Today / weight log within 0.1 kg.
- Does not cite chat prose over structured data.

**Failure signals**

- Wrong weight vs logged value.
- Coach says weight unknown when entry exists.
- Coach cites outdated pre-edit weight after new log.

**Logs to inspect**

- `today.weight.weightKg` in assembled context
- Timeline `weightLogged` confirmed event
- `missingData.weightMissing` — false when entry exists

---

## Photo

### 21. Upload clear meal photo

**Steps**

1. Attach a clear photo of a single recognizable meal (e.g. plate of pasta).
2. Send without extra text, or with short caption `Log this`.
3. Wait for analysis to complete.

**Expected result**

- Photo appears in user message; analysis assistant message follows.
- Timeline: `photoAttached` → `photoAnalysisStarted` → `photoAnalysisCompleted`.
- `AIMealImageAnalysisRequest` includes `CoachContextPacketV2` (`schemaVersion: 2`).
- Pending food confirmation shown; food **not** logged until user confirms.
- Estimate reasonable for visible food.

**Failure signals**

- Analysis runs without context (gateway missing `context.meta.schemaVersion`).
- Food auto-logged without confirmation.
- Raw image bytes in timeline payload JSON.
- Crash on image upload.

**Logs to inspect**

- `recordPhotoAttached` / `recordPhotoAnalysisCompleted`
- `CoachMealImageAIRequestBuilder.buildAnalysisRequest` — context attached
- `FormaPipelineTracer` — image analysis trace
- Gateway `analyze-meal-image` — context v2 in request body

---

### 22. Upload ambiguous meal photo

**Steps**

1. Attach a blurry, partial, or empty plate photo.
2. Send to Coach.

**Expected result**

- Analysis completes with low-confidence estimate **or** clarifying question.
- If clarification: `clarificationAsked` timeline event; no food logged.
- `needsUserReview` behavior — pending confirmation still required for any estimate.
- No fabricated high-confidence macros for invisible food.

**Failure signals**

- Specific meal named with high confidence when image is ambiguous.
- Crash or hung analysis with no timeout/retry UI.
- Food logged without user review.

**Logs to inspect**

- `clarificationAsked` or `photoAnalysisCompleted` with low confidence
- `analyzeMealImagePromptRules` — clarifying question path
- No `foodLogged` until explicit confirm

---

### 23. Answer clarification

**Steps**

1. Trigger clarification flow (scenario 22).
2. When Coach asks clarifying question, reply with specific answer (e.g. `It's chicken salad with ranch`).
3. Wait for re-analysis.

**Expected result**

- `clarificationAnswered` recorded with session link.
- Re-analysis uses answer + prior context; new estimate or follow-up question.
- Photo session ID consistent across clarification events (`link.linkedPhotoSessionId`).
- Still requires confirmation before logging.

**Failure signals**

- Clarification answer ignored; same question repeated indefinitely.
- Session ID mismatch between clarification events.
- Food logged without second confirmation step.

**Logs to inspect**

- `clarificationAsked` / `clarificationAnswered` pair with same `sessionId`
- `ImageAnalysisSessionStore` session state
- Second `photoAnalysisStarted` / `photoAnalysisCompleted` cycle

---

### 24. Confirm photo estimate

**Steps**

1. Complete photo analysis (scenario 21) to pending confirmation.
2. Tap **Confirm** on food estimate from photo.

**Expected result**

- Food entry on Today matching photo analysis estimate.
- `foodLogged` linked to photo session where applicable.
- Timeline shows full pipeline: photo events → estimate → confirm → `foodLogged`.
- Coach does not re-analyze photo after confirm.

**Failure signals**

- Today empty after confirm.
- Macros differ significantly from shown estimate card.
- `photoAnalysisCompleted` treated as logged without `foodLogged`.

**Logs to inspect**

- `pendingConfirmationConfirmed` → `foodLogged`
- `FoodLoggedPayload` — `source` indicates photo/meal image path
- `linkedPhotoSessionId` on confirmation payload

---

### 25. Retry failed photo

**Steps**

1. Force analysis failure (airplane mode during upload, or invalid backend in DEBUG).
2. Observe failure message with retry affordance.
3. Restore network; tap **Retry**.

**Expected result**

- `photoAnalysisFailed` recorded with `isRetryable: true`.
- Retry creates new attempt; `PhotoPayload.isRetry: true` on retry event.
- Successful retry produces estimate and pending confirmation.
- Failed attempt not counted as logged food.

**Failure signals**

- No retry button on recoverable failure.
- Retry loops infinitely without backoff message.
- Failed analysis leaves orphan pending confirmation.
- Coach cites failed analysis as consumed meal.

**Logs to inspect**

- `photoAnalysisFailed` — `category`, `isRetryable`
- Retry trace — new `photoAnalysisStarted` with higher `attemptNumber`
- `photoAnalysisFailed` excluded from AI context facts

---

## Health

### 26. Apple Health connected with steps

**Steps**

1. On physical device, grant HealthKit read for steps.
2. Ensure steps > 0 today in Health app.
3. Open Coach; send: `How many steps do I have today?`

**Expected result**

- Coach reports step count matching Health app (±small sync delay).
- `today.steps` has `source: healthKit`, numeric value — not missing.
- `missingData.stepsMissing` and `stepsUnavailable` are **false**.
- Timeline may include `stepsUpdated` event.

**Failure signals**

- Coach says steps unavailable when Health shows steps.
- Coach reports 0 when Health shows thousands (confused with denied).
- `stepsMissing: true` while value present in packet.

**Logs to inspect**

- `today.steps` — `value`, `source: healthKit`
- `missingData.stepsMissing` / `stepsUnavailable`
- `recordStepsUpdated` if timeline side-effect fired

---

### 27. Apple Health connected with workout

**Steps**

1. Grant HealthKit workout read access.
2. Ensure at least one workout logged today in Apple Health.
3. Send: `Did I work out today?` or open Coach after workout sync.

**Expected result**

- `training.workoutsToday` ≥ 1; workout summary in `training.workouts`.
- Coach acknowledges workout without asking user to log it in Coach.
- Timeline `workoutDetected` with `workoutCount` ≥ 1.
- Workout is read-only — no Coach mutation to log workout.

**Failure signals**

- `workoutsToday: nil` when workouts exist in Health.
- Coach offers to log workout via Coach (unsupported mutation).
- Wrong workout count or duration vs Health app.

**Logs to inspect**

- `training.workoutsToday`, `training.workouts[]`
- `workoutDetected` timeline payload
- `missingData.workoutPermissionDeniedOrUnavailable` — false

---

### 28. Apple Health denied

**Steps**

1. Deny HealthKit permissions (or revoke in Settings → Privacy → Health).
2. Open Coach; send: `How many steps today?` and `Did I work out?`

**Expected result**

- Coach states Health data unavailable or permission denied.
- `missingData.healthKitDenied` or `stepsUnavailable` / `workoutPermissionDeniedOrUnavailable` true.
- `training.workoutsToday` is **nil** (unknown), not `0`.
- Coach does **not** claim zero steps as fact.

**Failure signals**

- Coach reports `0 steps` as confirmed fact.
- `workoutsToday: 0` when permission denied (should be nil).
- Coach gives specific workout advice based on invented activity.

**Logs to inspect**

- `generationMode: degraded` likely
- `missingData.healthKitDenied`, `stepsUnavailable`
- `healthDataUnavailable` timeline event may be recorded
- `training.workoutsToday` — nil vs 0 distinction

---

### 29. No HealthKit on simulator

**Steps**

1. Run app on iOS Simulator (no real HealthKit data).
2. Open Coach; ask about steps and workouts.

**Expected result**

- Graceful unavailable messaging; no crash.
- `missingData.healthKitUnavailable` or related flags set.
- Coach still functional for food/water/weight logging.
- `generationMode` may be `degraded`; context still sent.

**Failure signals**

- Crash on HealthKit query.
- Infinite spinner waiting for Health data.
- Simulator-specific assertion failure in DEBUG.

**Logs to inspect**

- `healthUnavailable` flags in context assembly
- `HealthKitOptionalAccessPolicy` handling — no thrown crash
- `CoachContextPacketV2 assembled` — `mode: degraded` acceptable

---

### 30. Ask post-workout meal advice

**Steps**

1. With workout in Health (scenario 27), log partial nutrition today (below protein target).
2. Send: `What should I eat after my workout?` or tap meal advice chip.

**Expected result**

- Advice uses `training`, `healthIntelligence`, `today` remaining protein/calories.
- Mentions post-workout protein/hydration practically.
- Does not claim foods already eaten unless in `recentMealsStructured`.
- References workout detected today.

**Failure signals**

- Generic advice ignoring workout and remaining macros.
- Advice based on rejected/pending meals.
- Claims user worked out when `workoutsToday` nil/denied.

**Logs to inspect**

- Route to meal-advice endpoint with full v2 context
- `training.workoutsToday` ≥ 1, `today.nutrition.proteinRemaining`
- `healthIntelligence` section if HI enabled
- `mealAdvicePromptRules` context in gateway logs

---

## Timeline

### 31. Relaunch app and verify chat persists

**Steps**

1. Send several messages in Coach (user + assistant).
2. Force-quit app (swipe away from app switcher).
3. Relaunch app; open Coach tab.

**Expected result**

- Prior chat transcript visible (SwiftData `CoachChatTranscriptStore`).
- Messages in correct order with timestamps.
- No duplicate messages on reload.
- Image messages show thumbnail if photo was sent (per transcript persistence).

**Failure signals**

- Empty transcript after relaunch (session-only memory regression).
- Crash loading transcript entities.
- Duplicate or corrupted message order.

**Logs to inspect**

- `SwiftDataCoachChatTranscriptStore` load on Coach open
- `CoachChatTranscriptPersistenceRepository` — no decode errors
- Timeline `userMessage` / `assistantMessage` counts may be lower than UI messages (audit only)

---

### 32. Relaunch app and ask about earlier logged meal

**Steps**

1. Log and confirm a distinctive meal (e.g. `salmon bowl`).
2. Force-quit and relaunch app.
3. Send: `What did I eat earlier today?`

**Expected result**

- Coach cites salmon bowl from backfilled `foodLogged` timeline + `recentMealsStructured`.
- Today tab still shows meal (SSOT in SwiftData logs).
- Backfill hydrates timeline on first context build after relaunch (within 60s throttle).

**Failure signals**

- Coach says no meals logged when Today shows meal.
- `noTimelineHistory` true when logs exist after relaunch.
- Backfill duplicate entries causing inflated timeline counts.

**Logs to inspect**

- `CoachTimelineBackfillService.runBackfill` on first `makeContext`
- `foodLogged` events with `sourceAttribution: systemBackfill`
- `recentMealsStructured` includes salmon bowl
- Deduplicator — no duplicate `linkedEntryId` within tolerance

---

### 33. Confirm rejected estimate is not counted

**Steps**

1. Log food estimate; **reject** it (scenario 8).
2. Send: `How many calories have I eaten today?`

**Expected result**

- Calorie total **excludes** rejected estimate.
- `timeline.recentEvents` has no eligible `foodEstimateCreated` or `foodRejected` as facts.
- Coach does not mention rejected food as consumed.

**Failure signals**

- Calories include rejected estimate macros.
- Coach says rejected meal was eaten.
- `foodRejected` with wrong status in AI context.

**Logs to inspect**

- `today.nutrition.caloriesConsumed` vs sum of confirmed food only
- `CoachContextCorrectnessValidator` — `pendingRejectedNotInTotals`
- Timeline selector — `foodRejected` excluded from `isContextEligible`

---

### 34. Confirm pending estimate is not counted

**Steps**

1. Log food estimate but do **not** confirm (leave pending bar open or dismiss without confirm/reject if possible).
2. Send: `What's my calorie total today?`

**Expected result**

- Calories consumed reflect **confirmed** food only; pending estimate excluded.
- Only `pendingConfirmationCreated` may appear in timeline context (as pending, not logged).
- Coach says food is awaiting confirmation if asked about that specific meal.

**Failure signals**

- Pending estimate macros added to Today totals.
- Coach says pending meal is already logged.
- `foodEstimateCreated` treated as confirmed in response.

**Logs to inspect**

- `today.nutrition.caloriesConsumed` — unchanged by pending estimate
- Eligible timeline — only `pendingConfirmationCreated` for pending bar, not `foodLogged`
- `FoodLogService` — no entry for pending meal

---

### 35. Verify same-day localDate near midnight

**Steps**

1. Set device timezone to a known zone (e.g. `America/Los_Angeles`).
2. At **11:45 PM** local, log and confirm a meal.
3. At **12:05 AM** local (next calendar day), send: `What did I eat today?`

**Expected result**

- Meal logged at 11:45 PM has `localDate` of previous day on timeline event.
- After midnight, "today" refers to new `meta.localDate`; yesterday's meal in `recentMealsStructured` or cross-day timeline if sparse today.
- Coach does not attribute yesterday's meal to new day totals.
- `CoachTimelineEvent.localDate` uses device timezone, not UTC rollover.

**Failure signals**

- 11:45 PM meal counted in new day calories.
- `localDate` off-by-one vs wall clock.
- Timeline query misses meal due to UTC/local mismatch.

**Logs to inspect**

- Logged event `localDate` — e.g. `2026-07-03` at 11:45 PM
- `meta.localDate` after midnight — `2026-07-04`
- `CoachContextPacketV2Builder` — `todayLocalDate` from `CoachContextMeta.make`
- Scenario covered by `CoachTimelineHardeningTests.testMidnightBoundaryUsesLocalDateNotUTC`

---

## Cross-screen

### 36. Log food in Coach and verify Today

**Steps**

1. Note Today tab calories before test.
2. In Coach, log and confirm a known-calorie food (e.g. 200 kcal snack).
3. Switch to Today tab without manual refresh button (if removed).

**Expected result**

- Today shows new food entry and increased calories (+200 ±5).
- Entry appears in food list with correct name and macros.
- Coach and Today share same SwiftData SSOT.

**Failure signals**

- Today unchanged after Coach confirm.
- Calories differ between Coach status and Today.
- Entry appears in Coach context but not Today UI.

**Logs to inspect**

- `AppRefreshCenter.notifyDataChanged` after mutation
- `DailyLogService.getTodayLog()` matches UI
- No second conflicting write path bypassing `FitnessActionCenter`

---

### 37. Log water in Coach and verify Today

**Steps**

1. Note Today hydration before test.
2. Log 250 ml water in Coach; confirm.
3. Switch to Today tab.

**Expected result**

- Today hydration increases by 250 ml.
- Water progress ring/bar updates.
- Consistent with `today.hydration` in Coach context.

**Failure signals**

- Water not on Today.
- Wrong volume displayed.
- Delay > few seconds without eventual consistency.

**Logs to inspect**

- `WaterLogService` entry persisted
- Today view model refresh on data change notification
- `waterLogged` timeline event

---

### 38. Log weight in Coach and verify Plan/Journey if applicable

**Steps**

1. Log weight in Coach (scenario 19).
2. Navigate to Plan and/or Journey tabs.

**Expected result**

- Latest weight reflected where app surfaces current weight (profile, journey, plan edit).
- Same `weightKg` as Coach and Today weight section.
- No stale weight from previous session.

**Failure signals**

- Plan/Journey shows old weight indefinitely.
- Different weight on Plan vs Coach.
- Crash on weight-dependent views.

**Logs to inspect**

- `WeightLogService` / `UserProfileReading` weight fields
- Journey/Plan data sources read same SwiftData entry
- `weightLogged` timeline audit event

---

### 39. Ask Coach after Today refresh

**Steps**

1. On Today tab, pull to refresh or trigger data refresh (if available).
2. Return to Coach; send: `How am I doing today?`

**Expected result**

- Coach status reflects post-refresh Today data (steps, workouts, nutrition).
- Context rebuild includes latest `dailyLog` and Health reads.
- No stale pre-refresh numbers in response.

**Failure signals**

- Coach cites outdated steps or calories after Today refresh.
- `systemRefresh` causes duplicate or conflicting timeline events in context.
- Crash on refresh → Coach navigation.

**Logs to inspect**

- Fresh `CoachContextPacketV2 assembled` after refresh
- `today` section matches post-refresh Today tab
- `generationMode` and `missingData` still valid

---

### 40. Ask Coach after Health refresh

**Steps**

1. Record a new workout or walk in Apple Health (or wait for sync).
2. Open Today to allow Health sync, then open Coach.
3. Send: `Did my workout sync?` or `How many steps now?`

**Expected result**

- Coach reflects updated steps/workouts from HealthKit read in context build.
- `training.workouts` or `today.steps` updated vs pre-workout state.
- Timeline may record new `workoutDetected` or `stepsUpdated`.

**Failure signals**

- Coach shows pre-sync Health data indefinitely.
- Health refresh causes `healthKitDenied` false positive.
- Steps/workouts double-counted in context.

**Logs to inspect**

- `HealthActivityQueryService` read on context build
- `workoutDetected` / `stepsUpdated` timeline updates
- `missingData` flags cleared when data available
- `healthIntelligence` snapshot refresh if HI enabled

---

## Sign-off sheet

| # | Scenario | Tester | Date | Device / iOS | Result | Notes |
|---|----------|--------|------|--------------|--------|-------|
| 1 | Fresh install | | | | | |
| 2 | Greeting | | | | | |
| 3 | Status today | | | | | |
| 4 | Backend unavailable | | | | | |
| 5 | Auth expired | | | | | |
| 6 | Simple food | | | | | |
| 7 | Compound food | | | | | |
| 8 | Reject food | | | | | |
| 9 | Edit estimate | | | | | |
| 10 | Confirm food | | | | | |
| 11 | What ate earlier | | | | | |
| 12 | Protein from lunch | | | | | |
| 13 | Delete meal | | | | | |
| 14 | Edit meal | | | | | |
| 15 | Double confirm | | | | | |
| 16 | 500ml water | | | | | |
| 17 | 1.5L water | | | | | |
| 18 | Water remaining | | | | | |
| 19 | Log weight | | | | | |
| 20 | Latest weight | | | | | |
| 21 | Clear photo | | | | | |
| 22 | Ambiguous photo | | | | | |
| 23 | Clarification | | | | | |
| 24 | Confirm photo | | | | | |
| 25 | Retry photo | | | | | |
| 26 | Health steps | | | | | |
| 27 | Health workout | | | | | |
| 28 | Health denied | | | | | |
| 29 | Simulator no HK | | | | | |
| 30 | Post-workout advice | | | | | |
| 31 | Chat persists | | | | | |
| 32 | Meal after relaunch | | | | | |
| 33 | Rejected not counted | | | | | |
| 34 | Pending not counted | | | | | |
| 35 | Midnight localDate | | | | | |
| 36 | Food → Today | | | | | |
| 37 | Water → Today | | | | | |
| 38 | Weight → Plan/Journey | | | | | |
| 39 | After Today refresh | | | | | |
| 40 | After Health refresh | | | | | |

**QA lead sign-off:** _______________ **Date:** _______________

---

*Last updated: 2026-07-03. Pair with [COACH_TIMELINE_CONTEXT_V2_IMPLEMENTATION.md](./COACH_TIMELINE_CONTEXT_V2_IMPLEMENTATION.md) for architecture and debugging context.*
