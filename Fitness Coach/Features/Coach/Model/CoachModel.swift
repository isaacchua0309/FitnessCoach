//
//  CoachModel.swift
//  Fitness Coach
//
//  FitPilot AI — AI interface into shared fitness state (not a state owner).
//

import Combine
import Foundation

@MainActor
final class CoachModel: ObservableObject {

    @Published private(set) var messages: [ChatMessage] = []
    @Published private(set) var inputState: CoachInputState = .empty
    @Published private(set) var processingPhase: CoachProcessingPhase = .idle
    @Published private(set) var errorTitle: String?
    @Published private(set) var errorMessage: String?
    @Published private(set) var showsAuthRetry: Bool = false

    var isSending: Bool {
        if case .idle = processingPhase { return false }
        return true
    }

    var inputText: String {
        get { inputState.text }
        set { mutateInputState { $0.updateText(newValue) } }
    }

    var stagedAttachment: CoachInputAttachment? {
        inputState.attachment
    }

    var stagedMealPhotoJPEG: Data? {
        inputState.attachment?.imageData
    }

    var messageCount: Int {
        messages.count
    }
    @Published private(set) var pendingConfirmation: CoachPendingConfirmation?
    @Published var isShowingFoodEditSheet = false
    @Published private(set) var isConfirmingPending = false
    @Published private(set) var foodEditErrorMessage: String?
    @Published private(set) var todayContext: CoachTodayContextState?
    @Published private(set) var starterPromptSpecs: [CoachStarterPromptSpec] = CoachStarterPrompt.defaultQuickActionSpecs

    private let localCommandParser: LocalCommandParser
    private let dailyLogReader: any DailyLogReading
    private let healthActivityQuery: HealthActivityQueryService
    private let weightLogReader: (any WeightLogReading)?
    private let mutationHistory = CoachMutationHistory()

    private let aiService: AIServiceProtocol?
    private let aiContextBuilder: CoachContextBuilder?
    private var routeDecider: CoachRouteDecider
    private let coachModelConfig: CoachModelConfig
    private let aiCommandParsingEnabled: Bool
    private let trainingInsightsStore: TrainingInsightsStore?

    private let mutationExecutor: CoachMutationExecutor
    private let routeHandler: CoachAIRouteHandler
    private let mealPhotoAnalyzer: CoachMealPhotoAnalyzer
    private let transcriptStore: CoachChatTranscriptStore

    init(
        localCommandParser: LocalCommandParser? = nil,
        actionCenter: FitnessActionCenter,
        dailyLogReader: any DailyLogReading,
        healthActivityQuery: HealthActivityQueryService,
        weightLogReader: (any WeightLogReading)? = nil,
        aiService: AIServiceProtocol? = nil,
        userProfileReader: (any UserProfileReading)? = nil,
        aiCommandParsingEnabled: Bool = false,
        coachModelConfig: CoachModelConfig? = nil,
        routeDecider: CoachRouteDecider? = nil,
        trainingInsightsStore: TrainingInsightsStore? = nil,
        transcriptStore: CoachChatTranscriptStore = CoachInMemoryChatTranscriptStore()
    ) {
        self.localCommandParser = localCommandParser ?? .standard
        self.dailyLogReader = dailyLogReader
        self.healthActivityQuery = healthActivityQuery
        self.weightLogReader = weightLogReader
        self.aiService = aiService
        self.aiCommandParsingEnabled = aiCommandParsingEnabled
        self.coachModelConfig = coachModelConfig ?? .default
        self.routeDecider = routeDecider ?? CoachRouteDecider()
        self.trainingInsightsStore = trainingInsightsStore
        if let userProfileReader {
            self.aiContextBuilder = CoachContextBuilder(
                dailyLogReader: dailyLogReader,
                userProfileReader: userProfileReader,
                healthActivityQuery: healthActivityQuery,
                actionCenter: actionCenter
            )
        } else {
            self.aiContextBuilder = nil
        }

        let executor = CoachMutationExecutor(
            actionCenter: actionCenter,
            dailyLogReader: dailyLogReader,
            healthActivityQuery: healthActivityQuery,
            mutationHistory: mutationHistory
        )
        self.mutationExecutor = executor
        self.routeHandler = CoachAIRouteHandler(
            aiService: aiService,
            aiCommandParsingEnabled: aiCommandParsingEnabled,
            dailyLogReader: dailyLogReader,
            userProfileReader: userProfileReader,
            trainingInsightsStore: trainingInsightsStore,
            mutationExecutor: executor
        )
        self.mealPhotoAnalyzer = CoachMealPhotoAnalyzer(
            aiCommandParsingEnabled: aiCommandParsingEnabled,
            aiContextBuilder: self.aiContextBuilder,
            routeHandler: routeHandler
        )
        self.transcriptStore = transcriptStore
        self.messages = transcriptStore.loadMessages()
    }

