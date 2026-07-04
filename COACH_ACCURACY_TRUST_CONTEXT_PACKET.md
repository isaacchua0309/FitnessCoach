# Coach Accuracy and Trust Context Packet

**Repository:** FitnessCoach (iOS `Fitness Coach/` + Firebase `functions/`)  
**Generated:** 2026-07-05  
**Method:** Full-repo code audit. No behavior changes.  
**Related docs read:** `USER_DATA_STORAGE_CONTEXT_PACKET.md`, `ACCOUNT_PERSISTENCE_RESTORE_CONTEXT_PACKET.md`, `Docs/Coach/COACH_CONTEXT_PACKET_V2.md`, `Docs/Coach/COACH_ACCURACY_HARDENING_FINAL_REPORT.md`, `Docs/CoachNutritionEstimateCards.md`, `Docs/AccountPersistence/PHASE_2`–`PHASE_6`, `Docs/Coach/COACH_FULL_CONTEXT_PACKET.md`, `FORMA_AI_API_SERVER_CONTEXT_PACKET.md`

**Claim labels:** **Confirmed** (direct code/doc evidence), **Likely** (strong inference), **Unknown** (not verifiable from repo)

---

## 1. Executive Summary

Coach is a tab-level conversational assistant (`CoachView` → `CoachModel`) that routes user text and meal photos through a multi-stage pipeline: local guard → cheap LLM intent classifier → specialized AI endpoints → validation → optional confirmation → `CoachMutationExecutor` → `FitnessActionCenter` → SwiftData. Coach reads structured app state via `CoachContextPacketV2` (schema v2) on every AI call and never treats chat prose as nutrition truth (**Confirmed** — `Docs/Coach/COACH_CONTEXT_PACKET_V2.md`, `CoachContextPacketV2Builder.swift`).

### What Coach can currently do (**Confirmed**)

| Capability | Evidence |
|------------|----------|
| General chat / greetings | `LocalNoAPIGuard`, `CoachRoute.noOp` — `CoachRouteDecider.swift` |
| Text food estimate + log (with confirmation) | `estimate-food` endpoint, `ConfirmationPolicy`, `CoachConfirmationBar` |
| Meal photo estimate + log (with confirmation) | `analyze-meal-image`, `CoachMealPhotoAnalyzer`, `CoachImagePipeline` |
| Photo clarification / recommission | `ImageAnalysisSession`, `ImageAnalysisRecommissionContext`, `CoachMealPhotoAnalyzer.analyze(recommission:)` |
| Nutrition estimate cards (advice, no auto-log) | `generate-nutrition-estimate`, `NutritionEstimateCard` — `Docs/CoachNutritionEstimateCards.md` |
| Nutrition comparison cards | `generate-nutrition-comparison`, `NutritionComparisonCard` |
| Meal / nutrition / workout / weight advice (prose) | `generate-meal-advice`, `CoachAIRouteHandler` |
| Water / weight logging | `CoachMutationExecutor.executeLogWater/Weight`, local parser immediate path |
| Food edit / delete / undo (with confirmation for AI-parsed) | `parse-edit-delete`, `CoachEntryReferenceResolver`, `CoachMutationExecutor` |
| Daily review generation | `generate-daily-review`, `executeDailyReview` |
| Daily status summary | `CoachMutationExecutor.executeStatus`, `CoachDailyStatusBuilder` |
| Local high-confidence food catalog match | `LocalNutritionEstimator`, `LocalFoodEstimateRequest` |
| Compound dish decomposition | `foodCompoundDish.ts`, `FoodCompoundDishDetector.swift` |
| Timeline + chat context for AI | `CoachTimelineStore`, `CoachContextPacketV2Builder` |
| Health Intelligence in context (default-on when flags allow) | `CoachHealthIntelligenceContextBuilder`, `HealthIntelligenceFeatureFlags` |

### What Coach cannot do (**Confirmed** unless noted)

| Limitation | Evidence |
|------------|----------|
| Workout logging via Coach mutations | `ConfirmationPolicy` rejects `.logWorkout` — `TrainingIntegrationCopy.coachWorkoutMutationUnavailable` |
| Weight undo | `CoachMutationExecutor` returns placeholder for weight undo (**Confirmed** — subagent audit) |
| Auto-log food without confirmation | `AIResponseValidator.validateFood` always returns `.requiresConfirmation` for AI food |
| Persistent learning from user corrections beyond logged entries | No correction-memory store found; `commonFoods` derived from past logs only (**Likely**) |
| Cloud-backed nutrition restore awareness in context | Nutrition logs are device-local; `missingData` has no `restorePending` flag (**Confirmed** — `USER_DATA_STORAGE_CONTEXT_PACKET.md`) |
| Calorie ranges on pending food confirmation cards | `FoodLogDraft` uses scalar totals; ranges exist on `NutritionEstimateCardState` model but not wired in `NutritionEstimateCard` UI grep (**Likely**) |
| Barcode / packaged food scan | No scanner flow found (**Confirmed** — repo search) |

### How Coach estimates calories (**Confirmed**)

1. **Text:** User message → `CoachRouteDecider` → `estimate-food` (`AIService.estimateFood`) → `FoodExtractionResponse` validated server-side (`foodEstimateExtraction.ts`) + client (`FoodEstimateResponseValidator`, `NutritionSanityValidator`) → `FoodLogDraft` with `components[]` summing to totals.
2. **Photo:** JPEG via `CoachImagePipeline` → `analyze-meal-image` → `MealImageAnalysisResponse` with per-item macros + `needsUserReview: true` (always) → mapped to `FoodLogDraft` via `MealImageAnalysisMapper`.
3. **Local catalog:** `LocalNutritionEstimator` matches aliases → immediate pending confirmation, no API.
4. **Advice-only estimate card:** `generate-nutrition-estimate` → structured card; Log action creates pending draft.

Models: `cheap` tier (`gpt-5-nano` default) for classifier/text; `strong` tier (`gpt-5.4-nano` default) for photos and meal advice (**Confirmed** — `CoachModelConfig.default`, `functions/src/index.ts` `resolveModel`).

### How Coach analyzes meal photos (**Confirmed**)

`CoachImagePickFlowController` → `CoachImagePipeline.process` (max 500KB JPEG, 1280px longest side — `CoachImageUploadConfig.default`) → `CoachMealPhotoAnalyzer.analyze` → `CoachMealImageAIRequestBuilder` → `FormaAIBackendClient.analyzeMealImage` → validation (`MealImageAnalysisResponseValidator`, `mealImageAnalysis.ts` `validateMealImageAnalysisResponse`) → pending food confirmation + assistant analysis message.

### How Coach logs food/water/weight (**Confirmed**)

All committed mutations go through `FitnessActionCenter` (`logFood`, `logWater`, `logDailyWeight`, `editFoodEntry`, `deleteFoodEntry`) which calls `FoodLogService` / `WaterLogService` / `WeightLogService` → SwiftData → `notifyAccountDataChanged()` → `AccountDataRefreshEventBus` (when sync wired). Timeline events recorded via `CoachTimelineRecorder`.

### Edit / delete / undo (**Confirmed**)

- **Local undo:** `ParsedCommand.intent.undo` → `executeImmediately` → `CoachMutationExecutor.executeUndo`
- **AI edit/delete:** `parse-edit-delete` → pending bar → `CoachEntryReferenceResolver.resolve` using `linkedEntryId`, timeline, `recentMealsStructured`
- **Undo last:** `CoachMutationHistory.latest()` → delete entry
- **Weight undo:** Not supported

### Today / Plan / Journey integration (**Confirmed**)

- **Today:** `CoachContextPacketV2.today` from `DailyLogService`; `CoachView.refreshTodayContext()` on appear/foreground; `SmartCoachEngine` (deterministic, no AI) deep-links to Coach with prefills (`TodayCoachPrompt`)
- **Plan:** Profile targets in `CoachContextPacketV2.profile` + `today.targets`; plan changes not auto-applied from Coach without explicit parse path (**Likely** — no dedicated plan-mutation executor found in Coach)
- **Journey:** Indirect via weight/food history in context; no Journey-specific Coach endpoint (**Confirmed**)

### Uncertainty handling (**Confirmed**)

- `ConfidenceLevel` on drafts; `NutritionSanityValidator` downgrades to `.low` with warnings
- `CoachMissingDataContext` flags for HealthKit gaps
- `needsUserReview: true` hardcoded on meal image schema
- Clarification routes: `CoachRoute.clarification`, photo `clarifyingQuestion`, `CoachIntentConfidenceGate`
- Assumptions: per-item `assumptions[]` in meal image response; `CoachAssumptionContext` in packet

### Confirmation before commit (**Confirmed**)

`CoachPendingConfirmation` + `CoachConfirmationBar` + typed yes/no (`CoachPendingConfirmationPresenter.handleTextInput`) + `AIFoodConfirmationSheet` for food edit. Water/weight from local parser execute immediately; from AI parser same policy.

### Wrong estimates / correction (**Confirmed**)

