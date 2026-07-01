//
//  CoachAIRouteHandler.swift
//  Fitness Coach
//
//  Coach AI route and task handling — routing decisions to mutations or pending confirmations.
//

import Foundation

@MainActor
final class CoachAIRouteHandler {

    private let aiService: AIServiceProtocol?
    private let aiCommandParsingEnabled: Bool
    private let dailyLogService: DailyLogService
    private let userProfileReader: (any UserProfileReading)?
    private let trainingInsightsStore: TrainingInsightsStore?
    private let mutationExecutor: CoachMutationExecutor

    init(
        aiService: AIServiceProtocol?,
        aiCommandParsingEnabled: Bool,
        dailyLogService: DailyLogService,
        userProfileReader: (any UserProfileReading)?,
        trainingInsightsStore: TrainingInsightsStore?,
        mutationExecutor: CoachMutationExecutor
    ) {
        self.aiService = aiService
        self.aiCommandParsingEnabled = aiCommandParsingEnabled
        self.dailyLogService = dailyLogService
        self.userProfileReader = userProfileReader
        self.trainingInsightsStore = trainingInsightsStore
        self.mutationExecutor = mutationExecutor
    }

    func handle(_ route: CoachRoute, context: AIContext) async throws -> CoachActionResult {
        switch route {
        case .noOp(let response):
            switch response {
            case .casual(let message), .meaningless(let message):
                return .message(message)
            }

        case .localCommand(let command):
            switch ConfirmationPolicy.decision(for: command) {
            case .executeImmediately:
                let response = await mutationExecutor.execute(command)
                return .message(response)
            case .requiresConfirmation(let message):
                return .message(message)
            case .reject(let message):
                return .message(message)
            }

        case .localFoodEstimate(let request):
            return handleLocalFoodEstimate(request)

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

        case .trainingLogRedirect:
            let message = await trainingLogRedirectMessage()
            return .message(message)

        case .clarification(let message), .invalid(let message):
            return .message(message)
        }
    }

