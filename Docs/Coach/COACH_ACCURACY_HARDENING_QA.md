# Coach Accuracy Hardening Sprint — Manual QA Checklist

**Status:** Manual QA (2026-07-04)  
**Audience:** QA, release engineering, engineers validating the accuracy hardening sprint  
**Schema version:** `CoachContextPacketV2.meta.schemaVersion == 2`

**Trust Hardening v1 supplement:** [COACH_ACCURACY_TRUST_HARDENING_V1_FINAL_REPORT.md](./COACH_ACCURACY_TRUST_HARDENING_V1_FINAL_REPORT.md) — trust contract, 13-flow regression matrix, photo/text range behavior.

**Related docs:**
- [COACH_TIMELINE_CONTEXT_V2_QA.md](./COACH_TIMELINE_CONTEXT_V2_QA.md) — baseline timeline/context matrix (scenarios 1–40)
- [COACH_CONTEXT_PACKET_V2.md](./COACH_CONTEXT_PACKET_V2.md) — packet contract
- [COACH_TIMELINE_V2_MIGRATION.md](./COACH_TIMELINE_V2_MIGRATION.md) — SwiftData migration notes
- [COACH_FULL_CONTEXT_PACKET.md](./COACH_FULL_CONTEXT_PACKET.md) — full field reference
- [BackendAPI.md](../BackendAPI.md) — gateway paths

---

## Before you start

### Prerequisites

| Requirement | Notes |
|-------------|-------|
| Coach AI enabled | `aiCommandParsingEnabled = true` in `AppContainer` |
| Signed-in Firebase user | Required for backend paths unless testing auth failure |
| Physical device (recommended) | HealthKit, camera, and photo library scenarios |
| DEBUG build for deep tracing | `FormaPipelineTracer`, food/image debug loggers |
| Release build for privacy QA | Section 11 requires a **Release** or non-DEBUG configuration |
| Backend reachable | Firebase `aiGateway` or emulator; note when testing offline paths |
| Timezone noted | Record `timezoneIdentifier` for date-boundary cases |

### Flag matrix (sprint-specific)

| Flag | Env key | Production default | Recommended QA override |
|------|---------|-------------------|-------------------------|
| HI foundation | `FORMA_HEALTH_INTELLIGENCE_ENABLED` | `1` | Case-specific |
| HI engines | `FORMA_HEALTH_INTELLIGENCE_ENGINES_ENABLED` | `1` | Case-specific |
| HI UI | `FORMA_HEALTH_INTELLIGENCE_UI_ENABLED` | `0` | `1` when testing Today HI cards |
| **HI Coach context** | `FORMA_HEALTH_INTELLIGENCE_COACH_CONTEXT_ENABLED` | `0` | `1` for HI-03…HI-06 |
| Pipeline trace (DEBUG) | `FORMA_PIPELINE_TRACE=1` | off | `1` for routing/endpoint cases |
| Food estimate debug (DEBUG) | `FORMA_FOOD_ESTIMATE_DEBUG=1` | off | `1` for compound cases |
| Backend auth required | `FORMA_AI_REQUIRE_AUTH` (functions) | on | `0` only in controlled emulator QA |

**Production default-on note:** HI **engines** and **sync** default on; HI **Coach context** defaults **off** until `FORMA_HEALTH_INTELLIGENCE_COACH_CONTEXT_ENABLED=1`. Section 1 validates both prod-default and enabled-context behavior.

### How to inspect logs

**Production-safe (Release or Debug):**

| Subsystem / category | Filter | Key fields |
|---------------------|--------|------------|
| `Forma` / `CoachAccuracy` | `CoachAccuracy` | `event=context_generated`, `route_selected`, `endpoint_called`, `mutation_executed`, `pending_confirmation_created` |
| Firebase Functions | `AI gateway` | `endpoint`, `contextSchemaVersion`, `contextSizeBucket`, `responseValidationSuccess`, `backendErrorCategory` |

**DEBUG-only (never expect in Release privacy QA):**

| Category | Use for |
|----------|---------|
| `Forma` / `PipelineTrace` | Stage flow: `.context`, `.classify`, `.routeDecision`, `.aiTask`, `.mealImageAnalysis` |
| `Forma` / `CoachFoodEstimate` | Component counts, sanity validation |
| `Forma` / `CoachImageAnalysis` | Photo bytes, parse success, error category |
| `Forma` / `CoachContextCorrectnessValidator` | Auto-correction warnings |

### Pass / fail convention

| Result | Meaning |
|--------|---------|
| **PASS** | All expected results; no failure signals |
| **FAIL** | Any failure signal |
| **BLOCKED** | Environment cannot run (document reason) |

### Test case field guide

Every case below includes:

- **Setup** — account, flags, prior logs, device state
- **Steps** — reproducible actions
- **Expected user-visible result** — transcript, cards, confirmation bars, Today tab
- **Expected timeline events** — `CoachTimelineEventType` sequence
- **Expected context packet fields** — v2 fields sent on next AI turn (or built locally)
- **Expected backend endpoint / local route** — gateway path or `chosenHandler`
- **Failure signals** — crashes, wrong mutations, PII in logs
- **Logs to inspect** — concrete categories and field names

---

## 1. Health Intelligence default-on QA

### HI-01. Production default — engines on, Coach HI context off

| Field | Details |
|-------|---------|
| **Setup** | Fresh install; **do not** set `FORMA_HEALTH_INTELLIGENCE_COACH_CONTEXT_ENABLED`. HealthKit authorized on device. |
| **Steps** | 1. Complete onboarding and open Coach.<br>2. Ask: `What should I eat after my workout today?`<br>3. Inspect outbound context (DEBUG context inspector or logs). |
| **Expected user-visible result** | Coach responds with general advice; may include missing-data disclaimer if HI not in context. No crash. Today HI UI cards may still be hidden (`UI` flag default off). |
| **Expected timeline events** | `userMessage`, `assistantMessage` only (no mutation). |
| **Expected context packet fields** | `meta.schemaVersion=2`, `generationMode=live` or `degraded`; **`healthIntelligence` absent**; `sourceAttribution.healthIntelligenceIncluded=false`; `missingData` may flag workouts/steps if Health denied. |
| **Expected backend endpoint / local route** | `POST /v1/ai/classify-coach-intent` → `POST /v1/ai/generate-meal-advice`; `routeSelected=strong_meal_advice` or `cheap_meal_advice`. |
| **Failure signals** | Crash; `healthIntelligence` populated when Coach context flag off; fabricated recovery metrics in copy without context support. |
| **Logs to inspect** | `CoachAccuracy`: `healthIntelligencePresent=false`; `classifierIntent=workout_advice` or `nutrition_advice`; Firebase: `contextHasHealthIntelligence=false`. |

### HI-02. Engines disabled — Coach degrades without HI

| Field | Details |
|-------|---------|
| **Setup** | Set `FORMA_HEALTH_INTELLIGENCE_ENABLED=0` or `FORMA_HEALTH_INTELLIGENCE_ENGINES_ENABLED=0`. |
| **Steps** | 1. Relaunch app.<br>2. Open Coach; send `How am I doing today?` |
| **Expected user-visible result** | Status-style reply without recovery/HRV-specific claims. Optional disclaimer that health sync is limited. |
| **Expected timeline events** | `userMessage`, `assistantMessage`. |
| **Expected context packet fields** | `healthIntelligence` absent; `missingData` flags populated (`steps`, `workouts`, etc. as applicable); `generationMode` may be `degraded`. |
| **Expected backend endpoint / local route** | Local `local_command` / `daily_summary` path OR classify → local status; **no** HI-specific gateway payload fields. |
| **Failure signals** | Coach claims HealthKit workout data when engines off; crash on Today/Coach load. |
| **Logs to inspect** | `CoachAccuracy`: `healthIntelligencePresent=false`, `missingDataFlagsCount` ≥ 1; no `coach_health_context_used` analytics (if enabled). |

### HI-03. Coach HI context enabled — post-workout advice uses HI fields

| Field | Details |
|-------|---------|
| **Setup** | Set `FORMA_HEALTH_INTELLIGENCE_COACH_CONTEXT_ENABLED=1` and engines on. Log a workout today (HealthKit or manual Today state). |
| **Steps** | 1. Open Coach.<br>2. Ask: `I just finished a run — what should I eat?`<br>3. Confirm advice references recovery/load tone (not raw HRV ms). |
| **Expected user-visible result** | Advice mentions training/recovery context appropriately; no raw medical numbers. |
| **Expected timeline events** | `userMessage`, `assistantMessage`. |
| **Expected context packet fields** | `healthIntelligence` present with `healthContextStatus`, `recoveryStatus`, `workoutCompletedToday`, `availableSignals[]`, `missingSignals[]`; `sourceAttribution.healthIntelligenceIncluded=true`. |
| **Expected backend endpoint / local route** | Classify → `generate-meal-advice`; `healthIntelligencePresent=true` in logs. |
| **Failure signals** | `healthIntelligence` missing with flag on and snapshot available; advice contradicts `missingData`. |
| **Logs to inspect** | `CoachAccuracy`: `healthIntelligencePresent=true`; DEBUG `contextSummary` includes `healthIntelligence` presence in redacted description only. |

