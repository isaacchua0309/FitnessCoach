# Coach Full Context Packet

**Generated:** 2026-07-04  
**Scope:** Audit + context packet only — no production code changes.  
**Repo:** FitnessCoach (Forma / FitPilot iOS + Firebase `aiGateway`)  
**Purpose:** Enable external AI architectural analysis focused on improving Coach model accuracy via better user timeline/context.

---

## Legend

| Tag | Meaning |
|-----|---------|
| **CONFIRMED** | Directly evidenced in source code or tests in this repo |
| **HYPOTHESIS** | Reasonable inference not fully proven by code |
| **RISK** | Known or likely failure mode |

---

## 1. Executive Summary

### What Coach currently does

**CONFIRMED:** Coach is the app's conversational AI interface for fitness logging and coaching. It is explicitly **not a state owner** — it reads summarized app state, routes user intent, calls remote AI when needed, and mutates fitness data only through `FitnessActionCenter` / `CoachMutationExecutor`. Chat bubbles (`ChatMessage`) are display history only; food, water, and weight truth lives in SwiftData via log services.

### Main user flows

1. **Text chat** — type message → local guard or AI classify → local mutation, food estimate, or meal advice → optional confirmation → persistence → assistant reply.
2. **Food logging** — "I ate chicken rice" → classify as `log_food` → remote `estimate-food` → pending food confirmation → user confirms → `FoodLogService` write → Today refresh.
3. **Water/weight logging** — local parser or classifier draft → immediate execute (no confirmation for water/weight).
4. **Meal advice** — "what should I eat?" → classify as advice intent → `generate-meal-advice` → formatted reply using today's log.
5. **Meal photo** — camera/library → JPEG pipeline → `analyze-meal-image` (separate schema, no full `AIContext`) → clarification loop → food confirmation.
6. **Today's progress** — `daily_summary` intent → local `.status` command → deterministic `CoachResponseBuilder` reply from `DailyLog`.
7. **Workout questions** — reads Apple Health workout count for context; does **not** log workouts in Coach.

### Current AI architecture

```mermaid
flowchart TD
    User[User] --> CV[CoachView]
    CV --> CM[CoachModel]
    CM --> Guard[LocalNoAPIGuard]
    Guard -->|pass| Classify[cheap LLM classify-coach-intent]
    Classify --> Gate[CoachIntentConfidenceGate]
    Gate --> Router[CoachIntentRouter]
    Router --> Handler[CoachAIRouteHandler]
    Handler -->|mutate| ME[CoachMutationExecutor]
    Handler -->|AI| AIS[AIService]
    AIS --> Client[FormaAIBackendClient]
    Client --> GW[Firebase aiGateway]
    GW --> OAI[OpenAI Responses API]
    ME --> AC[FitnessActionCenter]
    AC --> SD[(SwiftData)]
    CM --> CCB[CoachContextBuilder]
    CCB --> CTX[AIContext payload]
    CTX --> AIS
```

**CONFIRMED:** Stateless per request — iOS builds `AIContext` on each send; backend receives JSON `context` + task-specific fields. Prior messages included by iOS (last 5), not server-side session store.

### Current data sources

| Source | Coach usage |
|--------|-------------|
| `DailyLog` / `DailyLogService` | Today's macros, water, weight-on-log, steps, workout calories burned |
| `FoodLogService` | Meal entries; recent 6 names in AI context |
| `WaterLogService` / `WeightLogService` | Mutations |
| `UserProfileService` | Demographics for `UserProfileSummary` |
| `HealthActivityQueryService` | Live workout count today (HealthKit or cached repository) |
| `HealthDataRepository` | Cached normalized HealthKit when feature flag on |
| `CoachInMemoryChatTranscriptStore` | Session-only chat (not cross-launch) |
| `ImageAnalysisSessionStore` | In-memory photo analysis FSM |

### Current timeline/context limitations

**CONFIRMED — highest impact gaps:**

1. **No true event timeline** — chat history + point-in-time `todaySummary` snapshot, not an ordered ledger of today's events.
2. **Only 5 prior messages** sent to AI — role + text only, no timestamps, no linkage to logged entries.
3. **Recent meals are labels only** — last 6 food names as strings; no per-entry macros, meal type, confidence, or timestamps.
4. **Steps often stale/missing** — AI context uses `DailyLog.steps`, not live `stepsToday()` query.
5. **Photo analysis omits workout context** — `CoachMealPhotoAnalyzer` calls `makeContext` without `workoutsToday` (defaults to 0).
6. **Photo endpoint ignores `AIContext`** — meal image API uses separate request schema.
7. **Chat not persisted** — relaunch loses conversation; model cannot reference prior session.
8. **`commonFoods` always empty** — field exists but unused.
9. **Health Intelligence context not wired** — rich 28-day `HealthIntelligenceContextBuilder` exists but Coach does not use it.
10. **No correction/undo events in context** — undo stack is in-memory only.

### Highest-risk areas for model accuracy

1. Misclassification at cheap classifier → wrong endpoint (food vs advice).
2. Model invents nutrition from chat history despite prompt rules (no structural enforcement).
3. Stale `todaySummary` if context built before mutation completes.
4. Workout false negative when HealthKit errors degrade to empty array.
5. Compound foods ("chicken rice") forced through estimate-food with weak portion context.
6. Timezone/day-boundary ambiguity — `date` is `Date()` at build time; log reads use `getTodayLog()` (calendar-dependent).
7. Classifier `log_food` always re-estimates via API even when draft is complete.
8. Conversation truncation hides user corrections and prior estimates.

---

## 2. Coach Feature File Inventory

~150 files touch Coach. Below: grouped inventory with path, responsibility, key types, and effect tags (`CTX`=AI context, `UI`, `MUT`, `PERS`, `NET`).

### 2.1 Features/Coach — UI & Feature Model (55 files)

#### Root
| Path | Responsibility | Key types | Tags |
|------|----------------|-----------|------|
| `Fitness Coach/Features/Coach/CoachView.swift` | Root Coach tab; wires model to conversation, composer, sheets | `CoachView` | UI |

#### Components (18)
| Path | Responsibility | Key types | Tags |
|------|----------------|-----------|------|
| `.../Components/CoachConversationView.swift` | Scrollable message list | `CoachConversationView` | UI |
| `.../Components/CoachComposer.swift` | Text input, send, voice, attachment | `CoachComposer` | UI |
| `.../Components/CoachMessageView.swift` | Single chat bubble | `CoachMessageView` | UI |
| `.../Components/CoachMessagePresenter.swift` | Domain → presentation models | `CoachMessagePresenter`, `CoachMessagePresentation` | UI |
| `.../Components/CoachConfirmationBar.swift` | Confirm/reject/edit for pending mutations | `CoachConfirmationBar` | UI, MUT |
| `.../Components/CoachHeader.swift` | Header on empty conversation | `CoachHeader` | UI |
| `.../Components/CoachEmptyState.swift` | Empty chat + today card + starter chips | `CoachEmptyState` | UI |
| `.../Components/CoachErrorView.swift` | Session error banner + auth retry | `CoachErrorView` | UI |
| `.../Components/CoachTypingIndicatorView.swift` | Typing indicator | `CoachTypingIndicatorView` | UI |
| `.../Components/CoachStarterChips.swift` | Quick-action chips | `CoachStarterChips` | UI |
| `.../Components/CoachStarterPrompt.swift` | Starter prompt specs | `CoachStarterPrompt`, `CoachStarterPromptSpec` | UI |
| `.../Components/CoachTodayContextCard.swift` | Today nutrition/training summary card | `CoachTodayContextCard` | UI |
| `.../Components/CoachAttachmentMenu.swift` | Camera/photo picker menu | `CoachAttachmentMenu` | UI |
| `.../Components/CoachPhotoCapture.swift` | Camera picker wrapper | `CoachCameraPicker` | UI |
| `.../Components/CoachChatPhotoMessageView.swift` | Photo message bubble | `CoachChatPhotoMessageView` | UI |
| `.../Components/CoachMealPhotoThumbnail.swift` | Staged meal photo thumbnail | `CoachMealPhotoThumbnailView` | UI |
| `.../Components/AIFoodConfirmationSheet.swift` | Edit AI food estimate before logging | `AIFoodConfirmationSheet` | UI, MUT |
| `.../Components/FoodLogEditFormState.swift` | Editable food draft form | `FoodLogEditFormState` | UI, MUT |
| `.../Components/CoachHaptics.swift` | Haptic feedback | `CoachHaptics` | UI |

#### Formatting (5)
| Path | Key types | Tags |
|------|-----------|------|
| `.../Formatting/CoachPendingCopyFormatter.swift` | `CoachPendingCopyFormatter` | UI |
| `.../Formatting/AIFoodConfirmationDraft.swift` | `AIFoodConfirmationDraft` | UI |
| `.../Formatting/AIFoodConfirmationFormatter.swift` | `AIFoodConfirmationFormatter` | UI |
| `.../Formatting/FoodComponentDisplayFormatter.swift` | `FoodComponentDisplayFormatter` | UI |
| `.../Formatting/FoodMealDisplayNameFormatter.swift` | `FoodMealDisplayNameFormatter` | UI |