    // MARK: Today context

    func refreshTodayContext() {
        Task {
            await refreshTodayContextAsync()
        }
    }

    private func refreshTodayContextAsync() async {
        do {
            let dailyLog = try dailyLogReader.getTodayLog()
            let training = await healthActivityQuery.dailyTrainingActivity(on: dailyLog.date)
            let latestWeight = dailyLog.weightKg == nil ? try weightLogReader?.getLatestWeight() : nil
            let weightLogged = (dailyLog.weightKg ?? latestWeight?.weightKg) != nil
            let integration = trainingInsightsStore?.integrationState ?? .connected
            let dataSource = trainingInsightsStore?.dataSource ?? .appleHealth

            todayContext = CoachTodayContextBuilder.build(
                dailyLog: dailyLog,
                weightLogged: weightLogged,
                hasWorkout: training.hasWorkout,
                trainingIntegration: integration,
                trainingDataSource: dataSource
            )
        } catch {
            todayContext = nil
        }
    }

    // MARK: Composer — meal photo attachment

    func removeStagedMealPhoto() {
        mutateInputState { $0.removeAttachment() }
    }

    @discardableResult
    func requestPhotoPick() -> Bool {
        guard inputState.canPickImage else {
            mutateInputState { $0.error = .attachmentAlreadyPresent }
            return false
        }
        return true
    }

    func handleMealPhotoSelection(
        _ result: Result<Data, CoachMealPhotoError>,
        source: CoachInputAttachmentSource
    ) {
        switch result {
        case .failure(.userCancelled):
            return
        case .failure(let error):
            appendAssistantMessage(CoachResponseBuilder.mealPhotoError(error))
        case .success(let rawData):
            stageMealPhoto(rawData, source: source)
        }
    }

    /// Legacy entry point — prefer `handleMealPhotoSelection`.
    func handlePhotoSelected() {
        handleMealPhotoSelection(.failure(.noImage), source: .library)
    }

    private func stageMealPhoto(_ rawData: Data, source: CoachInputAttachmentSource) {
        let prepared = mealPhotoAnalyzer.prepareJPEG(from: rawData)
        guard case .success(let jpegData) = prepared else {
            if case .failure(let error) = prepared {
                appendAssistantMessage(CoachResponseBuilder.mealPhotoError(error))
            }
            return
        }

        CoachMealPhotoPipeline.assertImagePayloadPresent(jpegData)
        mutateInputState { $0.stageImage(jpegData: jpegData, source: source) }
    }

    private func mutateInputState(_ transform: (inout CoachInputState) -> Void) {
        var next = inputState
        transform(&next)
        next.setSending(isSending)
        inputState = next
    }

    private func syncInputSendingFlag() {
        mutateInputState { $0.setSending(isSending) }
    }

    // MARK: Send

    func sendCurrentMessage() async {
        guard !isSending else { return }

        guard let snapshot = {
            var next = inputState
            guard let frozen = next.takeSendSnapshot() else { return nil }
            inputState = next
            syncInputSendingFlag()
            return frozen
        }() else {
            return
        }

        switch snapshot.sendPayload {
        case .textOnly(let text):
            await send(text)
        case .imageOnly(let jpegData):
            await sendMealPhoto(
                jpegData: jpegData,
                caption: nil,
                source: snapshot.attachment?.source
            )
        case .textAndImage(let text, let jpegData):
            await sendMealPhoto(
                jpegData: jpegData,
                caption: text,
                source: snapshot.attachment?.source
            )
        }
    }