- Edit pending draft before confirm (`AIFoodConfirmationSheet`)
- Photo recommission with `previousAnalysis` sent to gateway
- Post-log edit/delete via natural language
- No dedicated "correction memory" sent on subsequent turns beyond updated timeline/meals

### Trust strengths today (**Confirmed**)

- AI food always requires confirmation (`AIResponseValidator`)
- Structured context v2 with `missingData` flags
- Advice vs log intent separation (`CoachIntentConfidenceGate`, classifier prompt rules)
- Compound dish validation + Singapore fixture pack (50 cases)
- Production-safe observability (`CoachAccuracyObservability.swift`)
- Entry reference resolver reduces wrong-target edits
- Estimate vs logged visually separated (pending bar vs "Logged …" confirmation card)

### Trust weaknesses today (**Confirmed** / **Likely**)

- Scalar calorie display implies false precision (**Likely**)
- Multi-user local data leakage risk (nutrition not UID-scoped) — `USER_DATA_STORAGE_CONTEXT_PACKET.md`
- No cloud nutrition sync → Coach context empty after reinstall (**Confirmed**)
- Water/weight log without confirmation on local/AI immediate path
- Coach may advise on partial/restored data without explicit "stale restore" flag
- Long prose still possible on `mealAdvice` path (900 token limit)
- Production model accuracy unmeasured in repo (**Unknown**)

### Biggest risks

| Category | Risk |
|----------|------|
| **Accuracy** | Portion ambiguity, hidden oil/sauce, mixed plates, overconfident single numbers |
| **UX flow** | User thinks estimate = logged; duplicate confirm taps; app kill during pending |
| **Architecture** | Device-local logs vs cloud profile mismatch; context stale after cross-tab lag |

### Verdict: Current user belief strength

> "Coach can count calories faster, more accurately, and smarter than I ever can."

**Rating: Weak → Moderate (leaning Weak)**

| Dimension | Assessment |
|-----------|------------|
| **Faster** | **Moderate** — photo + one-tap confirm is fast when pipeline succeeds; clarification/retry adds friction |
| **More accurate** | **Weak** — LLM estimates with sanity checks but no proven accuracy vs manual weighing; single-point numbers |
| **Smarter** | **Moderate** — strong context (targets, remaining macros, HI, timeline) beats manual counting for situational advice |

**Why not Strong/Moderate overall:** Accuracy is the core of the belief and remains probabilistic. Confirmation helps trust but does not make estimates more accurate than a careful human with a scale. Reinstall/multi-device data loss breaks "smarter than me" continuity. Ranges and assumptions are partially implemented but not consistently surfaced in the primary log path.

---

## 2. Coach Architecture Overview

### Pipeline diagram (text)

```
┌─────────────────────────────────────────────────────────────────────────────┐
│                              USER INTERFACE                                  │
│  CoachView → CoachConversationView / CoachComposer / CoachConfirmationBar    │
│           → NutritionEstimateCard / CoachMessageView / AIFoodConfirmationSheet│
└───────────────────────────────────┬─────────────────────────────────────────┘
                                    │ CoachModel (@MainActor)
                                    ▼
┌─────────────────────────────────────────────────────────────────────────────┐
│                         ROUTING & ORCHESTRATION                              │
│  CoachRouteDecider.decide()                                                  │
│    1. LocalNoAPIGuard (greeting, deterministic commands, local food)         │
│    2. CheapLLMIntentClassifier → classify-coach-intent                       │
│    3. CoachIntentRouter → CoachRoute + CoachIntentConfidenceGate             │
│  CoachAIRouteHandler.handle() → AIService → FormaAIBackendClient → aiGateway │
└───────────────────────────────────┬─────────────────────────────────────────┘
                                    │
          ┌─────────────────────────┼─────────────────────────┐
          ▼                         ▼                         ▼
   estimate-food            analyze-meal-image      generate-nutrition-*
   parse-command             generate-meal-advice    parse-edit-delete
   parse-workout             generate-daily-review   parse-multi-action
          │                         │                         │
          ▼                         ▼                         ▼
┌─────────────────────────────────────────────────────────────────────────────┐
│                         VALIDATION LAYER                                     │
│  AIResponseValidator / FoodEstimateResponseValidator / NutritionSanityValidator│
│  MealImageAnalysisResponseValidator / ConfirmationPolicy                     │
└───────────────────────────────────┬─────────────────────────────────────────┘
                                    ▼
┌─────────────────────────────────────────────────────────────────────────────┐
│                         CONFIRMATION (optional)                              │
│  CoachPendingConfirmationPresenter → CoachPendingConfirmation enum           │
│  CoachConfirmationBar / typed confirm / AIFoodConfirmationSheet              │
└───────────────────────────────────┬─────────────────────────────────────────┘
                                    ▼
┌─────────────────────────────────────────────────────────────────────────────┐
│                         MUTATION                                             │
│  CoachMutationExecutor → FitnessActionCenter → *LogService → SwiftData       │
│  CoachTimelineRecorder → CoachTimelineStore                                  │
│  AccountDataRefreshEventBus (sync phases)                                    │
└───────────────────────────────────┬─────────────────────────────────────────┘
                                    ▼
┌─────────────────────────────────────────────────────────────────────────────┐
│                         CONTEXT BUILD (read path)                            │
│  CoachContextPacketV2Builder ← DailyLog, FoodLog, Profile, HealthKit, HI    │
└─────────────────────────────────────────────────────────────────────────────┘
```

### 2.1 Text Message Flow (**Confirmed**)

| Stage | File / Symbol |
|-------|---------------|
| Entry | `CoachView` → `CoachModel.sendCurrentMessage()` / `send(_:)` |
| Input | `CoachInputState.takeSendSnapshot()` |
| Route | `CoachRouteDecider.decide(text:context:aiService:config:)` |
| Handle | `CoachAIRouteHandler.handle(_:context:pendingConfirmation:)` |
| Context | `CoachContextPacketV2Builder.makeContext(recentMessages:currentUserMessage:)` |
| Result | `CoachActionResult` → `CoachModel.applyActionResult` |
| Persist chat | `SwiftDataCoachChatTranscriptStore` (**Confirmed**) |
| UI | `CoachMessagePresenter.presentation(for:)` |

**Error handling:** Transient classifier failure → clarification message (`CoachResponseBuilder.classifierUnavailableResponse`); other errors → `CoachErrorView` / assistant error copy.

**User-visible states:** `CoachProcessingPhase` (`.idle` / `.active(.text)`), `isSending`, `pendingConfirmation`, `isConfirmingPending`.

### 2.2 Meal Text Estimate Flow (**Confirmed**)

| Stage | Symbol |
|-------|--------|
| Route | `CoachRoute.ai(.estimateFood)` or `.classifiedFood` / `.localFoodEstimate` |
| API | `AIService.estimateFood` → `LLMEndpoint.estimateFood` → `/v1/ai/estimate-food` |
| Map | `FoodLogDraftMapper`, `AICommandParser.mapFoodEstimate` |
| Sanity | `NutritionSanityValidator.validate(meal:prompt:confidence:)` |
| Confirm | `ConfirmationPolicy.decision(for: FoodLogDraft)` → pending |
| Log | `CoachMutationExecutor.executeLogFood` → `FitnessActionCenter.logFood` |
| Refresh | `actionCenter.dataRefreshToken`, `CoachTodaySyncDebugLogger.coachMealSaved` |

### 2.3 Meal Photo Flow (**Confirmed**)

| Stage | Symbol |
|-------|--------|
| Pick | `CoachImagePickFlowController`, `CoachPhotoCapture`, PhotosPicker |
| Process | `CoachImagePipeline.process` — `CoachImageUploadConfig.default` |
| Stage | `CoachInputState` attachment, `CoachInputAttachmentPreview` |
| Send | `CoachModel.sendMealPhoto` → `ImageAnalysisSession` |
| Analyze | `CoachMealPhotoAnalyzer.analyze` → `CoachAIRouteHandler.analyzeMealPhoto` |
| API | `/v1/ai/analyze-meal-image` |
| Present | `presentAIFoodEstimate` → `CoachPendingConfirmation.food` |
| Gating | `CoachMealPhotoPipeline.isClientPipelineReady` ← `FormaAbTest.Coach.mealPhotoPipelineReady` |

### 2.4 Meal Photo Recommission / Correction Flow (**Confirmed**)

| Stage | Symbol |
|-------|--------|
| Trigger | User text during clarification session OR bar retry OR edit flow |
| Context | `ImageAnalysisRecommissionContext(clarification:previousAnalysis:)` |
| Prompt | `ImageAnalysisPromptBuilder.recommissionMessage` |
| Request | `CoachMealImageAIRequestBuilder` includes `previousAnalysis` field |
| Backend | `analyzeMealImage` body `previousAnalysis` — `mealImageAnalysis.ts` |
| Re-present | Updated `FoodLogDraft` → pending confirmation |

### 2.5 Food Commit Flow (**Confirmed**)

