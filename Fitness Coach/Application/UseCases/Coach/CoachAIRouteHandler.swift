//
//  CoachAIRouteHandler.swift
//  Fitness Coach
//
//  Coach AI route and task handling — routing decisions to mutations or pending confirmations.
//

import Foundation

struct PhotoAnalysisPresentation: Equatable {
    let actionResult: CoachActionResult
    let sessionResult: ImageAnalysisSessionResult
}

@MainActor
final class CoachAIRouteHandler {

    private let aiService: AIServiceProtocol?
    private let aiCommandParsingEnabled: Bool
    private let dailyLogReader: any DailyLogReading
    private let userProfileReader: (any UserProfileReading)?
    private let trainingInsightsStore: TrainingInsightsStore?
    private let mutationExecutor: CoachMutationExecutor

    init(
        aiService: AIServiceProtocol?,
        aiCommandParsingEnabled: Bool,
        dailyLogReader: any DailyLogReading,
        userProfileReader: (any UserProfileReading)?,
        trainingInsightsStore: TrainingInsightsStore?,
        mutationExecutor: CoachMutationExecutor
    ) {
        self.aiService = aiService
        self.aiCommandParsingEnabled = aiCommandParsingEnabled
        self.dailyLogReader = dailyLogReader
        self.userProfileReader = userProfileReader
        self.trainingInsightsStore = trainingInsightsStore
        self.mutationExecutor = mutationExecutor
    }

    func handle(
        _ route: CoachRoute,
        context: CoachContextPacketV2,
        pendingConfirmation: CoachPendingConfirmation? = nil
    ) async throws -> CoachActionResult {
        switch route {
        case .noOp(let response):
            switch response {
            case .casual(let message), .meaningless(let message):
                return .message(message)
            }

        case .localCommand(let command):
            switch ConfirmationPolicy.decision(for: command) {
            case .executeImmediately:
                let response = await mutationExecutor.execute(
                    command,
                    healthIntelligence: resolvedHealthIntelligence(from: context),
                    contextHints: CoachResponseContextHints.from(context)
                )
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
                context: context,
                pendingConfirmation: pendingConfirmation
            )

        case .ai(let task):
            return try await handleAITask(
                task,
                context: context,
                pendingConfirmation: pendingConfirmation
            )

        case .trainingLogRedirect:
            let message = await trainingLogRedirectMessage()
            return .message(message)

        case .clarification(let message), .invalid(let message):
            return .message(message)
        }
    }

    func handleAITask(
        _ routed: RoutedAITask,
        context: CoachContextPacketV2,
        pendingConfirmation: CoachPendingConfirmation? = nil
    ) async throws -> CoachActionResult {
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
                routed: routed,
                context: context
            )

        case .photoFoodAnalysis(let imageData, let prompt, let recommission):
            guard let imageData, CoachMealPhotoPipeline.hasImagePayload(imageData) else {
                return .message(CoachResponseBuilder.mealPhotoError(.noImage))
            }
            CoachMealPhotoPipeline.assertImagePayloadPresent(imageData)

            let uploadAttachment = CoachMealImageUploadAttachment.fromUploadData(imageData)
            let presentation = try await analyzeMealPhoto(
                uploadAttachment: uploadAttachment,
                prompt: prompt,
                recommission: recommission,
                context: context
            )
            return presentation.actionResult

        case .mealAdvice(let prompt):
            let advice = try await aiService.generateMealAdvice(
                prompt: prompt,
                context: context,
                intentResult: routed.intentResult,
                tier: routed.tier
            )
            let hints = CoachResponseContextHints.from(context)
            let message = CoachResponseBuilder.mealAdvice(
                log: try? dailyLogReader.getTodayLog(),
                profile: try? userProfileReader?.getCurrentProfile(),
                hasWorkoutToday: hasWorkoutToday(from: context),
                healthIntelligence: resolvedHealthIntelligence(from: context),
                intent: routed.intentResult.intent,
                assistantMessage: advice.message,
                contextHints: hints
            )
            return .message(message)

        case .nutritionEstimate(let prompt):
            return try await presentNutritionEstimate(
                prompt: prompt,
                context: context,
                routed: routed
            )

        case .nutritionComparison(let prompt):
            return try await presentNutritionComparison(
                prompt: prompt,
                context: context,
                routed: routed
            )

        case .parseWorkout:
            let message = await trainingLogRedirectMessage()
            return .message(message)

