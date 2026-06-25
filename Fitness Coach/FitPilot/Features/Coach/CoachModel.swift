//
//  CoachModel.swift
//  Fitness Coach
//
//  FitPilot AI — Feature model for the Coach chat shell.
//
//  CoachModel owns chat state, runs the deterministic LocalCommandParser first,
//  and falls back to AIService only when needed. It executes supported commands
//  through existing services. It does not import SwiftData, call the LLMClient
//  directly, call backend directly, or call another feature model. It never
//  trusts AI arithmetic as final daily totals.
//

import Combine
import Foundation

@MainActor
final class CoachModel: ObservableObject {

    @Published private(set) var messages: [ChatMessage] = []
    @Published var inputText: String = ""
    @Published private(set) var isSending: Bool = false
    @Published private(set) var errorMessage: String?
    @Published private(set) var foodConfirmationState: AIFoodConfirmationState = .none
    @Published var isShowingFoodConfirmationSheet = false
    @Published private(set) var foodConfirmationErrorMessage: String?

    private let localCommandParser: LocalCommandParser
    private let dailyLogService: DailyLogService
    private let foodLogService: FoodLogService
    private let waterLogService: WaterLogService
    private let weightLogService: WeightLogService
    private let workoutLogService: WorkoutLogService
    private let reviewService: ReviewService

    private let aiService: AIServiceProtocol?
    private let aiContextBuilder: CoachAIContextBuilder?
    private let aiCommandParsingEnabled: Bool
    private let refreshCenter: AppRefreshCenter

    init(
        localCommandParser: LocalCommandParser = .standard,
        dailyLogService: DailyLogService,
        foodLogService: FoodLogService,
        waterLogService: WaterLogService,
        weightLogService: WeightLogService,
        workoutLogService: WorkoutLogService,
        reviewService: ReviewService,
        aiService: AIServiceProtocol? = nil,
        userProfileService: UserProfileService? = nil,
        aiCommandParsingEnabled: Bool = false,
        refreshCenter: AppRefreshCenter
    ) {
        self.localCommandParser = localCommandParser
        self.dailyLogService = dailyLogService
        self.foodLogService = foodLogService
        self.waterLogService = waterLogService
        self.weightLogService = weightLogService
        self.workoutLogService = workoutLogService
        self.reviewService = reviewService
        self.aiService = aiService
        self.aiCommandParsingEnabled = aiCommandParsingEnabled
        self.refreshCenter = refreshCenter
        if let userProfileService {
            self.aiContextBuilder = CoachAIContextBuilder(
                dailyLogService: dailyLogService,
                userProfileService: userProfileService
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

        appendUserMessage(trimmed)

        isSending = true
        defer { isSending = false }

        let result = localCommandParser.parse(trimmed)
        let response = await handle(result, originalText: trimmed)
        appendAssistantMessage(response)
    }

    func tapQuickAction(_ action: CoachQuickAction) async {
        if let prefill = action.prefillText {
            inputText = prefill
            return
        }
        if let command = action.commandText {
            await send(command)
        }
    }

    func clearError() {
        errorMessage = nil
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
            let entry = try foodLogService.addFoodEntry(draft, date: Date())
            let log = try? dailyLogService.getLog(for: Date())
            notifyDataChanged()
            clearFoodConfirmation()
            appendAssistantMessage(CoachResponseBuilder.food(entry, log: log))
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
        case .newDay(let weightKg):
            return executeNewDay(weightKg: weightKg)
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

    /// Executes a validated single non-food action through existing services.
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
            return executeNewDay(weightKg: action.startNewDayWeightKg)
        case .status:
            return executeStatus()
        case .dailyReview:
            return await executeDailyReview()
        case .mealAdvice:
            return command.assistantMessage ?? "Here is some quick guidance based on your day."
        case .logWorkout:
            // Workouts are inferred and always confirmed before logging in this step.
            return command.assistantMessage ?? CoachResponseBuilder.aiNeedsConfirmation
        }
    }

    // MARK: Command Execution

    private func executeNewDay(weightKg: Double?) -> String {
        do {
            _ = try dailyLogService.startNewDay(weightKg: weightKg)
            notifyDataChanged()
            return CoachResponseBuilder.newDay(weightKg: weightKg)
        } catch ServiceError.missingUserProfile {
            return "I could not start a new day. Please check that your profile is set up."
        } catch {
            return "I could not start a new day. Please try again."
        }
    }

    private func executeLogWater(_ draft: WaterDraft) -> String {
        do {
            let entry = try waterLogService.addWater(draft, date: Date())
            let log = try? dailyLogService.getLog(for: Date())
            notifyDataChanged()
            return CoachResponseBuilder.water(loggedMl: entry.amountMl, log: log)
        } catch ServiceError.invalidInput(let message) {
            return message
        } catch {
            return "I could not save that water entry. Please try again."
        }
    }

    private func executeLogWeight(_ draft: WeightDraft) -> String {
        do {
            let entry = try weightLogService.logWeight(draft, date: Date())
            notifyDataChanged()
            return CoachResponseBuilder.weight(entry.weightKg)
        } catch ServiceError.invalidInput(let message) {
            return message
        } catch {
            return "I could not log that weight. Please try again."
        }
    }

    private func executeLogFood(_ draft: FoodDraft) -> String {
        do {
            let entry = try foodLogService.addFoodEntry(draft, date: Date())
            let log = try? dailyLogService.getLog(for: Date())
            notifyDataChanged()
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
                let entry = try foodLogService.undoLastFoodEntry(date: Date())
                notifyDataChanged()
                return CoachResponseBuilder.undoFood(entry)
            } catch {
                return "I could not undo your last food entry. Please try again."
            }
        case .water:
            do {
                let entry = try waterLogService.undoLastWaterEntry(date: Date())
                notifyDataChanged()
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
            let review = try await reviewService.generateDailyReview(for: Date())
            notifyDataChanged()
            return CoachResponseBuilder.dailyReview(review)
        } catch ServiceError.missingUserProfile {
            return "I could not generate your daily review yet. Please start a day and make sure your profile is set up."
        } catch ServiceError.dailyLogNotFound {
            return "There is no daily log for today yet. Start a new day first."
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

    private func notifyDataChanged() {
        refreshCenter.notifyDataChanged()
    }
}