    func handleAITask(_ routed: RoutedAITask, context: AIContext) async throws -> CoachActionResult {
        guard aiCommandParsingEnabled, let aiService else {
            return .message(CoachResponseBuilder.backendUnavailableResponse)
        }

        switch routed.task {
        case .estimateFood(let prompt):
            let response = try await aiService.estimateFood(
                prompt: prompt,
                context: context,
                imageJPEGData: nil
            )
            return presentEstimateFoodResponse(
                response,
                prompt: prompt,
                routed: routed
            )

        case .photoFoodAnalysis(let imageData, let prompt):
            guard CoachMealPhotoPipeline.hasImagePayload(imageData) else {
                return .message(CoachResponseBuilder.mealPhotoError(.noImage))
            }
            CoachMealPhotoPipeline.assertImagePayloadPresent(imageData!)

            let response = try await aiService.estimateFood(
                prompt: prompt,
                context: context,
                imageJPEGData: imageData
            )
            return presentEstimateFoodResponse(
                response,
                prompt: prompt,
                routed: routed,
                photoAnalysis: true
            )

        case .mealAdvice(let prompt):
            let advice = try await aiService.generateMealAdvice(
                prompt: prompt,
                context: context,
                intentResult: routed.intentResult,
                tier: routed.tier
            )
            let message = CoachResponseBuilder.mealAdvice(
                log: try? dailyLogService.getTodayLog(),
                profile: try? userProfileReader?.getCurrentProfile(),
                hasWorkoutToday: await mutationExecutor.hasWorkoutToday(),
                assistantMessage: advice.message
            )
            return .message(message)

        case .parseWorkout:
            let message = await trainingLogRedirectMessage()
            return .message(message)

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

    func trainingLogRedirectMessage() async -> String {
        if let trainingInsightsStore {
            await trainingInsightsStore.refresh()
            return TrainingIntegrationCopy.coachWorkoutLogMessage(
                isAppleHealthConnected: trainingInsightsStore.integrationState.isConnected
            )
        }
        return TrainingIntegrationCopy.coachWorkoutLogMessage(isAppleHealthConnected: false)
    }

    private func handleLocalFoodEstimate(_ request: LocalFoodEstimateRequest) -> CoachActionResult {
        switch ConfirmationPolicy.decision(for: request) {
        case .executeImmediately:
            return .message(mutationExecutor.executeLogFood(request.estimate.draft))
        case .requiresConfirmation:
            return CoachPendingConfirmationPresenter.presentLocalFoodEstimatePending(request)
        case .reject(let message):
            return .message(message)
        }
    }

    private func presentEstimateFoodResponse(
        _ response: AIFoodEstimateResponse,
        prompt: String,
        routed: RoutedAITask,
        photoAnalysis: Bool = false
    ) -> CoachActionResult {
        let classifierDraft: FoodDraft? = {
            if case .logFood(let draft) = routed.intentResult.action { return draft }
            return nil
        }()

        guard var draft = response.foodDrafts.first else {
            return .message(CoachResponseBuilder.aiNotUnderstood)
        }

        if photoAnalysis {
            draft.source = .aiPhotoEstimate
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
    }

    private func handleParsedAICommand(
        _ parsed: AIParsedCommand,
        context: AIContext
    ) async throws -> CoachActionResult {
        switch ConfirmationPolicy.decision(for: parsed) {
        case .reject(let message):
            return .message(message)
        case .requiresConfirmation(let message):
            if let action = parsed.actions.first {
                return try await presentAIActionConfirmation(action, parsed: parsed, fallback: message)
            }
            return .message(parsed.assistantMessage ?? message)
        case .executeImmediately:
            if parsed.actions.isEmpty {
                return .message(parsed.assistantMessage ?? CoachResponseBuilder.aiNotUnderstood)
            }
            let response = try await executeAIActions(parsed.actions)
            return .message(response)
        }
    }

    private func presentAIActionConfirmation(
        _ action: AICommandAction,
        parsed: AIParsedCommand,
        fallback: String
    ) async throws -> CoachActionResult {
        switch action.type {
        case .logFood:
            guard let draft = action.foodDraft else { return .message(fallback) }
            return presentAIFoodEstimate(
                draft: draft,
                originalText: parsed.originalText,
                assistantMessage: parsed.assistantMessage,
                confidence: parsed.confidence
            )
        case .logWorkout:
            guard action.workoutDraft != nil else { return .message(fallback) }
            let message = await trainingLogRedirectMessage()
            return .message(message)
        case .logWater:
            guard let draft = action.waterDraft else { return .message(fallback) }
            return CoachPendingConfirmationPresenter.presentWaterPending(
                draft,
                assistantMessage: parsed.assistantMessage
            )
        case .logWeight:
            guard let draft = action.weightDraft else { return .message(fallback) }
            return CoachPendingConfirmationPresenter.presentWeightPending(
                draft,
                assistantMessage: parsed.assistantMessage
            )
        case .editEntry:
            return CoachPendingConfirmationPresenter.presentMutationPending(
                .edit(action, originalText: parsed.originalText, assistantMessage: parsed.assistantMessage),
                assistantMessage: parsed.assistantMessage,
                fallback: fallback
            )
        case .deleteEntry:
            return CoachPendingConfirmationPresenter.presentMutationPending(
                .delete(action, originalText: parsed.originalText, assistantMessage: parsed.assistantMessage),
                assistantMessage: parsed.assistantMessage,
                fallback: fallback
            )
        case .undo:
            return CoachPendingConfirmationPresenter.presentMutationPending(
                .undo(action, originalText: parsed.originalText, assistantMessage: parsed.assistantMessage),
                assistantMessage: parsed.assistantMessage,
                fallback: fallback
            )
        case .mealAdvice, .status, .dailyReview, .startNewDay:
            return .message(parsed.assistantMessage ?? fallback)
        }
    }

    private func executeAIActions(_ actions: [AICommandAction]) async throws -> String {
        var responses: [String] = []
        for action in actions {
            switch action.type {
            case .logFood:
                if let draft = action.foodDraft {
                    responses.append(mutationExecutor.executeLogFood(draft))
                }
            case .logWater:
                if let draft = action.waterDraft {
                    responses.append(mutationExecutor.executeLogWater(draft))
                }
            case .logWeight:
                if let draft = action.weightDraft {
                    responses.append(mutationExecutor.executeLogWeight(draft))
                }
            case .logWorkout:
                if action.workoutDraft != nil {
                    responses.append(await trainingLogRedirectMessage())
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
    ) -> CoachActionResult {
        let sanitized = FoodDraftNutritionCompleter.sanitizePartial(draft, hintText: originalText)
        switch ConfirmationPolicy.decision(for: sanitized) {
        case .requiresConfirmation, .executeImmediately:
            return CoachPendingConfirmationPresenter.presentFoodPending(
                originalText: originalText,
                assistantMessage: assistantMessage,
                foodDraft: sanitized,
                confidence: confidence
            )
        case .reject(let message):
            return .message(message)
        }
    }
}