    func send(_ text: String) async {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        guard !isSending else { return }

        switch CoachInputSafety.validate(trimmed) {
        case .empty:
            return
        case .tooLong:
            appendUserMessage(text: trimmed)
            appendAssistantMessage(CoachResponseBuilder.inputTooLongResponse)
            return
        case .valid:
            break
        }

        appendUserMessage(text: trimmed)

        let traceId = FormaPipelineTracer.beginTrace(userMessage: trimmed)
        let traceStarted = Date()
        var traceOutcome = "completed"

        beginProcessing(.text)
        defer {
            endProcessing()
            FormaPipelineTracer.endTrace(
                traceId: traceId,
                outcome: traceOutcome,
                durationMs: Int(Date().timeIntervalSince(traceStarted) * 1_000)
            )
        }

        if let pendingResult = await handlePendingConfirmationInput(trimmed) {
            traceOutcome = "pendingConfirmation"
            applyActionResult(pendingResult)
            return
        }

        let result = await processCoachMessage(trimmed, traceId: traceId, traceOutcome: &traceOutcome)
        applyActionResult(result)
    }

    func retryMealPhotoAnalysis(for userMessageID: UUID) async {
        guard !isSending else { return }
        guard let userMessage = messages.first(where: { $0.id == userMessageID }),
              let jpegData = userMessage.mealPhotoJPEG else {
            return
        }

        removeMealPhotoFailureMessages(relatedTo: userMessageID)

        let caption = userMessage.text.trimmingCharacters(in: .whitespacesAndNewlines)
        let prompt = caption.isEmpty ? CoachMealPhotoPipeline.defaultAnalysisPrompt : caption
        await analyzeMealPhoto(
            jpegData: jpegData,
            userMessageID: userMessageID,
            prompt: prompt,
            isRetry: true
        )
    }

    private func sendMealPhoto(
        jpegData: Data,
        caption: String?,
        source: CoachInputAttachmentSource?
    ) async {
        guard !isSending else { return }

        let prepared = mealPhotoAnalyzer.prepareJPEG(from: jpegData)
        guard case .success(let normalizedJPEG) = prepared else {
            if case .failure(let error) = prepared {
                appendAssistantMessage(CoachResponseBuilder.mealPhotoError(error))
            }
            return
        }

        let displayCaption = caption?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        let userMessage = appendUserMealPhotoMessage(
            caption: displayCaption.isEmpty ? nil : displayCaption,
            jpegData: normalizedJPEG,
            source: source
        )

        let prompt = displayCaption.isEmpty ?
            CoachMealPhotoPipeline.defaultAnalysisPrompt :
            displayCaption

        await analyzeMealPhoto(
            jpegData: normalizedJPEG,
            userMessageID: userMessage.id,
            prompt: prompt,
            isRetry: false
        )
    }

    private func analyzeMealPhoto(
        jpegData: Data,
        userMessageID: UUID,
        prompt: String,
        isRetry: Bool
    ) async {
        CoachMealPhotoPipeline.assertImagePayloadPresent(jpegData)

        let traceLabel = isRetry ? "Meal photo retry" : CoachMealPhotoPipeline.userMessageLabel
        let traceId = FormaPipelineTracer.beginTrace(userMessage: traceLabel)
        let traceStarted = Date()
        var traceOutcome = "photoAnalysis"

        beginProcessing(.mealPhoto(userMessageID: userMessageID, prompt: prompt))
        defer {
            endProcessing()
            FormaPipelineTracer.endTrace(
                traceId: traceId,
                outcome: traceOutcome,
                durationMs: Int(Date().timeIntervalSince(traceStarted) * 1_000)
            )
        }

        let priorChatMessages = messages.filter { $0.id != userMessageID }
        let result = await mealPhotoAnalyzer.analyze(
            jpegData: jpegData,
            prompt: prompt,
            recentMessages: priorChatMessages
        )
        traceOutcome = "photoAnalysisCompleted"

        if result.pendingConfirmation != nil {
            applyActionResult(result, relatedPhotoUserMessageID: userMessageID)
        } else if !result.message.isEmpty {
            appendMealPhotoFailureMessage(
                text: result.message,
                relatedUserMessageID: userMessageID
            )
        }
    }

    private func handlePendingConfirmationInput(_ text: String) async -> CoachActionResult? {
        guard pendingConfirmation != nil else { return nil }

        let normalized = CommandParserUtilities.normalized(text)
        if CoachPendingConfirmationPresenter.confirmWords.contains(normalized) {
            isConfirmingPending = true
            defer { isConfirmingPending = false }
        }

        guard let result = await CoachPendingConfirmationPresenter.handleTextInput(
            text,
            pendingConfirmation: pendingConfirmation,
            executor: mutationExecutor
        ) else {
            return nil
        }

        if result.pendingConfirmation == nil {
            clearPendingConfirmation()
        }
        return result
    }