        case .editEntry(let prompt), .deleteEntry(let prompt):
            let parsed = try await aiService.parseEditOrDelete(prompt: prompt, context: context)
            return try await handleParsedAICommand(
                parsed,
                context: context,
                pendingConfirmation: pendingConfirmation
            )

        case .multiAction(let prompt):
            let parsed = try await aiService.parseMultiAction(prompt: prompt, context: context)
            return try await handleParsedAICommand(
                parsed,
                context: context,
                pendingConfirmation: pendingConfirmation
            )

        case .parseCommand(let prompt):
            let parsed = try await aiService.parseCommand(prompt, context: context)
            return try await handleParsedAICommand(
                parsed,
                context: context,
                pendingConfirmation: pendingConfirmation
            )
        }
    }

    func analyzeMealPhoto(
        uploadAttachment: CoachMealImageUploadAttachment,
        prompt: String,
        recommission: ImageAnalysisRecommissionContext?,
        context: CoachContextPacketV2
    ) async throws -> PhotoAnalysisPresentation {
        guard let aiService else {
            throw AIServiceError.backendUnavailable
        }

        let trimmedPrompt = prompt.trimmingCharacters(in: .whitespacesAndNewlines)
        let requestResult = CoachMealImageAIRequestBuilder.buildAnalysisRequest(
            attachment: uploadAttachment,
            context: context,
            message: trimmedPrompt.isEmpty ? nil : trimmedPrompt,
            clarification: recommission?.clarification,
            previousAnalysis: recommission?.previousResult.map(MealImageAnalysisMapper.previousAnalysis)
        )

        let request: AIMealImageAnalysisRequest
        switch requestResult {
        case .failure(let error):
            CoachImageAnalysisDebugLogger.logUploadValidationFailed(
                error,
                attachment: uploadAttachment
            )
            throw CoachMealImageAIRequestBuilder.mapBuildError(error)
        case .success(let built):
            request = built
            CoachImageAnalysisDebugLogger.logUploadPayloadReady(
                attachment: uploadAttachment,
                request: request
            )
        }

        let response = try await aiService.analyzeMealImage(request: request)
        let extractionValidation = MealImageAnalysisResponseValidator.validate(response: response)
        guard extractionValidation.isValid else {
            throw AIServiceError.invalidNutritionJSON(extractionValidation.errors.joined(separator: " | "))
        }

        let sessionResult = MealImageAnalysisMapper.sessionResult(from: response)

        let sanity = NutritionSanityValidator.validate(
            meal: sessionResult.mealDraft,
            prompt: prompt,
            confidence: sessionResult.confidence
        )

        switch ConfirmationPolicy.decision(for: sanity.mealDraft) {
        case .reject(let message):
            throw AIServiceError.invalidNutritionJSON(message)
        case .requiresConfirmation, .executeImmediately:
            break
        }

        let actionResult = presentAIFoodEstimate(
            mealDraft: sanity.mealDraft,
            originalText: prompt,
            assistantMessage: response.summary,
            confidence: sanity.confidence,
            context: context,
            debugContext: FoodEstimateDebugContext(
                source: .aiPhoto,
                llmMealDraft: sessionResult.mealDraft,
                fallbackMealDraft: nil,
                fallbackLabel: nil
            ),
            sanityWarning: sanity.isAcceptable ? nil : NutritionSanityResult.underEstimatedUserMessage,
            fromPhotoAnalysis: true
        )

        guard actionResult.pendingConfirmation != nil else {
            throw AIServiceError.invalidNutritionJSON(
                actionResult.message.isEmpty ?
                    "Could not extract reliable nutrition from the meal photo." :
                    actionResult.message
            )
        }

        return PhotoAnalysisPresentation(
            actionResult: actionResult,
            sessionResult: ImageAnalysisSessionResult(
                mealDraft: sanity.mealDraft,
                confidence: sanity.confidence,
                summary: sessionResult.summary,
                clarifyingQuestion: sessionResult.clarifyingQuestion
            )
        )
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
        let mealDraft = FoodLogDraftNutritionCompleter.sanitize(
            FoodLogDraftMapper.fromLegacyDraft(request.estimate.draft),
            hintText: request.originalText
        )
        let confidence: AIConfidence = request.estimate.confidence == .high ? .high : .medium
        let sanity = NutritionSanityValidator.validate(
            meal: mealDraft,
            prompt: request.originalText,
            confidence: confidence
        )
        logFoodEstimateDebug(
            CoachFoodEstimateDebugSnapshot(
                source: .localEstimator,
                originalText: request.originalText,
                llmMealDraft: nil,
                fallbackMealDraft: mealDraft,
                fallbackLabel: "local_nutrition_estimator",
                sanitizedMealDraft: mealDraft,
                sanityResult: sanity,
                displayedMealDraft: sanity.mealDraft,
                responseConfidence: confidence,
                sanityWarning: sanity.isAcceptable ? nil : NutritionSanityResult.underEstimatedUserMessage
            )
        )

        switch ConfirmationPolicy.decision(for: request) {
        case .executeImmediately:
            return .message(mutationExecutor.executeLogFood(request.estimate.draft))
        case .requiresConfirmation:
            return CoachPendingConfirmationPresenter.presentLocalFoodEstimatePending(
                request,
                sourceAttribution: .localParser
            )
        case .reject(let message):
            return .message(message)
        }
    }

    private func presentEstimateFoodResponse(
        _ response: AIFoodEstimateResponse,
        prompt: String,
        routed: RoutedAITask,
        context: CoachContextPacketV2,
        photoAnalysis: Bool = false
    ) -> CoachActionResult {
        let classifierDraft: FoodDraft? = {
            if case .logFood(let draft) = routed.intentResult.action { return draft }
            return nil
        }()

        guard var meal = FoodLogDraftMapper.primaryMeal(from: response) else {
            if photoAnalysis {
                return .message(CoachResponseBuilder.mealPhotoAnalysisFailed(
                    .invalidNutritionJSON("Response is missing food log drafts.")
                ))
            }
            return .message(CoachResponseBuilder.aiNotUnderstood)
        }

        let extractionValidation = FoodEstimateResponseValidator.validate(
            response: response,
            prompt: prompt
        )
        guard extractionValidation.isValid else {
            if photoAnalysis {
                return .message(CoachResponseBuilder.mealPhotoAnalysisFailed(
                    .invalidNutritionJSON(extractionValidation.errors.joined(separator: " | "))
                ))
            }
            return .message(CoachResponseBuilder.aiNotUnderstood)
        }

        if photoAnalysis {
            meal.source = .aiPhotoEstimate
        }

        let llmMeal = meal

        if let classifierDraft, !classifierDraft.hasCompleteNutritionEstimate {
            meal = FoodLogDraftNutritionCompleter.mergeExplicit(
                classifierDraft,
                into: meal,
                hintText: prompt
            )
        }

        let usedClassifierMerge = meal != llmMeal
        let matchedCommonFood = CoachAIResponseContextAdapter.matchesCommonFoodReference(
            prompt: prompt,
            commonFoods: context.commonFoods
        )

        return presentAIFoodEstimate(
            mealDraft: meal,
            originalText: prompt,
            assistantMessage: response.assistantMessage,
            confidence: response.confidence,
            context: context,
            debugContext: FoodEstimateDebugContext(
                source: photoAnalysis ? .aiPhoto : .aiText,
                llmMealDraft: llmMeal,
                fallbackMealDraft: usedClassifierMerge ? meal : nil,
                fallbackLabel: usedClassifierMerge ? "classifier_merge" : nil
            ),
            fromPhotoAnalysis: photoAnalysis,
            usedClassifierMerge: usedClassifierMerge,
            matchedCommonFood: matchedCommonFood
        )
    }

    private enum ParsedMutationPreparation {
        case respond(CoachActionResult)
        case proceed(AIParsedCommand)
    }

    private func handleParsedAICommand(
        _ parsed: AIParsedCommand,
        context: CoachContextPacketV2,
        pendingConfirmation: CoachPendingConfirmation? = nil
    ) async throws -> CoachActionResult {
        var workingParsed = parsed
        if let mutationAction = parsed.actions.first,
           mutationAction.type == .editEntry || mutationAction.type == .deleteEntry {
            switch prepareMutationCommand(
                mutationAction,
                parsed: parsed,
                context: context,
                pendingConfirmation: pendingConfirmation
            ) {
            case .respond(let result):
                return result
            case .proceed(let enrichedParsed):
                workingParsed = enrichedParsed
            }
        }

        switch ConfirmationPolicy.decision(for: workingParsed) {
        case .reject(let message):
            return .message(message)
        case .requiresConfirmation(let message):
            if let action = workingParsed.actions.first {
                return try await presentAIActionConfirmation(
                    action,
                    parsed: workingParsed,
                    fallback: message,
                    context: context
                )
            }
            return .message(workingParsed.assistantMessage ?? message)
        case .executeImmediately:
            if workingParsed.actions.isEmpty {
                return .message(workingParsed.assistantMessage ?? CoachResponseBuilder.aiNotUnderstood)
            }
            let response = try await executeAIActions(workingParsed.actions)
            return .message(response)
        }
    }

    private func prepareMutationCommand(
        _ action: AICommandAction,
        parsed: AIParsedCommand,
        context: CoachContextPacketV2,
        pendingConfirmation: CoachPendingConfirmation?
    ) -> ParsedMutationPreparation {
        let resolution = CoachEntryReferenceResolver.resolve(
            action: action,
            context: context,
            pendingConfirmation: pendingConfirmation
        )

        switch resolution.outcome {
        case .clarify(let message), .blocked(let message):
            return .respond(.message(message))

        case .target(_, _, let confidence, let pendingFoodDraft):
            if confidence == .low {
                return .respond(.message(CoachResponseBuilder.entryReferenceClarification()))
            }

            if let pendingFoodDraft {
                return .respond(
                    CoachPendingConfirmationPresenter.presentFoodPending(
                        originalText: pendingFoodDraft.originalText,
                        assistantMessage: parsed.assistantMessage ?? pendingFoodDraft.assistantMessage,
                        mealDraft: pendingFoodDraft.primaryMealDraft,
                        confidence: pendingFoodDraft.confidence,
                        sanityWarning: pendingFoodDraft.sanityWarning,
                        sourceAttribution: pendingFoodDraft.sourceAttribution
                    )
                )
            }

            guard let enriched = CoachEntryReferenceResolver.enrichAction(
                action,
                context: context,
                pendingConfirmation: pendingConfirmation
            ).enrichedAction else {
                return .respond(.message(CoachResponseBuilder.entryReferenceClarification()))
            }

            var enrichedParsed = parsed
            enrichedParsed.actions = [enriched] + parsed.actions.dropFirst()
            return .proceed(enrichedParsed)
        }
    }

    private func presentAIActionConfirmation(
        _ action: AICommandAction,
        parsed: AIParsedCommand,
        fallback: String,
        context: CoachContextPacketV2
    ) async throws -> CoachActionResult {
        switch action.type {
        case .logFood:
            guard let draft = action.foodDraft else { return .message(fallback) }
            return presentAIFoodEstimate(
                mealDraft: FoodLogDraftMapper.fromLegacyDraft(draft),
                originalText: parsed.originalText,
                assistantMessage: parsed.assistantMessage,
                confidence: parsed.confidence,
                context: context,
                debugContext: FoodEstimateDebugContext(
                    source: .parsedCommand,
                    llmMealDraft: nil,
                    fallbackMealDraft: FoodLogDraftMapper.fromLegacyDraft(draft),
                    fallbackLabel: "parsed_command"
                )
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

    private struct FoodEstimateDebugContext {
        var source: CoachFoodEstimateDebugSnapshot.Source
        var llmMealDraft: FoodLogDraft?
        var fallbackMealDraft: FoodLogDraft?
        var fallbackLabel: String?
    }

    private func presentAIFoodEstimate(
        mealDraft: FoodLogDraft,
        originalText: String,
        assistantMessage: String?,
        confidence: AIConfidence,
        context: CoachContextPacketV2? = nil,
        debugContext: FoodEstimateDebugContext? = nil,
        sanityWarning: String? = nil,
        fromPhotoAnalysis: Bool = false,
        usedClassifierMerge: Bool = false,
        matchedCommonFood: Bool = false
    ) -> CoachActionResult {
        let sanitized = FoodLogDraftNutritionCompleter.sanitize(mealDraft, hintText: originalText)
        let sanity = NutritionSanityValidator.validate(
            meal: sanitized,
            prompt: originalText,
            confidence: confidence
        )
        let resolvedSanityWarning = sanityWarning ?? (sanity.isAcceptable ? nil : NutritionSanityResult.underEstimatedUserMessage)
        let trustGate = FoodEstimateTrustPolicy.confirmGate(
            sanityResult: sanity,
            userEditedBeforeConfirm: false
        )

        if let debugContext {
            logFoodEstimateDebug(
                CoachFoodEstimateDebugSnapshot(
                    source: debugContext.source,
                    originalText: originalText,
                    llmMealDraft: debugContext.llmMealDraft,
                    fallbackMealDraft: debugContext.fallbackMealDraft,
                    fallbackLabel: debugContext.fallbackLabel,
                    sanitizedMealDraft: sanitized,
                    sanityResult: sanity,
                    displayedMealDraft: sanity.mealDraft,
                    responseConfidence: confidence,
                    sanityWarning: resolvedSanityWarning
                )
            )
        }

        switch ConfirmationPolicy.decision(for: sanity.mealDraft) {
        case .requiresConfirmation, .executeImmediately:
            let sourceAttribution = CoachAIResponseContextAdapter.resolveFoodEstimateAttribution(
                fromPhotoAnalysis: fromPhotoAnalysis,
                usedClassifierMerge: usedClassifierMerge,
                matchedCommonFood: matchedCommonFood || CoachAIResponseContextAdapter.matchesCommonFoodReference(
                    prompt: originalText,
                    commonFoods: context?.commonFoods ?? []
                ),
                isLocalEstimate: false
            )
            return CoachPendingConfirmationPresenter.presentFoodPending(
                originalText: originalText,
                assistantMessage: assistantMessage,
                mealDraft: sanity.mealDraft,
                confidence: sanity.confidence,
                sanityWarning: resolvedSanityWarning,
                fromPhotoAnalysis: fromPhotoAnalysis,
                sourceAttribution: sourceAttribution,
                sanityFailed: trustGate.sanityFailed,
                requiresEditBeforeConfirm: trustGate.requiresEditBeforeConfirm
            )
        case .reject(let message):
            return .message(message)
        }
    }

    private func presentNutritionEstimate(
        prompt: String,
        context: CoachContextPacketV2,
        routed: RoutedAITask
    ) async throws -> CoachActionResult {
        guard let aiService else {
            return .message(CoachResponseBuilder.backendUnavailableResponse)
        }

        let dailyLog = try? dailyLogReader.getTodayLog()

        do {
            let response = try await aiService.generateNutritionEstimate(
                prompt: prompt,
                context: context,
                intentResult: routed.intentResult,
                tier: routed.tier
            )
            switch NutritionEstimateResponseParser.parseEstimate(response, dailyLog: dailyLog) {
            case .estimate(let card):
                return .structured(
                    .nutritionEstimate(card),
                    accessibilityText: NutritionEstimateCardFormatter.accessibilitySummary(for: card)
                )
            case .comparison(let card):
                return .structured(
                    .nutritionComparison(card),
                    accessibilityText: NutritionEstimateCardFormatter.accessibilitySummary(for: card)
                )
            case .plainText(let text):
                return .message(text)
            }
        } catch {
            return .message(CoachResponseBuilder.aiNotUnderstood)
        }
    }

    private func presentNutritionComparison(
        prompt: String,
        context: CoachContextPacketV2,
        routed: RoutedAITask
    ) async throws -> CoachActionResult {
        guard let aiService else {
            return .message(CoachResponseBuilder.backendUnavailableResponse)
        }

        do {
            let response = try await aiService.generateNutritionComparison(
                prompt: prompt,
                context: context,
                intentResult: routed.intentResult,
                tier: routed.tier
            )
            switch NutritionEstimateResponseParser.parseComparison(response) {
            case .comparison(let card):
                return .structured(
                    .nutritionComparison(card),
                    accessibilityText: NutritionEstimateCardFormatter.accessibilitySummary(for: card)
                )
            case .estimate(let card):
                return .structured(
                    .nutritionEstimate(card),
                    accessibilityText: NutritionEstimateCardFormatter.accessibilitySummary(for: card)
                )
            case .plainText(let text):
                return .message(text)
            }
        } catch {
            return .message(CoachResponseBuilder.aiNotUnderstood)
        }
    }

    private func logFoodEstimateDebug(_ snapshot: CoachFoodEstimateDebugSnapshot) {
        CoachFoodEstimateDebugLogger.log(snapshot)
    }

    private func hasWorkoutToday(from context: CoachContextPacketV2) -> Bool {
        if let healthIntelligence = context.healthIntelligence {
            return healthIntelligence.workoutCompletedToday
        }
        return (context.training?.workoutsToday ?? 0) > 0
    }

    private func resolvedHealthIntelligence(from context: CoachContextPacketV2) -> CoachHealthIntelligenceContext? {
        context.healthIntelligence
    }
}
