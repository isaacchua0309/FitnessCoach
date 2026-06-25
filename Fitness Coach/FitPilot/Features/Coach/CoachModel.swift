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
    case aiCommand(AIParsedCommand)
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
    private let routeDecider: CoachRouteDecider
    private let localNutritionEstimator: LocalNutritionEstimator
    private let actionCenter: FitnessActionCenter
    private let dailyLogService: DailyLogService
    private let workoutLogService: WorkoutLogService
    private let toolbarUsageStore: CoachToolbarUsageStore
    private let mutationHistory = CoachMutationHistory()

    private let aiService: AIServiceProtocol?
    private let aiContextBuilder: CoachAIContextBuilder?
    private let userProfileService: UserProfileService?
    private let aiCommandParsingEnabled: Bool
    private var pendingAction: CoachPendingAction?
    private var aiResponseCache: [String: String] = [:]

    init(
        localCommandParser: LocalCommandParser = .standard,
        routeDecider: CoachRouteDecider? = nil,
        localNutritionEstimator: LocalNutritionEstimator = .standard,
        actionCenter: FitnessActionCenter,
        dailyLogService: DailyLogService,
        workoutLogService: WorkoutLogService,
        toolbarUsageStore: CoachToolbarUsageStore? = nil,
        aiService: AIServiceProtocol? = nil,
        userProfileService: UserProfileService? = nil,
        aiCommandParsingEnabled: Bool = false
    ) {
        self.localCommandParser = localCommandParser
        self.localNutritionEstimator = localNutritionEstimator
        self.routeDecider = routeDecider ?? CoachRouteDecider(
            localCommandParser: localCommandParser,
            nutritionEstimator: localNutritionEstimator
        )
        self.actionCenter = actionCenter
        self.dailyLogService = dailyLogService
        self.workoutLogService = workoutLogService
        self.toolbarUsageStore = toolbarUsageStore ?? .shared
        self.aiService = aiService
        self.userProfileService = userProfileService
        self.aiCommandParsingEnabled = aiCommandParsingEnabled
        if let userProfileService {
            self.aiContextBuilder = CoachAIContextBuilder(
                dailyLogService: dailyLogService,
                userProfileService: userProfileService
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
            let route = routeDecider.decide(trimmed)
            response = await handle(route)
        }
        appendAssistantMessage(response)
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

    private func presentAIFoodConfirmation(for command: AIParsedCommand, foodDraft: FoodDraft) {
        presentFoodConfirmation(
            originalText: command.originalText,
            assistantMessage: command.assistantMessage,
            foodDraft: foodDraft,
            confidence: command.confidence
        )
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

        case .localCoaching(let request):
            return executeLocalCoaching(request)

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

    private func executeLocalCoaching(_ request: CoachingRequest) -> String {
        switch request.kind {
        case .mealNext:
            return CoachResponseBuilder.mealAdvice(
                log: try? dailyLogService.getTodayLog(),
                profile: try? userProfileService?.getCurrentProfile(),
                hasWorkoutToday: hasWorkoutToday(),
                assistantMessage: nil
            )
        case .recovery:
            return recoveryAdvice()
        case .tomorrowFocus:
            return CoachResponseBuilder.tomorrowFocus(
                log: try? dailyLogService.getTodayLog(),
                profile: try? userProfileService?.getCurrentProfile(),
                hasWorkoutToday: hasWorkoutToday()
            )
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
        case .aiCommand(let command):
            return await executeConfirmedAICommand(command)
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

    // MARK: AI Fallback

    private func handleAITask(_ task: AITask) async -> String {
        let cacheKey = "\(task.type):\(task.originalText.lowercased())"
        if let cached = aiResponseCache[cacheKey] {
            return cached
        }

        guard aiCommandParsingEnabled, let aiService, let aiContextBuilder else {
            return CoachResponseBuilder.needsAIResponse
        }

        let context = aiContextBuilder.makeContext(recentMessages: messages)
        let response: String

        do {
            switch task.type {
            case .estimateFood:
                let draft = try await aiService.estimateFood(from: task.originalText, context: context)
                response = handleAIFoodDraft(draft, originalText: task.originalText, assistantMessage: nil)

            case .generateMealAdvice:
                let advice = try await aiService.generateMealAdvice(
                    request: MealAdviceAIRequest(question: task.originalText),
                    context: context
                )
                response = CoachResponseBuilder.mealAdvice(
                    log: try? dailyLogService.getTodayLog(),
                    profile: try? userProfileService?.getCurrentProfile(),
                    hasWorkoutToday: hasWorkoutToday(),
                    assistantMessage: advice.message
                )

            case .parseCommand, .parseWorkout, .editEntry, .deleteEntry, .multiAction:
                let command = try await aiService.parseCommand(task.originalText, context: context)
                response = await executeAICommand(command)
            }
        } catch let error as AIServiceError {
            response = error.userMessage
        } catch {
            response = AIServiceError.requestFailed(error.localizedDescription).userMessage
        }

        aiResponseCache[cacheKey] = response
        return response
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

    private func handleAIFallback(_ text: String, localReason: String? = nil) async -> String {
        if let coachingResponse = coachingResponseForNaturalLanguage(text) {
            return coachingResponse
        }

        guard aiCommandParsingEnabled, let aiService, let aiContextBuilder else {
            return localReason ?? CoachResponseBuilder.needsAIResponse
        }

        let context = aiContextBuilder.makeContext(recentMessages: messages)

        do {
            let command = try await aiService.parseCommand(text, context: context)
            return await executeAICommand(command)
        } catch let error as AIServiceError {
            return error.userMessage
        } catch {
            return AIServiceError.requestFailed(error.localizedDescription).userMessage
        }
    }

    private func coachingResponseForNaturalLanguage(_ text: String) -> String? {
        let lowered = text.lowercased()

        if lowered.contains("tomorrow") || lowered.contains("focus on tomorrow") {
            return CoachResponseBuilder.tomorrowFocus(
                log: try? dailyLogService.getTodayLog(),
                profile: try? userProfileService?.getCurrentProfile(),
                hasWorkoutToday: hasWorkoutToday()
            )
        }

        if lowered.contains("recover") || lowered.contains("recovery") {
            return recoveryAdvice()
        }

        if lowered.contains("what should i eat")
            || lowered.contains("meal idea")
            || lowered.contains("eat next") {
            return CoachResponseBuilder.mealAdvice(
                log: try? dailyLogService.getTodayLog(),
                profile: try? userProfileService?.getCurrentProfile(),
                hasWorkoutToday: hasWorkoutToday(),
                assistantMessage: nil
            )
        }

        return nil
    }

    private func recoveryAdvice() -> String {
        guard hasWorkoutToday() else {
            return "No workout logged today yet. If you trained, log it first and I'll tailor recovery advice."
        }

        let log = try? dailyLogService.getTodayLog()
        let profile = try? userProfileService?.getCurrentProfile()
        let proteinTarget = log.map { MacroCalculator.macroTargets(from: $0.targets).protein } ?? profile?.targets.proteinTarget ?? 0
        let proteinConsumed = log?.totals.protein ?? 0
        let proteinGap = max(proteinTarget - proteinConsumed, 0)

        var advice = "Good work today. Prioritize 7–9 hours of sleep and a protein-rich meal within the next few hours."
        if proteinGap > 20 {
            advice += " You still need about \(Int(proteinGap.rounded()))g protein to support recovery."
        }
        if let waterRemaining = log.map({
            WaterTargetCalculator.remainingMl(
                consumedMl: $0.waterConsumedMl,
                targetMl: $0.targets.waterTargetMl
            )
        }), waterRemaining > 300 {
            advice += " Drink \(waterRemaining)ml more water before bed."
        }
        return advice
    }

    private func hasWorkoutToday() -> Bool {
        (try? !workoutLogService.getWorkouts(for: Date()).isEmpty) ?? false
    }

    private func executeAICommand(_ command: AIParsedCommand) async -> String {
        if command.actions.count > 1 {
            pendingAction = .aiCommand(command)
            return command.assistantMessage ?? CoachResponseBuilder.aiMultiActionDeferred
        }

        if let foodAction = command.actions.first(where: { $0.type == .logFood }),
           let foodDraft = foodAction.foodDraft {
            switch AIResponseValidator.validateFood(foodDraft, confidence: command.confidence) {
            case .invalid(let message):
                return message.isEmpty ? CoachResponseBuilder.aiNotUnderstood : message
            case .requiresConfirmation:
                pendingAction = .food(foodDraft, originalText: command.originalText, assistantMessage: command.assistantMessage)
                presentAIFoodConfirmation(for: command, foodDraft: foodDraft)
                return CoachResponseBuilder.aiFoodPendingMessage(assistantMessage: command.assistantMessage)
            case .valid:
                pendingAction = .food(foodDraft, originalText: command.originalText, assistantMessage: command.assistantMessage)
                presentAIFoodConfirmation(for: command, foodDraft: foodDraft)
                return CoachResponseBuilder.aiFoodPendingMessage(assistantMessage: command.assistantMessage)
            }
        }

        if let workoutAction = command.actions.first(where: { $0.type == .logWorkout }),
           let workoutDraft = workoutAction.workoutDraft {
            switch AIResponseValidator.validateWorkout(workoutDraft) {
            case .invalid(let message):
                return message
            case .requiresConfirmation, .valid:
                pendingAction = .workout(workoutDraft)
                return CoachResponseBuilder.workoutPending(workoutDraft)
            }
        }

        switch AIResponseValidator.validate(command) {
        case .invalid(let message):
            return message.isEmpty ? CoachResponseBuilder.aiNotUnderstood : message
        case .requiresConfirmation:
            return command.assistantMessage ?? CoachResponseBuilder.aiNeedsConfirmation
        case .valid:
            return await executeValidatedAIAction(command)
        }
    }

    private func executeValidatedAIAction(_ command: AIParsedCommand) async -> String {
        guard let action = command.actions.first, command.actions.count == 1 else {
            return command.assistantMessage ?? CoachResponseBuilder.aiNeedsConfirmation
        }

        switch action.type {
        case .logFood:
            return CoachResponseBuilder.aiNotUnderstood
        case .logWater:
            guard let draft = action.waterDraft else { return CoachResponseBuilder.aiNotUnderstood }
            return executeLogWater(draft)
        case .logWeight:
            guard let draft = action.weightDraft else { return CoachResponseBuilder.aiNotUnderstood }
            return executeLogWeight(draft)
        case .startNewDay:
            return ensureTodayLog(weightKg: action.startNewDayWeightKg)
        case .status:
            return executeStatus()
        case .dailyReview:
            return await executeDailyReview()
        case .mealAdvice:
            return CoachResponseBuilder.mealAdvice(
                log: try? dailyLogService.getTodayLog(),
                profile: try? userProfileService?.getCurrentProfile(),
                hasWorkoutToday: hasWorkoutToday(),
                assistantMessage: command.assistantMessage
            )
        case .logWorkout:
            guard let draft = action.workoutDraft else { return CoachResponseBuilder.aiNotUnderstood }
            return executeLogWorkout(draft)
        case .editEntry, .deleteEntry, .undo:
            return command.assistantMessage ?? CoachResponseBuilder.aiNeedsConfirmation
        }
    }

    private func executeConfirmedAICommand(_ command: AIParsedCommand) async -> String {
        var responses: [String] = []

        for action in command.actions {
            switch action.type {
            case .logFood:
                guard let draft = action.foodDraft else { return CoachResponseBuilder.aiNotUnderstood }
                responses.append(executeLogFood(draft))
            case .logWater:
                guard let draft = action.waterDraft else { return CoachResponseBuilder.aiNotUnderstood }
                responses.append(executeLogWater(draft))
            case .logWeight:
                guard let draft = action.weightDraft else { return CoachResponseBuilder.aiNotUnderstood }
                responses.append(executeLogWeight(draft))
            case .logWorkout:
                guard let draft = action.workoutDraft else { return CoachResponseBuilder.aiNotUnderstood }
                responses.append(executeLogWorkout(draft))
            case .startNewDay:
                responses.append(ensureTodayLog(weightKg: action.startNewDayWeightKg))
            case .status:
                responses.append(executeStatus())
            case .dailyReview:
                responses.append(await executeDailyReview())
            case .mealAdvice:
                responses.append(
                    CoachResponseBuilder.mealAdvice(
                        log: try? dailyLogService.getTodayLog(),
                        profile: try? userProfileService?.getCurrentProfile(),
                        hasWorkoutToday: hasWorkoutToday(),
                        assistantMessage: command.assistantMessage
                    )
                )
            case .editEntry, .deleteEntry, .undo:
                responses.append(command.assistantMessage ?? "I need a bit more detail before changing existing entries.")
            }
        }

        return responses.joined(separator: "\n\n")
    }

    // MARK: Command Execution

    private func ensureTodayLog(weightKg: Double?) -> String {
        do {
            _ = try actionCenter.ensureTodayLog()
            if let weightKg {
                return executeLogWeight(WeightDraft(weightKg: weightKg))
            }
            return CoachResponseBuilder.automaticDayMessage
        } catch ServiceError.missingUserProfile {
            return "I could not load today's log. Please check that your profile is set up."
        } catch {
            return "I could not load today's log. Please try again."
        }
    }

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