#### Model (22)
| Path | Responsibility | Key types | Tags |
|------|----------------|-----------|------|
| `.../Model/CoachModel.swift` | **Central orchestrator** | `CoachModel` | UI, CTX, MUT, NET |
| `.../Model/CoachInputState.swift` | Composer + staged attachment state machine | `CoachInputState`, `CoachInputSendSnapshot` | UI |
| `.../Model/CoachPendingConfirmation.swift` | Pending food/water/weight/edit/delete/undo | `CoachPendingConfirmation` | UI, MUT |
| `.../Model/CoachTodayContextState.swift` | Today summary for empty-state card | `CoachTodayContextState` | UI |
| `.../Model/CoachPreviewData.swift` | SwiftUI preview fixtures | `CoachPreviewData` | UI |
| `.../Model/CoachChatTranscriptStore.swift` | Chat persistence protocol + in-memory impl | `CoachChatTranscriptStore`, `CoachInMemoryChatTranscriptStore` | UI, PERS |
| `.../Model/CoachSpeechRecognizerService.swift` | Speech-to-text | `CoachSpeechRecognizerService` | UI |
| `.../Model/CoachSpeechAccess.swift` | Speech permission | `CoachSpeechAccess` | UI |
| `.../Model/CoachSpeechError.swift` | Speech errors | `CoachSpeechError` | UI |
| `.../Model/CoachCameraAccess.swift` | Camera permission | `CoachCameraAccess` | UI |
| `.../Model/CoachImagePickFlowController.swift` | Photo pick + processing orchestration | `CoachImagePickFlowController` | UI |
| `.../Model/CoachPhotoPickerTransfer.swift` | PhotosUI transferable | `CoachPhotoPickerTransfer` | UI |
| `.../Model/CoachMealPhotoPipeline.swift` | Meal photo send/analyze flow | `CoachMealPhotoPipeline` | UI, NET, MUT |
| `.../Model/CoachMealPhotoError.swift` | Photo flow errors | `CoachMealPhotoError` | UI |
| `.../Model/CoachImageUploadState.swift` | Processing phase + send payload | `CoachProcessingPhase`, `CoachMealPhotoSendPayload` | UI |
| `.../Model/CoachPendingImageState.swift` | Staged image attachment | `CoachPendingImageState` | UI |
| `.../Model/CoachPendingImageLocalSourceStore.swift` | UIImage refs for retry | `CoachPendingImageLocalSourceStore` | UI |
| `.../Model/ImageAnalysisSession.swift` | Photo clarification session FSM | `ImageAnalysisSession`, `ImageAnalysisSessionReducer`, `ImageAnalysisSessionStore`, `ImageAnalysisPromptBuilder` | UI, CTX, NET |

#### ImagePipeline (12)
| Path | Key types | Tags |
|------|-----------|------|
| `.../Model/ImagePipeline/CoachImagePipeline.swift` | `CoachImagePipeline` | UI, NET |
| `.../Model/ImagePipeline/CoachImagePipeline+Camera.swift` | Camera processing | UI |
| `.../Model/ImagePipeline/CoachImagePipeline+PhotoLibrary.swift` | Library import | UI |
| `.../Model/ImagePipeline/CoachImagePipeline+ImportedImageProcessing.swift` | Generic import | UI |
| `.../Model/ImagePipeline/CoachImagePipeline+ProcessedImageImport.swift` | Re-import | UI |
| `.../Model/ImagePipeline/CoachImagePipelineEncoding.swift` | JPEG encoding | UI |
| `.../Model/ImagePipeline/CoachImagePipelineError.swift` | Pipeline errors | UI |
| `.../Model/ImagePipeline/CoachImagePipelineResult.swift` | Result enum | UI |
| `.../Model/ImagePipeline/CoachImageProcessingConfig.swift` | Pixel/compression config | UI |
| `.../Model/ImagePipeline/CoachImageUploadConfig.swift` | Upload limits | NET |
| `.../Model/ImagePipeline/CoachImagePickFlowState.swift` | Pick-flow state machine | UI |
| `.../Model/ImagePipeline/CoachProcessedImage.swift` | Processed image value type | UI |

### 2.2 Application/UseCases/Coach (20 files)

| Path | Responsibility | Key types | Tags |
|------|----------------|-----------|------|
| `.../CoachMutationExecutor.swift` | Executes commands via `FitnessActionCenter` | `CoachMutationExecutor` | MUT |
| `.../CoachAIRouteHandler.swift` | Dispatches routes to AI or mutations | `CoachAIRouteHandler` | CTX, MUT, NET |
| `.../CoachActionResult.swift` | Action result (message, pending confirm) | `CoachActionResult` | UI |
| `.../CoachPendingConfirmationPresenter.swift` | Pending confirmation text handling | `CoachPendingConfirmationPresenter` | UI, MUT |
| `.../CoachMealPhotoAnalyzer.swift` | Photo AI analysis orchestration | `CoachMealPhotoAnalyzer` | CTX, NET |
| `.../CoachMealImageAIRequestBuilder.swift` | Builds `AIMealImageAnalysisRequest` | `CoachMealImageAIRequestBuilder` | CTX, NET |
| `.../CoachMealImageUploadAttachment.swift` | Image upload payload | `CoachMealImageUploadAttachment` | NET |
| `.../MealImageAnalysisMapper.swift` | AI meal image response → drafts | `MealImageAnalysisMapper` | MUT |

#### Pipeline (12)
| Path | Key types | Tags |
|------|-----------|------|
| `.../Pipeline/CoachIntentResult.swift` | `CoachIntentResult`, `CoachIntent`, `CoachAction`, `CoachModelConfig` | CTX |
| `.../Pipeline/CoachIntentRouter.swift` | `CoachIntentRouter`, `RoutedAITask` | CTX, NET |
| `.../Pipeline/CoachRouteDecider.swift` | `CoachRouteDecider`, `CoachRoute`, `CoachRouteDecision` | CTX |
| `.../Pipeline/CheapLLMIntentClassifier.swift` | `CheapLLMIntentClassifier` | CTX, NET |
| `.../Pipeline/CoachIntentConfidenceGate.swift` | `CoachIntentConfidenceGate` | CTX |
| `.../Pipeline/InputNormalizer.swift` | `InputNormalizer`, `NormalizedCoachInput` | CTX |
| `.../Pipeline/CoachInputSafety.swift` | `CoachInputSafety` | CTX |
| `.../Pipeline/ConfirmationPolicy.swift` | `ConfirmationPolicy` | UI, MUT |
| `.../Pipeline/LocalNutritionEstimator.swift` | `LocalNutritionEstimator` | CTX |
| `.../Pipeline/LocalNoAPIGuard.swift` | `LocalNoAPIGuard` | CTX |
| `.../Pipeline/CoachMutationHistory.swift` | Undo stack | MUT |
| `.../Pipeline/CoachRouteDebugLogger.swift` | Route debug logging | — |

### 2.3 Application/StateBuilders

| Path | Key types | Tags |
|------|-----------|------|
| `.../Coach/CoachAIContextBuilder.swift` | `CoachContextBuilder` | CTX |
| `.../Coach/CoachResponseBuilder.swift` | `CoachResponseBuilder` | UI |
| `.../Coach/CoachTodayContextBuilder.swift` | `CoachTodayContextBuilder` | UI |
| `.../Coach/CoachNutritionSummaryFormatter.swift` | `CoachNutritionSummaryFormatter` | UI |
| `.../Coaching/DailyBriefBuilder.swift` | `DailyBriefBuilder`, `TodayDailyBrief` | UI (local fallback) |
| `.../Nutrition/DailyNutritionSummaryBuilder.swift` | `DailyNutritionSummaryBuilder` | CTX, UI |
| `.../Nutrition/TodayAISummaryMapper.swift` | `TodayAISummaryMapper` | CTX |
| `.../Training/TrainingInsightsCoachNoteBuilder.swift` | `TrainingInsightsCoachNoteBuilder` | UI |

### 2.4 Services, Commands, Infrastructure

| Path | Key types | Tags |
|------|-----------|------|
| `.../Services/AIService.swift` | `AIService`, `AIServiceProtocol` | CTX, NET |
| `.../UseCases/FitnessActionCenter.swift` | `FitnessActionCenter` | MUT |
| `.../UseCases/Commands/LocalCommandParser.swift` | `LocalCommandParser` | CTX, MUT |
| `.../UseCases/Commands/CommandIntent.swift` | `CommandIntent` | CTX |
| `.../UseCases/Commands/ParsedCommand.swift` | `ParsedCommand` | MUT |
| `.../UseCases/Commands/CommandParseResult.swift` | `CommandParseResult` | CTX |
| `.../UseCases/Commands/CommandParserError.swift` | `CommandParserError` | — |
| `.../UseCases/Commands/CommandParserUtilities.swift` | Parser helpers | — |
| `.../UseCases/Commands/CommandKeywordFuzzyMatcher.swift` | `CommandKeywordFuzzyMatcher` | CTX |
| `.../UseCases/Onboarding/OnboardingCoachingContextStore.swift` | `OnboardingCoachingContextStore` | PERS, CTX |
| `.../Infrastructure/AI/FormaAIBackendClient.swift` | `FormaAIBackendClient` | NET |
| `.../Infrastructure/AI/LLMClient.swift` | `LLMClient` | NET |
| `.../Infrastructure/AI/LLMEndpoint.swift` | `LLMEndpoint` | NET |
| `.../Infrastructure/AI/FallbackLLMClient.swift` | `FallbackLLMClient` | NET |
| `.../Infrastructure/AI/UnavailableLLMClient.swift` | `UnavailableLLMClient` | NET |
| `.../Infrastructure/AI/MockLLMClient.swift` | `MockLLMClient` | NET |
| `.../Infrastructure/AI/AIContracts.swift` | All AI DTOs | CTX, NET |
| `.../Infrastructure/AI/AIContext.swift` | `AIContext`, `TodayAISummary` | CTX |
| `.../Infrastructure/AI/AICoachResponse.swift` | `AICoachResponse` | CTX |
| `.../Infrastructure/AI/AIPromptBuilder.swift` | iOS reference prompts | CTX |
| `.../Infrastructure/AI/AICommandParser.swift` | `AICommandParser` | NET |
| `.../Infrastructure/AI/AIParsedCommand.swift` | `AIParsedCommand` | CTX, MUT |
| `.../Infrastructure/AI/AICommandAction.swift` | `AICommandAction` | MUT |
| `.../Infrastructure/AI/AIResponseValidator.swift` | Response validation | CTX |
| `.../Infrastructure/AI/FoodEstimateResponseValidator.swift` | Food estimate validation | CTX |
| `.../Infrastructure/AI/MealImageAnalysisResponseValidator.swift` | Meal image validation | CTX |
| `.../Infrastructure/AI/AIGatewayPayloadLimits.swift` | Payload size limits | NET |
| `.../Infrastructure/AI/AIConfidence.swift` | `AIConfidence` | CTX |
| `.../Infrastructure/AI/AIServiceError.swift` | `AIServiceError` | NET |
| `.../Infrastructure/AI/LLMClientError.swift` | `LLMClientError` | NET |
| `.../Infrastructure/Diagnostics/CoachImageAnalysisDebugLogger.swift` | Image debug logs | — |
| `.../Diagnostics/FormaPipelineTracer.swift` | Pipeline tracing | — |
| `.../Persistence/SwiftData/Entities/ChatMessageEntity.swift` | Legacy v1 only | PERS (deprecated) |