```
User taps Log / types "yes"
  → CoachModel.confirmPendingFromBar()
  → CoachMutationExecutor.executePendingConfirmation(.food)
  → FitnessActionCenter.logFood(FoodLogDraft)
  → FoodLogService.addFoodEntry → FoodEntryEntity + DailyLogEntity update
  → mutationHistory.record + timelineRecorder.recordFoodLogged
  → CoachResponseBuilder.food → ChatMessage confirmation presentation
  → AccountDataRefreshEventBus (if sync enabled)
```

### 2.6 Edit / Delete / Undo Flow (**Confirmed**)

| Path | Flow |
|------|------|
| Local undo | `LocalNoAPIGuard` → `ParsedCommand.undo` → immediate `executeUndo` |
| AI edit/delete | `parse-edit-delete` → `CoachEntryReferenceResolver` → pending → confirm → `executeEditAction` / `executeDeleteAction` |
| Undo (AI) | `executeUndoAction` with selector resolution |
| Food edit sheet | `AIFoodConfirmationSheet` → `saveFoodEdit` updates pending draft only |

### 2.7 Advice-Only Flow (**Confirmed**)

Intents: `nutrition_advice`, `meal_decision`, `nutrition_estimate_query`, etc. → `generate-meal-advice` or nutrition card endpoints → `CoachActionResult.message` or `.structured` → **no** `FitnessActionCenter` call.

### 2.8 Daily Review Flow (**Confirmed**)

`CoachMutationExecutor.executeDailyReview` → builds `DailyReviewAIInput` from daily log → `AIService.generateDailyReview` → saves via `ReviewService` → Today/Journey read `DailyReviewEntity` (**Confirmed** — `ReviewService.swift` uses context packet).

### 2.9 Weight Explanation Flow (**Likely**)

No dedicated endpoint. User asks "why is weight up?" → classified as `weight_loss_advice` or `nutrition_advice` → `generate-meal-advice` with `CoachContextPacketV2` weight history + HI → prose response. **No mutation.**

### 2.10 Plan Change Flow (**Likely** / **Unknown**)

No `parse-plan-change` endpoint found. Plan adjustments likely require Plan tab (`PlanModel`) or unsupported Coach path. Coach context includes targets but Coach cannot safely mutate plan without dedicated validation (**Likely**).

---

## 3. Coach Capability Inventory

| Capability | Supported? | Entry Point | AI/Local Path | Mutates Data? | Confirmation? | Accuracy Risk | Trust Risk | Files |
|-----------|------------|-------------|---------------|---------------|---------------|---------------|------------|-------|
| Greeting / general chat | Yes | `LocalNoAPIGuard` | Local | No | No | Low | Low | `CoachRouteDecider.swift`, `LocalNoAPIGuard.swift` |
| Food text logging | Yes | `send(_:)` | `estimate-food` / local | Yes | **Always** for AI | High | Medium | `AIService.swift`, `ConfirmationPolicy.swift` |
| Food text estimate only | Yes | `nutrition_estimate_query` | `generate-nutrition-estimate` | No | N/A | Medium | Low | `NutritionEstimateCard.swift` |
| Meal photo estimate | Yes | `sendMealPhoto` | `analyze-meal-image` | No until confirm | Yes | High | Medium | `CoachMealPhotoAnalyzer.swift` |
| Meal photo logging | Yes | confirm pending | Same + mutation | Yes | Yes | High | Medium | `CoachMutationExecutor.swift` |
| Photo correction/recommission | Yes | clarification / retry | `analyze-meal-image` + `previousAnalysis` | No until confirm | Yes | Medium | Low | `ImageAnalysisSession.swift` |
| Food edit | Yes | `parse-edit-delete` | AI + resolver | Yes | Yes | Medium | Medium | `CoachEntryReferenceResolver.swift` |
| Food delete | Yes | same | same | Yes | Yes | Low | Medium | same |
| Undo last food | Yes | local / AI undo | Local / `parse-edit-delete` | Yes | Local: No; AI: Yes | Medium | Medium | `CoachMutationExecutor.executeUndo` |
| Water logging | Yes | local / AI | `parse-command` | Yes | **No** (immediate) | Low | Medium | `ConfirmationPolicy.swift` L19-20 |
| Weight logging | Yes | local / AI | same | Yes | **No** (immediate) | Low | Medium | same |
| Workout logging | No | — | Redirect | No | — | — | Low | `TrainingIntegrationCopy` |
| Daily review | Yes | `executeDailyReview` | `generate-daily-review` | Yes (review entity) | No | Medium | Low | `CoachMutationExecutor.swift` |
| Meal advice | Yes | `mealAdvice` route | `generate-meal-advice` | No | No | Medium | Medium | `CoachAIRouteHandler.swift` |
| Nutrition comparison | Yes | `nutrition_comparison_query` | `generate-nutrition-comparison` | No | N/A | Medium | Low | `NutritionComparisonCard.swift` |
| Plan adjustment | No/Limited | — | — | — | — | — | — | **Unknown** |
| Weight trend explanation | Partial | advice intent | `generate-meal-advice` | No | No | Medium | Medium | **Likely** |
| Journey explanation | Partial | advice + context | prose | No | No | Medium | Medium | **Likely** |
| Sync/restore awareness | No | — | — | No | — | High | High | `USER_DATA_STORAGE_CONTEXT_PACKET.md` |
| Account/privacy awareness | Partial | Settings | — | No | — | Low | Medium | Account deletion WIP in git status |
| Navigation to screens | Partial | launch intents | Local | No | No | Low | Low | `CoachLaunchIntent.swift` |
| Clarifying questions | Yes | classifier / photo | AI | No | No | Low | Low | `CoachRoute.clarification` |
| Confidence bands | Yes | drafts + cards | AI + validators | No | N/A | Medium | Medium | `ConfidenceLevel`, `NutritionEstimateCard` |
| Assumption display | Partial | image items | AI | No | N/A | Medium | Medium | `MealImageAnalysisItem.assumptions` |
| Error recovery | Yes | retry buttons | — | No | No | — | Medium | `CoachMessageView` retry |
| Offline behavior | Partial | `UnavailableLLMClient` | — | No | — | — | High | `FallbackLLMClient.swift` |

---

## 4. Current Coach Data Access

| Data Source | In Context? | File/Builder | Fields Included | Fields Missing | Accuracy Impact |
|------------|-------------|--------------|-----------------|----------------|-----------------|
| User profile | Yes | `CoachContextPacketV2Builder` | age, sex, height, weight, goal, activity, training freq, goalType | diet preferences detail (**Likely** partial) | Medium |
| Calorie/macro targets | Yes | `today.targets` | calorie, P/C/F, water targets | — | High |
| Today totals | Yes | `today.nutrition/hydration` | consumed, remaining, over-target flags | — | High |
| Recent meals | Yes | `recentMealsStructured` | name, macros, mealType, linkedEntryId | image URLs stripped | High |
| Common foods | Yes | `CoachContextFoodMemoryBuilder` | frequent foods + typical macros | user corrections | Medium |
| Water intake | Yes | `today.hydration` | ml consumed/remaining | — | Medium |
| Weight history | Partial | `today.weight`, profile | today's weight | full trend series (**Likely** limited) | Medium |
| Journey trend | Indirect | HI + weight | readiness, load | journey milestones | Low |
| Plan targets | Yes | profile + today.targets | same as plan | plan edit history | Medium |
| HealthKit steps | Yes | `CoachContextSourcedInt` | value, source, confidence | — | Medium |
| Workouts | Yes | `training.workouts` | summaries | — | Medium |
| Sleep / HRV | Yes (HI) | `healthIntelligence` | recovery signals | raw samples | Medium |
| Sync/restore state | **No** | — | — | pending sync, restore phase | **High** |
| Pending local mutations | Partial | timeline pending events | `pendingConfirmationCreated` | outbox detail | Medium |
| Prior Coach messages | Yes | `recentChatMessages` | text previews, no images | — | Low (tone only) |
| Prior photo analyses | Partial | timeline photo events | summaries | full prior JSON unless recommission | Medium |
| Corrections | **No** | — | — | explicit correction memory | Medium |
| Failed estimates | **No** | excluded | — | rejected/failed timeline filtered | Low |
| User preferences | Partial | profile | activity level | theme, units in context (**Likely** meta only) | Low |
| Account state | Partial | auth gating | — | mismatch, deletion | Medium |

### Context awareness questions

| Question | Answer | Confidence |
|----------|--------|------------|
| Does Coach know when data is missing? | Yes — `missingData` flags | **Confirmed** |
| Distinguishes real zero from missing? | Steps: `stepsMissing` vs value 0; workouts: nil vs 0 | **Confirmed** — `COACH_ACCURACY_HARDENING_FINAL_REPORT.md` §3 |
| Knows HealthKit unavailable? | `healthKitDenied`, `healthKitUnavailable`, `stepsUnavailable` | **Confirmed** |
| Knows logs restored/synced? | No explicit flag | **Confirmed** |
| Knows Today/Journey stale? | No stale timestamp in packet | **Likely** |
| Knows partial data? | `generationMode: .degraded`, fallback builder | **Confirmed** |