### HI-04. HealthKit denied — degraded mode and honest disclaimers

| Field | Details |
|-------|---------|
| **Setup** | Deny HealthKit for Forma (Settings → Privacy → Health). Coach HI context flag optional. |
| **Steps** | 1. Open Coach.<br>2. Ask: `How many steps have I taken?` and `What should I eat after training?` |
| **Expected user-visible result** | Coach does not invent steps/workouts; copy explains limited health data when applicable. |
| **Expected timeline events** | `userMessage`, `assistantMessage`; possible `healthDataUnavailable` (system). |
| **Expected context packet fields** | `missingData.healthKitDenied=true` or `stepsUnavailable` / `workoutsUnavailable`; `today.steps` nil or absent; `generationMode=degraded`. |
| **Expected backend endpoint / local route** | Classify → advice or local status; no fabricated HealthKit values in request JSON. |
| **Failure signals** | Specific step counts matching old cached data presented as live HealthKit; no missing flags. |
| **Logs to inspect** | `missingDataFlagsCount` ≥ 1; labels include `steps` or `healthKitDenied` in DEBUG `contextSummary`. |

### HI-05. HI UI off, engines on — internal refresh without Coach packet bloat

| Field | Details |
|-------|---------|
| **Setup** | `FORMA_HEALTH_INTELLIGENCE_UI_ENABLED=0`, engines `=1`, Coach context `=0`. |
| **Steps** | 1. Open Today tab (HI cards hidden).<br>2. Open Coach and send a message requiring context build. |
| **Expected user-visible result** | Today loads without HI cards; Coach functions normally. |
| **Expected timeline events** | Normal message events only. |
| **Expected context packet fields** | `healthIntelligence` omitted; packet size remains under 24 KB. |
| **Expected backend endpoint / local route** | Any AI route; local context build only. |
| **Failure signals** | Today blocked on HI load failure; unexpected HI section in Coach context. |
| **Logs to inspect** | `CoachAccuracy`: `healthIntelligencePresent=false`; Today tab reaches loaded state. |

### HI-06. Stale HI snapshot — status fields not fabricated

| Field | Details |
|-------|---------|
| **Setup** | Coach HI context `=1`; simulate stale snapshot (>24h since sync) or airplane mode during HI refresh then reconnect. |
| **Steps** | 1. Open Coach after stale condition.<br>2. Ask for recovery-aware meal advice. |
| **Expected user-visible result** | Advice uses cautious language; may note limited freshness. No precise recovery score unless `healthContextStatus=available`. |
| **Expected timeline events** | `userMessage`, `assistantMessage`. |
| **Expected context packet fields** | `healthIntelligence.healthContextStatus` = `stale` or `partial`; `missingSignals` may include sleep/hrv. |
| **Expected backend endpoint / local route** | `generate-meal-advice` with partial HI object. |
| **Failure signals** | `healthContextStatus=available` with empty signals; crash on stale path. |
| **Logs to inspect** | HI analytics / snapshot load events; `healthIntelligencePresent=true` with degraded status in packet summary. |

---

## 2. Classifier advice-vs-log QA

### CL-01. Calorie lookup — advice only, no log

| Field | Details |
|-------|---------|
| **Setup** | Signed in; empty or non-conflicting food log today. |
| **Steps** | 1. Send: `How many calories in a banana?`<br>2. Do **not** confirm any pending bar. |
| **Expected user-visible result** | Nutrition estimate card or prose answer; **no** pending confirmation; Today calories unchanged. |
| **Expected timeline events** | `userMessage`, `assistantMessage` — **no** `foodLogged`, `pendingConfirmationCreated`. |
| **Expected context packet fields** | Next turn: `recentMealsStructured` unchanged; no new `foodLogged` in exported timeline. |
| **Expected backend endpoint / local route** | Classify → `nutrition_estimate_query` → `POST /v1/ai/generate-nutrition-estimate`; `routeSelected=cheap_nutrition_estimate`. |
| **Failure signals** | Pending confirmation appears; Today log increments; classifier returns `log_food`. |
| **Logs to inspect** | `classifierIntent=nutrition_estimate_query` or `calorie_lookup`; `requiresAPI=true`; no `pending_confirmation_created`. |

### CL-02. Explicit log — mutation path with confirmation

| Field | Details |
|-------|---------|
| **Setup** | Signed in; note starting calorie total on Today. |
| **Steps** | 1. Send: `Log 2 eggs for breakfast`.<br>2. Review estimate card; tap **Confirm**. |
| **Expected user-visible result** | Pending confirmation bar; after confirm, success copy and Today updates. |
| **Expected timeline events** | `foodEstimateCreated` → `pendingConfirmationCreated` → `pendingConfirmationConfirmed` → `foodLogged` (confirmed). |
| **Expected context packet fields** | After confirm: new meal in `recentMealsStructured` with `linkedEntryId`; timeline includes confirmed `foodLogged`. |
| **Expected backend endpoint / local route** | Classify → `log_food` → `POST /v1/ai/estimate-food`; `routeSelected=ai_estimate_food`; confirm → local mutation. |
| **Failure signals** | Auto-log without confirmation; wrong meal type; duplicate log on double tap. |
| **Logs to inspect** | `pending_confirmation_created` `pendingConfirmationKind=Food`; `mutation_executed` `mutationSuccess=true`. |

### CL-03. Nutrition comparison — no mutation

| Field | Details |
|-------|---------|
| **Setup** | None. |
| **Steps** | 1. Send: `Which has more protein: Greek yogurt or cottage cheese?` |
| **Expected user-visible result** | Comparison card or structured answer; no confirmation bar. |
| **Expected timeline events** | `userMessage`, `assistantMessage` only. |
| **Expected context packet fields** | Unchanged meal counts. |
| **Expected backend endpoint / local route** | `nutrition_comparison_query` → `POST /v1/ai/generate-nutrition-comparison`; `routeSelected=cheap_nutrition_comparison`. |
| **Failure signals** | Routes to `estimate-food`; attempts to log one item. |
| **Logs to inspect** | `classifierIntent=nutrition_comparison_query`; endpoint `generateNutritionComparison`. |

### CL-04. Meal advice — prose only

| Field | Details |
|-------|---------|
| **Setup** | Profile with calorie target set. |
| **Steps** | 1. Send: `Should I have pasta or rice for dinner tonight?` |
| **Expected user-visible result** | Conversational advice; no nutrition log card requiring confirm. |
| **Expected timeline events** | `userMessage`, `assistantMessage`. |
| **Expected context packet fields** | `currentUserMessage` set on active turn; `today.nutrition` reflects actual logs only. |
| **Expected backend endpoint / local route** | `meal_decision` or `nutrition_advice` → `POST /v1/ai/generate-meal-advice`; `routeSelected=strong_meal_advice` or `cheap_meal_advice`. |
| **Failure signals** | `log_food` intent; pending confirmation. |
| **Logs to inspect** | `classifierIntent=meal_decision` or `nutrition_advice`; no `mutation_executed`. |

### CL-05. Low-confidence mutation blocked

| Field | Details |
|-------|---------|
| **Setup** | Use ambiguous phrasing likely to yield medium/low classifier confidence (e.g. `maybe log something from lunch`). |
| **Steps** | 1. Send ambiguous log request.<br>2. Observe response. |
| **Expected user-visible result** | Clarification: *"I'm not fully sure what you want me to log…"* — **no** pending confirmation. |
| **Expected timeline events** | `userMessage`, `assistantMessage` only. |
| **Expected context packet fields** | No new pending entries in timeline export. |
| **Expected backend endpoint / local route** | Classify may succeed → `confidence_clarify` or gate blocks before `estimate-food`. |
| **Failure signals** | Pending confirmation on vague input; silent wrong log. |
| **Logs to inspect** | DEBUG: confidence gate `branch=medium_clarify` or `low_mutation_blocked`; `routeSelected=confidence_clarify`. |

### CL-06. Classifier transient failure — graceful fallback

| Field | Details |
|-------|---------|
| **Setup** | Simulate flaky network or backend 503 on **classify** only (proxy/throttle). |
| **Steps** | 1. Send: `Log 200ml water`.<br>2. Repeat once if first attempt fails. |
| **Expected user-visible result** | Either local water log **or** *"I'm having trouble understanding right now…"* — not a crash or blank screen. |
| **Expected timeline events** | Water path: `waterLogged` if parsed locally; else message events only. |
| **Expected context packet fields** | If water logged: hydration fields update on next context build. |
| **Expected backend endpoint / local route** | `classify_fallback` or `local_command` for simple water; `routeSource` reflects fallback. |
| **Failure signals** | Infinite spinner; unhandled error bubble; duplicate classify loops. |
| **Logs to inspect** | DEBUG: `Intent classification failed after retry`; `routeSelected=classify_fallback`. |

