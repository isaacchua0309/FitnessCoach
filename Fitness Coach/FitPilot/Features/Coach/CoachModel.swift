//
//  CoachModel.swift
//  Fitness Coach
//
//  FitPilot AI — AI interface into shared fitness state (not a state owner).
//

import Combine
import Foundation

private enum CoachPendingAction {
    case food(FoodDraft, originalText: String, assistantMessage: String?)
    case workout(WorkoutDraft)
}

@MainActor
final class CoachModel: ObservableObject {

    @Published private(set) var messages: [ChatMessage] = []
    @Published var inputText: String = ""
    @Published private(set) var isSending: Bool = false
    @Published private(set) var errorMessage: String?
    @Published private(set) var toolbarActions: [CoachToolbarAction] = CoachToolbarBuilder.defaultActions()
    @Published private(set) var foodConfirmationState: AIFoodConfirmationState = .none
    @Published var isShowingFoodConfirmationSheet = false
    @Published private(set) var foodConfirmationErrorMessage: String?

    private let localCommandParser: LocalCommandParser
    private let localNutritionEstimator: LocalNutritionEstimator
    private let actionCenter: FitnessActionCenter
    private let dailyLogService: DailyLogService
    private let workoutLogService: WorkoutLogService
    private let toolbarUsageStore: CoachToolbarUsageStore
    private let mutationHistory = CoachMutationHistory()

    private let aiService: AIServiceProtocol?
    private let aiContextBuilder: CoachContextBuilder?
    private let coachPipeline: CoachMessagePipeline?
    private let coachModelConfig: CoachModelConfig
    private let userProfileService: UserProfileService?
    private let aiCommandParsingEnabled: Bool
    private var pendingAction: CoachPendingAction?
    private var aiResponseCache: [String: String] = [:]