---

## 5. Coach Context Packet Analysis

**Type:** `CoachContextPacketV2` — `Fitness Coach/Infrastructure/AI/CoachContextPacketV2.swift`  
**Schema version:** `2` (`CoachContextPacketV2.schemaVersion`)  
**Builder:** `CoachContextPacketV2Builder.makeContext` — `Application/StateBuilders/Coach/CoachContextPacketV2Builder.swift`  
**Fallback:** `CoachContextPacketV2FallbackBuilder` + `CoachContextCorrectnessValidator`  
**Server:** `functions/src/coachContextPacketV2.ts` — `validateCoachContextPacketV2`, `parseCoachContextForPrompt`

### Limits (**Confirmed**)

| Limit | Value | Source |
|-------|-------|--------|
| Encoded JSON max | 24,576 bytes | `CoachContextPacketV2Limits.defaultMaxEncodedBytes` |
| Timeline events (gateway) | 20 | `coachContextPacketV2.ts` |
| Timeline events (iOS transport clamp) | 40 | `CoachContextPacketV2Builder.defaultTimelineEventLimit` = 20 builder; compaction policy |
| Recent chat | 12 | builder constant |
| Recent meals | 10 | `CoachContextPacketV2Limits.maxRecentMeals` |
| Common foods | 10 | limits struct |
| Event summary | 180 chars | `COACH_CONTEXT_PACKET_V2.md` |

### Compaction (**Confirmed**)

`CoachContextPacketV2TimelineCompactionPolicy`, `CoachContextPacketV2SizeCompactor` — protects confirmed food/water/weight/photo events.

### Context field table (selected)

| Context Field | Source | Accuracy Benefit | Hallucination Risk | Missing/Degraded Behavior |
|--------------|--------|------------------|--------------------|---------------------------|
| `today.nutrition.caloriesRemaining` | `DailyLogService` | High — budget advice | Model ignores and guesses | Omitted if log read fails → `missingData` |
| `recentMealsStructured` | `FoodLogService` | High — edit targets | Confuse with chat | `noRecentMeals` flag |
| `timeline.recentEvents` | `CoachTimelineStore` | High — "that meal" resolution | Stale event summaries | `noTimelineHistory` |
| `commonFoods` | `CoachContextFoodMemoryBuilder` | Medium — repeat meals | Wrong typical portion | Empty array |
| `healthIntelligence` | HI engines | Medium — recovery advice | Overclaim causality | Timeout → flag + omit section |
| `recentChatMessages` | transcript | Low — tone | **High if treated as facts** | Prompt rules forbid |
| `steps` (`CoachContextSourcedInt`) | HealthKit | Medium | Treat missing as 0 | `stepsMissing` / `stepsUnavailable` |
| `training.workoutsToday` | HealthKit | Medium | — | nil when denied |
| `assumptions` | builder metadata | Medium | — | Empty |
| `generationMode` | builder | Signals degraded context | Model may ignore | `.degraded` on fallback |

### Identified risks (**Confirmed** / **Likely**)

| Risk | Label |
|------|-------|
| Zero vs missing for nutrition totals when log empty | **Likely** — consumed may be 0 legitimately; `noRecentMeals` helps meals not totals |
| Chat treated as truth | Mitigated by prompt rules — **Confirmed** |
| Stale context if Today not refreshed before send | **Likely** — builder reads live SwiftData at send time |
| UI vs context mismatch after mutation | Mitigated by `dataRefreshToken` — **Confirmed** `CoachTodaySyncTests` |
| No user correction memory | **Confirmed** gap |
| Context bloat reducing model focus | Mitigated by 24KB compaction — **Confirmed** |

---

## 6. AI Backend and Prompt Inventory

**Gateway:** Single export `aiGateway` → `handleAiGatewayRequest` — `functions/src/index.ts`  
**Auth:** Firebase ID token; timeout 90s server / 45s client request — **Confirmed**

| Endpoint | Purpose | Request DTO (iOS) | Response DTO | Model Tier | Reasoning | Prompt Builder | Validation | Fallback | Risk |
|---------|---------|-------------------|--------------|------------|-----------|----------------|------------|----------|------|
| `classify-coach-intent` | Intent routing | `AICoachIntentClassificationRequest` | `CoachIntentResult` | cheap | GPT-5 env | `coachIntentClassificationInstructions()` | schema + `sanitizeCoachIntentResult` + phrase guard | clarification UI | Misroute advice→log |
| `parse-command` | Structured commands | `AIParseCommandRequest` | `AIParsedCommand` | cheap | same | `commandInstructions()` | JSON schema | error | Multi-action ambiguity |
| `estimate-food` | Text/photo food extract | `AIFoodEstimateRequest` | `AIFoodEstimateResponse` | strong if image else cheap | same | `foodEstimateInstructions()` / `foodPhotoEstimateInstructions()` | `validateFoodExtraction` + 1 retry | repair pass | Portion error |
| `analyze-meal-image` | Vision meal analysis | `AIMealImageAnalysisRequest` | `AIMealImageAnalysisResponse` | strong | same | `mealImageAnalysisInstructions()` | payload + response validation | 422 error | Overconfidence |
| `generate-meal-advice` | Prose coaching | `AIMealAdviceRequest` | `AICoachResponse` | strong (default) | same | `mealAdviceInstructions()` | schema | error message | Long/hallucinated prose |
| `generate-nutrition-estimate` | Estimate card | `AINutritionEstimateRequest` | `NutritionEstimateResponse` | cheap | same | `nutritionEstimateInstructions()` | schema + sanitizer | error | False precision |
| `generate-nutrition-comparison` | Comparison card | `AINutritionComparisonRequest` | `NutritionComparisonResponse` | cheap | same | `nutritionComparisonInstructions()` | sanitizer | error | Same |
| `generate-daily-review` | EOD review | `AIDailyReviewRequest` | `AICoachResponse` | cheap | same | `dailyReviewInstructions()` | requires `input` | error | Generic review |
| `parse-workout` | Workout draft | `AIWorkoutParseRequest` | `AIWorkoutParseResponse` | cheap | same | `workoutParseInstructions()` | schema | blocked in UI | N/A (unused) |
| `parse-edit-delete` | Edit/delete parse | `AIEditDeleteParseRequest` | `AIParsedCommand` | cheap | same | `editDeleteInstructions()` | schema | clarify | Wrong target |
| `parse-multi-action` | Multi-step | `AIMultiActionParseRequest` | `AIParsedCommand` | cheap | same | `multiActionInstructions()` | schema | confirm | Partial execution |

**Temperature:** Not set anywhere — **Confirmed**  
**Reasoning effort:** `OPENAI_REASONING_EFFORT` default `low` for GPT-5 models — `openAIReasoningEffort.ts`  
**Image handling:** Base64 JPEG/PNG; max 1.5M chars b64 gateway; client 500KB JPEG — **Confirmed**  
**Logging:** `CoachAccuracyObservability` redacted; DEBUG loggers may include food names — **Confirmed**  
**Hallucination prevention:** Strict JSON schema, server sanitizers, client validators, confirmation gate, context prompt rules (`coachContextV2Rules`)

### Configuration risks

| Risk | Label |
|------|-------|
| `OPENAI_FALLBACK_MODEL` defined but unused | **Confirmed** |
| Production model names env-dependent | **Unknown** |
| Schema drift iOS ↔ TS | Mitigated by contract tests — **Confirmed** |
| `mealAdvice` returns free text | **Confirmed** — by design |

---

## 7. Calorie Estimation Accuracy Audit

| Accuracy Factor | Current Handling | Evidence | Risk | Recommended Improvement |
|----------------|------------------|----------|------|-------------------------|
| Portion ambiguity | Clarifying questions (photo); medium confidence default | `mealImageAnalysis` schema, `CoachIntentConfidenceGate` | High | Mandatory portion chips |
| Hidden oil/sauce | Compound decomposition prompts; sanity floors | `foodCompoundDish.ts`, `NutritionSanityValidator` | High | Explicit sauce assumption UI |
| Rice/noodle serving | Component model + SG fixtures | `singapore_food_estimation_cases.json` | High | Region default portions |
| Fried vs grilled | Prompt hints only | `coachPromptInstructions.ts` | Medium | User toggle |
| Drink calories | Separate components | extraction schema | Medium | Liquid volume prompts |
| Mixed dishes | Multi-component required | `FoodLogDraft.isMultiComponent` | High | Collapsed dish detection |
| Hawker/SG food | 50-case fixture pack | `SingaporeFoodEstimationFixtureTests` | Medium | Expand + monitor |
| Visual size estimation | Vision model only | `analyze-meal-image` | High | Range display |
| No scale reference | Assumptions array | `MealImageAnalysisItem` | High | Portion clarification |
| Calorie ranges | Model fields exist for cards; log path single int | `NutritionEstimateModels.caloriesRange*` | High | Show ranges on pending card |
| Macro consistency | 15% tolerance check | `NutritionSanityValidator.macroTolerance` | Medium | Reject on fail |
| User trust copy | Warnings array on draft | `FoodLogDraft.warnings` | Medium | Prominent warnings UI |
| "I'm not sure" | low confidence + review gate | `needsUserReview: true` | Low | — |
| Clarification when needed | Photo `clarifyingQuestion`; classifier clarify | multiple | Medium | Text portion clarify |
| Learn from correction | **No** persistent memory | — | High | Correction memory in context |
| Compare to remaining macros | In context `today.nutrition` | packet | Low | Surface in card UI |
| Overconfidence | Sanity downgrade to low | `NutritionSanityValidator` | Medium | Block auto-present high |