### CL-07. Duplicate classify within 8s — dedup message

| Field | Details |
|-------|---------|
| **Setup** | Slow network or large context (optional). |
| **Steps** | 1. Send a message requiring classification.<br>2. Immediately send a second message before first completes. |
| **Expected user-visible result** | Second reply: *"I am still working on your last request…"* or equivalent; no double mutation. |
| **Expected timeline events** | Two `userMessage`; one primary assistant path. |
| **Expected context packet fields** | No duplicate `foodLogged` from deduped turn. |
| **Expected backend endpoint / local route** | Second: `routeSelected=classify_dedup`; at most one classify HTTP call per dedup window. |
| **Failure signals** | Two parallel food logs; two estimate cards for one intent. |
| **Logs to inspect** | DEBUG stage `.classifyDedup`; `routeSelected=classify_dedup`. |

---

## 3. Compound food estimation QA

### CF-01. Local guard bypass — chicken rice routes to AI

| Field | Details |
|-------|---------|
| **Setup** | Signed in; `FORMA_FOOD_ESTIMATE_DEBUG=1` (DEBUG). |
| **Steps** | 1. Send: `Log chicken rice`.<br>2. Wait for estimate card. |
| **Expected user-visible result** | Multi-component estimate (rice + chicken + optional sides); confirmation required. |
| **Expected timeline events** | `foodEstimateCreated` → `pendingConfirmationCreated`. |
| **Expected context packet fields** | `commonFoods` may gain entry after confirm; pre-confirm timeline excludes rejected estimates. |
| **Expected backend endpoint / local route** | **Not** `local_food_estimate`; must be `ai_estimate_food` → `POST /v1/ai/estimate-food`. |
| **Failure signals** | Single-component catalog match; local guard used; obviously wrong total kcal. |
| **Logs to inspect** | `routeSelected=ai_estimate_food`; DEBUG `CoachFoodEstimate`: `parsedComponents` count ≥ 2. |

### CF-02. Explicit multi-ingredient sentence — components preserved

| Field | Details |
|-------|---------|
| **Setup** | None. |
| **Steps** | 1. Send: `Log chicken rice bowl with egg and vegetables`.<br>2. Inspect confirmation card components. |
| **Expected user-visible result** | ≥3 components listed; totals ≈ sum of components (±sanity tolerance). |
| **Expected timeline events** | Estimate + pending events. |
| **Expected context packet fields** | N/A until confirmed. |
| **Expected backend endpoint / local route** | `estimate-food` with strong/cheap tier based on text; validation repair if needed. |
| **Failure signals** | Collapsed to one line item; backend 422 without user-facing recovery. |
| **Logs to inspect** | Firebase: no raw food names in summary logs; DEBUG food estimate sanity fields. |

### CF-03. Simple catalog food — local estimate path

| Field | Details |
|-------|---------|
| **Setup** | None. |
| **Steps** | 1. Send: `Log 500g chicken breast`. |
| **Expected user-visible result** | Fast estimate; confirmation still shown per policy. |
| **Expected timeline events** | Pending → confirm → `foodLogged`. |
| **Expected context packet fields** | After confirm: meal with plausible macros in `recentMealsStructured`. |
| **Expected backend endpoint / local route** | `local_food_estimate` **or** cheap `estimate-food` — must **not** use blocked compound patterns. |
| **Failure signals** | Routes to comparison/advice; zero kcal entry. |
| **Logs to inspect** | `routeSelected=local_food_estimate` or `ai_estimate_food` with single component. |

### CF-04. Sanity warning on under-estimated totals

| Field | Details |
|-------|---------|
| **Setup** | Log a large compound meal (e.g. restaurant bowl). |
| **Steps** | 1. Send compound log request.<br>2. If sanity warning appears on card, read assistant footnote. |
| **Expected user-visible result** | Warning text when `NutritionSanityValidator` flags low totals; user can still confirm or edit. |
| **Expected timeline events** | Standard estimate flow. |
| **Expected context packet fields** | Assumptions may include estimation caveats after confirm. |
| **Expected backend endpoint / local route** | `estimate-food`. |
| **Failure signals** | Silent implausible totals (<200 kcal for full meal); crash on warning path. |
| **Logs to inspect** | DEBUG: `sanityValidation` field; `responseValidationSuccess=true` on success path. |

### CF-05. Reject compound estimate — no Today mutation

| Field | Details |
|-------|---------|
| **Setup** | Compound log request submitted. |
| **Steps** | 1. Tap **Reject** or dismiss confirmation without confirming. |
| **Expected user-visible result** | Confirmation bar clears; Today unchanged. |
| **Expected timeline events** | `pendingConfirmationRejected` or `foodRejected`; **no** confirmed `foodLogged`. |
| **Expected context packet fields** | Rejected events **excluded** from AI timeline export; totals unchanged. |
| **Expected backend endpoint / local route** | N/A (local reject). |
| **Failure signals** | Partial log applied; calories increased despite reject. |
| **Logs to inspect** | No `mutation_executed` success; timeline status `rejected`. |

### CF-06. Confirm compound — linkedEntryId on meal and timeline

| Field | Details |
|-------|---------|
| **Setup** | Compound estimate pending. |
| **Steps** | 1. Confirm estimate.<br>2. Ask: `Delete the chicken rice I just logged`. |
| **Expected user-visible result** | First: success log; second: delete confirmation targeting correct meal. |
| **Expected timeline events** | `foodLogged` with `linkedEntryId` → later `foodDeleted`. |
| **Expected context packet fields** | `recentMealsStructured[].linkedEntryId` matches timeline `foodLogged.linkedEntryId`. |
| **Expected backend endpoint / local route** | Confirm: local mutation; delete: classify → `parse-edit-delete`. |
| **Failure signals** | Missing `linkedEntryId`; delete cannot resolve target. |
| **Logs to inspect** | `mutation_executed` `mutationKind=Food`; edit/delete resolver logs in DEBUG. |

---

## 4. Singapore food QA

### SG-01. Nasi lemak — compound AI path

| Field | Details |
|-------|---------|
| **Setup** | Signed in; Singapore timezone optional (`Asia/Singapore`). |
| **Steps** | 1. Send: `Log nasi lemak`.<br>2. Review components (rice, egg, sambal, etc.). |
| **Expected user-visible result** | Multi-component estimate; confirmation required; culturally plausible totals. |
| **Expected timeline events** | Estimate + pending flow. |
| **Expected context packet fields** | `meta.timezoneIdentifier` matches device; no SG-specific schema fields required. |
| **Expected backend endpoint / local route** | `ai_estimate_food` (blocked local pattern `nasi lemak`). |
| **Failure signals** | Single generic "meal" component; local catalog match. |
| **Logs to inspect** | `routeSelected=ai_estimate_food`; component count ≥ 2 in DEBUG. |

### SG-02. Economy / mixed rice — no local shortcut

| Field | Details |
|-------|---------|
| **Setup** | None. |
| **Steps** | 1. Send: `Log economy rice with fish and vegetables`. |
| **Expected user-visible result** | AI estimate with multiple components; confirm bar shown. |
| **Expected timeline events** | Standard food estimate sequence. |
| **Expected context packet fields** | Standard v2 packet. |
| **Expected backend endpoint / local route** | `estimate-food`; not `local_food_estimate`. |
| **Failure signals** | Local guard triggered incorrectly; 400 context error. |
| **Logs to inspect** | Classify `log_food`; endpoint `estimateFood`. |

### SG-03. Calorie question — no log for chicken rice

| Field | Details |
|-------|---------|
| **Setup** | None. |
| **Steps** | 1. Send: `How many calories in chicken rice?` |
| **Expected user-visible result** | Estimate/lookup card; Today unchanged. |
| **Expected timeline events** | Message events only. |
| **Expected context packet fields** | No new confirmed meals. |
| **Expected backend endpoint / local route** | `nutrition_estimate_query` → `generate-nutrition-estimate`. |
| **Failure signals** | `log_food` routing; pending confirmation. |
| **Logs to inspect** | `classifierIntent=nutrition_estimate_query` or `calorie_lookup`. |

### SG-04. Same as usual — commonFoods + timeline hint

| Field | Details |
|-------|---------|
| **Setup** | Confirm-log `chicken rice` at least twice over prior days (or same day twice for QA). |
| **Steps** | 1. Send: `Log my usual chicken rice`. |
| **Expected user-visible result** | Estimate referencing prior pattern; still requires confirmation. |
| **Expected timeline events** | New estimate + pending. |
| **Expected context packet fields** | `commonFoods` includes chicken rice pattern (`logCount` ≥ 1); confirmed `foodLogged` in timeline export. |
| **Expected backend endpoint / local route** | `estimate-food` with context v2. |
| **Failure signals** | Empty estimate; ignores `commonFoods`; invents unseen dish. |
| **Logs to inspect** | `commonFoodsCount` ≥ 1 in `context_generated`; Firebase `contextCommonFoods` ≥ 1. |

