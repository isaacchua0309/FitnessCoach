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
    @Published private(set) var errorMessage: String?
    @Published private(set) var toolbarActions: [CoachToolbarAction] = CoachToolbarBuilder.defaultActions()
    @Published private(set) var foodConfirmationState: AIFoodConfirmationState = .none
    @Published var isShowingFoodConfirmationSheet = false
    @Published private(set) var foodConfirmationErrorMessage: String?

    private let localCommandParser: LocalCommandParser
    private let actionCenter: FitnessActionCenter
    private let dailyLogService: DailyLogService
    private let workoutLogService: WorkoutLogService
    private let toolbarUsageStore: CoachToolbarUsageStore

    private let aiService: AIServiceProtocol?
    private let aiContextBuilder: CoachAIContextBuilder?
    private let userProfileService: UserProfileService?
    private let aiCommandParsingEnabled: Bool

    init(
        localCommandParser: LocalCommandParser = .standard,
        actionCenter: FitnessActionCenter,
        dailyLogService: DailyLogService,
        workoutLogService: WorkoutLogService,
        toolbarUsageStore: CoachToolbarUsageStore = .shared,
        aiService: AIServiceProtocol? = nil,
        userProfileService: UserProfileService? = nil,
        aiCommandParsingEnabled: Bool = false
    ) {
        self.localCommandParser = localCommandParser
        self.actionCenter = actionCenter
        self.dailyLogService = dailyLogService
        self.workoutLogService = workoutLogService
        self.toolbarUsageStore = toolbarUsageStore
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

        let result = localCommandParser.parse(trimmed)
        let response = await handle(result, originalText: trimmed)
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
        let pending = AIFoodConfirmationDraft.from(command: command, foodDraft: foodDraft)
        foodConfirmationState = .pending(pending)
        foodConfirmationErrorMessage = nil
        isShowingFoodConfirmationSheet = true
    }

    // MARK: Result Handling

    private func handle(_ result: CommandParseResult, originalText: String) async -> String {
        switch result {
        case .success(let command):
            return await execute(command)
        case .needsAI:
            return await handleAIFallback(originalText)
        case .unsupported(_, let reason):
            return await handleAIFallback(originalText, localReason: reason ?? CoachResponseBuilder.unsupportedResponse)
        case .invalid(_, let reason):
            return reason
        case .ambiguous(_, let reason):
            return await handleAIFallback(
                originalText,
                localReason: reason.isEmpty ? CoachResponseBuilder.ambiguousResponse : reason
            )
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
            return CoachResponseBuilder.aiMultiActionDeferred
        }

        if let foodAction = command.actions.first(where: { $0.type == .logFood }),
           let foodDraft = foodAction.foodDraft {
            switch AIResponseValidator.validateFood(foodDraft, confidence: command.confidence) {
            case .invalid(let message):
                return message.isEmpty ? CoachResponseBuilder.aiNotUnderstood : message
            case .requiresConfirmation:
                presentAIFoodConfirmation(for: command, foodDraft: foodDraft)
                return CoachResponseBuilder.aiFoodPendingMessage(assistantMessage: command.assistantMessage)
            case .valid:
                presentAIFoodConfirmation(for: command, foodDraft: foodDraft)
                return CoachResponseBuilder.aiFoodPendingMessage(assistantMessage: command.assistantMessage)
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
            return command.assistantMessage ?? CoachResponseBuilder.aiNeedsConfirmation
        }
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
            return CoachResponseBuilder.food(entry, log: log)
        } catch ServiceError.invalidInput(let message) {
            return message
        } catch ServiceError.missingUserProfile {
            return "I could not log that food entry. Please check that your profile is set up."
        } catch {
            return "I could not log that food entry. Please check the calories and macro values."
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
        case .last, .workout, .weight:
            return CoachResponseBuilder.undoLastPlaceholder
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
}