### Specific answers

| Question | Answer | Confidence |
|----------|--------|------------|
| Range or single number? | **Single** on log path; ranges in estimate card model underused in UI | **Confirmed** / **Likely** |
| Shows assumptions? | Photo items yes; pending bar partial | **Confirmed** |
| Identifies uncertainty sources? | warnings + confidence | **Partial** |
| Portion clarification when needed? | Photo yes; text inconsistent | **Likely** |
| Fast correction? | Edit sheet + recommission | **Confirmed** |
| Learns from correction? | **No** (only via new log → commonFoods) | **Likely** |
| Compares to remaining macros? | Context yes; UI inconsistent | **Likely** |
| Avoids overconfidence? | Partial — sanity + confirmation | **Confirmed** |

---

## 8. Meal Photo Accuracy Pipeline

| Stage | File/Type | What Happens | Accuracy Risk | UX Trust Risk |
|------|-----------|--------------|---------------|---------------|
| Camera/picker entry | `CoachImagePickFlowController` | permission + pick | — | Permission denial |
| Preview | `CoachInputAttachmentPreview` | thumbnail shown | — | Low |
| Delete before send | `CoachInputState` clear attachment | user can remove | — | Low |
| Compression | `CoachImagePipeline` | scale + JPEG quality steps | Detail loss | Medium |
| Max dimensions | 1280px / 500KB | `CoachImageUploadConfig` | Underestimate small portions | Low |
| Base64 payload | `CoachMealImageUploadAttachment` | MIME jpeg | — | — |
| Caption | `session.userCaption` | sent as `message` | Ambiguity | Medium |
| Previous analysis | `previousAnalysis` on recommission | refinement | Low | Low |
| Response parse | `MealImageAnalysisResponseValidator` | strict | Bad JSON rejected | Error message |
| Estimate display | assistant photo analysis message | prose + metrics | False precision | Medium |
| Confirmation | `CoachConfirmationBar` | explicit Log | Skip risk | Low |
| Commit | `executeLogFood` | SwiftData | — | Low |
| Failure | `appendMealPhotoFailureMessage` + retry | recoverable | — | Medium |

### Photo flow Q&A (**Confirmed** unless noted)

| Question | Answer |
|----------|--------|
| See image before sending? | **Yes** — attachment preview |
| See image in chat after send? | **Yes** — `CoachChatPhotoMessageView` |
| Remove before send? | **Yes** |
| Correct estimate? | **Yes** — edit sheet, clarification, recommission |
| Recommission? | **Yes** — `retryMealPhotoAnalysis`, clarification path |
| Previous analysis sent? | **Yes** — `previousAnalysis` field |
| Analysis vs logged distinct? | **Yes** — pending bar vs "Logged" card |
| Image failure trust? | Retry button + human copy — **Likely** good |
| Estimates too confident? | **Likely** — scalar totals despite `needsUserReview` |

---

## 9. Food Logging User Flow Audit

| Flow | Steps | Confirmation? | Failure State | Correction Path | Trust Risk |
|------|-------|---------------|---------------|-----------------|------------|
| Text log from Today | Today → Coach launch intent → send | Yes (AI) | error message | edit/delete | Low |
| Text log from Coach | send → classify → estimate → pending → confirm | Yes | pending stuck | sheet / discard | Medium |
| Photo log from Coach | pick → send → analyze → pending → confirm | Yes | analysis failed + retry | recommission | Medium |
| Estimate-only question | nutrition card, no pending until Log tap | N/A | parse fail | re-ask | Low |
| Advice-only | meal advice prose | No | — | — | Low |
| Edit after log | parse-edit-delete → pending | Yes | resolver clarify | — | Medium |
| Delete after log | same | Yes | blocked message | — | Medium |
| Undo | local immediate / AI pending | AI: Yes | unsupported weight | — | Medium |
| Multi-food meal | multi-component draft | Yes | validation fail | edit sheet | Medium |
| Duplicate logs | `completedPendingConfirmationIDs` | — | double tap | idempotent message | Medium |
| Failed logs | error in chat | — | retry | — | Low |
| Offline logs | local SwiftData works; AI needs network | — | backend unavailable | queue? **No** | High |
| Sync pending | outbox WIP (git status) | — | stale other device | **Unknown** | High |

### Confusion points (**Confirmed** / **Likely**)

| Confusion | Where |
|-----------|-------|
| Estimated but not logged | Nutrition estimate card without tapping Log — **Confirmed** by design |
| Logged but user didn't confirm | Should not happen for AI food — **Confirmed** blocked |
| Duplicate logs | Rapid double confirm — mitigated by `completedPendingConfirmationIDs` — **Confirmed** |
| App kill during pending | Pending lost; no auto-log — **Likely** |
| Coach stale after restore | No nutrition in cloud yet — **Confirmed** |
| Today not refreshing | Mitigated by refresh token tests — **Confirmed** `CoachTodaySyncTests` |

---

## 10. Coach Response UI and Trust Audit

| Response Type | UI Component | Structured? | Actionable? | Shows Confidence? | Shows Assumptions? | Trust Risk |
|--------------|--------------|-------------|-------------|-------------------|--------------------|------------|
| Plain assistant text | `CoachMessageView` | No | Partial | Rare | No | Medium |
| Food estimate (pending) | `CoachConfirmationBar` | Semi | Yes | Partial | Partial | Medium |
| Nutrition estimate card | `NutritionEstimateCard` | Yes | Yes (chips) | Yes | Partial | Low |
| Nutrition comparison card | `NutritionComparisonCard` | Yes | Yes | Yes | Partial | Low |
| Photo user bubble | `CoachChatPhotoMessageView` | — | — | — | — | Low |
| Photo analysis | `assistantPhotoAnalysis` | Semi | Retry | Partial | Partial | Medium |
| Logged confirmation | inline metrics card | Yes | No | No | No | Low |
| Daily review | prose / structured | Partial | — | — | — | Medium |
| Clarification | assistant text | No | User replies | No | No | Low |
| Error | `CoachErrorView` / assistant | No | Retry | No | No | Medium |

### UI trust Q&A

| Question | Answer |
|----------|--------|
| Easy to scan? | Cards yes; prose variable — **Likely** |
| Calorie numbers prominent? | Yes on confirmation bar + cards — **Confirmed** |
| Assumptions visible? | Partial — **Likely** |
| Corrections easy? | Edit sheet + recommission — **Confirmed** |
| Logged vs estimated distinct? | Yes — **Confirmed** |
| Risky actions confirmed? | Food/edit/delete yes; water/weight no — **Confirmed** |
| Errors recoverable? | Retry on photo/classifier — **Confirmed** |
| Giant paragraphs possible? | Yes on meal advice — **Confirmed** |
| Source of truth after log? | SwiftData `FoodEntryEntity` + Today — **Confirmed** |

---

## 11. Coach Mutation Safety Audit

| Mutation | Path | Confirmation | Validation | UID Safe | Sync Safe | Undo Safe | Risk |
|---------|------|--------------|------------|----------|----------|-----------|------|
| Log food | `actionCenter.logFood` | Yes (AI) | `AIResponseValidator` + services | `requireCurrentUID` | Outbox WIP | undo last | Medium |
| Edit food | `editFoodEntry` | Yes | resolver + service | same | WIP | no dedicated undo | Medium |
| Delete food | `deleteFoodEntry` | Yes | resolver | same | WIP | no | Medium |
| Log water | `logWater` | **No** | amount bounds | same | WIP | undo | Low |
| Log weight | `logDailyWeight` | **No** | > 0 | same | WIP | **No** | Low |
| Daily review | `ReviewService` | No | input builder | **Likely** | local | — | Low |
| Update plan | Not via Coach executor | — | — | — | — | — | — |
| Workout log | Blocked | — | — | — | — | — | — |

### Flags (**Confirmed**)

| Issue | Present? |
|-------|----------|
| Bypasses `FitnessActionCenter` | **No** for food/water/weight |
| Bypasses UID scoping | **Partial** — action center checks UID; entities lack ownerUID |
| Bypasses sync outbox | **Likely** during migration |
| No UI refresh | **No** — refresh token |
| Ambiguous target | Mitigated by resolver |
| Duplicate entries | Mitigated by pending ID set |
| No confirmation when risky | Water/weight immediate |

---

## 12. Coach Trust and Accuracy Failure Modes