### SG-05. Hawker-style ambiguous photo caption (text-only QA)

| Field | Details |
|-------|---------|
| **Setup** | None (text-only stand-in for hawker meal). |
| **Steps** | 1. Send: `Log this mixed rice plate from the hawker centre — rice, chicken, veggies`. |
| **Expected user-visible result** | Compound text estimate; clarification only if backend returns low confidence. |
| **Expected timeline events** | Estimate + pending. |
| **Expected context packet fields** | `currentUserMessage` on turn; no image bytes in packet. |
| **Expected backend endpoint / local route** | `estimate-food`. |
| **Failure signals** | Routes to meal advice only; single-component collapse. |
| **Logs to inspect** | `routeSelected=ai_estimate_food`; validation success in `endpoint_called`. |

---

## 5. Context compaction QA

### CP-01. Large timeline — compaction flag set

| Field | Details |
|-------|---------|
| **Setup** | Log 15+ mixed events today (food, water, messages, system refreshes if possible). |
| **Steps** | 1. Open Coach and send any AI message.<br>2. Inspect context metrics. |
| **Expected user-visible result** | Normal Coach UX; no user-visible truncation errors. |
| **Expected timeline events** | Historical events preserved in store; exported count ≤ 40. |
| **Expected context packet fields** | `timeline.recentEvents.count` ≤ 40; protected types (`foodLogged`, `photoAttached`, etc.) retained preferentially. |
| **Expected backend endpoint / local route** | Any AI call carrying compacted context. |
| **Failure signals** | HTTP 413; gateway 400 context size; crash during compact. |
| **Logs to inspect** | `compactionOccurred=true`; `contextSizeBucket` not `>24k`; `contextEncodedBytes` ≤ 24576. |

### CP-02. Long assistant chat — truncated for transport

| Field | Details |
|-------|---------|
| **Setup** | Generate 10+ back-and-forth Coach turns with long assistant replies. |
| **Steps** | 1. Send another AI message.<br>2. Verify packet chat section (DEBUG). |
| **Expected user-visible result** | Full transcript in UI; transport layer may truncate assistant entries. |
| **Expected timeline events** | `userMessage` / `assistantMessage` pairs in store. |
| **Expected context packet fields** | `recentChatMessages.count` ≤ 12; assistant text ≤ 180 chars (≤80 after aggressive compaction). |
| **Expected backend endpoint / local route** | Next classify/advice call. |
| **Failure signals** | User messages truncated; schema validation failure. |
| **Logs to inspect** | `context_generated`: `contextSizeBucket`; DEBUG context `chatMessages` count. |

### CP-03. System events dropped before mutations

| Field | Details |
|-------|---------|
| **Setup** | Trigger multiple `systemRefresh` / `contextGenerated` timeline rows (navigate Today↔Coach repeatedly). |
| **Steps** | 1. Log one food item and confirm.<br>2. Build context for next send. |
| **Expected user-visible result** | Today and Coach consistent. |
| **Expected timeline events** | Confirmed `foodLogged` retained in export. |
| **Expected context packet fields** | Low-value system types dropped from export before food events when over byte budget. |
| **Expected backend endpoint / local route** | Local context build. |
| **Failure signals** | Missing confirmed `foodLogged` in export; calorie mismatch vs Today. |
| **Logs to inspect** | `CoachContextCorrectnessValidator` warnings; `timelineEventCount` vs store count. |

### CP-04. Correctness validator — size rule triggers clamp

| Field | Details |
|-------|---------|
| **Setup** | Approach byte limit (many meals + HI enabled + long timeline). |
| **Steps** | 1. Send Coach message.<br>2. Watch for validator correction. |
| **Expected user-visible result** | No user-facing error. |
| **Expected timeline events** | Unchanged in persistence. |
| **Expected context packet fields** | `contextSizeBelowThreshold` rule satisfied after correction. |
| **Expected backend endpoint / local route** | Outbound request succeeds (200). |
| **Failure signals** | Uncorrected oversize packet; 400 from gateway. |
| **Logs to inspect** | `CoachContextCorrectnessValidator` warn: `issueCount`, `rules=contextSizeBelowThreshold`. |

### CP-05. Degraded fallback packet — fallback flag

| Field | Details |
|-------|---------|
| **Setup** | Deny Health + force partial read failures if possible (airplane during context build once). |
| **Steps** | 1. Open Coach after degraded build.<br>2. Send simple greeting. |
| **Expected user-visible result** | Coach loads; optional degraded disclaimer. |
| **Expected timeline events** | Normal message events. |
| **Expected context packet fields** | `generationMode=degraded`; `missingData` flags set; minimal required sections present. |
| **Expected backend endpoint / local route** | Classify with degraded context still schema v2. |
| **Failure signals** | `fallbackPacketUsed` false when mode degraded; crash. |
| **Logs to inspect** | `fallbackPacketUsed=true`; `contextGenerationMode=degraded`. |

---

## 6. SwiftData migration QA

### SD-01. Fresh install — empty timeline entities

| Field | Details |
|-------|---------|
| **Setup** | Delete app; reinstall. |
| **Steps** | 1. Onboard and open Coach.<br>2. Send one message. |
| **Expected user-visible result** | Coach loads; empty/minimal transcript. |
| **Expected timeline events** | First `userMessage` persisted. |
| **Expected context packet fields** | `missingData.noTimelineHistory=true` initially; then false after events. |
| **Expected backend endpoint / local route** | Classify or no-op. |
| **Failure signals** | SwiftData migration crash; `FormaSchemaV6` load failure. |
| **Logs to inspect** | No `Coach timeline backfill failed` on true fresh install. |

### SD-02. Upgrade from pre-timeline schema — lightweight migration

| Field | Details |
|-------|---------|
| **Setup** | Install previous build with V4/V5 schema (if available) with existing food logs; upgrade to sprint build. |
| **Steps** | 1. Launch upgraded app.<br>2. Open Coach and Today. |
| **Expected user-visible result** | No data loss on Today; Coach opens. |
| **Expected timeline events** | Backfill creates `foodLogged` rows with `sourceAttribution=systemBackfill`. |
| **Expected context packet fields** | `recentMealsStructured` populated from logs; `generationMode=live` or `backfill`. |
| **Expected backend endpoint / local route** | Local backfill + context build. |
| **Failure signals** | Migration error alert; duplicate backfill entries multiplying on relaunch. |
| **Logs to inspect** | `CoachTimelineBackfill` success; `timelineEventCount` > 0 after first open. |

### SD-03. Chat transcript persistence across relaunch

| Field | Details |
|-------|---------|
| **Setup** | Send 5+ Coach messages including one photo message if possible. |
| **Steps** | 1. Force-quit app.<br>2. Relaunch and open Coach. |
| **Expected user-visible result** | Transcript restored; thumbnails visible; no full-res photo bloat in UI. |
| **Expected timeline events** | Matching persisted timeline rows. |
| **Expected context packet fields** | `recentChatMessages` reflects restored transcript (clamped). |
| **Expected backend endpoint / local route** | N/A on relaunch. |
| **Failure signals** | Empty transcript; crash loading corrupt message row. |
| **Logs to inspect** | SwiftData fetch errors (should be none). |

### SD-04. Corrupt timeline row — decodes as unknown

| Field | Details |
|-------|---------|
| **Setup** | QA/dev: inject invalid `eventTypeRaw` via debug tools **or** use test fixture build if available. |
| **Steps** | 1. Open Coach.<br>2. Send message. |
| **Expected user-visible result** | Coach remains usable; corrupt row skipped in export. |
| **Expected timeline events** | Corrupt row stored as `.unknown` (if visible in debug). |
| **Expected context packet fields** | Unknown types excluded from AI export. |
| **Expected backend endpoint / local route** | Normal AI path. |
| **Failure signals** | Crash on decode; unknown type in outbound JSON. |
| **Logs to inspect** | Decode warning if logged; no crash backtrace. |

### SD-05. Timeline linkedEntryId index — edit after relaunch

| Field | Details |
|-------|---------|
| **Setup** | Log and confirm a meal; note entry on Today. |
| **Steps** | 1. Relaunch app.<br>2. Send: `Edit my last meal to 500 calories`.<br>3. Confirm edit. |
| **Expected user-visible result** | Edit confirmation targets correct meal; Today updates. |
| **Expected timeline events** | `foodEdited`; prior `foodLogged` may be `superseded`. |
| **Expected context packet fields** | `linkedEntryId` stable across relaunch in meals + timeline. |
| **Expected backend endpoint / local route** | `parse-edit-delete` → local mutation on confirm. |
| **Failure signals** | "Couldn't find entry"; wrong meal edited. |
| **Logs to inspect** | `mutation_executed` `mutationKind=Edit`; resolver enriches `linkedEntryId`. |