    private func processCoachMessage(
        _ text: String,
        traceId: UUID,
        traceOutcome: inout String
    ) async -> CoachActionResult {
        guard aiCommandParsingEnabled,
              let aiContextBuilder,
              let aiService else {
            traceOutcome = "aiDisabled"
            FormaPipelineTracer.logError(
                traceId: traceId,
                stage: .coachSend,
                message: "AI command parsing unavailable",
                fields: [
                    "aiCommandParsingEnabled": String(aiCommandParsingEnabled),
                    "hasContextBuilder": String(self.aiContextBuilder != nil),
                    "hasAIService": String(self.aiService != nil)
                ]
            )
            return .message(CoachResponseBuilder.backendUnavailableResponse)
        }

        let priorChatMessages = Array(messages.dropLast())
        let workoutsToday = await healthActivityQuery.dailyTrainingActivity().workoutCount
        let context = aiContextBuilder.makeContext(
            recentMessages: priorChatMessages,
            workoutsToday: workoutsToday
        )

        do {
            let decision = try await routeDecider.decide(
                text: text,
                context: context,
                aiService: aiService,
                config: coachModelConfig
            )
            CoachRouteDebugLogger.log(decision)
            let result = try await routeHandler.handle(decision.route, context: context)
            traceOutcome = "routed:\(decision.chosenHandler)"
            return result
        } catch let error as AIServiceError {
            if case .authenticationFailed = error {
                traceOutcome = "authFailed"
                FormaPipelineTracer.logError(
                    traceId: traceId,
                    stage: .error,
                    message: "Coach session authentication failed",
                    fields: ["error": error.userMessage]
                )
                presentCoachSessionFailure()
                return .message("")
            }
            traceOutcome = "aiServiceError"
            var errorFields: [String: String] = [
                "error": String(describing: error),
                "userMessage": error.userMessage
            ]
            #if DEBUG
            if case .backendUnavailable = error {
                errorFields["debugHint"] = "See OSLog subsystem Forma category CoachAI and PipelineTrace for this traceId"
            }
            #endif
            FormaPipelineTracer.logError(
                traceId: traceId,
                stage: .error,
                message: "AIService error surfaced to user",
                fields: errorFields
            )
            return .message(error.userMessage)
        } catch {
            traceOutcome = "unexpectedError"
            FormaPipelineTracer.logError(
                traceId: traceId,
                stage: .error,
                message: "Unexpected coach processing error",
                fields: [
                    "error": error.localizedDescription,
                    "errorType": String(describing: type(of: error))
                ]
            )
            return .message(AIServiceError.requestFailed(error.localizedDescription).userMessage)
        }
    }

    private func presentCoachSessionFailure() {
        errorTitle = AIServiceError.coachSessionFailureTitle
        errorMessage = AIServiceError.coachSessionFailureMessage
        showsAuthRetry = true
    }

    func applyStarterPrompt(_ prompt: CoachStarterPrompt) async {
        await applyStarterPromptSpec(prompt.spec)
    }

    func applyStarterPromptSpec(_ prompt: CoachStarterPromptSpec) async {
        switch prompt.behavior {
        case .prefill(let text):
            inputText = text
        case .send(let text):
            await send(text)
        case .openPhotoPicker:
            break
        }
    }

    func applyExampleCommand(_ text: String) async {
        await send(text)
    }

    func clearError() {
        errorTitle = nil
        errorMessage = nil
        showsAuthRetry = false
    }

    func prepareInput(prefill: String?) {
        mutateInputState { $0.updateText(prefill ?? "") }
    }

    // MARK: Pending Confirmation

    func confirmPendingFromBar() async {
        guard let confirmation = pendingConfirmation else { return }
        isConfirmingPending = true
        defer { isConfirmingPending = false }

        let response = await mutationExecutor.executePendingConfirmation(confirmation)
        clearPendingConfirmation()
        if !response.isEmpty {
            appendAssistantMessage(response)
        }
    }

    func rejectPendingFromBar() {
        guard pendingConfirmation != nil else { return }
        clearPendingConfirmation()
        appendAssistantMessage(CoachResponseBuilder.pendingRejected)
    }

    func openFoodEditSheet() {
        guard pendingConfirmation?.foodDraft != nil else { return }
        foodEditErrorMessage = nil
        isShowingFoodEditSheet = true
    }

    func dismissFoodEditSheet() {
        isShowingFoodEditSheet = false
    }