| Priority | Failure Mode | User Impact | Current Prevention | Gap | Recommended Fix |
|---------|--------------|-------------|--------------------|-----|-----------------|
| P0 | Overconfident calorie logged | Wrong daily total | confirmation + sanity | single precise number | ranges + block high-risk |
| P0 | Photo logged without clear confirm | Trust break | pending bar | user confusion estimate vs log | stronger visual states |
| P0 | Coach says logged but write failed | Data lie | error copy | edge error paths | verify read-back |
| P0 | Wrong meal edited/deleted | Data loss | resolver | ambiguous "that" | disambiguation UI |
| P0 | Stale Today totals in advice | Bad guidance | live builder | no stale flag | refresh + timestamp |
| P1 | Wrong portion size | Calorie error | clarification | inconsistent text | portion UI |
| P1 | Hidden oil/sauce missed | Underestimate | compound rules | vision limits | sauce prompt + range |
| P1 | Mixed dish misidentified | Wrong macros | decomposition | vision | multi-pass |
| P1 | Duplicate log | Inflated calories | idempotent pending | race | disable confirm during save |
| P1 | Sync fail silent | Cross-device drift | WIP sync | not shipped | outbox + UI badge |
| P1 | Restored partial data | Wrong advice | missingData partial | no restore flag | restore awareness |
| P2 | Classifier misroute | Wrong flow | gate + sanitizer | edge intents | fixture expansion |
| P2 | Timeout | Frustration | client 45s | no offline queue | cached offline |
| P2 | HealthKit zero confusion | Wrong advice | missing flags | — | already improved |
| P2 | Daily review generic | Low value | structured input | — | richer input |
| P2 | Long prose | Unscannable | cards for estimates | meal advice | tighten schema |

---

## 13. Accuracy Guardrails and Validation

| Guardrail | Location | Protects Against | Strength | Gap |
|----------|----------|------------------|----------|-----|
| Local no-API guard | `LocalNoAPIGuard.swift` | needless API calls | Strong | — |
| Classifier confidence gate | `CoachIntentConfidenceGate.swift` | risky mutations | Medium | threshold tuning |
| Food extraction validation | `foodEstimateExtraction.ts` | bad JSON/macros | Strong | vision edge cases |
| Nutrition sanity | `NutritionSanityValidator.swift` | underestimated composites | Medium | doesn't block log |
| AI response validator | `AIResponseValidator.swift` | incomplete drafts | Strong | always confirms food |
| Meal image validator | `MealImageAnalysisResponseValidator.swift` | bad vision output | Medium | — |
| Macro consistency | 15% tolerance | inconsistent totals | Medium | warn only |
| Gateway body limits | `gatewayGuardrails.ts` | abuse | Strong | — |
| Rate limits | 30/min, 400/day | cost/abuse | Medium | — |
| Context size 24KB | client + server | prompt overflow | Strong | — |
| Compound dish rules | `foodCompoundDish.ts` | collapsed meals | Medium | — |
| Generic food name rejection | `mealImageAnalysis.ts` `GENERIC_FOOD_NAME_PATTERN` | lazy labels | Medium | — |
| Duplicate classify dedup | `CoachRouteDecider` 8s window | double API | Weak | user confusion |

### Recommendations

| Estimate type | Should… |
|---------------|---------|
| Ambiguous portion | Ask clarification |
| Photo meal | Confirm + show assumptions |
| Hawker mixed plate | Show range + components |
| Sanity fail | Block or force low + edit |
| High calorie single item | Second confirm |
| Advice query | No log path |

---

## 14. Evaluation and Test Coverage Audit

### iOS Coach tests (80 files matching `Coach*.swift` — **Confirmed**)

| Test File | Covers | Accuracy | Flow | Trust | Missing |
|----------|--------|----------|------|-------|---------|
| `CoachFoodLoggingRegressionTests` | compound logging | Yes | Yes | Partial | live AI |
| `CoachMealPhotoAnalysisTests` | photo pipeline | Yes | Yes | Partial | real images |
| `CoachRoutingTests` | intent routes | Partial | Yes | Partial | — |
| `CoachContextPacketV2BuilderTests` | context assembly | Yes | Partial | Partial | restore |
| `CoachContextCorrectnessValidatorTests` | packet rules | Yes | No | Yes | — |
| `CoachEntryReferenceResolverTests` | edit/delete targets | Partial | Yes | Yes | — |
| `CoachTodaySyncTests` | UI refresh after log | Partial | Yes | Yes | — |
| `CoachImageWorkflowE2ETests` | image E2E | Partial | Yes | Yes | — |
| `SingaporeFoodEstimationFixtureTests` | SG ranges | Yes | No | Partial | live AI |
| `NutritionSanityValidatorTests` | sanity rules | Yes | No | Partial | — |
| `FoodEstimateResponseValidatorTests` | extraction | Yes | No | Partial | — |
| `CoachV2ResponseHandlingTests` | decode | Partial | Partial | Partial | — |
| `CoachAccuracyObservabilityTests` | telemetry | No | No | Yes | — |
| `CoachIntentRegressionFixtureTests` | classifier fixtures | Partial | Yes | Partial | — |

### Firebase tests (21 files — **Confirmed**)

| Test File | Covers |
|----------|--------|
| `aiGateway.contract.test.ts` | all 11 routes + context |
| `foodEstimateExtraction.test.ts` | extraction validation |
| `foodCompoundDish.test.ts` | compound rules |
| `foodLoggingGolden.test.ts` | 36 golden cases |
| `mealImageAnalysis.test.ts` | image response validation |
| `singaporeFoodEstimationFixture.test.ts` | 206 assertions on 50 cases |
| `coachContextV2Contract.test.ts` | schema contract |
| `coachPromptSnapshots.test.ts` | prompt regression |

### Notably missing tests (**Confirmed** gaps)

- Live OpenAI accuracy benchmarks
- Real photo accuracy suite in CI
- Plan change from Coach
- Offline queue behavior
- Multi-device sync + Coach context freshness
- User correction memory
- Latency SLA tests
- Production model config verification

---

## 15. Manual Accuracy Benchmark Set

### 15.1 Text Meal Prompts (50)

| # | Prompt | Expected Behavior | Clarify? | Log? | Advise? | Confidence | UI Card | Calorie Range (kcal) |
|---|--------|-------------------|----------|------|---------|------------|---------|---------------------|
| 1 | log chicken rice | decompose rice+chicken+sauce, pending | Maybe portion | After confirm | No | medium | pending bar | 450–750 |
| 2 | log roasted chicken rice | higher fat assumption | Maybe | After confirm | No | medium | pending | 480–820 |
| 3 | log steamed chicken rice | lower fat | Maybe | After confirm | No | medium | pending | 400–700 |
| 4 | log nasi lemak | coconut rice + sambal + egg | Yes sides | After confirm | No | medium | pending | 500–900 |
| 5 | log char kway teow | oily noodle dish | Yes portion | After confirm | No | medium | pending | 600–950 |
| 6 | log laksa | coconut broth | Yes size | After confirm | No | medium | pending | 450–800 |
| 7 | log bak chor mee | noodle + minced pork | Maybe | After confirm | No | medium | pending | 450–750 |
| 8 | log fish soup noodles | soup + fish | Maybe | After confirm | No | medium | pending | 350–600 |
| 9 | log roti prata plain | 2 pieces | Yes count | After confirm | No | medium | pending | 300–500 |
| 10 | log prata egg | with egg | Yes count | After confirm | No | medium | pending | 350–550 |
| 11 | log mee goreng | fried noodles | Maybe | After confirm | No | medium | pending | 550–900 |
| 12 | log hainanese curry rice | mixed plate | Yes components | After confirm | No | low-medium | pending | 600–1000 |
| 13 | log duck rice | rice + duck | Maybe | After confirm | No | medium | pending | 550–850 |
| 14 | log thunder tea rice | leicha | Maybe | After confirm | No | medium | pending | 400–650 |
| 15 | log yong tau foo | variable items | **Yes** | After confirm | No | low | pending | 400–900 |
| 16 | log caifan 2 meat 1 veg | economy rice | **Yes** items | After confirm | No | low | pending | 500–900 |
| 17 | log mala xiang guo | oily + customizable | **Yes** | After confirm | No | low | pending | 700–1200 |
| 18 | log bubble tea less sugar | drink | Yes size | After confirm | No | medium | pending | 250–450 |
| 19 | log kopi o | coffee | No | After confirm | No | high | pending | 80–120 |
| 20 | log milo dinosaur | drink | Yes size | After confirm | No | medium | pending | 200–350 |
| 21 | log 200g chicken breast grilled | exact grams | No | After confirm | No | high | pending | 300–360 |
| 22 | log chicken breast | ambiguous portion | **Yes** | After confirm | No | medium | pending | 150–350 |
| 23 | log meal prep: 150g rice 120g chicken broccoli | multi | Maybe | After confirm | No | medium | pending | 450–650 |
| 24 | log big mac meal | packaged | Maybe fries drink | After confirm | No | medium | pending | 900–1200 |
| 25 | log subway 6 inch turkey | chain | Maybe sauce | After confirm | No | medium | pending | 280–380 |
| 26 | log salad with sesame dressing | dressing risk | Yes dressing amt | After confirm | No | medium | pending | 350–700 |
| 27 | log caesar salad | creamy dressing | Yes | After confirm | No | medium | pending | 400–800 |
| 28 | log tiramisu | dessert | Maybe portion | After confirm | No | medium | pending | 350–550 |
| 29 | log ice cream 2 scoops | dessert | Maybe | After confirm | No | medium | pending | 300–500 |
| 30 | log brownie | dessert | Maybe | After confirm | No | medium | pending | 250–450 |
| 31 | how many calories in chicken rice | estimate only | No | **No** | Yes | medium | estimate card | 450–750 |
| 32 | estimate pad thai but don't log | estimate only | No | **No** | Yes | medium | estimate card | 500–800 |
| 33 | can I eat dessert tonight? | advice | Maybe context | No | Yes | — | prose/card | — |
| 34 | log breakfast: 2 eggs toast butter | multi | Maybe butter amt | After confirm | No | medium | pending | 350–550 |
| 35 | log oatmeal with banana | multi | Maybe portion | After confirm | No | medium | pending | 250–450 |
| 36 | log protein shake 1 scoop | supplement | Maybe | After confirm | No | high | pending | 120–200 |
| 37 | log fries large | side | Maybe | After confirm | No | medium | pending | 400–600 |
| 38 | log small fries | side | No | After confirm | No | medium | pending | 200–350 |
| 39 | log sushi 8 pieces salmon | count-based | Maybe | After confirm | No | medium | pending | 300–500 |
| 40 | log ramen tonkotsu | restaurant | Yes size | After confirm | No | medium | pending | 600–950 |
| 41 | log pepper lunch beef rice | sizzling oil | Maybe | After confirm | No | medium | pending | 650–950 |
| 42 | log 1 bowl wanton mee | hawker | Maybe | After confirm | No | medium | pending | 400–650 |
| 43 | log 3 wings fried | fried | Yes count | After confirm | No | medium | pending | 300–500 |
| 44 | log grilled salmon 180g | exact | No | After confirm | No | high | pending | 350–420 |
| 45 | log avocado toast | brunch | Maybe | After confirm | No | medium | pending | 350–550 |
| 46 | actually the chicken was 300g | correction | No | After confirm | No | medium-high | pending | 480–540 |
| 47 | log same as yesterday lunch | memory | **Yes** if ambiguous | After confirm | No | medium | pending | — |
| 48 | log 1 serving pasta aglio olio | oily pasta | Maybe oil | After confirm | No | medium | pending | 500–800 |
| 49 | log vending machine sandwich | packaged | Maybe | After confirm | No | medium | pending | 300–450 |
| 50 | log 500ml full cream milk | liquid | No | After confirm | No | high | pending | 300–330 |