---

## 7. Photo context QA

### PH-01. Clear meal photo — image-first analysis

| Field | Details |
|-------|---------|
| **Setup** | Camera permission granted; signed in. |
| **Steps** | 1. Attach clear photo of single plate meal.<br>2. Send without caption or with short caption `lunch`.<br>3. Review analysis card. |
| **Expected user-visible result** | Items visible in photo only; `needsUserReview` messaging; confirmation required; **no auto-log**. |
| **Expected timeline events** | `photoAttached` → `photoAnalysisStarted` → `photoAnalysisCompleted` → `foodEstimateCreated` → `pendingConfirmationCreated`. |
| **Expected context packet fields** | v2 context attached to analyze request; **no** image bytes in timeline; `linkedPhotoSessionId` on events after link. |
| **Expected backend endpoint / local route** | `POST /v1/ai/analyze-meal-image`; `routeSelected=ai_photo_food`; `endpoint=analyzeMealImage`. |
| **Failure signals** | Hidden foods from chat history; auto-log; image base64 in timeline payload. |
| **Logs to inspect** | `endpoint_called` `responseValidationSuccess=true`; DEBUG `CoachImageAnalysis`: `itemCount`, `compressedBytes` (no base64). |

### PH-02. Ambiguous photo — clarifying question loop

| Field | Details |
|-------|---------|
| **Setup** | Photo of mixed buffet / unclear portions. |
| **Steps** | 1. Send photo.<br>2. If clarifying question appears, answer (e.g. `large portion`).<br>3. Complete flow to confirmation. |
| **Expected user-visible result** | Clarification UI; revised estimate; still requires confirm. |
| **Expected timeline events** | `clarificationAsked` → `clarificationAnswered` → analysis completed → pending. |
| **Expected context packet fields** | `clarification` on re-request only; context schema v2. |
| **Expected backend endpoint / local route** | Second `analyze-meal-image` with `clarification` + optional `previousAnalysis`. |
| **Failure signals** | Silent guess with no review flag; crash on recommission. |
| **Logs to inspect** | DEBUG: `isRetry=true`; timeline clarification events. |

### PH-03. Caption must not override visible-only rule

| Field | Details |
|-------|---------|
| **Setup** | Photo of salad only. |
| **Steps** | 1. Attach photo.<br>2. Caption: `also had a large pizza and soda`.<br>3. Review items list. |
| **Expected user-visible result** | Items primarily from visible salad; caption influences assumptions/warnings, not invisible pizza as confirmed item. |
| **Expected timeline events** | Standard photo sequence. |
| **Expected context packet fields** | Assumptions may note caption uncertainty. |
| **Expected backend endpoint / local route** | `analyze-meal-image` with `message` caption. |
| **Failure signals** | Pizza/soda logged as detected items without review warning. |
| **Logs to inspect** | Response `needsUserReview=true`; DEBUG parse warnings. |

### PH-04. Photo analysis failure — recoverable error

| Field | Details |
|-------|---------|
| **Setup** | Airplane mode **or** invalid backend config for one attempt. |
| **Steps** | 1. Send meal photo while offline.<br>2. Observe error copy and retry when online. |
| **Expected user-visible result** | User-friendly failure; retry available; no phantom log. |
| **Expected timeline events** | `photoAnalysisFailed`; possible `backendError`. |
| **Expected context packet fields** | No confirmed food from failed analysis. |
| **Expected backend endpoint / local route** | Failed `analyzeMealImage`; `backendErrorCategory=network` or `backend_unavailable`. |
| **Failure signals** | Crash; stuck analyzing spinner forever. |
| **Logs to inspect** | `endpoint_called` `responseValidationSuccess=false`; DEBUG `errorCategory=network`. |

### PH-05. Confirm photo meal — session linkage

| Field | Details |
|-------|---------|
| **Setup** | Successful photo analysis pending. |
| **Steps** | 1. Confirm log.<br>2. Inspect Today entry source. |
| **Expected user-visible result** | Entry marked as photo/AI estimate; macros on Today. |
| **Expected timeline events** | `pendingConfirmationConfirmed` → `foodLogged` with photo session link. |
| **Expected context packet fields** | New `recentMealsStructured` entry with `linkedEntryId`. |
| **Expected backend endpoint / local route** | Local `mutation_executed` on confirm. |
| **Failure signals** | Missing link between photo session and food entry; duplicate logs on confirm tap. |
| **Logs to inspect** | `mutationSuccess=true`; timeline `linkedPhotoSessionId` present in DEBUG. |

### PH-06. Photo without auth — session failure UI

| Field | Details |
|-------|---------|
| **Setup** | Sign out or use expired token scenario. |
| **Steps** | 1. Attempt meal photo send while signed out / auth broken. |
| **Expected user-visible result** | Session failure UI with retry/sign-in (`Couldn't start Coach` pattern); no silent drop. |
| **Expected timeline events** | `authError` possible. |
| **Expected context packet fields** | N/A (request may not complete). |
| **Expected backend endpoint / local route** | `analyzeMealImage` fails; `backendErrorCategory=authentication`. |
| **Failure signals** | Generic crash; token printed in logs. |
| **Logs to inspect** | `authFailed` trace outcome; `backendErrorCategory=authentication`; **no** Bearer token in console. |

---

## 8. Edit/delete reference QA

### ED-01. Delete by meal name — recentMeals resolution

| Field | Details |
|-------|---------|
| **Setup** | Confirm-log `grilled salmon` once today. |
| **Steps** | 1. Send: `Delete the grilled salmon`.<br>2. Confirm delete. |
| **Expected user-visible result** | Delete confirmation naming salmon; entry removed from Today. |
| **Expected timeline events** | `pendingConfirmationCreated` → `foodDeleted`; prior `foodLogged` → `superseded`. |
| **Expected context packet fields** | Pre-delete: `recentMealsStructured` contains salmon with `linkedEntryId`. |
| **Expected backend endpoint / local route** | Classify `delete_log` → `POST /v1/ai/parse-edit-delete` → `ai_delete_entry`. |
| **Failure signals** | "Couldn't find entry"; deletes wrong meal; meal-type-only fallback delete. |
| **Logs to inspect** | `pendingConfirmationKind=Delete`; `mutation_executed` success. |

### ED-02. Edit with linkedEntryId from parser

| Field | Details |
|-------|---------|
| **Setup** | Two distinct meals logged today (breakfast + lunch). |
| **Steps** | 1. Send: `Change my lunch to 600 calories`.<br>2. Confirm edit. |
| **Expected user-visible result** | Edit targets lunch entry only. |
| **Expected timeline events** | `foodEdited` with link to lunch entry. |
| **Expected context packet fields** | Timeline confirmed events include both entries with distinct `linkedEntryId`. |
| **Expected backend endpoint / local route** | `parse-edit-delete`; resolver enriches `linkedEntryId` from meals/timeline. |
| **Failure signals** | Edits breakfast; clarifies without resolving when single match exists. |
| **Logs to inspect** | `CoachEntryReferenceResolver.enrichAction` path (DEBUG); mutation kind `Edit`. |

### ED-03. Ambiguous delete — clarification, no mutation

| Field | Details |
|-------|---------|
| **Setup** | Log two similar items (e.g. two chicken rice meals). |
| **Steps** | 1. Send: `Delete the chicken rice`. |
| **Expected user-visible result** | Clarification asking which entry; **no** delete until confirmed. |
| **Expected timeline events** | No `foodDeleted` until explicit confirm of correct target. |
| **Expected context packet fields** | Multiple matching meals in `recentMealsStructured`. |
| **Expected backend endpoint / local route** | `parse-edit-delete` may return low-confidence or clarification path. |
| **Failure signals** | Deletes most recent without asking; deletes both. |
| **Logs to inspect** | No premature `mutation_executed`; classifier confidence field. |

### ED-04. Delete rejected estimate — not deletable as logged food

| Field | Details |
|-------|---------|
| **Setup** | Start food log then **reject** confirmation. |
| **Steps** | 1. Send: `Delete what I just logged`. |
| **Expected user-visible result** | Coach explains nothing confirmed to delete; Today unchanged. |
| **Expected timeline events** | Prior `foodRejected` / `pendingConfirmationRejected` excluded from resolution. |
| **Expected context packet fields** | Exported timeline excludes rejected/failed food events. |
| **Expected backend endpoint / local route** | `parse-edit-delete` or clarification locally. |
| **Failure signals** | Deletes an older unrelated meal. |
| **Logs to inspect** | Resolver ignores non-confirmed statuses. |

### ED-05. UUID selector — explicit linkedEntryId