### 2.5 Domain, Design, App Integration

| Path | Key types | Tags |
|------|-----------|------|
| `.../DesignSystem/Coach/CoachDesignTokens.swift` | `CoachDesignTokens` | UI |
| `.../Domain/Models/ChatMessage.swift` | `ChatMessage` | UI, CTX |
| `.../Domain/Models/ChatMessageImageAttachment.swift` | Image attachment | UI |
| `.../Domain/Models/Enums/ChatMessageRole.swift` | `ChatMessageRole` | UI |
| `.../Domain/Onboarding/OnboardingCoachingContext.swift` | Onboarding coaching prefs | CTX, PERS |
| `.../Domain/Copy/FormaProductCopy.swift` | `FormaProductCopy.Coach` | UI |
| `.../App/AppContainer.swift` | DI wiring | UI, NET |
| `.../App/MainTabView.swift` | Coach tab entry | UI |
| `.../App/AIBackendConfiguration.swift` | Gateway URL resolution | NET |
| `.../Features/Today/Model/TodayActionCoordinator.swift` | Routes to Coach | UI |
| `.../Application/Queries/HealthActivityQueryService.swift` | Health queries | CTX |
| `.../Health/Repository/HealthDataRepository.swift` | Cached HealthKit | CTX |
| `.../Health/Intelligence/HealthIntelligenceContextBuilder.swift` | Rich health context (not used by Coach) | — |

### 2.6 Firebase Functions

| Path | Key items | Tags |
|------|-----------|------|
| `functions/src/index.ts` | `aiGateway`, classify, estimate, advice, review, parse-* | NET |
| `functions/src/coachIntentSanitizer.ts` | `sanitizeCoachIntentResult` | CTX |
| `functions/src/mealImageAnalysis.ts` | Meal image endpoint | NET |
| `functions/test/*.test.ts` | Gateway contract tests | — |

### 2.7 Tests (30+ Coach-prefixed + related)

See Section 18 for coverage detail.

---

## 3. Coach User Experience Map

### Flow descriptions

| Flow | Behavior |
|------|----------|
| **Opening Coach** | `MainTabView` shows `CoachView` with long-lived `CoachModel`. On appear/task: `refreshTodayContext()` loads `CoachTodayContextState` for empty-state card. Messages loaded from in-memory transcript store (empty on fresh launch). |
| **Plain text message** | Composer → `sendCurrentMessage()` → `send(_:)` → validate → append user bubble → `processCoachMessage` → route → assistant reply or pending confirmation. |
| **Food log request** | Classify `log_food` → `estimate-food` API → `CoachPendingConfirmation.food` → user confirms via bar/sheet → `executeLogFood` → Today refresh via `AppRefreshCenter`. |
| **Water log** | Local parser or classifier `log_water` → immediate `executeLogWater`. |
| **Advice** | Advice intents → `generate-meal-advice` → `CoachResponseBuilder.mealAdvice` wraps AI text with today's numbers. |
| **Today's progress** | `daily_summary` → local `.status` → deterministic status string from `DailyLog`. |
| **Workout / Apple Health** | Read-only: workout count in AI context; redirect message for logging workouts. Training integration copy from `TrainingIntegrationCopy`. |
| **Logging from AI result** | Food: confirmation required. Water/weight from AI parse: immediate. Edit/delete: confirmation required. |
| **Photo upload** | Stage JPEG → send → `ImageAnalysisSession` → `analyze-meal-image` → clarification optional → food pending confirmation. |
| **Retry/error** | Auth: `CoachErrorView` + token refresh. Photo: retry analysis or re-pick image. Backend: assistant error message. |
| **Offline/backend unavailable** | `AIServiceError.backendUnavailable` → "Coach is temporarily unavailable..." |
| **Auth/session failure** | `authenticationFailed` → banner with retry; empty assistant message. |

### Sequence diagram

```mermaid
sequenceDiagram
    participant U as User
    participant CV as CoachView
    participant CM as CoachModel
    participant RD as CoachRouteDecider
    participant RH as CoachAIRouteHandler
    participant AIS as AIService
    participant GW as aiGateway
    participant ME as CoachMutationExecutor
    participant AC as FitnessActionCenter
    participant DB as SwiftData

    U->>CV: Send message
    CV->>CM: sendCurrentMessage()
    CM->>CM: appendUserMessage
    CM->>CM: CoachContextBuilder.makeContext()
    CM->>RD: decide(text, context)
    alt Local guard match
        RD-->>CM: localCommand / greeting / noOp
    else Needs classify
        RD->>AIS: classifyCoachIntent
        AIS->>GW: POST classify-coach-intent
        GW-->>AIS: CoachIntentResult
        RD-->>CM: CoachRoute
    end
    CM->>RH: handle(route, context)
    alt Food estimate
        RH->>AIS: estimateFood
        AIS->>GW: POST estimate-food
        GW-->>RH: FoodLogDraft
        RH-->>CM: pendingConfirmation(.food)
    else Meal advice
        RH->>AIS: generateMealAdvice
        AIS->>GW: POST generate-meal-advice
        GW-->>CM: assistant message
    else Local water/weight
        RH->>ME: execute(command)
        ME->>AC: logWater / logWeight
        AC->>DB: persist
        AC-->>CM: response text
    end
    CM->>CM: applyActionResult / appendAssistantMessage
    CM-->>CV: @Published messages update
    CV-->>U: UI refresh
```

---

## 4. Coach UI Architecture

### CoachView structure

**CONFIRMED:** `NavigationStack` → `ZStack` background → `VStack`:
- Optional `CoachHeader` (empty conversation)
- `CoachConversationView` (messages or empty state)
- Optional `CoachErrorView` banner
- `safeAreaInset(bottom)`: `CoachConfirmationBar` (if pending) + `CoachComposer`

### Input bar (`CoachComposer`)

- Binds `model.inputState.text`
- `CoachAttachmentMenu` → camera / photo library via `CoachImagePickFlowController`
- Mic via `CoachSpeechRecognizerService` (owned as `@StateObject` in `CoachView`)
- Send enabled when `!isSending && !isProcessingImage && (hasText || readyImage)`
- Photo preview: `CoachMealPhotoThumbnailView`

### Message list

- `CoachConversationView`: `LazyVStack` of `CoachMessageView`
- Empty: `CoachEmptyState` + `CoachTodayContextCard` + `CoachStarterChips`
- `isSending` → `CoachTypingIndicatorView`
- Auto-scroll on message count / typing changes

### State ownership

| State | Owner |
|-------|-------|
| `messages`, `pendingConfirmation`, `todayContext`, errors | `CoachModel` |
| Speech recording | `CoachSpeechRecognizerService` |
| Image pick/processing | `CoachImagePickFlowController` |
| Auth retry | `AuthManager` via `CoachView.retryCoachSession()` |

### Where UI reads state

- `CoachView` reads `@ObservedObject model: CoachModel` published properties
- `CoachConversationView` receives `messages`, `isSending`, `todayContext` as parameters

### Where user intent enters

- `CoachComposer` send → `model.sendCurrentMessage()`
- Starter chips → `model.applyStarterPrompt(_:)`
- Confirmation bar → `confirmPendingFromBar()`, `rejectPendingFromBar()`, etc.

### Where messages appended

- `CoachModel.appendUserMessage`, `appendAssistantMessage`, `appendUserMealPhotoMessage`
- Each append calls `persistTranscript()` → `CoachInMemoryChatTranscriptStore`

### Optimistic UI

**CONFIRMED:** User message appended **before** routing completes. No optimistic mutation of logs — food waits for confirmation.

### State resets

- Composer cleared on `takeSendSnapshot()` at send start
- `clearPendingConfirmation()` after confirm/reject
- `todayContext = nil` on refresh failure
- Tab switch does **not** reset `CoachModel` (long-lived in `MainTabView`)

