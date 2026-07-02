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
    @Published var inputText: String = ""
    @Published private(set) var inputAttachmentState = CoachInputAttachmentState.none
    @Published private(set) var isSending: Bool = false
    @Published private(set) var errorTitle: String?
    @Published private(set) var errorMessage: String?
    @Published private(set) var showsAuthRetry: Bool = false

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

    init(
        localCommandParser: LocalCommandParser? = nil,
        localNutritionEstimator: LocalNutritionEstimator? = nil,
        actionCenter: FitnessActionCenter,
        dailyLogReader: any DailyLogReading,
        healthActivityQuery: HealthActivityQueryService,
        weightLogReader: (any WeightLogReading)? = nil,
        aiService: AIServiceProtocol? = nil,
        userProfileReader: (any UserProfileReading)? = nil,
        aiCommandParsingEnabled: Bool = false,
        coachModelConfig: CoachModelConfig? = nil,
        routeDecider: CoachRouteDecider? = nil,
        trainingInsightsStore: TrainingInsightsStore? = nil
    ) {
        self.localCommandParser = localCommandParser ?? .standard
        let nutritionEstimator = localNutritionEstimator ?? .standard
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
            localNutritionEstimator: nutritionEstimator,
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
            let training = try await healthActivityQuery.dailyTrainingActivity(on: dailyLog.date)
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

    // MARK: Intent

    func sendCurrentMessage() async {
        let text = inputText.trimmingCharacters(in: .whitespacesAndNewlines)
        let imageJPEGData = inputAttachmentState.attachment?.jpegData
        guard !text.isEmpty || imageJPEGData != nil else { return }
        guard !isSending else { return }
        guard !inputAttachmentState.isImporting else { return }

        let displayText = outgoingMessageText(text: text, hasImage: imageJPEGData != nil)
        appendUserMessage(displayText, imageJPEGData: imageJPEGData)
        clearComposerInput()

        if let imageJPEGData {
            await analyzeMealPhoto(imageJPEGData, userMessageAlreadyAppended: true)
        } else {
            await send(displayText, userMessageAlreadyAppended: true)
        }
    }

    func send(_ text: String, userMessageAlreadyAppended: Bool = false) async {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        guard !isSending else { return }

        if !userMessageAlreadyAppended {
            appendUserMessage(trimmed)
            clearComposerInput()
        }

        let traceId = FormaPipelineTracer.beginTrace(userMessage: trimmed)
        let traceStarted = Date()
        var traceOutcome = "completed"

        isSending = true
        defer {
            isSending = false
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
        let workoutsToday = (try? await healthActivityQuery.dailyTrainingActivity().workoutCount) ?? 0
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

    func importAttachment(from item: PhotosPickerItem) async {
        beginAttachmentImport()
        let sourceLabel = CoachMealPhotoPipeline.librarySourceLabel(for: item)
        let result = await CoachMealPhotoPipeline.loadJPEG(from: item)
        await applyPreparedAttachmentImport(result, sourceLabel: sourceLabel)
    }

    func importAttachment(from result: Result<Data, CoachMealPhotoError>, sourceLabel: String? = nil) async {
        switch result {
        case .failure(.userCancelled):
            inputAttachmentState.cancelImport()
            return
        case .failure(.cameraUnavailable):
            inputAttachmentState.failImport(.cameraUnavailable)
            return
        default:
            break
        }
        beginAttachmentImport()
        await applyPreparedAttachmentImport(result, sourceLabel: sourceLabel)
    }

    func beginAttachmentImport() {
        guard !isSending else { return }
        inputAttachmentState.beginImport()
    }

    func removeInputAttachment() {
        inputAttachmentState.clear()
    }

    func dismissAttachmentImportError() {
        inputAttachmentState.dismissImportError()
    }

    private func applyPreparedAttachmentImport(
        _ result: Result<Data, CoachMealPhotoError>,
        sourceLabel: String?
    ) async {
        switch result {
        case .failure(.userCancelled):
            inputAttachmentState.cancelImport()
        case .failure(let error):
            inputAttachmentState.failImport(error)
        case .success(let jpegData):
            inputAttachmentState.applyImported(jpegData: jpegData, sourceLabel: sourceLabel)
        }
    }

    private func prepareAttachmentJPEG(from rawData: Data) async -> Result<Data, CoachMealPhotoError> {
        await Task.detached(priority: .userInitiated) {
            CoachMealPhotoPipeline.prepareJPEG(from: rawData)
        }.value
    }

    private func clearInputAttachment() {
        inputAttachmentState.clear()
    }

    /// Legacy entry point — prefer `importAttachment(from:)`.
    func handleMealPhotoSelection(_ result: Result<Data, CoachMealPhotoError>) async {
        await importAttachment(from: result)
    }

    /// Legacy entry point — prefer `importAttachment(from:)`.
    func handlePhotoSelected() async {
        await importAttachment(from: .failure(.noImage))
    }

    private func analyzeMealPhoto(_ rawData: Data, userMessageAlreadyAppended: Bool = false) async {
        let prepared = await prepareAttachmentJPEG(from: rawData)
        guard case .success(let jpegData) = prepared else {
            if case .failure(let error) = prepared {
                appendAssistantMessage(CoachResponseBuilder.mealPhotoError(error))
            }
            return
        }

        CoachMealPhotoPipeline.assertImagePayloadPresent(jpegData)
        guard !isSending else { return }

        if !userMessageAlreadyAppended {
            appendUserMessage(CoachMealPhotoPipeline.userMessageLabel)
        }

        let traceId = FormaPipelineTracer.beginTrace(userMessage: CoachMealPhotoPipeline.userMessageLabel)
        let traceStarted = Date()
        var traceOutcome = "photoAnalysis"

        isSending = true
        defer {
            isSending = false
            FormaPipelineTracer.endTrace(
                traceId: traceId,
                outcome: traceOutcome,
                durationMs: Int(Date().timeIntervalSince(traceStarted) * 1_000)
            )
        }

        let priorChatMessages = Array(messages.dropLast())
        let result = await mealPhotoAnalyzer.analyze(jpegData: jpegData, recentMessages: priorChatMessages)
        traceOutcome = "photoAnalysisCompleted"
        applyActionResult(result)
    }

    func clearError() {
        errorTitle = nil
        errorMessage = nil
        showsAuthRetry = false
    }

    func prepareInput(prefill: String?) {
        inputText = prefill ?? ""
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

    func saveFoodEdit(_ formState: FoodEntryFormState) {
        guard case .food(var draft) = pendingConfirmation,
              let originalDraft = draft.primaryFoodDraft else {
            foodEditErrorMessage = "I could not prepare that estimate for editing."
            return
        }

        do {
            let updated = try formState.makeAIFoodDraft(original: originalDraft)
            draft.foodDrafts = [updated]
            pendingConfirmation = .food(draft)
            foodEditErrorMessage = nil
            isShowingFoodEditSheet = false
        } catch let error as FoodEntryFormError {
            foodEditErrorMessage = error.localizedDescription
        } catch {
            foodEditErrorMessage = CoachResponseBuilder.aiFoodSaveFailed
        }
    }

    // MARK: Action result application

    private func applyActionResult(_ result: CoachActionResult) {
        if let confirmation = result.pendingConfirmation {
            setPendingConfirmation(confirmation)
        }
        if !result.message.isEmpty {
            appendAssistantMessage(result.message)
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

    private func clearComposerInput() {
        inputText = ""
        clearInputAttachment()
    }

    private func outgoingMessageText(text: String, hasImage: Bool) -> String {
        if !text.isEmpty {
            return text
        }
        if hasImage {
            return CoachMealPhotoPipeline.userMessageLabel
        }
        return text
    }

    private func appendUserMessage(_ text: String, imageJPEGData: Data? = nil) {
        messages.append(
            ChatMessage(
                id: UUID(),
                role: .user,
                text: text,
                createdAt: Date(),
                relatedDailyLogId: nil,
                relatedEntryId: nil,
                attachedImageJPEGData: imageJPEGData
            )
        )
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
    }
}