    init(
        localCommandParser: LocalCommandParser = .standard,
        localNutritionEstimator: LocalNutritionEstimator = .standard,
        actionCenter: FitnessActionCenter,
        dailyLogService: DailyLogService,
        workoutLogService: WorkoutLogService,
        toolbarUsageStore: CoachToolbarUsageStore? = nil,
        aiService: AIServiceProtocol? = nil,
        userProfileService: UserProfileService? = nil,
        aiCommandParsingEnabled: Bool = false,
        coachModelConfig: CoachModelConfig = .default
    ) {
        self.localCommandParser = localCommandParser
        self.localNutritionEstimator = localNutritionEstimator
        self.actionCenter = actionCenter
        self.dailyLogService = dailyLogService
        self.workoutLogService = workoutLogService
        self.toolbarUsageStore = toolbarUsageStore ?? .shared
        self.aiService = aiService
        self.userProfileService = userProfileService
        self.aiCommandParsingEnabled = aiCommandParsingEnabled
        self.coachModelConfig = coachModelConfig
        if let aiService {
            self.coachPipeline = CoachMessagePipeline(
                aiService: aiService,
                config: coachModelConfig,
                localCommandParser: localCommandParser,
                nutritionEstimator: localNutritionEstimator
            )
        } else {
            self.coachPipeline = nil
        }
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

    // MARK: Toolbar Context

    func refreshToolbarContext() {
        let log = try? dailyLogService.getTodayLog()
        let hasWorkoutToday = (try? !workoutLogService.getWorkouts(for: Date()).isEmpty) ?? false
        toolbarActions = CoachToolbarBuilder.build(
            log: log,
            hasWorkoutToday: hasWorkoutToday,
            usageStore: toolbarUsageStore
        )
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

        isSending = true
        defer {
            isSending = false
            refreshToolbarContext()
        }

        let response: String
        if let pendingResponse = await handlePendingActionInput(trimmed) {
            response = pendingResponse
        } else {
            response = await processCoachMessage(trimmed)
        }
        appendAssistantMessage(response)
    }

    private func processCoachMessage(_ text: String) async -> String {
        guard aiCommandParsingEnabled,
              let coachPipeline,
              let aiContextBuilder else {
            return CoachResponseBuilder.needsAIResponse
        }

        let context = aiContextBuilder.makeContext(recentMessages: messages)
        do {
            let decision = try await coachPipeline.process(text, context: context)
            CoachRouteDebugLogger.log(decision)
            return await handle(decision.route)
        } catch let error as AIServiceError {
            return error.userMessage
        } catch {
            return AIServiceError.requestFailed(error.localizedDescription).userMessage
        }
    }

    func applyToolbarAction(_ action: CoachToolbarAction) async {
        noteToolbarUse(action)

        switch action.behavior {
        case .prefill(let text):
            inputText = text
        case .send(let text):
            await send(text)
        case .openPhotoPicker:
            break
        }
    }

    func noteToolbarUse(_ action: CoachToolbarAction) {
        toolbarUsageStore.recordUse(of: action)
        refreshToolbarContext()
    }

    func applyExampleCommand(_ text: String) async {
        await send(text)
    }

    func handlePhotoSelected() async {
        await send("Should I eat this?")
    }

    func clearError() {
        errorMessage = nil
    }

    func prepareInput(prefill: String?) {
        inputText = prefill ?? ""
    }

    // MARK: AI Food Confirmation

    func openFoodConfirmationSheet() {
        guard foodConfirmationState.pendingDraft != nil else { return }
        foodConfirmationErrorMessage = nil
        isShowingFoodConfirmationSheet = true
    }

    func dismissFoodConfirmationSheet() {
        isShowingFoodConfirmationSheet = false
    }

    func confirmAIFoodEstimate(_ formState: FoodEntryFormState) async {
        guard let pending = foodConfirmationState.pendingDraft,
              let originalDraft = pending.primaryFoodDraft else {
            foodConfirmationErrorMessage = "I could not prepare that estimate for confirmation."
            return
        }

        foodConfirmationState = .saving(pending)
        foodConfirmationErrorMessage = nil

        do {
            let draft = try formState.makeAIFoodDraft(original: originalDraft)
            let entry = try actionCenter.logFood(draft, date: Date())
            let log = try? dailyLogService.getLog(for: Date())
            mutationHistory.record(entryId: entry.id, type: .food, summary: entry.name)
            pendingAction = nil
            clearFoodConfirmation()
            appendAssistantMessage(CoachResponseBuilder.food(entry, log: log))
            refreshToolbarContext()
        } catch let error as FoodEntryFormError {
            foodConfirmationState = .error(pending, error.localizedDescription)
            foodConfirmationErrorMessage = error.localizedDescription
        } catch ServiceError.invalidInput(let message) {
            foodConfirmationState = .error(pending, message)
            foodConfirmationErrorMessage = message
        } catch ServiceError.missingUserProfile {
            clearFoodConfirmation()
            appendAssistantMessage("I could not log that food entry. Please check that your profile is set up.")
        } catch {
            foodConfirmationState = .error(pending, CoachResponseBuilder.aiFoodSaveFailed)
            foodConfirmationErrorMessage = CoachResponseBuilder.aiFoodSaveFailed
        }
    }

    func rejectAIFoodEstimate() {
        clearFoodConfirmation()
        appendAssistantMessage(CoachResponseBuilder.aiFoodRejected)
    }

    private func clearFoodConfirmation() {
        foodConfirmationState = .none
        foodConfirmationErrorMessage = nil
        isShowingFoodConfirmationSheet = false
    }

    private func presentFoodConfirmation(
        originalText: String,
        assistantMessage: String?,
        foodDraft: FoodDraft,
        confidence: AIConfidence
    ) {
        let pending = AIFoodConfirmationDraft(
            originalText: originalText,
            assistantMessage: assistantMessage,
            foodDrafts: [foodDraft],
            confidence: confidence,
            requiresConfirmation: true
        )
        foodConfirmationState = .pending(pending)
        foodConfirmationErrorMessage = nil
        isShowingFoodConfirmationSheet = true
    }

    // MARK: Result Handling

    private func handle(_ route: CoachRoute) async -> String {
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

        case .action(let action, let intentResult):
            return await executeCoachAction(action, intentResult: intentResult)

        case .localMutation(let request):
            return executeLocalMutation(request)

        case .ai(let task):
            return await handleAITask(task)

        case .clarification(let message), .invalid(let message):
            return message
        }
    }

    private func handleLocalFoodEstimate(_ request: LocalFoodEstimateRequest) async -> String {
        switch ConfirmationPolicy.decision(for: request) {
        case .executeImmediately:
            return executeLogFood(request.estimate.foodDraft)
        case .requiresConfirmation:
            let confidence: AIConfidence = request.estimate.confidence == .high ? .high : .medium
            pendingAction = .food(
                request.estimate.foodDraft,
                originalText: request.originalText,
                assistantMessage: request.estimate.explanation
            )
            presentFoodConfirmation(
                originalText: request.originalText,
                assistantMessage: request.estimate.explanation,
                foodDraft: request.estimate.foodDraft,
                confidence: confidence
            )
            return CoachResponseBuilder.localFoodEstimatePending(request.estimate)
        case .reject(let message):
            return message
        }
    }

    private func executeLocalMutation(_ request: CoachMutationRequest) -> String {
        switch request {
        case .deleteMeal(let mealType):
            return deleteFood(mealType: mealType)
        case .deleteLastFood:
            return executeUndo(.food)
        case .editLastFoodQuantity(let quantity, let unit):
            return editLastFoodQuantity(quantity, unit: unit)
        }
    }