### 15.2 Meal Photo Scenarios (30)

| # | Scenario | Expected | Clarify? | Log? | Confidence |
|---|----------|----------|----------|------|------------|
| 1 | Single chicken rice plate top-down | decompose 3+ components | Maybe | After confirm | medium |
| 2 | Mixed economy rice 3 items | multiple items | Yes | After confirm | low-medium |
| 3 | Rice + protein + veg bento | compartment tray | Maybe | After confirm | medium |
| 4 | Rice + protein + dessert side | include dessert | Yes | After confirm | medium |
| 5 | Drink + food together | separate items | Maybe drink size | After confirm | medium |
| 6 | Hidden sauce pool on plate | note sauce assumption | Yes | After confirm | low |
| 7 | Poor lighting dark restaurant | lower confidence | Yes | After confirm | low |
| 8 | Partial plate cropped | missing food edge | **Yes** | After confirm | low |
| 9 | Two plates in frame | **Yes** which plate | **Yes** | After confirm | low |
| 10 | Char kway teow hawker | oily noodles | Maybe | After confirm | medium |
| 11 | Nasi lemak wrapped banana leaf | components | Maybe | After confirm | medium |
| 12 | Meal prep containers 3 boxes | multiple meals? | **Yes** | After confirm | low |
| 13 | Salad with dressing on side | include dressing optional | Yes | After confirm | medium |
| 14 | Burger + fries + soda | fast food combo | Maybe drink | After confirm | medium |
| 15 | Pizza 2 slices on plate | count slices | Maybe | After confirm | medium |
| 16 | Sushi platter 12 pieces | count-based | Maybe | After confirm | medium |
| 17 | Soup noodle close-up | broth calories | Maybe | After confirm | medium |
| 18 | Smoothie cup only | drink | Maybe size | After confirm | medium |
| 19 | Coffee latte art | milk calories | Maybe size | After confirm | medium |
| 20 | Deep fried chicken wings basket | fried + count | Yes count | After confirm | medium |
| 21 | Steamed fish dish | lighter cooking | Maybe | After confirm | medium |
| 22 | Mala hotpot bowl | oily spicy | Yes | After confirm | low |
| 23 | Buffet small portions many dishes | **Yes** items | **Yes** | After confirm | low |
| 24 | Bakery pastry display | which pastry | **Yes** | After confirm | low |
| 25 | Fruit bowl | simpler | No | After confirm | high |
| 26 | Protein bar unwrapped | packaged | No | After confirm | high |
| 27 | Overnight oats jar | single item | Maybe toppings | After confirm | medium |
| 28 | Hawker drink stall sugar cane | sugar | Maybe size | After confirm | medium |
| 29 | Recommission: "rice was half portion" | adjust rice component | No | After confirm | medium |
| 30 | Recommission: "add chili sauce" | add component | No | After confirm | medium |

### 15.3 Trust Stress Tests

| Prompt | Expected | Clarify? | Log? | Advise? | UI |
|--------|----------|----------|------|---------|-----|
| log this | clarify what "this" refers | **Yes** | Maybe | No | clarification |
| estimate this but don't log | estimate card only | No | **No** | Yes | estimate card |
| actually the chicken was 300g | update pending or edit flow | No | After confirm | No | pending/sheet |
| delete that | resolver target | Maybe | After confirm | No | pending |
| undo | undo last mutation | No | Yes (undo) | No | confirmation msg |
| why is my weight up? | prose with trend context | Maybe | No | Yes | prose |
| can I still eat dessert? | budget advice | Maybe | No | Yes | prose/card |
| am I on track? | status / review | No | No | Yes | status prose |
| change my plan to lose faster | plan guidance; likely no auto-mutate | **Yes** | **No** | Yes | prose |
| I forgot to log yesterday's dinner | ask what meal / date | **Yes** | After confirm | No | pending |

---

## 16. User Trust Product Requirements

### Speed

| Requirement | Met? | Evidence |
|-------------|------|----------|
| Minimal friction | **Partially** | confirmation required for food |
| Image preview | **Yes** | `CoachInputAttachmentPreview` |
| Fast response | **Unknown** | no latency SLA in repo |
| No unnecessary questions | **Partially** | sanity/clarify adds steps |
| One-tap confirm | **Yes** | `CoachConfirmationBar` |
| Quick correction | **Yes** | edit sheet + recommission |

### Accuracy

| Requirement | Met? | Evidence |
|-------------|------|----------|
| Component breakdown | **Yes** | `FoodLogDraft.components` |
| Ranges where uncertain | **Partially** | model fields; log path single |
| Confidence level | **Yes** | `ConfidenceLevel` |
| Assumptions | **Partially** | photo items; pending partial |
| Correction handling | **Partially** | no memory |
| Common food memory | **Yes** | `commonFoods` |
| Local cuisine knowledge | **Partially** | SG fixtures + prompts |
| Sanity checks | **Yes** | `NutritionSanityValidator` |

### Smartness

| Requirement | Met? | Evidence |
|-------------|------|----------|
| Remaining macros | **Yes** | context `today.nutrition` |
| User goals | **Yes** | profile |
| Recent meals | **Yes** | `recentMealsStructured` |
| Weight trend | **Partially** | limited history |
| Training day context | **Yes** | `training` + HI |
| Recommend next action | **Partially** | estimate card chips |
| Explain tradeoffs | **Partially** | meal advice |

### Trust

| Requirement | Met? | Evidence |
|-------------|------|----------|
| Says when unsure | **Partially** | low confidence |
| Never pretends | **Partially** | failures return errors |
| Estimate vs logged distinct | **Yes** | UI separation |
| Shows assumptions | **Partially** | |
| Easy correct | **Yes** | |
| Updates app visibly | **Yes** | Today sync tests |
| No duplicate logs | **Partially** | idempotent pending |
| Error recovery | **Yes** | retry |

---

## 17. Recommended Coach Improvement Sprint Options

### Option A — Coach Accuracy Hardening

