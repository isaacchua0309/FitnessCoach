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
    @Published var inputText: String = ""
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

    private let localCommandParser: LocalCommandParser
    private let localNutritionEstimator: LocalNutritionEstimator
    private let actionCenter: FitnessActionCenter
    private let dailyLogService: DailyLogService
    private let workoutLogService: WorkoutLogService
    private let mutationHistory = CoachMutationHistory()

    private let aiService: AIServiceProtocol?
    private let aiContextBuilder: CoachContextBuilder?
    private var routeDecider: CoachRouteDecider
    private let coachModelConfig: CoachModelConfig
    private let userProfileService: UserProfileService?
    private let aiCommandParsingEnabled: Bool

    init(
        localCommandParser: LocalCommandParser = .standard,
        localNutritionEstimator: LocalNutritionEstimator = .standard,
        actionCenter: FitnessActionCenter,
        dailyLogService: DailyLogService,
        workoutLogService: WorkoutLogService,
        aiService: AIServiceProtocol? = nil,
        userProfileService: UserProfileService? = nil,
        aiCommandParsingEnabled: Bool = false,
        coachModelConfig: CoachModelConfig = .default,
        routeDecider: CoachRouteDecider = CoachRouteDecider()
    ) {
        self.localCommandParser = localCommandParser
        self.localNutritionEstimator = localNutritionEstimator
        self.actionCenter = actionCenter
        self.dailyLogService = dailyLogService
        self.workoutLogService = workoutLogService
        self.aiService = aiService
        self.userProfileService = userProfileService
        self.aiCommandParsingEnabled = aiCommandParsingEnabled
        self.coachModelConfig = coachModelConfig
        self.routeDecider = routeDecider
        if let userProfileService {
            self.aiContextBuilder = CoachContextBuilder(
                dailyLogService: dailyLogService,
                userProfileService: userProfileService,
                actionCenter: actionCenter,
                workoutLogService: workoutLogService
            )
        } else {
            self.aiContextBuilder = nil
        }
    }

    // MARK: Intent

    func sendCurrentMessage() async {
        let text = inputText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !text.isEmpty else { return }
        inputText = ""
        await send(text)
    }

    func send(_ text: String) async {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        guard !isSending else { return }

        appendUserMessage(trimmed)

        let traceId = FitPilotPipelineTracer.beginTrace(userMessage: trimmed)
        let traceStarted = Date()
        var traceOutcome = "completed"

        isSending = true
        defer {
            isSending = false
            FitPilotPipelineTracer.endTrace(
                traceId: traceId,
                outcome: traceOutcome,
                durationMs: Int(Date().timeIntervalSince(traceStarted) * 1_000)
            )
        }

        let response: String
        if let pendingResponse = await handlePendingConfirmationInput(trimmed) {
            traceOutcome = "pendingConfirmation"
            response = pendingResponse
        } else {
            response = await processCoachMessage(trimmed, traceId: traceId, traceOutcome: &traceOutcome)
        }
        if !response.isEmpty {
            appendAssistantMessage(response)
        }
    }

    private func processCoachMessage(
        _ text: String,
        traceId: UUID,
        traceOutcome: inout String
    ) async -> String {
        guard aiCommandParsingEnabled,
              let aiContextBuilder,
              let aiService else {
            traceOutcome = "aiDisabled"
            FitPilotPipelineTracer.logError(
                traceId: traceId,
                stage: .coachSend,
                message: "AI command parsing unavailable",
                fields: [
                    "aiCommandParsingEnabled": String(aiCommandParsingEnabled),
                    "hasContextBuilder": String(self.aiContextBuilder != nil),
                    "hasAIService": String(self.aiService != nil)
                ]
            )
            return CoachResponseBuilder.backendUnavailableResponse
        }

        let priorChatMessages = Array(messages.dropLast())
        let context = aiContextBuilder.makeContext(recentMessages: priorChatMessages)

        do {
            let decision = try await routeDecider.decide(
                text: text,
                context: context,
                aiService: aiService,
                config: coachModelConfig
            )
            CoachRouteDebugLogger.log(decision)
            let response = try await handle(decision.route, context: context)
            traceOutcome = "routed:\(decision.chosenHandler)"
            return response
        } catch let error as AIServiceError {
            if case .authenticationFailed = error {
                traceOutcome = "authFailed"
                FitPilotPipelineTracer.logError(
                    traceId: traceId,
                    stage: .error,
                    message: "Coach session authentication failed",
                    fields: ["error": error.userMessage]
                )
                presentCoachSessionFailure()
                return ""
            }
            traceOutcome = "aiServiceError"
            FitPilotPipelineTracer.logError(
                traceId: traceId,
                stage: .error,
                message: "AIService error surfaced to user",
                fields: [
                    "error": String(describing: error),
                    "userMessage": error.userMessage
                ]
            )
            return error.userMessage
        } catch {
            traceOutcome = "unexpectedError"
            FitPilotPipelineTracer.logError(
                traceId: traceId,
                stage: .error,
                message: "Unexpected coach processing error",
                fields: [
                    "error": error.localizedDescription,
                    "errorType": String(describing: type(of: error))
                ]
            )
            return AIServiceError.requestFailed(error.localizedDescription).userMessage
        }
    }

    private func presentCoachSessionFailure() {
        errorTitle = AIServiceError.coachSessionFailureTitle
        errorMessage = AIServiceError.coachSessionFailureMessage
        showsAuthRetry = true
    }

    func applyStarterPrompt(_ prompt: CoachStarterPrompt) async {
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

    func handlePhotoSelected() async {
        await send("Should I eat this?")
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

        let response = await executePendingConfirmation(confirmation)
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

    private func presentFoodPending(
        originalText: String,
        assistantMessage: String?,
        foodDraft: FoodDraft,
        confidence: AIConfidence
    ) -> String {
        let draft = AIFoodConfirmationDraft(
            originalText: originalText,
            assistantMessage: assistantMessage,
            foodDrafts: [foodDraft],
            confidence: confidence,
            requiresConfirmation: true
        )
        setPendingConfirmation(.food(draft))
        return CoachResponseBuilder.aiFoodEstimatePending(
            draft: foodDraft,
            confidence: confidence,
            originalText: originalText
        )
    }

    private func presentWorkoutPending(
        _ draft: WorkoutDraft,
        assistantMessage: String?
    ) -> String {
        setPendingConfirmation(.workout(draft, assistantMessage: assistantMessage))
        return CoachResponseBuilder.workoutPending(draft, assistantMessage: assistantMessage)
    }

    private func presentWaterPending(
        _ draft: WaterDraft,
        assistantMessage: String?
    ) -> String {
        setPendingConfirmation(.water(draft, assistantMessage: assistantMessage))
        return CoachResponseBuilder.waterPending(draft, assistantMessage: assistantMessage)
    }

    private func presentWeightPending(
        _ draft: WeightDraft,
        assistantMessage: String?
    ) -> String {
        setPendingConfirmation(.weight(draft, assistantMessage: assistantMessage))
        return CoachResponseBuilder.weightPending(draft, assistantMessage: assistantMessage)
    }

    private func executePendingConfirmation(_ confirmation: CoachPendingConfirmation) async -> String {
        switch confirmation {
        case .food(let draft):
            guard let foodDraft = draft.primaryFoodDraft else {
                return CoachResponseBuilder.aiNotUnderstood
            }
            return executeLogFood(foodDraft)
        case .workout(let draft, _):
            return executeLogWorkout(draft)
        case .water(let draft, _):
            return executeLogWater(draft)
        case .weight(let draft, _):
            return executeLogWeight(draft)
        case .edit(let action, _, _):
            return executeEditAction(action)
        case .delete(let action, _, _):
            return executeDeleteAction(action)
        case .undo(let action, _, _):
            return executeUndoAction(action)
        }
    }

    private func handlePendingConfirmationInput(_ text: String) async -> String? {
        guard pendingConfirmation != nil else { return nil }

        let normalized = CommandParserUtilities.normalized(text)
        let confirmWords = ["confirm", "yes", "yep", "log it", "save it", "do it"]
        let rejectWords = ["cancel", "no", "nope", "discard", "reject"]

        if rejectWords.contains(normalized) {
            clearPendingConfirmation()
            return CoachResponseBuilder.pendingRejected
        }

        guard confirmWords.contains(normalized), let confirmation = pendingConfirmation else {
            return nil
        }

        isConfirmingPending = true
        defer { isConfirmingPending = false }

        let response = await executePendingConfirmation(confirmation)
        clearPendingConfirmation()
        return response
    }

    // MARK: Result Handling

    private func handle(_ route: CoachRoute, context: AIContext) async throws -> String {
        switch route {
        case .noOp(let response):
            switch response {
            case .casual(let message), .meaningless(let message):
                return message
            }

        case .localCommand(let command):
            switch ConfirmationPolicy.decision(for: command) {
            case .executeImmediately:
                return await execute(command)
            case .requiresConfirmation(let message):
                return message
            case .reject(let message):
                return message
            }

        case .localFoodEstimate(let request):
            return await handleLocalFoodEstimate(request)

        case .classifiedFood(_, let originalText, let intentResult):
            return try await handleAITask(
                RoutedAITask(
                    task: .estimateFood(originalText),
                    tier: .cheap,
                    intentResult: intentResult
                ),
                context: context
            )

        case .ai(let task):
            return try await handleAITask(task, context: context)

        case .clarification(let message), .invalid(let message):
            return message
        }
    }

    private func handleLocalFoodEstimate(_ request: LocalFoodEstimateRequest) async -> String {
        switch ConfirmationPolicy.decision(for: request) {
        case .executeImmediately:
            return executeLogFood(request.estimate.draft)
        case .requiresConfirmation:
            let confidence: AIConfidence = request.estimate.confidence == .high ? .high : .medium
            let draft = AIFoodConfirmationDraft(
                originalText: request.originalText,
                assistantMessage: request.estimate.explanation,
                foodDrafts: [request.estimate.draft],
                confidence: confidence,
                requiresConfirmation: true
            )
            setPendingConfirmation(.food(draft))
            return CoachResponseBuilder.localFoodEstimatePending(
                request.estimate,
                originalText: request.originalText
            )
        case .reject(let message):
            return message
        }
    }

    // MARK: AI Tasks

    private func handleAITask(_ routed: RoutedAITask, context: AIContext) async throws -> String {
        guard aiCommandParsingEnabled, let aiService else {
            return CoachResponseBuilder.backendUnavailableResponse
        }

        switch routed.task {
        case .estimateFood(let prompt), .photoFoodAnalysis(_, let prompt):
            let classifierDraft: FoodDraft? = {
                if case .logFood(let draft) = routed.intentResult.action { return draft }
                return nil
            }()

            let response = try await aiService.estimateFood(prompt: prompt, context: context)
            guard var draft = response.foodDrafts.first else {
                return CoachResponseBuilder.aiNotUnderstood
            }
            if let classifierDraft, !classifierDraft.hasCompleteNutritionEstimate {
                draft = FoodDraftNutritionCompleter.mergeExplicit(
                    classifierDraft,
                    into: draft,
                    hintText: prompt
                )
            }
            return presentAIFoodEstimate(
                draft: draft,
                originalText: prompt,
                assistantMessage: response.assistantMessage,
                confidence: response.confidence
            )

        case .mealAdvice(let prompt):
            let advice = try await aiService.generateMealAdvice(
                prompt: prompt,
                context: context,
                intentResult: routed.intentResult,
                tier: routed.tier
            )
            return CoachResponseBuilder.mealAdvice(
                log: try? dailyLogService.getTodayLog(),
                profile: try? userProfileService?.getCurrentProfile(),
                hasWorkoutToday: hasWorkoutToday(),
                assistantMessage: advice.message
            )

        case .parseWorkout(let prompt):
            let response = try await aiService.parseWorkout(prompt: prompt, context: context)
            switch ConfirmationPolicy.decision(forWorkout: response.workoutDraft) {
            case .executeImmediately, .requiresConfirmation:
                return presentWorkoutPending(
                    response.workoutDraft,
                    assistantMessage: response.assistantMessage
                )
            case .reject(let message):
                return message
            }

        case .editEntry(let prompt), .deleteEntry(let prompt):
            let parsed = try await aiService.parseEditOrDelete(prompt: prompt, context: context)
            return try await handleParsedAICommand(parsed, context: context)

        case .multiAction(let prompt):
            let parsed = try await aiService.parseMultiAction(prompt: prompt, context: context)
            return try await handleParsedAICommand(parsed, context: context)

        case .parseCommand(let prompt):
            let parsed = try await aiService.parseCommand(prompt, context: context)
            return try await handleParsedAICommand(parsed, context: context)
        }
    }

    private func handleParsedAICommand(
        _ parsed: AIParsedCommand,
        context: AIContext
    ) async throws -> String {
        switch ConfirmationPolicy.decision(for: parsed) {
        case .reject(let message):
            return message
        case .requiresConfirmation(let message):
            if let action = parsed.actions.first {
                return try await presentAIActionConfirmation(action, parsed: parsed, fallback: message)
            }
            return parsed.assistantMessage ?? message
        case .executeImmediately:
            if parsed.actions.isEmpty {
                return parsed.assistantMessage ?? CoachResponseBuilder.aiNotUnderstood
            }
            return try await executeAIActions(parsed.actions)
        }
    }

    private func presentAIActionConfirmation(
        _ action: AICommandAction,
        parsed: AIParsedCommand,
        fallback: String
    ) async throws -> String {
        switch action.type {
        case .logFood:
            guard let draft = action.foodDraft else { return fallback }
            return presentAIFoodEstimate(
                draft: draft,
                originalText: parsed.originalText,
                assistantMessage: parsed.assistantMessage,
                confidence: parsed.confidence
            )
        case .logWorkout:
            guard let draft = action.workoutDraft else { return fallback }
            return presentWorkoutPending(draft, assistantMessage: parsed.assistantMessage)
        case .logWater:
            guard let draft = action.waterDraft else { return fallback }
            return presentWaterPending(draft, assistantMessage: parsed.assistantMessage)
        case .logWeight:
            guard let draft = action.weightDraft else { return fallback }
            return presentWeightPending(draft, assistantMessage: parsed.assistantMessage)
        case .editEntry:
            setPendingConfirmation(
                .edit(action, originalText: parsed.originalText, assistantMessage: parsed.assistantMessage)
            )
            return CoachResponseBuilder.mutationPending(assistantMessage: parsed.assistantMessage ?? fallback)
        case .deleteEntry:
            setPendingConfirmation(
                .delete(action, originalText: parsed.originalText, assistantMessage: parsed.assistantMessage)
            )
            return CoachResponseBuilder.mutationPending(assistantMessage: parsed.assistantMessage ?? fallback)
        case .undo:
            setPendingConfirmation(
                .undo(action, originalText: parsed.originalText, assistantMessage: parsed.assistantMessage)
            )
            return CoachResponseBuilder.mutationPending(assistantMessage: parsed.assistantMessage ?? fallback)
        case .mealAdvice, .status, .dailyReview, .startNewDay:
            return parsed.assistantMessage ?? fallback
        }
    }

    private func executeAIActions(_ actions: [AICommandAction]) async throws -> String {
        var responses: [String] = []
        for action in actions {
            switch action.type {
            case .logFood:
                if let draft = action.foodDraft {
                    responses.append(executeLogFood(draft))
                }
            case .logWater:
                if let draft = action.waterDraft {
                    responses.append(executeLogWater(draft))
                }
            case .logWeight:
                if let draft = action.weightDraft {
                    responses.append(executeLogWeight(draft))
                }
            case .logWorkout:
                if let draft = action.workoutDraft {
                    switch ConfirmationPolicy.decision(forWorkout: draft) {
                    case .executeImmediately, .requiresConfirmation:
                        return presentWorkoutPending(draft, assistantMessage: nil)
                    case .reject(let message):
                        responses.append(message)
                    }
                }
            case .editEntry, .deleteEntry, .undo, .mealAdvice, .status, .dailyReview, .startNewDay:
                break
            }
        }
        return responses.isEmpty ? CoachResponseBuilder.aiNotUnderstood : responses.joined(separator: "\n\n")
    }

    private func presentAIFoodEstimate(
        draft: FoodDraft,
        originalText: String,
        assistantMessage: String?,
        confidence: AIConfidence
    ) -> String {
        let sanitized = FoodDraftNutritionCompleter.sanitizePartial(draft, hintText: originalText)
        switch ConfirmationPolicy.decision(for: sanitized) {
        case .requiresConfirmation, .executeImmediately:
            return presentFoodPending(
                originalText: originalText,
                assistantMessage: assistantMessage,
                foodDraft: sanitized,
                confidence: confidence
            )
        case .reject(let message):
            return message
        }
    }

    private func executeEditAction(_ action: AICommandAction) -> String {
        if let foodDraft = action.foodDraft {
            return applyFoodEdit(from: foodDraft, selector: action.targetEntrySelector)
        }
        return "I couldn't find which entry to edit. Try being more specific."
    }

    private func executeDeleteAction(_ action: AICommandAction) -> String {
        if let mealType = action.foodDraft?.mealType {
            return deleteFood(mealType: mealType)
        }

        let selector = (action.targetEntrySelector ?? "").lowercased()
        for mealType in MealType.allCases where selector.contains(mealType.rawValue.lowercased()) {
            return deleteFood(mealType: mealType)
        }

        return "I couldn't find which entry to delete. Try naming the meal type."
    }

    private func executeUndoAction(_ action: AICommandAction) -> String {
        let selector = (action.targetEntrySelector ?? "").lowercased()
        if selector.contains("food") {
            return executeUndo(.food)
        }
        if selector.contains("water") {
            return executeUndo(.water)
        }
        if selector.contains("workout") {
            return executeUndo(.workout)
        }
        return executeUndo(.last)
    }

    private func applyFoodEdit(from draft: FoodDraft, selector: String?) -> String {
        do {
            let entries = try actionCenter.getFoodEntries(for: Date())
            guard let entry = entries.last else {
                return "There is no food entry to edit today."
            }

            let update = FoodEntryUpdate(
                mealType: draft.mealType,
                name: draft.name.isEmpty ? nil : draft.name,
                quantity: draft.quantity,
                unit: draft.unit,
                calories: draft.calories,
                protein: draft.protein,
                carbs: draft.carbs,
                fat: draft.fat,
                fiber: draft.fiber,
                sodium: draft.sodium,
                source: .corrected,
                confidence: draft.confidence,
                imageUrl: draft.imageUrl,
                notes: draft.notes ?? selector
            )
            let updated = try actionCenter.editFoodEntry(id: entry.id, update: update)
            mutationHistory.record(entryId: updated.id, type: .food, summary: "edit \(updated.name)")
            return CoachResponseBuilder.editFood(updated)
        } catch ServiceError.invalidInput(let message) {
            return message
        } catch {
            return "I could not edit that food entry. Please try again."
        }
    }

    private func hasWorkoutToday() -> Bool {
        (try? !workoutLogService.getWorkouts(for: Date()).isEmpty) ?? false
    }

    private func execute(_ command: ParsedCommand) async -> String {
        switch command.intent {
        case .logWater(let draft):
            return executeLogWater(draft)
        case .logWeight(let draft):
            return executeLogWeight(draft)
        case .logFood(let draft):
            return executeLogFood(draft)
        case .undo(let target):
            return executeUndo(target)
        case .status:
            return executeStatus()
        case .dailyReview:
            return await executeDailyReview()
        case .logSteps:
            return CoachResponseBuilder.stepsPlaceholder
        case .unsupported:
            return CoachResponseBuilder.unsupportedResponse
        case .needsAI:
            return CoachResponseBuilder.needsAIResponse
        }
    }

    // MARK: Command Execution

    private func executeLogWater(_ draft: WaterDraft) -> String {
        do {
            let entry = try actionCenter.logWater(draft, date: Date())
            let log = try? dailyLogService.getLog(for: Date())
            mutationHistory.record(
                entryId: entry.id,
                type: .water,
                summary: "\(entry.amountMl)ml water"
            )
            return CoachResponseBuilder.water(loggedMl: entry.amountMl, log: log)
        } catch ServiceError.invalidInput(let message) {
            return message
        } catch {
            return "I could not save that water entry. Please try again."
        }
    }

    private func executeLogWeight(_ draft: WeightDraft) -> String {
        do {
            let entry = try actionCenter.logDailyWeight(draft, date: Date())
            mutationHistory.record(
                entryId: entry.id,
                type: .weight,
                summary: "\(entry.weightKg)kg weight"
            )
            return CoachResponseBuilder.weight(entry.weightKg)
        } catch ServiceError.invalidInput(let message) {
            return message
        } catch {
            return "I could not log that weight. Please try again."
        }
    }

    private func executeLogFood(_ draft: FoodDraft) -> String {
        do {
            let entry = try actionCenter.logFood(draft, date: Date())
            let log = try? dailyLogService.getLog(for: Date())
            mutationHistory.record(entryId: entry.id, type: .food, summary: entry.name)
            return CoachResponseBuilder.food(entry, log: log)
        } catch ServiceError.invalidInput(let message) {
            return message
        } catch ServiceError.missingUserProfile {
            return "I could not log that food entry. Please check that your profile is set up."
        } catch {
            return "I could not log that food entry. Please check the calories and macro values."
        }
    }

    private func executeLogWorkout(_ draft: WorkoutDraft) -> String {
        do {
            let entry = try actionCenter.logWorkout(draft, date: Date())
            mutationHistory.record(
                entryId: entry.id,
                type: .workout,
                summary: entry.name ?? "Workout"
            )
            return CoachResponseBuilder.workout(entry)
        } catch ServiceError.invalidInput(let message) {
            return message
        } catch ServiceError.missingUserProfile {
            return "I could not log that workout. Please check that your profile is set up."
        } catch {
            return "I could not log that workout. Please try again."
        }
    }

    private func executeUndo(_ target: UndoTarget) -> String {
        switch target {
        case .food:
            do {
                let entry = try actionCenter.undoLastFoodEntry(date: Date())
                return CoachResponseBuilder.undoFood(entry)
            } catch {
                return "I could not undo your last food entry. Please try again."
            }
        case .water:
            do {
                let entry = try actionCenter.undoLastWaterEntry(date: Date())
                return CoachResponseBuilder.undoWater(entry)
            } catch {
                return "I could not undo your last water entry. Please try again."
            }
        case .last:
            return executeUndoLastMutation()
        case .workout:
            return executeUndoLastWorkout()
        case .weight:
            return "Weight undo is not available yet. Log the corrected weight instead."
        }
    }

    private func executeUndoLastMutation() -> String {
        guard let record = mutationHistory.latest() else {
            return CoachResponseBuilder.undoLastPlaceholder
        }

        do {
            switch record.entryType {
            case .food:
                try actionCenter.deleteFoodEntry(id: record.entryId)
            case .water:
                try actionCenter.deleteWaterEntry(id: record.entryId)
            case .workout:
                try actionCenter.deleteWorkout(id: record.entryId)
            case .weight:
                return "Weight undo is not available yet. Log the corrected weight instead."
            }
            mutationHistory.remove(id: record.id)
            return "Undid \(record.summary)."
        } catch {
            return "I could not undo that last action. Please try again."
        }
    }

    private func executeUndoLastWorkout() -> String {
        guard let record = mutationHistory.latest(type: .workout) else {
            return "There is no recent Coach workout to undo."
        }

        do {
            try actionCenter.deleteWorkout(id: record.entryId)
            mutationHistory.remove(id: record.id)
            return "Undid \(record.summary)."
        } catch {
            return "I could not undo your last workout. Please try again."
        }
    }

    private func deleteFood(mealType: MealType) -> String {
        do {
            let entries = try actionCenter.getFoodEntries(for: Date())
                .filter { $0.mealType == mealType }

            guard !entries.isEmpty else {
                return "I did not find a \(mealType.rawValue) entry for today."
            }

            guard entries.count == 1, let entry = entries.first else {
                return "I found \(entries.count) \(mealType.rawValue) entries. Which one should I delete?"
            }

            try actionCenter.deleteFoodEntry(id: entry.id)
            return CoachResponseBuilder.deleteFood(entry)
        } catch {
            return "I could not delete that food entry. Please try again."
        }
    }

    private func editLastFoodQuantity(_ quantity: Double, unit: String?) -> String {
        do {
            guard let entry = try actionCenter.getFoodEntries(for: Date()).last else {
                return "There is no food entry to edit today."
            }

            let estimateInput = InputNormalizer.normalize("log \(formatQuantity(quantity))\(unit ?? "g") \(entry.name)")
            let localEstimate = localNutritionEstimator.estimate(estimateInput)
            let update = FoodEntryUpdate(
                mealType: nil,
                name: nil,
                quantity: quantity,
                unit: unit,
                calories: localEstimate?.draft.calories,
                protein: localEstimate?.draft.protein,
                carbs: localEstimate?.draft.carbs,
                fat: localEstimate?.draft.fat,
                fiber: nil,
                sodium: nil,
                source: .corrected,
                confidence: localEstimate?.draft.confidence,
                imageUrl: nil,
                notes: localEstimate?.draft.notes
            )
            let updated = try actionCenter.editFoodEntry(id: entry.id, update: update)
            mutationHistory.record(entryId: updated.id, type: .food, summary: "edit \(updated.name)")
            return CoachResponseBuilder.editFood(updated)
        } catch ServiceError.invalidInput(let message) {
            return message
        } catch {
            return "I could not edit that food entry. Please try again."
        }
    }

    private func executeStatus() -> String {
        do {
            let log = try dailyLogService.getTodayLog()
            return CoachResponseBuilder.status(log)
        } catch ServiceError.missingUserProfile {
            return "I could not load your status. Please check that your profile is set up."
        } catch {
            return "I could not load your status. Please try again."
        }
    }

    private func executeDailyReview() async -> String {
        do {
            let review = try await actionCenter.generateDailyReview(for: Date())
            return CoachResponseBuilder.dailyReview(review)
        } catch ServiceError.missingUserProfile {
            return "I could not generate your daily review yet. Please start a day and make sure your profile is set up."
        } catch ServiceError.dailyLogNotFound {
            return "There is no daily log for today yet. Open Today to load your dashboard."
        } catch {
            return "I could not generate your daily review yet. Please try again."
        }
    }

    // MARK: Message Helpers

    private func appendUserMessage(_ text: String) {
        messages.append(
            ChatMessage(
                id: UUID(),
                role: .user,
                text: text,
                createdAt: Date(),
                relatedDailyLogId: nil,
                relatedEntryId: nil
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

    private func formatQuantity(_ value: Double) -> String {
        value.truncatingRemainder(dividingBy: 1) == 0
            ? String(format: "%.0f", value)
            : String(format: "%.1f", value)
    }

    private func aiConfidence(from level: ConfidenceLevel) -> AIConfidence {
        switch level {
        case .high: return .high
        case .medium: return .medium
        case .low: return .low
        }
    }
}