### Dependencies injected

From `AppContainer.makeCoachModel()`:
- `FitnessActionCenter`, `DailyLogService`, `HealthActivityQueryService`, `WeightLogService`
- `AIService`, `UserProfileService`, `TrainingInsightsStore`
- `aiCommandParsingEnabled: true` (when backend URL resolves)

---

## 5. CoachModel Deep Dive

### Published state

| Property | Type | Purpose |
|----------|------|---------|
| `messages` | `[ChatMessage]` | Chat transcript |
| `inputState` | `CoachInputState` | Composer + staged image |
| `processingPhase` | `CoachProcessingPhase` | Sending lock |
| `errorTitle`, `errorMessage`, `showsAuthRetry` | Optional strings/Bool | Session errors |
| `pendingConfirmation` | `CoachPendingConfirmation?` | Awaiting user confirm |
| `isShowingFoodEditSheet` | `Bool` | Food edit sheet |
| `isConfirmingPending` | `Bool` | Confirm in progress |
| `foodEditErrorMessage` | `String?` | Sheet validation error |
| `todayContext` | `CoachTodayContextState?` | Empty-state card |
| `starterPromptSpecs` | `[CoachStarterPromptSpec]` | Quick actions |

### Private collaborators

`LocalCommandParser`, `DailyLogReading`, `HealthActivityQueryService`, `WeightLogReading?`, `CoachMutationHistory`, `AIServiceProtocol?`, `CoachContextBuilder?`, `CoachRouteDecider`, `CoachModelConfig`, `CoachMutationExecutor`, `CoachAIRouteHandler`, `CoachMealPhotoAnalyzer`, `CoachChatTranscriptStore`, `ImageAnalysisSessionStore`, `CoachPendingImageLocalSourceStore`

### Initialization

`CoachModel.init` builds `CoachContextBuilder` when `userProfileReader` provided; wires executor and route handler with shared `mutationHistory`.

### Lifecycle

- `refreshTodayContext()` on appear / `AppRefreshCenter.refreshToken` change
- No explicit teardown; persists for app session

### Send message call graph (text)

```
sendCurrentMessage()
  → inputState.takeSendSnapshot()
  → beginProcessing(.text)
  → send(text, managesProcessingLock: false)
      → CoachInputSafety.validate
      → appendUserMessage
      → handlePendingConfirmationInput? (confirm words)
      → submitImageAnalysisClarification? (photo session active)
      → processCoachMessage
          → healthActivityQuery.dailyTrainingActivity().workoutCount
          → aiContextBuilder.makeContext(recentMessages:, workoutsToday:)
          → routeDecider.decide
          → routeHandler.handle
      → applyActionResult
  → endProcessing() [defer]
```

### Context refresh call graph

```
refreshTodayContext()
  → refreshTodayContextAsync()
      → dailyLogReader.getTodayLog()
      → healthActivityQuery.dailyTrainingActivity()
      → weightLogReader?.getLatestWeight() [fallback for card]
      → CoachTodayContextBuilder.build(...)
      → todayContext = ...
```

**Note:** This refresh is **UI-only** (`CoachTodayContextState`). It does not update AI context until next message send.

### Error handling

| Error | Behavior |
|-------|----------|
| `AIServiceError.authenticationFailed` | `presentCoachSessionFailure()`, empty assistant message |
| Other `AIServiceError` | `error.userMessage` as assistant text |
| Unexpected | `requestFailed` user message |
| AI disabled | `backendUnavailableResponse` |

### Retry logic

- Auth: `CoachView.retryCoachSession()` → `authManager.idToken(forceRefresh: true)`
- Photo analysis: `retryMealPhotoAnalysis(for:)`
- Image pick: `CoachImagePickFlowController.retryFailedImageSelection`
- Classifier: 300ms retry on transient failure in `CheapLLMIntentClassifier`

### Async / cancellation

**CONFIRMED:** No `Task` cancellation for in-flight Coach sends. `guard !isSending` prevents concurrent sends. `CoachModel` survives tab switches.

### MainActor

**CONFIRMED:** `CoachModel` is `@MainActor`. `CoachRouteDecider` and `LocalNoAPIGuard` are `Sendable` / `nonisolated` — called from MainActor context.

### Thread safety risks

**RISK:** `CoachRouteDecider.recentClassifyCache` is mutable on a `Sendable` class — safe today because `decide` is only called from `@MainActor CoachModel`, but not enforced by type system.

---

## 6. Coach Message Model and Timeline

### Message models

**`ChatMessage`** (`Domain/Models/ChatMessage.swift`):
- `id`, `role`, `text`, `createdAt`
- `relatedDailyLogId`, `relatedEntryId` (optional mutation links — lightly used)
- `imageAttachment`, `photoAnalysisLink`
- Explicitly **not** source of truth for logs

**`AIMessageContext`** (sent to AI):
- `role`, `text` only — no timestamps, IDs, or attachments

### Is there a true timeline today?

**CONFIRMED: No.** Coach uses:
1. **Lightweight in-memory chat history** (`[ChatMessage]`) — unlimited UI length, 5 messages to AI
2. **Separately queried point-in-time app state** (`AIContext.todaySummary` from `DailyLog` + Health query)

There is **no** unified event ledger tying "user said X" → "food logged Y at T" → "AI replied Z".

### Persistence

| Data | Persisted? |
|------|------------|
| Chat messages | **No** cross-launch (in-memory only) |
| Food/water/weight entries | **Yes** (SwiftData) |
| Pending confirmations | **No** (in-memory) |
| Image analysis sessions | **No** (in-memory) |
| Mutation undo history | **No** (in-memory `CoachMutationHistory`) |

### How logs relate to chat

**CONFIRMED:** Logging creates SwiftData entries via `FitnessActionCenter`. Chat may show assistant confirmation text and optional `relatedEntryId`, but rebuilding chat from logs on launch is **not implemented**.

### System events in timeline

**CONFIRMED:** No structured "meal logged" / "water added" system events in chat. User sees assistant natural-language confirmations only.

### Ordering

- Chat: append-only `messages` array ordered by insertion (`createdAt` set at creation)
- Food entries: ordered by service/repository (not re-synced to chat)

### Duplicates

**RISK:** No dedup on chat messages. Classify dedup (8s window) prevents duplicate API classify calls, not duplicate logs. User could confirm same food twice.

### Pending/failed messages

- Pending food: `CoachPendingConfirmation` + confirmation bar (not a chat bubble)
- Failed photo: `assistantPhotoAnalysisFailure` message with retry link
- Failed send: assistant error text bubble

### Timeline diagram

```mermaid
flowchart LR
    UM[User message] --> C[classification]
    C -->|log_food| E[estimate-food API]
    C -->|log_water| L[local execute]
    C -->|advice| A[meal-advice API]
    E --> PC[Pending confirmation]
    PC -->|confirm| M[MutationExecutor]
    L --> M
    M --> DL[DailyLog / FoodEntry persisted]
    DL --> CR[Context refresh on NEXT send]
    E --> AR[Assistant response]
    A --> AR
    M --> AR
```

### What data is missing from the model's view of the user's day?

- Per-meal timestamps and macros in context
- Water/weight log event sequence (only aggregates in `todaySummary`)
- Workout details (name, duration) — only count + stored calorie burn
- Live steps (often nil in `DailyLog.steps`)
- Corrections, deletes, undos
- Prior session conversation
- Photo analysis assumptions linked to logged entry
- Plan goal type, recovery, training load
- Low-confidence food flags (only in daily review path)

### Stale or contradictory data risks

| Scenario | Risk |
|----------|------|
| Context built before confirm completes | AI sees pre-log macros on next message |
| `DailyLog.workoutCaloriesBurned` vs live HealthKit count | Mismatch between calorie burn field and workout count |
| `DailyLog.steps` vs HealthKit live steps | Steps in context may be nil/stale |
| Chat says "logged 500 kcal" but user rejected | Model may still see old assistant text in recentMessages |
| Photo path `workoutsToday=0` | Under-reports training activity for image analysis |

---

## 7. Current Coach Context Packet Sent to AI

### Builder

**`CoachContextBuilder`** in `Application/StateBuilders/Coach/CoachAIContextBuilder.swift`

```swift
func makeContext(recentMessages: [ChatMessage], workoutsToday: Int = 0) -> AIContext
```

### Fields included

#### Top-level `AIContext`

| Field | Source | Notes |
|-------|--------|-------|
| `date` | `Date()` at build time | CONFIRMED |
| `timezoneIdentifier` | `TimeZone.current.identifier` | CONFIRMED |
| `userProfileSummary` | `UserProfileService` | age, sex, height, weight, goal, activity, training freq |
| `todaySummary` | `TodayAISummaryMapper` | See below |
| `commonFoods` | **Always `[]`** | Unused |
| `recentMessages` | Last **5** messages, role+text | Excludes current user message |

#### `TodayAISummary` (via `DailyNutritionSummaryBuilder`)

| Included | Field |
|----------|-------|
| Yes | Calorie target/consumed/remaining, over-target flag |
| Yes | Protein/carbs/fat targets, consumed, remaining |
| Yes | Water target/consumed/remaining, met flag |
| Yes | `weightKg` from `DailyLog` |
| Yes | `steps` from `DailyLog.steps` (often nil) |
| Yes | `workoutCaloriesBurned` from `DailyLog` |
| Yes | `workoutsToday` from caller (HealthKit query for text; **0 default for photo**) |
| Yes | `recentMeals` — last 6 food name strings |

### Fields NOT included (but available elsewhere)