| Field | Details |
|-------|---------|
| **Setup** | Dev/QA with known entry UUID from Today debug **or** copy from timeline export. |
| **Steps** | 1. Send delete/edit referencing UUID in selector if supported by parser test harness.<br>2. Confirm. |
| **Expected user-visible result** | Exact entry targeted. |
| **Expected timeline events** | Matching `linkedEntryId` on mutation event. |
| **Expected context packet fields** | UUID match in `resolveLinkedEntryId` priority 1–2. |
| **Expected backend endpoint / local route** | `parse-edit-delete`. |
| **Failure signals** | UUID ignored; name fallback wrong entry. |
| **Logs to inspect** | Enriched action includes explicit `linkedEntryId`. |

### ED-06. Edit/delete blocked without linkedEntryId at execution

| Field | Details |
|-------|---------|
| **Setup** | Simulate parser action missing `linkedEntryId` and name match (empty recent meals). |
| **Steps** | 1. Send: `Delete my lunch` with no meals logged. |
| **Expected user-visible result** | *"I couldn't find which entry to delete…"* — no mutation. |
| **Expected timeline events** | Messages only. |
| **Expected context packet fields** | `missingData.noRecentMeals=true` or empty meals array. |
| **Expected backend endpoint / local route** | May classify delete but executor blocks without id. |
| **Failure signals** | Meal-type heuristic delete; crash in executor. |
| **Logs to inspect** | No `mutation_executed` success; optional `mutationSuccess=false`. |

---

## 9. Local deterministic status QA

### DS-01. "How am I doing today?" — no API

| Field | Details |
|-------|---------|
| **Setup** | Log food, water, weight today; note Today tab numbers. |
| **Steps** | 1. Send: `How am I doing today?` or `status` |
| **Expected user-visible result** | Bullet list: calories, protein, water remaining; last meal line; steps/workout lines if available. |
| **Expected timeline events** | `userMessage`, `assistantMessage`. |
| **Expected context packet fields** | Built locally; numbers ±5 kcal of Today (`CoachContextCorrectnessValidator.calorieTolerance`). |
| **Expected backend endpoint / local route** | `local_command` / `daily_summary`; `requiresAPI=false`; **no** gateway call. |
| **Failure signals** | HTTP request fired; numbers disagree >5 kcal; includes rejected pending meals in totals. |
| **Logs to inspect** | `routeSelected=local_command`; `classifierIntent=daily_summary` if classified; no `endpoint_called`. |

### DS-02. Calories remaining — matches Today targets

| Field | Details |
|-------|---------|
| **Setup** | Profile with 2000 kcal target; log 500 kcal meal. |
| **Steps** | 1. Send: `How many calories left?` |
| **Expected user-visible result** | ~1500 kcal remaining (subject to logged items). |
| **Expected timeline events** | Message pair. |
| **Expected context packet fields** | `today.nutrition.caloriesRemaining` consistent with status text. |
| **Expected backend endpoint / local route** | Local parser path. |
| **Failure signals** | Off-by entire meal; uses estimate-not-confirmed entries. |
| **Logs to inspect** | Local guard hit; no classify latency. |

### DS-03. Missing Health — steps/workout lines omitted

| Field | Details |
|-------|---------|
| **Setup** | HealthKit denied or unavailable flags. |
| **Steps** | 1. Send status command. |
| **Expected user-visible result** | No fabricated step count; disclaimer may appear. |
| **Expected timeline events** | Standard messages. |
| **Expected context packet fields** | `missingData.stepsUnavailable` or related; `today.steps` nil. |
| **Expected backend endpoint / local route** | Local only. |
| **Failure signals** | Specific step count without permission. |
| **Logs to inspect** | `missingDataFlagsCount` ≥ 1; status copy includes disclaimer via `CoachAIResponseContextAdapter`. |

### DS-04. Classifier daily_summary maps to local status

| Field | Details |
|-------|---------|
| **Setup** | Same as DS-01. |
| **Steps** | 1. Send: `Give me my daily summary`. |
| **Expected user-visible result** | Same deterministic status structure (not long GPT essay unless routed elsewhere). |
| **Expected timeline events** | Message pair. |
| **Expected context packet fields** | Local aggregates drive copy. |
| **Expected backend endpoint / local route** | Classify `daily_summary` → local `.status` (not `generate-daily-review` unless explicitly different product path). |
| **Failure signals** | Unexpected `generate-daily-review` call for simple summary chip. |
| **Logs to inspect** | `routeSelected=local_command`; intent `daily_summary`. |

### DS-05. Midnight boundary — localDate consistency

| Field | Details |
|-------|---------|
| **Setup** | Device timezone known; test near local midnight if feasible. |
| **Steps** | 1. Before midnight: log meal and check status.<br>2. After midnight: check status again without new logs. |
| **Expected user-visible result** | After midnight, "today" resets; prior day meals not in today's totals. |
| **Expected timeline events** | Events stamped with correct UTC/local pairing. |
| **Expected context packet fields** | `meta.localDate` matches device calendar day; `localDateTimezoneConsistent` rule passes. |
| **Expected backend endpoint / local route** | Local status. |
| **Failure signals** | Yesterday meals counted in today status; wrong `localDate` in outbound context. |
| **Logs to inspect** | `contextLocalDate` in Firebase logs matches device; validator timezone rule silent. |

---

## 10. Backend unavailable / auth QA

### BE-01. Airplane mode — classify/estimate unavailable copy

| Field | Details |
|-------|---------|
| **Setup** | Enable airplane mode before send. |
| **Steps** | 1. Send: `Log pasta`. |
| **Expected user-visible result** | Network unavailable message; retry when online; no partial log. |
| **Expected timeline events** | `backendError` with network category possible. |
| **Expected context packet fields** | Unchanged confirmed data. |
| **Expected backend endpoint / local route** | Failed `classifyCoachIntent` or `estimateFood`; `backendErrorCategory=network`. |
| **Failure signals** | Crash; silent failure; phantom pending confirmation. |
| **Logs to inspect** | `endpoint_called` `responseValidationSuccess=false`; user-visible copy from `AIServiceError.networkUnavailable`. |

### BE-02. Backend 503 — service unavailable

| Field | Details |
|-------|---------|
| **Setup** | Point client to emulator returning 503 or disable functions. |
| **Steps** | 1. Send AI-requiring message. |
| **Expected user-visible result** | Temporary unavailable copy; Coach tab usable. |
| **Expected timeline events** | `backendError` recoverable. |
| **Expected context packet fields** | N/A. |
| **Expected backend endpoint / local route** | Gateway failure; Firebase `backendErrorCategory=gateway` or `internal`. |
| **Failure signals** | Raw stack trace shown to user. |
| **Logs to inspect** | Firebase `AI gateway request failed`; iOS `backend_unavailable` category. |

### BE-03. Auth token expired — session failure

| Field | Details |
|-------|---------|
| **Setup** | Expire/invalidate Firebase session (sign out on web while app open, or test token). |
| **Steps** | 1. Send Coach message requiring API. |
| **Expected user-visible result** | Auth failure UI with sign-in/retry; not a silent hang. |
| **Expected timeline events** | `authError`. |
| **Expected context packet fields** | N/A. |
| **Expected backend endpoint / local route** | 401; `backendErrorCategory=authentication`. |
| **Failure signals** | Token printed in logs; unrecoverable blank state. |
| **Logs to inspect** | `traceOutcome=authFailed`; `authentication` category; no Bearer in OSLog. |

### BE-04. Payload too large — 413 graceful handling

| Field | Details |
|-------|---------|
| **Setup** | Attempt oversize body (extremely long pasted text > limit) if client allows. |
| **Steps** | 1. Paste max-length overrun in Coach input if possible.<br>2. Send. |
| **Expected user-visible result** | Validation error or payload too large message; no crash. |
| **Expected timeline events** | Optional `backendError`. |
| **Expected context packet fields** | Request not sent with invalid oversize context. |
| **Expected backend endpoint / local route** | Client-side rejection or HTTP 413; `payload_too_large`. |
| **Failure signals** | Crash; hung request. |
| **Logs to inspect** | `backendErrorCategory=payload_too_large`. |

### BE-05. Local commands work offline — water log

| Field | Details |
|-------|---------|
| **Setup** | Airplane mode. |
| **Steps** | 1. Send: `Log 250ml water`. |
| **Expected user-visible result** | Water logged locally if parser handles; Today water increases. |
| **Expected timeline events** | `waterLogged` confirmed. |
| **Expected context packet fields** | Hydration updated on next online context build. |
| **Expected backend endpoint / local route** | `local_command`; no gateway. |
| **Failure signals** | Network error for simple water; no Today update. |
| **Logs to inspect** | `routeSelected=local_command`; `mutation_executed` water success. |

---

## 11. Privacy / logging QA

### PV-01. Release build — CoachAccuracy has no raw message text