| Field | Detail |
|-------|--------|
| **Goal** | Improve calorie estimate correctness and uncertainty communication |
| **Why** | Core product belief fails without accuracy + honest uncertainty |
| **Included** | Calorie ranges on pending card; mandatory portion clarification rules; expand SG fixtures; sanity→block policy; benchmark harness |
| **Excluded** | Sync engine; navigation contract |
| **Files** | `NutritionSanityValidator.swift`, `CoachConfirmationBar.swift`, `FoodEstimateResponseValidator.swift`, `foodEstimateExtraction.ts`, `mealImageAnalysis.ts`, `singapore_food_estimation_cases.json` |
| **Tests** | Extend `SingaporeFoodEstimationFixtureTests`, `mealImageAnalysis.test.ts`, new benchmark runner |
| **Risks** | More friction; slower flow |
| **Metrics** | % estimates within fixture range; clarification rate; user edit-before-confirm rate |

### Option B — Coach App Orchestration

| Field | Detail |
|-------|--------|
| **Goal** | Typed action contract, reliable cross-tab refresh, undo, navigation |
| **Why** | Mutations must be trustworthy across Today/Plan/Journey/sync |
| **Included** | Action result contract; restore/sync flags in context; outbox integration; weight undo; explicit refresh hooks |
| **Excluded** | Model prompt rewrites |
| **Files** | `CoachMutationExecutor.swift`, `FitnessActionCenter.swift`, `AccountSyncCoordinator.swift`, `CoachContextPacketV2Builder.swift`, `CoachModel.swift` |
| **Tests** | `CoachTodaySyncTests`, `AccountSyncMutationIntegrationTests`, E2E cross-device |
| **Risks** | Large scope; sync dependency |
| **Metrics** | Today refresh latency; duplicate log rate; cross-device consistency |

### Option C — Coach Trust UX

| Field | Detail |
|-------|--------|
| **Goal** | Make estimate vs logged vs advice unmistakable; surface confidence/assumptions |
| **Why** | Users trust what they can scan and correct |
| **Included** | Pending card redesign; assumption section; confidence badges; error recovery copy; estimate card range UI |
| **Excluded** | Backend model changes |
| **Files** | `CoachConfirmationBar.swift`, `NutritionEstimateCard.swift`, `CoachMessageView.swift`, `CoachPendingFoodCardPresentation.swift`, `FormaProductCopy.swift` |
| **Tests** | UI/snapshot tests; layout regression (`CoachPendingFoodCardLayoutRegressionTests`) |
| **Risks** | Visual churn |
| **Metrics** | confirm-without-edit rate; discard rate; support confusion tickets |

### Recommendation: **Option A (Accuracy Hardening)** first, then **Option C**

**Why:** The product belief lives or dies on accuracy and honest uncertainty. Architecture/orchestration (B) is critical but account persistence is already in flight (git status shows sync/deletion WIP). Accuracy + trust UX directly attack the Weak rating on "more accurate than I ever can" without waiting for full cloud sync. Option C should immediately follow A so ranges/assumptions are visible, not just computed.

---

## 18. Prioritized Gap Analysis

| Priority | Gap | Evidence | Trust Impact | Accuracy Impact | Effort | Fix |
|---------|-----|----------|--------------|-----------------|--------|-----|
| P0 | Single false-precise calorie on log path | `FoodLogDraft.totalCalories: Int` | High | High | M | Ranges on pending card |
| P0 | No restore/sync awareness in context | no flag in `CoachMissingDataContext` | High | High | M | Add `dataFreshness` section |
| P0 | Nutrition not cloud-synced | `USER_DATA_STORAGE_CONTEXT_PACKET.md` | High | Medium | L | Account persistence phases |
| P0 | Multi-user local leakage | no `ownerUID` on food entities | High | Medium | L | UID scoping + wipe |
| P0 | Water/weight log without confirmation | `ConfirmationPolicy` L19 | Medium | Low | S | Optional confirm setting |
| P1 | Sanity fails don't block | `NutritionSanityValidator` warn only | Medium | High | S | Block or force edit |
| P1 | No correction memory | no store | Medium | High | M | Timeline correction events |
| P1 | Estimate card ranges not shown | `NutritionEstimateCard` grep | Medium | Medium | S | Wire range UI |
| P1 | Text portion clarify inconsistent | routing | Medium | High | M | Portion classifier rules |
| P2 | Meal advice prose hallucination | free text endpoint | Medium | Medium | M | Structured advice schema |
| P2 | Offline AI unavailable | `UnavailableLLMClient` | Medium | — | M | Queue / cache |
| P2 | Production accuracy unknown | no live benchmarks | High | High | M | Benchmark harness |

---

## 19. Files Reviewed

### Coach UI
`Fitness Coach/Features/Coach/CoachView.swift`, `CoachModel.swift`, `CoachComposer.swift`, `CoachConversationView.swift`, `CoachMessageView.swift`, `CoachMessagePresenter.swift`, `CoachConfirmationBar.swift`, `NutritionEstimateCard.swift`, `NutritionComparisonCard.swift`, `AIFoodConfirmationSheet.swift`, `CoachInputState.swift`, `CoachInputAttachment.swift`, `CoachPendingImageState.swift`, `CoachImagePickFlowController.swift`, `CoachLaunchIntent.swift`, `ImagePipeline/*`, `CoachMealPhotoPipeline.swift`

### Coach model / state
`CoachPendingConfirmation.swift`, `CoachProcessingPhase` (`CoachImageUploadState.swift`), `ImageAnalysisSession.swift`, `CoachModelTimelineSupport.swift`

### AI services
`AIService.swift`, `FormaAIBackendClient.swift`, `LLMEndpoint.swift`, `LLMClient.swift`, `FallbackLLMClient.swift`, `UnavailableLLMClient.swift`, `AICommandParser.swift`, `AIContracts.swift`, `AIResponseValidator.swift`, `FoodEstimateResponseValidator.swift`, `MealImageAnalysisResponseValidator.swift`, `AIGatewayPayloadLimits.swift`

### Backend functions
`functions/src/index.ts`, `mealImageAnalysis.ts`, `foodEstimateExtraction.ts`, `foodCompoundDish.ts`, `gatewayGuardrails.ts`, `coachPromptInstructions.ts`, `coachContextPromptRules.ts`, `coachContextPacketV2.ts`, `coachIntentSanitizer.ts`, `coachIntentPhraseGuard.ts`, `openAIReasoningEffort.ts`, `nutritionResponseSanitizer.ts`

### Prompt / schema
`functions/test/__snapshots__/coachPromptSnapshots.test.ts.snap`, `Docs/Coach/COACH_CONTEXT_PACKET_V2.md`

### Persistence / repositories
`FoodLogDraft.swift`, `FitnessActionCenter.swift`, `FoodLogService` (via action center), `SwiftDataCoachChatTranscriptStore.swift`, `CoachTimelineStore.swift`, `FormaModelMigration.swift`

### Today / Journey / Plan
`SmartCoachEngine.swift`, `TodayCoachPrompt.swift`, `TodayActionCoordinator.swift`, `CoachTodayContextBuilder.swift`, `PlanModel.swift` (referenced), Journey builders (referenced)

### Sync / restore
`AccountDataRefreshEventBus.swift`, `AccountSyncCoordinator.swift`, `USER_DATA_STORAGE_CONTEXT_PACKET.md`, `ACCOUNT_PERSISTENCE_RESTORE_CONTEXT_PACKET.md`, `Docs/AccountPersistence/PHASE_2`–`PHASE_6`

### Diagnostics
`CoachAccuracyObservability.swift`, `CoachImageAnalysisDebugLogger.swift`, `CoachTodaySyncDebugLogger.swift`, `FormaPipelineTracer` (referenced), `CoachAIRequestContextLogging.swift`

### Tests
80 `Fitness CoachTests/Coach*.swift` files; 21 `functions/test/*.test.ts` files; `SingaporeFoodEstimationFixtureTests.swift`, `FoodLoggingGoldenTests.swift`

### Docs
`COACH_ACCURACY_HARDENING_FINAL_REPORT.md`, `COACH_ACCURACY_HARDENING_SPRINT_AUDIT.md`, `COACH_FULL_CONTEXT_PACKET.md`, `Docs/CoachNutritionEstimateCards.md`, `Docs/BackendAPI.md`, `FORMA_AI_API_SERVER_CONTEXT_PACKET.md`, `ACCOUNT_PERSISTENCE_IMPLEMENTATION_PLAN.md` (referenced)

---

## 20. Unknowns / Needs Manual Verification

| Item | Why Unknown |
|------|-------------|
| Production OpenAI model IDs deployed | Env vars not in repo |
| `OPENAI_REASONING_EFFORT` in production | Env-dependent |
| Firebase deployed function version vs local | Requires deployment inspect |
| `FormaAbTest.Coach.mealPhotoPipelineReady` in App Store build | Feature flag runtime |
| Real-world photo estimate accuracy | No production telemetry in repo |
| P50/P95 Coach latency | No metrics dashboard in repo |
| User analytics conversion (estimate→confirm) | Analytics not fully audited |
| Whether account sync WIP branch changes Coach behavior | Git status shows WIP; not verified integrated |
| External benchmark datasets outside repo | May exist operationally |
| Live manual QA results on device | Checklist in `COACH_ACCURACY_HARDENING_QA.md` not executed here |

---

*End of Coach Accuracy and Trust Context Packet*