| Data | Where it exists |
|------|-----------------|
| Per-entry food macros, confidence, meal type | `FoodEntry` / `FoodLogService` |
| Water/weight entry history | `WaterLogService`, `WeightLogService` |
| Workout names, duration, HR | `HealthWorkoutRecord` / repository |
| Live steps today | `HealthActivityQueryService.stepsToday()` |
| Recovery, sleep, HRV | `HealthIntelligenceContextBuilder` |
| Plan goal type, adaptive targets | Plan entities |
| Feature flags, app version | Not sent |
| Onboarding coaching context | `OnboardingCoachingContextStore` (not in AIContext) |
| Training insights | `TrainingInsightsStore` (used in meal advice formatting only) |

### Message window

**CONFIRMED:** 5 prior messages (`messages.dropLast()` then `.suffix(5)`). Current user message excluded.

### Example reconstructed payload (redacted)

```json
{
  "date": "2026-07-04T02:05:00Z",
  "timezoneIdentifier": "Asia/Singapore",
  "userProfileSummary": {
    "age": 32,
    "sex": "male",
    "heightCm": 178,
    "currentWeightKg": 82.5,
    "goalWeightKg": 78,
    "activityLevel": "moderatelyActive",
    "trainingFrequencyPerWeek": 4
  },
  "todaySummary": {
    "calorieTarget": 2100,
    "caloriesConsumed": 1200,
    "caloriesRemaining": 900,
    "isOverCalorieTarget": false,
    "proteinTarget": 160,
    "proteinConsumed": 80,
    "proteinRemaining": 80,
    "hasMetProteinTarget": false,
    "carbsTarget": 220,
    "carbsConsumed": 100,
    "carbsRemaining": 120,
    "fatTarget": 65,
    "fatConsumed": 30,
    "fatRemaining": 35,
    "waterTargetMl": 2500,
    "waterConsumedMl": 1000,
    "waterRemainingMl": 1500,
    "hasMetWaterTarget": false,
    "weightKg": 82.5,
    "steps": null,
    "workoutCaloriesBurned": 320,
    "workoutsToday": 1,
    "recentMeals": ["200 g chicken breast", "1 cup greek yogurt"]
  },
  "commonFoods": [],
  "recentMessages": [
    { "role": "user", "text": "should I eat a burger tonight" },
    { "role": "assistant", "text": "You have 900 kcal remaining." }
  ]
}
```

### Meal image endpoint — separate contract

**CONFIRMED:** `AIMealImageAnalysisRequest` uses `message`, `image`, optional `clarification`, `previousAnalysis` — **not** full `AIContext`. `CoachMealImageAIRequestBuilder` does not populate `userContext`.

---

## 8. AI Routing and Intent Classification

### Pipeline order

1. `InputNormalizer.normalize(text)`
2. `LocalNoAPIGuard.evaluate` → may return without API
3. Classify dedup cache (8s, normalized text + calorie/protein fingerprint)
4. `CheapLLMIntentClassifier.classify` → `POST /v1/ai/classify-coach-intent`
5. `CoachIntentConfidenceGate.evaluate` (thresholds 0.70 high, 0.45 medium)
6. `CoachIntentRouter.route`

### Local no-API guard branches

| Branch | Example input | Result |
|--------|---------------|--------|
| `.noOp` | `""`, `"..."` | Try fitness prompt |
| `.greeting` | `"hi"`, `"thanks"` (≤3 tokens) | Greeting response — **no API** |
| `.deterministicCommand` | `"add 500ml water"` | Local parse → execute |
| `.localFoodEstimate` | `"log 200g chicken breast"` (catalog, high confidence) | Local estimate → confirm |
| `.clarification` | Invalid local parse | Clarification message |
| `.passToCheapLLM` | `"chicken rice"`, `"what should I eat?"` | → Classifier API |

### Confidence gate

| Confidence | Mutation intent | Outcome |
|------------|-----------------|---------|
| ≥ 0.70 | Any | Proceed |
| < 0.70 | Harmless advice/lookup | Proceed (action stripped if spurious) |
| 0.45–0.69 | Has mutation/action | Clarify |
| < 0.45 | Has mutation/action | Clarify (low confidence message) |
| < 0.45 | `unrelatedOrUnsupported` | Unsupported scope |

### Intent → route mapping (`CoachIntentRouter`)

| Intent | Route |
|--------|-------|
| `log_food` | Always `.ai(.estimateFood)` |
| `log_water`, `log_weight`, `undo` | `.localCommand` if action draft present |
| `daily_summary` | `.localCommand(.status)` |
| `log_workout` | `.trainingLogRedirect` |
| `edit_log`, `delete_log` | `.ai(.editEntry/.deleteEntry)` |
| Advice intents | `.ai(.mealAdvice)` |
| `app_help`, `general_conversation` | `.noOp` greeting |
| `unrelated_or_unsupported` | `.invalid` |

### Decision tree

```mermaid
flowchart TD
    Start[User text] --> Norm[InputNormalizer]
    Norm --> Guard{LocalNoAPIGuard}
    Guard -->|empty/punct| NoOp[noOp]
    Guard -->|greeting ≤3 tokens| Greet[greeting - no API]
    Guard -->|local parse OK| Local[localCommand]
    Guard -->|catalog food high conf| LocalFood[localFoodEstimate]
    Guard -->|pass| Classify[classify-coach-intent API]
    Classify --> Gate{ConfidenceGate}
    Gate -->|low mutation| Clarify[clarification]
    Gate -->|proceed| Intent{CoachIntent}
    Intent -->|log_food| Est[estimate-food API]
    Intent -->|advice| Advice[meal-advice API]
    Intent -->|log_water/weight| LocMut[local mutation]
    Intent -->|log_workout| Redirect[training redirect]
    Est --> Confirm[food confirmation]
    Confirm -->|user confirms| Persist[FoodLogService]
    LocMut --> PersistW[Water/Weight Service]
```

### Key questions answered

| Question | Answer |
|----------|--------|
| **"I ate chicken rice" → log?** | Local guard fails (compound food) → classify `log_food` → **always** `estimate-food` API → pending confirmation |
| **"what should I eat?" → advice?** | Classify `meal_decision` or `nutrition_advice` → `meal-advice` API |
| **"hello" → backend?** | If ≤3 tokens and standalone greeting → **no API**. `"hello are you working?"` (4 tokens) → **requires classify API** |
| **Follow-up?** | Low confidence mutation → clarification string. Photo analysis → `ImageAnalysisSession` clarification loop. |
| **Misclassification loci** | Local guard boundaries, classifier intent, confidence gate, spurious `action` on advice intents (mitigated by stripping) |

---

## 9. Food Parsing and Nutrition Mutation Pipeline

### End-to-end flow

```
User input
  → Route (local catalog / classify + estimate-food / photo analyze-meal-image)
  → AI returns FoodLogDraft(s)
  → FoodEstimateResponseValidator
  → FoodLogDraftMapper.primaryMeal
  → FoodLogDraftNutritionCompleter.mergeExplicit + sanitize
  → NutritionSanityValidator
  → ConfirmationPolicy → requiresConfirmation (AI food always)
  → CoachPendingConfirmation.food
  → User confirm / edit sheet
  → CoachMutationExecutor.executeLogFood
  → FitnessActionCenter.logFood → FoodLogService → DailyLog recalc
  → AppRefreshCenter.notifyDataChanged
  → Assistant confirmation message
```

### Key files

| Stage | File |
|-------|------|
| Local parse | `LocalCommandParser.parseFood` — needs explicit calories + macros |
| Local catalog | `LocalNutritionEstimator` — ~15 items, blocks compound foods |
| AI estimate | `AIService.estimateFood` → `FormaAIBackendClient` |
| Backend | `functions/src/index.ts` `estimateFood()`, `foodEstimateExtraction.ts` |
| Validation | `FoodEstimateResponseValidator`, `AIResponseValidator` |
| Completion | `FoodLogDraftNutritionCompleter` |
| Confirmation | `ConfirmationPolicy`, `AIFoodConfirmationSheet` |
| Mutation | `CoachMutationExecutor.executeLogFood` |
| Photo | `mealImageAnalysis.ts`, `MealImageAnalysisMapper` |

### Confirmation behavior

**CONFIRMED:**
- **AI food (text or photo): always requires confirmation**
- **Local catalog food: requires confirmation**
- **Local parsed food with explicit macros: executes immediately**
- User sees structured nutrition in confirmation bar / sheet before commit

### Error paths

| Failure | Behavior |
|---------|----------|
| Invalid AI JSON | Validator reject → `aiNotUnderstood` or repair retry (one) |
| Backend timeout | `AIServiceError` → user message |
| Auth failure | Session banner + retry |
| Wrong parse | User can edit in `AIFoodConfirmationSheet` or reject |
| Photo 422 | Failure assistant message + retry |

### Schema contracts

- `FoodLogDraft` with `components[]`, `totals`, `confidence`, `assumptions`
- Backend strict JSON schema per ingredient component
- `requiresConfirmation: true` enforced in food estimate prompts

---

## 10. Water, Weight, Workout, and Other Mutation Pipelines

### Water

| Aspect | Detail |
|--------|--------|
| Examples | `"add 500ml water"`, `"drank 1.5L"` |
| Route | Local parser or classifier `log_water` |
| Parser | `LocalCommandParser.parseWater` (max 5000ml) |
| Confirmation | **Immediate execute** |
| Persistence | `WaterLogService` → `DailyLog` water total |
| AI path | `parseCommand` water action → immediate |