| Field | Details |
|-------|---------|
| **Setup** | **Release** configuration on device; Xcode console or Console.app. |
| **Steps** | 1. Send: `Log my secret private meal xyz`.<br>2. Filter logs: subsystem `Forma`, category `CoachAccuracy`. |
| **Expected user-visible result** | Normal Coach UX. |
| **Expected timeline events** | Standard flow. |
| **Expected context packet fields** | N/A for log test. |
| **Expected backend endpoint / local route** | Any. |
| **Failure signals** | Log line contains `secret private meal` or full user string. |
| **Logs to inspect** | Only `messageLength=<n>` — **not** message body; events `route_selected`, `context_generated`. |

### PV-02. Release build — no food names in CoachAccuracy

| Field | Details |
|-------|---------|
| **Setup** | Release; log uniquely named food e.g. `QA_UNIQUE_SALMON_42`. |
| **Steps** | 1. Confirm log.<br>2. Search console for `QA_UNIQUE_SALMON_42`. |
| **Expected user-visible result** | Food appears in UI (expected). |
| **Expected timeline events** | `foodLogged` in app storage. |
| **Expected context packet fields** | Names in app memory only. |
| **Expected backend endpoint / local route** | Any. |
| **Failure signals** | Production OSLog contains food name string. |
| **Logs to inspect** | `CoachAccuracy` lines — counts/buckets only; `recentMealsCount` numeric. |

### PV-03. Firebase gateway logs — summary fields only

| Field | Details |
|-------|---------|
| **Setup** | Backend logging enabled; send message with v2 context. |
| **Steps** | 1. Inspect `AI gateway request received/completed` log entry. |
| **Expected user-visible result** | N/A. |
| **Expected timeline events** | N/A. |
| **Expected context packet fields** | Logged: `contextSchemaVersion`, `contextSizeBucket`, `contextTimelineEvents`, `contextRecentMeals`, `contextCommonFoods`, `contextMissingDataFlagsCount`, `contextHasHealthIntelligence` — **not** meal names or HI payloads. |
| **Expected backend endpoint / local route** | Any successful gateway call. |
| **Failure signals** | JSON log contains `Salad`, `8000` steps value, or base64. |
| **Logs to inspect** | Firebase structured fields from `coachContextLogFields()`. |

### PV-04. DEBUG tracer — redacted JSON in HTTP debug

| Field | Details |
|-------|---------|
| **Setup** | DEBUG build; `FORMA_PIPELINE_TRACE=1`. |
| **Steps** | 1. Send meal photo or food log.<br>2. Inspect pipeline trace export / console. |
| **Expected user-visible result** | N/A. |
| **Expected timeline events** | N/A. |
| **Expected context packet fields** | Trace shows `redactedDebugDescription()` not full JSON. |
| **Expected backend endpoint / local route** | HTTP stages present. |
| **Failure signals** | `imageJPEGBase64`, Bearer token, or `text` fields with raw content in trace. |
| **Logs to inspect** | `CoachAccuracyObservabilityLogFormatter.redactSensitiveJSONFields` patterns: `<redacted>`. |

### PV-05. Image debug logger — bytes not base64 (DEBUG only)

| Field | Details |
|-------|---------|
| **Setup** | DEBUG; analyze meal photo. |
| **Steps** | 1. Filter `CoachImageAnalysis` category. |
| **Expected user-visible result** | N/A. |
| **Expected timeline events** | Photo sequence. |
| **Expected context packet fields** | No image in packet JSON. |
| **Expected backend endpoint / local route** | `analyzeMealImage`. |
| **Failure signals** | Base64 string in log; full caption text logged in production logger. |
| **Logs to inspect** | `compressedBytes`, `attempt`, `errorCategory` — DEBUG category only; Release must not emit `CoachImageAnalysis` body text. |

---

## 12. Regression QA

Baseline: cross-check with [COACH_TIMELINE_CONTEXT_V2_QA.md](./COACH_TIMELINE_CONTEXT_V2_QA.md) scenarios 1–40. Sprint regressions below.

### RG-01. Schema v2 rejected if wrong version

| Field | Details |
|-------|---------|
| **Setup** | Dev harness sending context schema ≠ 2 (if available). |
| **Steps** | 1. Attempt gateway call with invalid schema. |
| **Expected user-visible result** | Client-side validation prevents send **or** safe error message. |
| **Expected timeline events** | Optional `backendError`. |
| **Expected context packet fields** | Client never sends schema ≠ 2 in production path. |
| **Expected backend endpoint / local route** | HTTP 400 `Invalid context.meta.schemaVersion`. |
| **Failure signals** | Silent wrong-context request; crash. |
| **Logs to inspect** | Firebase 400; iOS validator errors. |

### RG-02. Greeting — no mutation regression

| Field | Details |
|-------|---------|
| **Setup** | Signed in. |
| **Steps** | 1. Send `Hi`. |
| **Expected user-visible result** | Greeting; no confirmation bar. |
| **Expected timeline events** | `userMessage`, `assistantMessage`. |
| **Expected context packet fields** | Standard v2; no spurious `currentUserMessage` duplication in chat array. |
| **Expected backend endpoint / local route** | `no_op` / `app_help`; may skip classify. |
| **Failure signals** | Food logged; API 400. |
| **Logs to inspect** | `routeSelected=no_op` or similar. |

### RG-03. Water log + undo

| Field | Details |
|-------|---------|
| **Setup** | Note water total. |
| **Steps** | 1. `Log 300ml water`.<br>2. `Undo last water`. |
| **Expected user-visible result** | Water increases then decreases on undo. |
| **Expected timeline events** | `waterLogged` → `undoPerformed`. |
| **Expected context packet fields** | Hydration fields match Today after each step. |
| **Expected backend endpoint / local route** | `local_command`. |
| **Failure signals** | Undo removes wrong entry type. |
| **Logs to inspect** | `mutation_executed` for water; undo success. |

### RG-04. Weight log — local mutation

| Field | Details |
|-------|---------|
| **Setup** | Profile with weight tracking. |
| **Steps** | 1. `Log weight 72.5kg`. |
| **Expected user-visible result** | Confirmation if policy requires; Today weight updates. |
| **Expected timeline events** | `weightLogged`. |
| **Expected context packet fields** | `today.weight.weightKg` updated. |
| **Expected backend endpoint / local route** | `local_command`. |
| **Failure signals** | Parsed as food log. |
| **Logs to inspect** | Intent `log_weight` or local parser water/weight path. |

### RG-05. Training log redirect

| Field | Details |
|-------|---------|
| **Setup** | None. |
| **Steps** | 1. `Log a 5km run`. |
| **Expected user-visible result** | Redirect copy to Training tab; **no** workout logged in nutrition. |
| **Expected timeline events** | Messages only. |
| **Expected context packet fields** | No workout mutation in nutrition timeline. |
| **Expected backend endpoint / local route** | `training_log_redirect`. |
| **Failure signals** | Fake workout logged as food. |
| **Logs to inspect** | `routeSelected=training_log_redirect`. |

### RG-06. Pending confirmation double confirm — idempotent

| Field | Details |
|-------|---------|
| **Setup** | Food pending on bar. |
| **Steps** | 1. Tap Confirm twice quickly. |
| **Expected user-visible result** | Single log entry; second tap shows already logged or no-op. |
| **Expected timeline events** | One confirmed `foodLogged`. |
| **Expected context packet fields** | Single new meal. |
| **Expected backend endpoint / local route** | One mutation. |
| **Failure signals** | Duplicate entries on Today. |
| **Logs to inspect** | `mutation_executed` once; executor idempotency path. |

### RG-07. Today ↔ Coach calorie parity

| Field | Details |
|-------|---------|
| **Setup** | Log two meals via Coach confirm. |
| **Steps** | 1. Compare Today consumed kcal to Coach status output. |
| **Expected user-visible result** | Match within ±5 kcal. |
| **Expected timeline events** | Two `foodLogged` confirmed. |
| **Expected context packet fields** | `today.nutrition.caloriesConsumed` matches Today. |
| **Expected backend endpoint / local route** | Local status check. |
| **Failure signals** | >5 kcal drift; rejected estimates included. |
| **Logs to inspect** | `CoachContextCorrectnessValidator` — no calorie rule violations. |

### RG-08. Rejected timeline excluded from classifier context

| Field | Details |
|-------|---------|
| **Setup** | Reject one pending estimate (CF-05). |
| **Steps** | 1. Ask: `What did I eat today?` |
| **Expected user-visible result** | Answer lists confirmed items only. |
| **Expected timeline events** | Rejected events stay out of export. |
| **Expected context packet fields** | No rejected summaries in `timeline.recentEvents` export. |
| **Expected backend endpoint / local route** | Classify + advice/estimate as appropriate. |
| **Failure signals** | Rejected food mentioned as eaten. |
| **Logs to inspect** | Exported timeline types exclude `foodRejected`. |

### RG-09. Multi-action parse — sequential confirmations

