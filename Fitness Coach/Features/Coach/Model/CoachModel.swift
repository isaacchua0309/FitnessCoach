//
//  CoachModel.swift
//  Fitness Coach
//
//  FitPilot AI — AI interface into shared fitness state (not a state owner).
//

import Combine
import Foundation
import PhotosUI

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

    var stagedAttachment: CoachPendingImageState? {
        inputState.pendingImage
    }

    var stagedMealPhotoJPEG: Data? {
        inputState.pendingImage?.uploadData
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
    private let imageAnalysisSessionStore = ImageAnalysisSessionStore()

    var awaitingPhotoClarification: Bool {
        imageAnalysisSessionStore.sessionAwaitingClarification() != nil
    }

    var photoClarificationComposerPlaceholder: String? {
        guard awaitingPhotoClarification else { return nil }
        return FormaProductCopy.Coach.composerPhotoClarificationPlaceholder
    }

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
        mutateInputState { $0.clearPendingImage() }
    }

    @discardableResult
    func beginPendingImageProcessing(source: CoachInputAttachmentSource) -> Bool {
        guard inputState.canStartImageSelection else { return false }
        mutateInputState { $0.beginProcessingNewSelection(source: source) }
        return true
    }

    @discardableResult
    func requestPhotoPick() -> Bool {
        inputState.canStartImageSelection
    }

    func handleMealPhotoSelection(
        _ result: Result<Data, CoachMealPhotoError>,
        source: CoachInputAttachmentSource
    ) async {
        switch result {
        case .failure(.userCancelled):
            return
        case .failure(let error):
            appendAssistantMessage(CoachResponseBuilder.mealPhotoError(error))
        case .success(let rawData):
            await stageMealPhoto(rawData, source: source)
        }
    }

    func handlePhotoLibrarySelection(_ item: PhotosPickerItem) async {
        guard inputState.canStartImageSelection else { return }
        beginPendingImageProcessing(source: .library)

        let importResult = await CoachImagePipeline.importFromPhotoLibrary(item)
        switch importResult {
        case .failure(.userCancelled):
            mutateInputState { state in
                state.pendingImage?.markFailedPreservingReadyPayload()
                if state.pendingImage?.byteSize == 0 {
                    state.pendingImage = nil
                }
            }
        case .failure(let error):
            mutateInputState { $0.failImageProcessing(error) }
            appendMealPhotoSelectionFailure(error)
        case .success(let imported):
            _ = await stagePipelineProcessedPhoto(imported, source: .library)
        }
    }

    func handleCameraCapture(_ image: UIImage) async {
        guard inputState.canStartImageSelection else { return }
        beginPendingImageProcessing(source: .camera)

        let importResult = await CoachImagePipeline.importFromCamera(image)
        switch importResult {
        case .failure(.userCancelled):
            mutateInputState { state in
                state.pendingImage?.markFailedPreservingReadyPayload()
                if state.pendingImage?.byteSize == 0 {
                    state.pendingImage = nil
                }
            }
        case .failure(let error):
            mutateInputState { $0.failImageProcessing(error) }
            appendMealPhotoSelectionFailure(error)
        case .success(let imported):
            _ = await stagePipelineProcessedPhoto(imported, source: .camera)
        }
    }

    @discardableResult
    func stagePipelineProcessedPhoto(
        _ imported: CoachImagePipeline.ProcessedImageImport,
        source: CoachInputAttachmentSource
    ) async -> Bool {
        let processed = imported.processed

        let staged = mutateInputState { state -> Bool in
            state.applyProcessedImage(
                processed,
                source: source,
                originalEstimatedBytes: imported.originalEstimatedBytes,
                localReferenceID: imported.localReferenceID
            )
        }

        guard staged else { return false }

        CoachMealPhotoPipeline.assertImagePayloadPresent(processed.uploadData)
        CoachImageAnalysisDebugLogger.logPipelineProcessed(
            source: source,
            processed: processed,
            originalEstimatedBytes: imported.originalEstimatedBytes
        )
        return true
    }

    func handlePipelineProcessedMealPhoto(
        _ processed: CoachProcessedImage,
        originalEstimatedBytes: Int?,
        source: CoachInputAttachmentSource
    ) async {
        _ = await stagePipelineProcessedPhoto(
            CoachImagePipeline.ProcessedImageImport(
                processed: processed,
                originalEstimatedBytes: originalEstimatedBytes
            ),
            source: source
        )
    }

    func appendMealPhotoSelectionFailure(_ error: CoachMealPhotoError) {
        guard error != .userCancelled else { return }
        CoachImageAnalysisDebugLogger.logError(error)
        appendAssistantMessage(CoachResponseBuilder.mealPhotoError(error))
    }

    func failPendingImageProcessing(_ error: CoachMealPhotoError) {
        mutateInputState { $0.failImageProcessing(error) }
    }

    func revertPendingImageProcessingCancel() {
        mutateInputState { state in
            guard var pending = state.pendingImage, pending.isProcessing else { return }
            if pending.byteSize == 0 {
                state.clearPendingImage()
            } else {
                pending.markFailedPreservingReadyPayload()
                state.pendingImage = pending
            }
        }
    }

    /// Legacy entry point — prefer `handleMealPhotoSelection`.
    func handlePhotoSelected() async {
        await handleMealPhotoSelection(.failure(.noImage), source: .library)
    }

    private func stageMealPhoto(_ rawData: Data, source: CoachInputAttachmentSource) async {
        let rawBytes = rawData.count
        let prepared = await mealPhotoAnalyzer.prepareJPEG(from: rawData)
        guard case .success(let jpegData) = prepared else {
            if case .failure(let error) = prepared {
                CoachImageAnalysisDebugLogger.logError(error)
                appendAssistantMessage(CoachResponseBuilder.mealPhotoError(error))
            }
            return
        }

        guard let thumbnail = await CoachMealPhotoPipeline.makeThumbnailJPEG(from: jpegData) else {
            appendAssistantMessage(CoachResponseBuilder.mealPhotoError(.loadFailed))
            return
        }

        CoachMealPhotoPipeline.assertImagePayloadPresent(jpegData)
        CoachImageAnalysisDebugLogger.logImageSelected(
            source: source,
            rawBytes: rawBytes,
            compressedBytes: jpegData.count
        )
        mutateInputState {
            $0.applyLegacyPreparedImage(
                uploadData: jpegData,
                thumbnail: thumbnail,
                source: source
            )
        }
    }

    @discardableResult
    private func mutateInputState<T>(_ transform: (inout CoachInputState) -> T) -> T {
        var next = inputState
        let value = transform(&next)
        next.setSending(isSending)
        inputState = next
        return value
    }

    private func restoreComposer(from snapshot: CoachInputSendSnapshot) {
        mutateInputState { $0.restore(from: snapshot) }
    }

    private func syncInputSendingFlag() {
        mutateInputState { $0.setSending(isSending) }
    }

    // MARK: Send

    func sendCurrentMessage() async {
        guard !isSending else { return }

        guard let snapshot = { () -> CoachInputSendSnapshot? in
            var next = inputState
            guard let frozen = next.takeSendSnapshot() else { return nil }
            inputState = next
            syncInputSendingFlag()
            return frozen
        }() else {
            return
        }

        beginProcessing(.text)
        defer { endProcessing() }

        switch snapshot.sendPayload {
        case .textOnly(let text):
            await send(text, managesProcessingLock: false)
        case .imageOnly(let jpegData):
            await sendMealPhoto(
                jpegData: jpegData,
                caption: nil,
                source: snapshot.pendingImage?.source,
                thumbnailJPEG: snapshot.pendingImage?.thumbnail,
                isPipelineProcessedUpload: snapshot.pendingImage?.isPipelineProcessedUpload == true,
                restoreSnapshotOnEarlyFailure: snapshot
            )
        case .textAndImage(let text, let jpegData):
            await sendMealPhoto(
                jpegData: jpegData,
                caption: text,
                source: snapshot.pendingImage?.source,
                thumbnailJPEG: snapshot.pendingImage?.thumbnail,
                isPipelineProcessedUpload: snapshot.pendingImage?.isPipelineProcessedUpload == true,
                restoreSnapshotOnEarlyFailure: snapshot
            )
        }
    }

    func send(_ text: String, managesProcessingLock: Bool = true) async {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        if managesProcessingLock {
            guard !isSending else { return }
            beginProcessing(.text)
        }

        defer {
            if managesProcessingLock {
                endProcessing()
            }
        }

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
        defer {
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

        if let clarificationSession = imageAnalysisSessionStore.sessionAwaitingClarification() {
            appendUserMessage(text: trimmed)
            await submitImageAnalysisClarification(trimmed, for: clarificationSession.userMessageID)
            traceOutcome = "photoClarification"
            return
        }

        let result = await processCoachMessage(trimmed, traceId: traceId, traceOutcome: &traceOutcome)
        applyActionResult(result)
    }

    func retryMealPhotoAnalysis(for userMessageID: UUID) async {
        guard !isSending else { return }
        guard let session = imageAnalysisSessionStore.session(forUserMessageID: userMessageID),
              let jpegData = messages.first(where: { $0.id == userMessageID })?.mealPhotoJPEG else {
            return
        }

        removePhotoAnalysisMessages(for: userMessageID, sessionID: session.sessionId)
        clearPendingConfirmationIfLinked(to: userMessageID)

        await runImageAnalysisSession(
            userMessageID: userMessageID,
            jpegData: jpegData,
            recommission: nil,
            isRetry: true
        )
    }

    func submitImageAnalysisClarification(_ clarification: String, for userMessageID: UUID) async {
        guard !isSending else { return }
        guard let session = imageAnalysisSessionStore.session(forUserMessageID: userMessageID),
              let jpegData = messages.first(where: { $0.id == userMessageID })?.mealPhotoJPEG else {
            return
        }

        let trimmed = clarification.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }

        _ = imageAnalysisSessionStore.apply(
            userMessageID: userMessageID,
            event: .clarificationAnswered(trimmed)
        )
        guard let updatedSession = imageAnalysisSessionStore.session(forUserMessageID: userMessageID) else {
            return
        }

        removePhotoAnalysisMessages(for: userMessageID, sessionID: updatedSession.sessionId)
        clearPendingConfirmationIfLinked(to: userMessageID)

        appendAssistantMessage(ImageAnalysisSessionCopy.recommissionAcknowledgement(trimmed))

        let recommission = ImageAnalysisRecommissionContext(
            clarification: trimmed,
            clarificationHistory: updatedSession.clarificationTurns,
            previousResult: updatedSession.latestResult
        )

        await runImageAnalysisSession(
            userMessageID: userMessageID,
            jpegData: jpegData,
            recommission: recommission,
            isRetry: false
        )
    }

    private func sendMealPhoto(
        jpegData: Data,
        caption: String?,
        source: CoachInputAttachmentSource?,
        thumbnailJPEG: Data? = nil,
        isPipelineProcessedUpload: Bool = false,
        restoreSnapshotOnEarlyFailure: CoachInputSendSnapshot? = nil
    ) async {
        let normalizedJPEG: Data
        if isPipelineProcessedUpload {
            normalizedJPEG = jpegData
            CoachMealPhotoPipeline.assertImagePayloadPresent(normalizedJPEG)
        } else {
            let prepared = await mealPhotoAnalyzer.prepareJPEG(from: jpegData)
            guard case .success(let preparedJPEG) = prepared else {
                if case .failure(let error) = prepared {
                    appendAssistantMessage(CoachResponseBuilder.mealPhotoError(error))
                }
                if let restoreSnapshotOnEarlyFailure {
                    restoreComposer(from: restoreSnapshotOnEarlyFailure)
                }
                return
            }
            normalizedJPEG = preparedJPEG
        }

        let displayCaption = caption?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        clearPhotoLinkedPendingConfirmation()

        let userMessage = appendUserMealPhotoMessage(
            caption: displayCaption.isEmpty ? nil : displayCaption,
            jpegData: normalizedJPEG,
            thumbnailJPEG: thumbnailJPEG,
            source: source
        )

        let attachment = userMessage.imageAttachment ?? ChatMessageImageAttachment(
            imageJPEG: normalizedJPEG,
            thumbnailJPEG: thumbnailJPEG
                ?? CoachMealPhotoPipeline.makeThumbnailJPEGSync(from: normalizedJPEG)
                ?? normalizedJPEG,
            source: source
        )
        var session = ImageAnalysisSession.newSession(
            userMessageID: userMessage.id,
            attachment: attachment,
            userCaption: displayCaption
        )
        imageAnalysisSessionStore.upsert(session)

        await runImageAnalysisSession(
            userMessageID: userMessage.id,
            jpegData: normalizedJPEG,
            recommission: nil,
            isRetry: false
        )
    }

    private func runImageAnalysisSession(
        userMessageID: UUID,
        jpegData: Data,
        recommission: ImageAnalysisRecommissionContext?,
        isRetry: Bool
    ) async {
        CoachMealPhotoPipeline.assertImagePayloadPresent(jpegData)

        guard let session = imageAnalysisSessionStore.session(forUserMessageID: userMessageID) else {
            return
        }

        let traceLabel = isRetry ? "Meal photo retry" : CoachMealPhotoPipeline.userMessageLabel
        let traceId = FormaPipelineTracer.beginTrace(userMessage: traceLabel)
        let traceStarted = Date()
        var traceOutcome = recommission == nil ? "photoAnalysis" : "photoRecommission"

        _ = imageAnalysisSessionStore.apply(userMessageID: userMessageID, event: .analysisStarted)
        let activeSession = imageAnalysisSessionStore.session(forUserMessageID: userMessageID) ?? session

        CoachImageAnalysisDebugLogger.logAnalysisStarted(
            sessionId: activeSession.sessionId,
            userMessageId: userMessageID,
            attempt: activeSession.attempts,
            isRetry: isRetry,
            isRecommission: recommission != nil,
            hasCaption: !session.userCaption.isEmpty,
            compressedBytes: jpegData.count
        )

        beginProcessing(.mealPhoto(userMessageID: userMessageID, prompt: session.userCaption))
        defer {
            endProcessing()
            FormaPipelineTracer.endTrace(
                traceId: traceId,
                outcome: traceOutcome,
                durationMs: Int(Date().timeIntervalSince(traceStarted) * 1_000)
            )
        }

        let priorChatMessages = messages.filter { $0.id != userMessageID }
        let outcome = await mealPhotoAnalyzer.analyze(
            session: activeSession,
            recommission: recommission,
            recentMessages: priorChatMessages
        )

        if let sessionResult = outcome.sessionResult, outcome.result.pendingConfirmation != nil {
            _ = imageAnalysisSessionStore.apply(
                userMessageID: userMessageID,
                event: .analysisSucceeded(sessionResult)
            )
            let updatedSession = imageAnalysisSessionStore.session(forUserMessageID: userMessageID) ?? activeSession
            applyPhotoAnalysisSuccess(
                outcome.result,
                session: updatedSession,
                supersedeExisting: recommission != nil || isRetry
            )
            if updatedSession.status == .needsClarification,
               let question = updatedSession.activeClarifyingQuestion {
                appendAssistantPhotoClarification(
                    CoachResponseBuilder.mealPhotoClarification(question),
                    session: updatedSession
                )
            }
            traceOutcome = updatedSession.status == .needsClarification ?
                "photoAnalysisNeedsClarification" :
                "photoAnalysisCompleted"
            CoachImageAnalysisDebugLogger.logSessionOutcome(
                sessionId: updatedSession.sessionId,
                attempt: updatedSession.attempts,
                sessionStatus: String(describing: updatedSession.status),
                confidence: sessionResult.confidence.rawValue,
                itemCount: sessionResult.mealDraft.components.count
            )
            return
        }

        let errorMessage = outcome.errorMessage ?? outcome.result.message
        _ = imageAnalysisSessionStore.apply(
            userMessageID: userMessageID,
            event: .analysisFailed(errorMessage)
        )
        clearPendingConfirmationIfLinked(to: userMessageID)
        if outcome.errorCategory == "authentication" {
            presentCoachSessionFailure()
        }
        if let failedSession = imageAnalysisSessionStore.session(forUserMessageID: userMessageID) {
            CoachImageAnalysisDebugLogger.logSessionOutcome(
                sessionId: failedSession.sessionId,
                attempt: failedSession.attempts,
                sessionStatus: "failed",
                errorCategory: outcome.errorCategory ?? "unknown"
            )
            appendMealPhotoFailureMessage(
                text: errorMessage,
                session: failedSession
            )
        }
        traceOutcome = "photoAnalysisFailed"
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
            if let userMessageID = draft.relatedPhotoUserMessageID {
                _ = imageAnalysisSessionStore.apply(
                    userMessageID: userMessageID,
                    event: .draftEdited(updated)
                )
                if let session = imageAnalysisSessionStore.session(forUserMessageID: userMessageID),
                   session.status == .needsClarification,
                   let question = session.activeClarifyingQuestion {
                    appendAssistantPhotoClarification(
                        CoachResponseBuilder.mealPhotoClarification(question),
                        session: session
                    )
                }
            }
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

    private func applyPhotoAnalysisSuccess(
        _ result: CoachActionResult,
        session: ImageAnalysisSession,
        supersedeExisting: Bool
    ) {
        let priorFoodDraft: AIFoodConfirmationDraft? = {
            guard supersedeExisting,
                  case .food(let draft) = pendingConfirmation,
                  draft.relatedPhotoUserMessageID == session.userMessageID else {
                return nil
            }
            return draft
        }()

        if supersedeExisting {
            removePhotoAnalysisMessages(
                for: session.userMessageID,
                sessionID: session.sessionId
            )
            if priorFoodDraft == nil {
                clearPendingConfirmationIfLinked(to: session.userMessageID)
            }
        }

        if var confirmation = result.pendingConfirmation,
           case .food(var draft) = confirmation {
            draft.imageAnalysisSessionID = session.sessionId
            draft.relatedPhotoUserMessageID = session.userMessageID
            if let priorFoodDraft {
                draft = AIFoodConfirmationDraft(
                    id: priorFoodDraft.id,
                    originalText: draft.originalText,
                    assistantMessage: draft.assistantMessage,
                    mealDraft: draft.mealDraft,
                    confidence: draft.confidence,
                    requiresConfirmation: draft.requiresConfirmation,
                    sanityWarning: draft.sanityWarning,
                    imageAnalysisSessionID: draft.imageAnalysisSessionID,
                    relatedPhotoUserMessageID: draft.relatedPhotoUserMessageID,
                    createdAt: priorFoodDraft.createdAt
                )
            }
            confirmation = .food(draft)
            setPendingConfirmation(confirmation)
        }

        if !result.message.isEmpty {
            appendAssistantPhotoAnalysisMessage(
                result.message,
                session: session
            )
        }
    }

    private func applyActionResult(
        _ result: CoachActionResult,
        relatedPhotoUserMessageID: UUID? = nil
    ) {
        if let confirmation = result.pendingConfirmation {
            setPendingConfirmation(confirmation)
        }
        if !result.message.isEmpty {
            if let relatedPhotoUserMessageID,
               let session = imageAnalysisSessionStore.session(forUserMessageID: relatedPhotoUserMessageID) {
                appendAssistantPhotoAnalysisMessage(result.message, session: session)
            } else {
                appendAssistantMessage(result.message)
            }
        }
    }

    private func clearPendingConfirmationIfLinked(to userMessageID: UUID) {
        guard case .food(let draft) = pendingConfirmation,
              draft.relatedPhotoUserMessageID == userMessageID else {
            return
        }
        clearPendingConfirmation()
    }

    private func clearPhotoLinkedPendingConfirmation() {
        guard case .food(let draft) = pendingConfirmation,
              draft.relatedPhotoUserMessageID != nil else {
            return
        }
        clearPendingConfirmation()
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
        thumbnailJPEG: Data? = nil,
        source: CoachInputAttachmentSource?
    ) -> ChatMessage {
        let attachment: ChatMessageImageAttachment
        if let thumbnailJPEG {
            attachment = ChatMessageImageAttachment(
                imageJPEG: jpegData,
                thumbnailJPEG: thumbnailJPEG,
                source: source
            )
        } else {
            attachment = ChatMessageImageAttachment.fromJPEG(jpegData, source: source)
                ?? ChatMessageImageAttachment(imageJPEG: jpegData, thumbnailJPEG: jpegData, source: source)
        }
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
        session: ImageAnalysisSession
    ) {
        messages.append(
            ChatMessage.assistantPhotoAnalysisResult(
                text: text,
                sessionID: session.sessionId,
                relatedUserMessageID: session.userMessageID
            )
        )
        persistTranscript()
    }

    private func appendAssistantPhotoClarification(
        _ text: String,
        session: ImageAnalysisSession
    ) {
        messages.append(
            ChatMessage.assistantPhotoClarification(
                text: text,
                sessionID: session.sessionId,
                relatedUserMessageID: session.userMessageID
            )
        )
        persistTranscript()
    }

    private func appendMealPhotoFailureMessage(text: String, session: ImageAnalysisSession) {
        messages.append(
            ChatMessage.assistantPhotoAnalysisFailure(
                text: text,
                sessionID: session.sessionId,
                relatedUserMessageID: session.userMessageID
            )
        )
        persistTranscript()
    }

    private func removePhotoAnalysisMessages(for userMessageID: UUID, sessionID: UUID) {
        messages.removeAll { message in
            guard let link = message.photoAnalysisLink else { return false }
            return link.relatedUserMessageID == userMessageID && link.sessionID == sessionID
        }
        persistTranscript()
    }

    private func persistTranscript() {
        transcriptStore.saveMessages(messages)
    }
}