### Weight

| Aspect | Detail |
|--------|--------|
| Examples | `"weight 90.15"`, `"log weight 82.5"` |
| Route | Local or classifier `log_weight` |
| Parser | `LocalCommandParser.parseWeight` |
| Confirmation | **Immediate execute** |
| Persistence | `WeightLogService` + `DailyLog.weightKg` |
| Undo | **Not available** — `executeUndo(.weight)` returns unavailable message |

### Workout

| Aspect | Detail |
|--------|--------|
| Examples | `"ran 5k"`, `"bench 5x5"` |
| Route | `.trainingLogRedirect` — **no mutation** |
| Message | `TrainingIntegrationCopy` — directs to Apple Health |
| `ConfirmationPolicy` | Rejects `.logWorkout` |

### Steps

| Aspect | Detail |
|--------|--------|
| Local parse | `parseSteps` exists |
| Execute | **Placeholder only** — `CoachResponseBuilder.stepsPlaceholder` |

### Daily review

| Aspect | Detail |
|--------|--------|
| Route | Local `.dailyReview` or AI `generate-daily-review` |
| Context | `DailyReviewAIInput` — richer than chat context |
| recentMessages | `[]` for review |

### Edit / delete food

| Aspect | Detail |
|--------|--------|
| Route | `parse-edit-delete` API |
| Confirmation | Required |
| Executor | `applyFoodEdit`, `deleteFood` on `CoachMutationExecutor` |

---

## 11. Apple Health and Workout Context in Coach

### HealthActivityQueryService

**File:** `Application/Queries/HealthActivityQueryService.swift`

| Method | Purpose |
|--------|---------|
| `workouts(from:to:)` | Repository cache or live HealthKit |
| `dailyTrainingActivity(on:)` | `DailyTrainingActivity` for a day |
| `workoutCountToday()` | Count wrapper |
| `stepsToday()` | Repository metrics or HealthKit |

### Cache vs live

**CONFIRMED:** When `HealthIntelligenceFeatureFlags.isRepositoryReadRoutingEnabled` (default true):
- Reads from `HealthDataRepository` cached bundles
- On cache miss: fetch HealthKit → normalize → store

When disabled: direct HealthKit with **empty array fallback** on errors (logged, not surfaced to user).

### Coach usage points

| Location | What it reads |
|----------|---------------|
| `CoachModel.processCoachMessage` | `dailyTrainingActivity().workoutCount` → `makeContext(workoutsToday:)` |
| `CoachMealPhotoAnalyzer.performAnalysis` | `makeContext` **without** workoutsToday → **defaults to 0** |
| `CoachMutationExecutor.hasWorkoutToday()` | For meal advice formatting |
| `CoachTodayContextBuilder` | `hasWorkout` for UI card |
| `TodayAISummaryMapper` | `workoutCaloriesBurned` from `DailyLog`, not live query |

### Permission denied / simulator

**CONFIRMED:** HealthKit optional-access failures → empty workouts array → `workoutsToday: 0`, `hasWorkout: false`. No distinct "permission denied" flag in AI context.

### Risk answers

| Question | Answer |
|----------|--------|
| Coach think user didn't work out? | **Yes RISK** — HealthKit error → empty → 0 workouts |
| Miss steps? | **Yes CONFIRMED** — context uses `DailyLog.steps`, not live `stepsToday()` |
| Miss workout history? | **Yes CONFIRMED** — only today's count in context; no history |
| Double-count legacy workout calories? | **RISK** — `DailyLog.workoutCaloriesBurned` may overlap with activity calories depending on sync logic |

---

## 12. Persistence and Data Source Map

### Data flow diagram

```mermaid
flowchart LR
    UA[User Action] --> CM[CoachModel]
    CM --> ME[CoachMutationExecutor]
    ME --> AC[FitnessActionCenter]
    AC --> FLS[FoodLogService]
    AC --> WLS[WaterLogService]
    AC --> WTS[WeightLogService]
    AC --> DLS[DailyLogService]
    FLS & WLS & WTS --> SD[(SwiftData)]
    DLS --> SD
    AC --> RC[AppRefreshCenter]
    RC --> Today[Today Tab]
    RC --> Journey[Journey Tab]
```

### Entity map

| Entity | Path | Read | Write | Synced remote | Timestamps |
|--------|------|------|-------|---------------|------------|
| `DailyLogEntity` | `Infrastructure/Persistence/SwiftData/Entities/DailyLogEntity.swift` | Coach, Today | ActionCenter | No | Yes (day) |
| `FoodEntryEntity` | `.../FoodEntryEntity.swift` | Coach context (names) | FoodLogService | No | Yes |
| `WaterEntryEntity` | `.../WaterEntryEntity.swift` | Via DailyLog aggregate | WaterLogService | No | Yes |
| `WeightEntryEntity` | `.../WeightEntryEntity.swift` | WeightLogService | WeightLogService | No | Yes |
| `UserProfileEntity` | `.../UserProfileEntity.swift` | AI context | Profile service | No | — |
| `ChatMessageEntity` | `.../ChatMessageEntity.swift` | **Legacy only** | Not used by Coach | No | — |
| Health cache | `HealthDataRepository` / `LocalHealthCacheStore` | HealthActivityQuery | Health sync | No | Yes |

### Chat storage

**CONFIRMED:** `CoachInMemoryChatTranscriptStore` — session only. TODO for SwiftData transcript store noted in code.

### Image storage

**CONFIRMED:** JPEG bytes in `ChatMessage.imageAttachment` in memory only. `CoachPendingImageLocalSourceStore` holds `UIImage` for retries.

---

## 13. Backend / Firebase / OpenAI Pipeline

### iOS client

**`FormaAIBackendClient`** (`Infrastructure/AI/FormaAIBackendClient.swift`):
- POST to `AIBackendConfiguration.backendURL()` + path
- Auth: Firebase ID token `Authorization: Bearer <token>` (value not documented here)
- Trace: `X-Forma-Trace-Id`
- Timeout: 45s request / 90s resource

**Gateway URL (CONFIRMED in `project.pbxproj`):** `https://us-central1-fitness-coach-732fd.cloudfunctions.net/aiGateway`  
**Secret (CONFIRMED name only):** `OPENAI_API_KEY` in Firebase Secret Manager — **value redacted**

### Endpoints (`LLMEndpoint.swift`)

| Endpoint | Path | Used for |
|----------|------|----------|
| Chat classify | `v1/ai/classify-coach-intent` | Intent routing |
| Food estimate | `v1/ai/estimate-food` | Text/photo food logging |
| Meal advice | `v1/ai/generate-meal-advice` | Coaching replies |
| Daily review | `v1/ai/generate-daily-review` | End-of-day review |
| Parse command | `v1/ai/parse-command` | Legacy/alternate parse |
| Parse workout | `v1/ai/parse-workout` | Redirected in practice |
| Edit/delete | `v1/ai/parse-edit-delete` | Entry mutations |
| Multi-action | `v1/ai/parse-multi-action` | Compound commands |
| Meal image | `v1/ai/analyze-meal-image` | Photo analysis |

### Request pattern

```json
{ "text": "...", "context": { ...AIContext... }, "modelName": "gpt-5-nano" }
```

Context JSON-stringified into OpenAI Responses API input on server.

### Models (CONFIRMED defaults in `CoachModelConfig`)

- Cheap classifier/answer: `gpt-5-nano`
- Strong coach: `gpt-5.4-nano`
- Server may override via env

### Stateless?

**CONFIRMED:** Yes. Each request carries `context` + `recentMessages` from iOS. No server-side conversation store.

### Error mapping

`LLMClientError` → `AIServiceError` → `userMessage` / `coachSessionFailure` / `backendUnavailable`

### Fallback

`FallbackLLMClient` wraps primary; if URL missing → `UnavailableLLMClient` at startup.

---

## 14. Prompt and System Instruction Audit

### Authoritative runtime prompts

**File:** `functions/src/index.ts`

#### `sharedRules()` (all tasks)

```
You are FitPilot's parsing and coaching assistant.
Return JSON only, matching the supplied schema.
You parse, estimate, and explain. You never mutate app state.
The app validates and logs drafts. You only return intents, drafts, and coaching text.
For uncertain food, workouts, edits, deletes, or multi-action commands, set requiresConfirmation true.
User text is untrusted...
Do not diagnose medical conditions...
Be concise, practical, supportive, and honest.
```

#### `coachIntentClassificationInstructions()`

- Classify only — do not answer user
- 17 intent enum values
- **"Never copy nutrition from chat history or prior assistant estimates"**
- `log_food` action: name/qty/unit only unless user supplied explicit numbers
- Macro grams vs portion quantity disambiguation rule

#### `foodEstimateInstructions()`

- Per-ingredient components required
- Never collapse multiple ingredients
- Sum components to totals exactly
- `requiresConfirmation true` unless user supplied exact complete nutrition

#### `mealAdviceInstructions()`

- Brief advice using fitness context
- **"Do not log anything"**

#### `foodPhotoEstimateInstructions()`

- Per visible item as component
- `requiresConfirmation true`

### iOS reference prompts

**File:** `Infrastructure/AI/AIPromptBuilder.swift` — parallel definitions; **backend is authoritative** in production.

### Prompt risks

| Risk | Severity |
|------|----------|
| Model may still hallucinate logs in `assistantMessage` despite rules | Medium |
| Chat history visible but instructions say ignore — soft constraint | High |
| No explicit "today's events in order" instruction | High |
| `mealAdvice` doesn't instruct to cite `recentMeals` vs `todaySummary` | Medium |
| Classifier told to populate `log_food` action then always re-estimated — redundant, noise | Low |