| Field | Details |
|-------|---------|
| **Setup** | None. |
| **Steps** | 1. Send: `Log 2 eggs and 300ml water`. |
| **Expected user-visible result** | Handles multi-action or prompts sequentially; both logged after confirms. |
| **Expected timeline events** | Food and water events in order. |
| **Expected context packet fields** | Both reflected after completion. |
| **Expected backend endpoint / local route** | `parse-multi-action` or multiple local steps. |
| **Failure signals** | Only first action executed; silent drop of second. |
| **Logs to inspect** | `routeSelected=ai_multi_action` if routed. |

### RG-10. Nutrition estimate card — no Today side effect

| Field | Details |
|-------|---------|
| **Setup** | Note Today calories. |
| **Steps** | 1. Ask macro question (CL-01).<br>2. Dismiss card. |
| **Expected user-visible result** | Card dismisses; Today unchanged. |
| **Expected timeline events** | No food mutation. |
| **Expected context packet fields** | Unchanged. |
| **Expected backend endpoint / local route** | `generate-nutrition-estimate`. |
| **Failure signals** | Side-effect log; duplicate cards on rotate. |
| **Logs to inspect** | No `pending_confirmation_created`. |

### RG-11. Context inspector / debug overlay (DEBUG)

| Field | Details |
|-------|---------|
| **Setup** | DEBUG with developer tools if available. |
| **Steps** | 1. Open context inspector after send.<br>2. Read summary line. |
| **Expected user-visible result** | Redacted summary only in overlay. |
| **Expected timeline events** | N/A. |
| **Expected context packet fields** | Inspector matches `redactedDebugDescription()` — counts/modes, not meal names. |
| **Expected backend endpoint / local route** | N/A. |
| **Failure signals** | Full JSON with PII in overlay. |
| **Logs to inspect** | Same redaction rules as PV-04. |

### RG-12. Rate limit — graceful message

| Field | Details |
|-------|---------|
| **Setup** | Burst >30 requests/min on same UID (test env) if possible. |
| **Steps** | 1. Rapid-fire AI messages. |
| **Expected user-visible result** | Rate limit message; app stable. |
| **Expected timeline events** | `backendError` possible. |
| **Expected context packet fields** | N/A. |
| **Expected backend endpoint / local route** | HTTP 429; `backendErrorCategory=rate_limited`. |
| **Failure signals** | Crash; account lockout without message. |
| **Logs to inspect** | Firebase 429; iOS mapped error category. |

### RG-13. Classifier does not copy chat history into log action

| Field | Details |
|-------|---------|
| **Setup** | Discuss calories for banana (CL-01) without logging. |
| **Steps** | 1. Then send: `Log it`. |
| **Expected user-visible result** | Clarify **or** estimate banana — must not silently merge unrelated prior food from history against user intent. |
| **Expected timeline events** | If clarified, no log until explicit. |
| **Expected context packet fields** | Chat history present but classifier rules prefer explicit referent. |
| **Expected backend endpoint / local route** | Classify → estimate or clarify. |
| **Failure signals** | Logs wrong item from earlier unrelated turn. |
| **Logs to inspect** | Classifier intent and action payload fields in DEBUG (redacted names). |

### RG-14. End-to-end sprint smoke — advice, log, photo, delete

| Field | Details |
|-------|---------|
| **Setup** | Clean Today; signed in; Health optional. |
| **Steps** | 1. Ask calorie lookup (no log).<br>2. Log compound meal via text; confirm.<br>3. Log meal via photo; confirm.<br>4. Delete text meal by name.<br>5. Run status command. |
| **Expected user-visible result** | Each step matches sections 2–9 expectations; Today coherent after delete. |
| **Expected timeline events** | Full lifecycle without duplicate/spurious events. |
| **Expected context packet fields** | v2 schema throughout; compaction if long session. |
| **Expected backend endpoint / local route** | Mix of estimate, analyze-meal-image, parse-edit-delete, local status. |
| **Failure signals** | Any FAIL from constituent scenarios. |
| **Logs to inspect** | Full `CoachAccuracy` trace: context → route → endpoint → mutation; Firebase completion logs with summary context fields. |

---

## Release readiness checklist

Complete before merging the Coach Accuracy Hardening Sprint to release.

### Automated verification

- [ ] iOS unit tests pass (`CoachAccuracyObservabilityTests`, `CoachEntryReferenceResolverTests`, `CoachMealPhotoContextV2Tests`, `CoachContextPacketV2Tests`, routing/regression suites)
- [ ] Firebase Functions tests pass (`npm test` in `functions/` — includes `coachContextLogFields` privacy cases)
- [ ] No new production log paths emit raw user text, food names, tokens, or base64 (PV-01–PV-03 verified on Release build)

### Manual QA coverage

- [ ] All **70** cases in this document executed or explicitly **BLOCKED** with reason recorded
- [ ] Section 1 (HI): prod-default **and** Coach-context-enabled paths tested
- [ ] Section 2 (Classifier): advice vs log matrix spot-checked (CL-01–CL-04 minimum)
- [ ] Section 3–4 (Compound + SG): at least one multi-component confirm + one lookup-only case
- [ ] Section 5 (Compaction): `compactionOccurred` verified under load
- [ ] Section 6 (Migration): fresh install **and** upgrade path (if prior build available)
- [ ] Section 7 (Photo): happy path + failure path (PH-01 + PH-04)
- [ ] Section 8 (Edit/delete): name resolution + ambiguous case (ED-01 + ED-03)
- [ ] Section 9 (Status): Today parity (DS-01 + DS-02)
- [ ] Section 10 (Errors): offline + auth (BE-01 + BE-03)
- [ ] Section 11 (Privacy): Release log audit complete
- [ ] Section 12 (Regression): smoke RG-14 passed

### Accuracy & data integrity

- [ ] Today ↔ Coach calorie parity within ±5 kcal (RG-07, DS-01)
- [ ] Rejected/pending estimates excluded from totals and AI context (RG-08, CF-05)
- [ ] Photo analysis image-first — no invisible foods auto-logged (PH-01, PH-03)
- [ ] Edit/delete requires resolved `linkedEntryId` — no meal-type-only delete fallback (ED-06)
- [ ] Compound foods preserve multiple components (CF-01, CF-02)
- [ ] Classifier low-confidence mutations blocked (CL-05)

### Backend & contract

- [ ] All gateway calls use `context.meta.schemaVersion == 2`
- [ ] Gateway logs use summary fields only (`coachContextLogFields`)
- [ ] Failure logs include `backendErrorCategory` without raw user content
- [ ] Endpoint matrix exercised: classify, estimate-food, analyze-meal-image, generate-nutrition-estimate, generate-meal-advice, parse-edit-delete

### Privacy & compliance

- [ ] Release `CoachAccuracy` logs contain only buckets/counts/categories
- [ ] DEBUG-only loggers (`CoachFoodEstimate`, `CoachImageAnalysis`, `PipelineTrace`) documented as non-production
- [ ] Timeline persistence stores no full-resolution photo bytes in SwiftData entities
- [ ] Health disclaimers present when `missingData` flags set (HI-04, DS-03)

### Sign-off

| Role | Name | Date | Build | Result |
|------|------|------|-------|--------|
| QA | | | | |
| Engineering | | | | |
| Product | | | | |

**Minimum bar for release:** zero open **FAIL** results in sections 2, 7, 8, 10, and 11; no P0/P1 accuracy or privacy defects; RG-14 smoke passed on a physical device.

---

## Appendix — quick reference

### Gateway endpoints

| Path | Purpose |
|------|---------|
| `/v1/ai/classify-coach-intent` | Intent classification |
| `/v1/ai/estimate-food` | Text/legacy photo food estimate |
| `/v1/ai/analyze-meal-image` | Meal photo analysis |
| `/v1/ai/generate-meal-advice` | Advice (no log) |
| `/v1/ai/generate-nutrition-estimate` | Calorie/macro lookup |
| `/v1/ai/generate-nutrition-comparison` | Food comparison |
| `/v1/ai/parse-edit-delete` | Edit/delete parse |
| `/v1/ai/parse-multi-action` | Multi-action parse |

### Common `routeSelected` handlers

`local_command`, `local_food_estimate`, `ai_estimate_food`, `cheap_nutrition_estimate`, `strong_meal_advice`, `ai_photo_food`, `ai_edit_entry`, `ai_delete_entry`, `classify_fallback`, `classify_dedup`, `confidence_clarify`, `training_log_redirect`, `no_op`

### Timeline types (high-signal)

`foodLogged`, `foodDeleted`, `foodEdited`, `foodEstimateCreated`, `foodRejected`, `pendingConfirmationCreated`, `pendingConfirmationConfirmed`, `pendingConfirmationRejected`, `photoAttached`, `photoAnalysisStarted`, `photoAnalysisCompleted`, `photoAnalysisFailed`, `clarificationAsked`, `clarificationAnswered`, `backendError`, `authError`

### CoachAccuracy log events

`context_generated`, `route_selected`, `endpoint_called`, `mutation_executed`, `pending_confirmation_created`