    func saveFoodEdit(_ formState: FoodLogEditFormState) {
        guard case .food(var draft) = pendingConfirmation else {
            foodEditErrorMessage = "I could not prepare that estimate for editing."
            return
        }

        do {
            let updated = try formState.makeMealDraft(original: draft.primaryMealDraft)
            draft.mealDraft = updated
            pendingConfirmation = .food(draft)
            foodEditErrorMessage = nil
            isShowingFoodEditSheet = false
        } catch let error as FoodEntryFormError {
            foodEditErrorMessage = error.localizedDescription
        } catch {
            foodEditErrorMessage = CoachResponseBuilder.aiFoodSaveFailed
        }
    }

    // MARK: Processing phase

    private func beginProcessing(_ operation: CoachProcessingOperation) {
        processingPhase = .active(operation)
        syncInputSendingFlag()
    }

    private func endProcessing() {
        processingPhase = .idle
        syncInputSendingFlag()
    }

    // MARK: Action result application

    private func applyActionResult(
        _ result: CoachActionResult,
        relatedPhotoUserMessageID: UUID? = nil
    ) {
        if let confirmation = result.pendingConfirmation {
            setPendingConfirmation(confirmation)
        }
        if !result.message.isEmpty {
            if let relatedPhotoUserMessageID {
                appendAssistantPhotoAnalysisMessage(
                    result.message,
                    relatedUserMessageID: relatedPhotoUserMessageID,
                    isFailure: false
                )
            } else {
                appendAssistantMessage(result.message)
            }
        }
    }

    private func clearPendingConfirmation() {
        pendingConfirmation = nil
        foodEditErrorMessage = nil
        isShowingFoodEditSheet = false
    }

    @discardableResult
    private func setPendingConfirmation(_ confirmation: CoachPendingConfirmation) -> CoachPendingConfirmation {
        pendingConfirmation = confirmation
        foodEditErrorMessage = nil
        isShowingFoodEditSheet = false
        return confirmation
    }

    // MARK: Message Helpers

    @discardableResult
    private func appendUserMessage(text: String) -> ChatMessage {
        let message = ChatMessage(
            id: UUID(),
            role: .user,
            text: text,
            createdAt: Date(),
            relatedDailyLogId: nil,
            relatedEntryId: nil
        )
        messages.append(message)
        persistTranscript()
        return message
    }

    @discardableResult
    private func appendUserMealPhotoMessage(
        caption: String?,
        jpegData: Data,
        source: CoachInputAttachmentSource?
    ) -> ChatMessage {
        let attachment = ChatMessageImageAttachment.fromJPEG(jpegData, source: source)
            ?? ChatMessageImageAttachment(imageJPEG: jpegData, thumbnailJPEG: jpegData, source: source)
        let message = ChatMessage.userMealPhoto(caption: caption, attachment: attachment)
        messages.append(message)
        persistTranscript()
        return message
    }

    private func appendAssistantMessage(_ text: String) {
        messages.append(
            ChatMessage(
                id: UUID(),
                role: .assistant,
                text: text,
                createdAt: Date(),
                relatedDailyLogId: nil,
                relatedEntryId: nil
            )
        )
        persistTranscript()
    }

    private func appendAssistantPhotoAnalysisMessage(
        _ text: String,
        relatedUserMessageID: UUID,
        isFailure: Bool
    ) {
        let message: ChatMessage
        if isFailure {
            message = ChatMessage.assistantPhotoAnalysisFailure(
                text: text,
                relatedUserMessageID: relatedUserMessageID
            )
        } else {
            message = ChatMessage.assistantPhotoAnalysisResult(
                text: text,
                relatedUserMessageID: relatedUserMessageID
            )
        }
        messages.append(message)
        persistTranscript()
    }

    private func appendMealPhotoFailureMessage(text: String, relatedUserMessageID: UUID) {
        appendAssistantPhotoAnalysisMessage(
            text,
            relatedUserMessageID: relatedUserMessageID,
            isFailure: true
        )
    }

    private func removeMealPhotoFailureMessages(relatedTo userMessageID: UUID) {
        messages.removeAll { message in
            message.photoAnalysisLink?.relatedUserMessageID == userMessageID &&
            message.photoAnalysisLink?.isFailure == true
        }
        persistTranscript()
    }

    private func persistTranscript() {
        transcriptStore.saveMessages(messages)
    }
}