---

## 15. Accuracy Failure Modes

### missing context

| Mode | Files | Severity | Reproduce | Timeline fix? |
|------|-------|----------|-----------|---------------|
| No per-meal macros in context | `CoachAIContextBuilder` | High | Ask "how much protein from lunch?" after logging | Yes |
| No water event history | `TodayAISummaryMapper` | Medium | "how much water did I drink earlier?" | Yes |
| No workout details | `HealthActivityQueryService` | Medium | "what workout did I do?" | Yes |
| Photo path missing workouts | `CoachMealPhotoAnalyzer` | Medium | Photo after morning workout | Yes |
| `commonFoods` empty | `CoachAIContextBuilder` | Low | Personalized suggestions | Partial |

### stale context

| Mode | Files | Severity | Reproduce | Timeline fix? |
|------|-------|----------|-----------|---------------|
| Context before confirm | `CoachModel.processCoachMessage` | High | Log food, immediately ask remaining calories | Yes |
| `DailyLog.steps` stale | `TodayAISummaryMapper` | Medium | Steps synced after log read | Yes |
| UI today card vs AI context diverge | `CoachTodayContextBuilder` vs builder | Low | Compare empty card to advice | Partial |

### wrong day boundary / timezone

| Mode | Files | Severity | Reproduce | Timeline fix? |
|------|-------|----------|-----------|---------------|
| `Date()` vs calendar day for logs | `CoachContextBuilder`, `DailyLogService` | Medium | Message near midnight | Yes |
| Timezone sent but log day implicit | `AIContext` | Medium | Travel across TZ | Yes |

### misclassification

| Mode | Files | Severity | Reproduce | Timeline fix? |
|------|-------|----------|-----------|---------------|
| Advice → log_food | `CoachIntentRouter` | High | "should I log pizza?" | Partial |
| Greeting needs API | `LocalNoAPIGuard` | Medium | "hello there friend" (4+ tokens) | No |
| Food → advice | Classifier | Medium | "calories in chicken rice" vs log intent | Partial |

### parsing errors

| Mode | Files | Severity | Reproduce | Timeline fix? |
|------|-------|----------|-----------|---------------|
| Compound dish underestimate | `estimate-food` | High | "chicken rice" | Partial |
| Portion conflation | `foodEstimateExtraction` | High | Multi-item meals | Partial |
| Macro in quantity field | Classifier sanitizer | Medium | "50g protein chicken" | Partial |

### duplicate logs

| Mode | Files | Severity | Reproduce | Timeline fix? |
|------|-------|----------|-----------|---------------|
| Double confirm same pending | `CoachModel` | Medium | Tap confirm twice quickly | Yes |
| Repeat "log eggs" | No dedup | Low | Send same message twice | Yes |

### immediate mutation without confirmation

| Mode | Files | Severity | Reproduce | Timeline fix? |
|------|-------|----------|-----------|---------------|
| Water/weight immediate | `ConfirmationPolicy` | Low (by design) | Wrong ml parsed | Yes (pending events) |

### Apple Health empty fallback

| Mode | Files | Severity | Reproduce | Timeline fix? |
|------|-------|----------|-----------|---------------|
| HealthKit error → 0 workouts | `HealthActivityQueryService` | High | Deny permission | Yes (attribution) |

### prompt ambiguity

| Mode | Severity | Reproduce |
|------|----------|-----------|
| Model cites chat not structured data | High | Multi-turn portion edit |
| No "missing data" signaling | Medium | Ask about steps when nil |

### backend timeout / fallback

| Mode | Severity | Reproduce |
|------|----------|-----------|
| Classify fails → unavailable | High | Airplane mode mid-message |
| Repair retry insufficient | Medium | Malformed JSON once |

### conversation truncation

| Mode | Severity | Reproduce |
|------|----------|-----------|
| Only 5 messages | High | 10-turn negotiation lost |
| No timestamps in AI messages | Medium | "earlier I said..." |

### UI / cross-screen inconsistency

| Mode | Severity | Reproduce |
|------|----------|-----------|
| Coach advice vs Today numbers | Medium | Stale DailyLog |
| Journey not in context | Low | Weekly trend questions |

---

## 16. Timeline Improvement Opportunities

**Repo-fact based proposals only — not implemented.**

1. **Event-sourced daily ledger** — append-only `CoachDayEvent` entities: `foodLogged`, `waterLogged`, `weightLogged`, `workoutDetected`, `aiResponse`, `userConfirmed`, `userRejected`, `entryEdited`, `entryDeleted`.
2. **Immutable log events + correction events** — never mutate events; add `foodCorrected` referencing prior event ID.
3. **Structured recent timeline for model** — compact last-N events with timestamps, source (`user`/`ai`/`healthkit`), confidence.
4. **Full recent timeline vs compact summary** — dual-layer context: `todaySummary` (aggregates) + `recentEvents[]` (ordered).
5. **Image attachment events** — link photo session ID → analysis result → confirmed entry ID.
6. **Apple Health workout events** — inject workout name, duration, energy at event time.
7. **Hydration events** — individual water adds, not just running total.
8. **Pending/failed mutation events** — expose in-context so model doesn't assume log succeeded.
9. **Timestamp normalization** — all events in user TZ ISO8601.
10. **Source attribution** — `parsedBy: local|classifier|estimate-food|photo`.
11. **Missing data flags** — explicit `steps: { value: null, reason: "not_synced" }`.
12. **Persist chat cross-launch** — `CoachSwiftDataChatTranscriptStore` (TODO already in code).
13. **Wire `HealthIntelligenceContextBuilder`** — recovery/load for advice quality.
14. **Populate `commonFoods`** from user history.
15. **Fix photo `workoutsToday`** — pass Health query into photo context builder.

---

## 17. Recommended Context Packet Shape for Future Coach

### Proposed schema

```swift
CoachContextPacket {
  // Meta
  generatedAt: ISO8601DateTime
  timezoneIdentifier: String
  localDate: String  // "2026-07-04" in user TZ
  appVersion: String?
  featureFlags: [String: Bool]?

  // User
  profile: {
    age, sex, heightCm, currentWeightKg, goalWeightKg,
    activityLevel, trainingFrequencyPerWeek,
    planGoalType: lose|maintain|gain
  }

  // Targets & consumption (canonical from DailyNutritionSummaryBuilder)
  today: {
    calorieTarget, caloriesConsumed, caloriesRemaining,
    proteinTarget, proteinConsumed, proteinRemaining,
    carbsTarget, carbsConsumed, carbsRemaining,
    fatTarget, fatConsumed, fatRemaining,
    waterTargetMl, waterConsumedMl, waterRemainingMl,
    weightKg: Double?,
    steps: { value: Int?, source: dailyLog|healthkit|missing, asOf: Date? }
  }

  // Training
  training: {
    workoutsToday: Int,
    workoutCaloriesBurned: Int,
    workouts: [{ name, durationMin, activeEnergyKcal, startTime }],
    hasWorkout: Bool
  }

  // Timeline (NEW — primary accuracy upgrade)
  recentEvents: [
    {
      id: UUID,
      at: ISO8601DateTime,
      type: userMessage|assistantMessage|foodLogged|waterLogged|weightLogged|
            workoutDetected|foodPending|foodRejected|entryEdited|photoAnalyzed,
      source: user|coach|healthkit|system,
      summary: String,
      payload: { ... type-specific ... },
      confidence: high|medium|low?,
      linkedEntryId: UUID?
    }
  ]

  // Conversational (bounded)
  recentMessages: [{ role, text, at, messageId }]

  // Food helpers
  recentMealsStructured: [
    { name, quantity, unit, calories, proteinG, loggedAt, confidence }
  ]
  commonFoods: [String]

  // Explicit gaps
  missingData: [String]
  assumptions: [String]
}
```

### Example JSON fragment

```json
{
  "localDate": "2026-07-04",
  "timezoneIdentifier": "Asia/Singapore",
  "today": { "caloriesRemaining": 900, "proteinRemaining": 80 },
  "training": { "workoutsToday": 1, "workouts": [{ "name": "Running", "durationMin": 32 }] },
  "recentEvents": [
    { "type": "foodLogged", "at": "2026-07-04T08:15:00+08:00", "summary": "200g chicken breast", "payload": { "calories": 330 } },
    { "type": "userMessage", "at": "2026-07-04T12:00:00+08:00", "summary": "should I eat burger tonight" },
    { "type": "assistantMessage", "at": "2026-07-04T12:00:02+08:00", "summary": "You have 900 kcal remaining..." }
  ],
  "missingData": ["steps"]
}
```

---

## 18. Tests and Current Coverage

### Coach-prefixed tests (27 files)

| File | Covers |
|------|--------|
| `CoachRoutingTests.swift` | Route decider, intent routing |
| `CoachInputHardeningTests.swift` | Safety, confidence gate, sanitizer |
| `CoachInputStateTests.swift` | Composer state machine |
| `CoachFoodLoggingRegressionTests.swift` | Food logging regressions |
| `CoachTodayContextBuilderTests.swift` | UI today card builder |
| `CoachMealPhoto*.swift` (4 files) | Photo pipeline, analysis, recovery |
| `CoachImage*.swift` (10+ files) | Image pipeline, pick flow, E2E |
| `CoachMessagePresenterTests.swift` | Presentation mapping |
| `CoachPending*Tests.swift` | Confirmation copy |
| `CoachMutationFormattingTests.swift` | Response formatting |
| `CoachNutritionSummaryTests.swift` | Nutrition formatter |
| `CoachSpeechTests.swift` | Speech recognizer |