    private func executeCoachAction(
        _ action: CoachAction,
        intentResult: CoachIntentResult
    ) async -> String {
        switch action {
        case .logFood(let draft):
            return handleAIFoodDraft(
                draft,
                originalText: intentResult.entities.food ?? "",
                assistantMessage: "I estimated this from your message."
            )
        case .logWater(let draft):
            return executeLogWater(draft)
        case .logWeight(let draft):
            return executeLogWeight(draft)
        case .logWorkout(let draft):
            switch AIResponseValidator.validateWorkout(draft) {
            case .invalid(let message):
                return message
            case .requiresConfirmation, .valid:
                return executeLogWorkout(draft)
            }
        case .editLog(let selector):
            if let selector,
               selector.localizedCaseInsensitiveContains("last"),
               let quantity = intentResult.entities.quantity,
               quantity > 0 {
                return editLastFoodQuantity(quantity, unit: intentResult.entities.unit)
            }
            return "I need the exact entry and change before editing your log."
        case .deleteLog(let selector):
            let lowered = selector?.lowercased() ?? ""
            if lowered.contains("breakfast") { return deleteFood(mealType: .breakfast) }
            if lowered.contains("lunch") { return deleteFood(mealType: .lunch) }
            if lowered.contains("dinner") { return deleteFood(mealType: .dinner) }
            if lowered.contains("snack") { return deleteFood(mealType: .snack) }
            if lowered.contains("last") { return executeUndo(.food) }
            return "I need the exact entry before deleting from your log."
        case .undo(let target):
            return executeUndo(target)
        case .status:
            return executeStatus()
        case .dailyReview:
            return await executeDailyReview()
        }
    }

    private func handlePendingActionInput(_ text: String) async -> String? {
        guard let pendingAction else { return nil }

        let normalized = CommandParserUtilities.normalized(text)
        let confirmWords = ["confirm", "yes", "yep", "log it", "save it", "do it"]
        let rejectWords = ["cancel", "no", "nope", "discard", "reject"]

        if rejectWords.contains(normalized) {
            self.pendingAction = nil
            clearFoodConfirmation()
            return "No problem — I did not log it."
        }

        guard confirmWords.contains(normalized) else {
            return nil
        }

        self.pendingAction = nil
        clearFoodConfirmation()

        switch pendingAction {
        case .food(let draft, _, _):
            return executeLogFood(draft)
        case .workout(let draft):
            return executeLogWorkout(draft)
        }
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

    // MARK: AI Answers

    private func handleAITask(_ task: AITask) async -> String {
        let cacheKey = "\(task.type):\(task.originalText.lowercased())"
        if let cached = aiResponseCache[cacheKey] {
            return cached
        }

        guard aiCommandParsingEnabled, let aiService, let aiContextBuilder else {
            return CoachResponseBuilder.needsAIResponse
        }

        let context = aiContextBuilder.makeContext(recentMessages: messages)
        do {
            let response: String
            switch task.type {
            case .answerWithCheapModel, .answerWithStrongModel:
                let tier: CoachModelTier = task.type == .answerWithStrongModel ? .strong : .cheap
                let advice = try await aiService.generateCoachAnswer(
                    request: MealAdviceAIRequest(
                        question: task.originalText,
                        intentResult: task.intentResult
                    ),
                    context: context,
                    config: coachModelConfig,
                    tier: tier
                )
                response = CoachResponseBuilder.mealAdvice(
                    log: try? dailyLogService.getTodayLog(),
                    profile: try? userProfileService?.getCurrentProfile(),
                    hasWorkoutToday: hasWorkoutToday(),
                    assistantMessage: advice.message
                )
            }
            aiResponseCache[cacheKey] = response
            return response
        } catch let error as AIServiceError {
            return error.userMessage
        } catch {
            return AIServiceError.requestFailed(error.localizedDescription).userMessage
        }
    }

    private func handleAIFoodDraft(
        _ draft: FoodDraft,
        originalText: String,
        assistantMessage: String?
    ) -> String {
        switch AIResponseValidator.validateFood(draft, confidence: .medium) {
        case .invalid(let message):
            return message.isEmpty ? CoachResponseBuilder.aiNotUnderstood : message
        case .requiresConfirmation, .valid:
            pendingAction = .food(draft, originalText: originalText, assistantMessage: assistantMessage)
            presentFoodConfirmation(
                originalText: originalText,
                assistantMessage: assistantMessage,
                foodDraft: draft,
                confidence: .medium
            )
            return CoachResponseBuilder.aiFoodPendingMessage(assistantMessage: assistantMessage)
        }
    }

    private func hasWorkoutToday() -> Bool {
        (try? !workoutLogService.getWorkouts(for: Date()).isEmpty) ?? false
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
                calories: localEstimate?.foodDraft.calories,
                protein: localEstimate?.foodDraft.protein,
                carbs: localEstimate?.foodDraft.carbs,
                fat: localEstimate?.foodDraft.fat,
                fiber: nil,
                sodium: nil,
                source: .corrected,
                confidence: localEstimate?.foodDraft.confidence,
                imageUrl: nil,
                notes: localEstimate?.foodDraft.notes
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
}