### Related tests

| File | Covers |
|------|--------|
| `ImageAnalysisSessionTests.swift` | Photo session FSM |
| `FormaAIBackendClientTests.swift` | HTTP client |
| `DailyNutritionSummaryBuilderTests.swift` | Nutrition math |
| `FitnessActionCenterTests.swift` | Mutations |
| `functions/test/coachIntentSanitizer.test.ts` | Intent sanitizer |
| `functions/test/aiGateway.contract.test.ts` | Gateway contracts |

### Missing test coverage (gaps)

| Area | Status |
|------|--------|
| Timeline ordering | **Not tested** |
| Duplicate log prevention | **Limited** |
| Food parse accuracy | Partial (regression only) |
| Model context completeness | **Not tested** |
| HealthKit denied state | **Not tested** |
| Workout context in AIContext | **Not tested** |
| Steps in AIContext (live vs DailyLog) | **Not tested** |
| Backend unavailable E2E | Partial |
| Correction/edit/delete flows | Partial |
| Timezone day boundary | **Not tested** |
| Conversation truncation impact | **Not tested** |
| Photo `workoutsToday=0` bug | **Not tested** |

---

## 19. Build / Run / Debug Instructions

### Build iOS app

**CONFIRMED from project structure:**
```bash
# Open in Xcode
open "Fitness Coach.xcodeproj"

# Or CLI (scheme: "Fitness Coach")
xcodebuild -scheme "Fitness Coach" -destination "platform=iOS Simulator,name=iPhone 16" build
```

CI scheme also exists: `Fitness Coach CI.xcscheme`

### Run tests

```bash
# iOS unit tests
xcodebuild -scheme "Fitness Coach" -destination "platform=iOS Simulator,name=iPhone 16" test

# Firebase functions tests
cd functions && npm test
```

### Backend URL configuration

- Build setting `FORMA_AI_BACKEND_URL` in `project.pbxproj` → `Info.plist`
- Env override: `FORMA_AI_BACKEND_URL` (localhost rejected by `AIBackendConfiguration`)
- Production: `https://us-central1-fitness-coach-732fd.cloudfunctions.net/aiGateway`

### Debug logs

**CONFIRMED subsystems (OSLog):**
- `Forma` / `CoachAI` — AI errors
- `Forma` / `AIBackend` — URL wiring
- `FormaPipelineTracer` — end-to-end trace (DEBUG-heavy)
- `CoachImageAnalysisDebugLogger`, `CoachFoodEstimateDebugLogger`
- Trace ID passed as `X-Forma-Trace-Id` header

### Feature flags

- `HealthIntelligenceFeatureFlags.isRepositoryReadRoutingEnabled` — Health cache routing
- `aiCommandParsingEnabled` — true when backend URL resolves (`AppContainer`)

### Test Coach locally

1. Run app in Simulator with valid Firebase auth + gateway URL
2. Use `AppContainer(inMemory: true)` in tests with `MockLLMClient` / test harness (`CoachRoutingIntegrationTestSupport`)
3. For backend: `cd functions && npm run serve` (emulator) — **HYPOTHESIS:** requires Firebase emulator setup and auth; localhost URL rejected by iOS client

### Simulator limitations

- HealthKit workouts/steps limited or empty
- Camera — use photo library test images
- Speech recognition requires permission

### Known HealthKit limitations

- Optional access failures silently become empty workout arrays
- Coach cannot distinguish "no workout" vs "permission denied" in AI context

---

## 20. Final Findings Summary

### Top 10 confirmed architecture facts

1. Coach is a **read/mutate-through-action-center** layer — not a state owner.
2. AI context is a **compact `AIContext`** built per send by `CoachContextBuilder`.
3. Only **5 prior chat messages** (role+text) and **6 meal name strings** reach the model.
4. **Food always confirms** before persistence when AI-estimated (text or photo).
5. **Water/weight log immediately** without confirmation.
6. **Workouts are read-only** in Coach; logging redirects to Apple Health.
7. **Chat is in-memory only** — no cross-launch persistence.
8. Routing is **local guard → classify API → confidence gate → intent router**.
9. Backend `aiGateway` is **stateless** — iOS sends full context each request.
10. **Meal photo endpoint does not receive `AIContext`** — separate schema.

### Top 10 model accuracy risks

1. No true timeline — model sees aggregates + 5 chat lines only.
2. Chat history can contradict structured data with no enforcement.
3. Compound foods rely entirely on estimate-food quality.
4. Steps often missing (`DailyLog.steps` not live query).
5. Photo analysis passes `workoutsToday=0` by default.
6. HealthKit errors → false "no workout today".
7. Context may be stale relative to just-confirmed logs.
8. Classifier + estimate-food double-call adds inconsistency surface.
9. Midnight/timezone boundary ambiguity for "today".
10. Truncated history drops corrections and prior estimates.

### Top 10 timeline gaps

1. No event ledger for today's actions.
2. No timestamps on AI messages in context.
3. No structured per-meal macros in context.
4. No water/weight event sequence.
5. No workout detail events.
6. No pending/failed mutation visibility.
7. No correction/edit audit trail for model.
8. No cross-session conversation memory.
9. No source attribution per fact.
10. No explicit `missingData` signaling.

### Top 10 files to inspect first

1. `Fitness Coach/Application/StateBuilders/Coach/CoachAIContextBuilder.swift`
2. `Fitness Coach/Features/Coach/Model/CoachModel.swift`
3. `Fitness Coach/Application/UseCases/Coach/Pipeline/CoachRouteDecider.swift`
4. `Fitness Coach/Application/UseCases/Coach/Pipeline/CoachIntentRouter.swift`
5. `Fitness Coach/Application/UseCases/Coach/CoachAIRouteHandler.swift`
6. `Fitness Coach/Infrastructure/AI/AIContext.swift`
7. `functions/src/index.ts`
8. `Fitness Coach/Application/StateBuilders/Nutrition/TodayAISummaryMapper.swift`
9. `Fitness Coach/Application/Queries/HealthActivityQueryService.swift`
10. `Fitness Coach/Application/UseCases/Coach/CoachMealPhotoAnalyzer.swift`

### Top 10 questions for ChatGPT

1. What canonical **event timeline schema** best fits Coach's mutation + advice flows?
2. How should **aggregates vs events** be dual-sent without blowing token budgets?
3. What's the minimum **timeline depth** (hours? events? tokens?) for meal advice accuracy?
4. Should classification and advice **share one context builder** or split?
5. How to prevent the model from **preferring chat text over structured events**?
6. What's the right **fix for photo context** — attach `AIContext` or event slice?
7. How should **HealthKit uncertainty** be represented (`missing` vs `0`)?
8. What **persistence layer** — SwiftData events, derived snapshot, or hybrid?
9. Phased rollout: **context layer first** without UI changes — what's the migration plan?
10. How to validate accuracy — **golden transcripts**, property tests, or offline eval harness?

---

## 21. Copy-Paste Analysis Prompt

Copy everything below together with this document into ChatGPT:

---

**Analysis prompt:**

You are an expert iOS + LLM systems architect reviewing the Forma/Fitness Coach feature.

I have attached a full context packet (`COACH_FULL_CONTEXT_PACKET.md`) documenting the current Coach architecture as implemented in an iOS SwiftUI app with a Firebase `aiGateway` backend.

Your goals:
1. **Analyze the current Coach architecture** — routing, context building, mutations, HealthKit integration, and backend contracts.
2. **Identify why model accuracy is weak today**, especially for questions about "what happened today", meal decisions, and food logging. Focus on timeline/context gaps, not UI polish.
3. **Design a production-ready timeline/context architecture** — event model, persistence, context packet shape, token budget strategy, and how iOS should build context before each AI call. Prefer immutable events + derived snapshots. Include source attribution and missing-data signaling.
4. **Propose a phased Cursor implementation workflow** — ordered PRs, files to touch first, test strategy, and feature flags. **Do not change Coach UI until the context layer is correct.**
5. **Call out risks** — stale data, timezone boundaries, HealthKit false negatives, duplicate logs, and chat-history hallucination. Separate confirmed facts from hypotheses.

Deliverables:
- Architecture diagram (Mermaid)
- Recommended `CoachContextPacket` schema (final form)
- Phase 0–3 implementation plan with acceptance criteria per phase
- Top 15 accuracy wins ranked by impact vs effort
- Explicit list of what **not** to build yet

Assume the app cannot send full database history or unbounded chat. Privacy and cost matter.

---

## Appendix: Checklist for Next Analysis Step

ChatGPT should answer:

- [ ] Is the current `AIContext` sufficient for meal advice? What specific fields cause wrong answers?
- [ ] Should food logging use classifier drafts or skip straight to estimate-food?
- [ ] What timeline events are **minimum viable** for v1?
- [ ] How to sync timeline with `FitnessActionCenter` mutations atomically?
- [ ] Should `recentMessages` be removed in favor of event-derived conversation summary?
- [ ] How to handle timezone / "today" definition consistently?
- [ ] What's the token budget target per request (classify vs advice vs estimate)?
- [ ] How should photo analysis context differ from text chat context?
- [ ] What eval dataset should we build from existing `Coach*Tests` patterns?
- [ ] Which existing files should **not** be refactored early (routing stability)?

---

*End of Coach Full Context Packet*
