//
//  CoachPendingConfirmationPresenter.swift
//  Fitness Coach
//
//  Pending confirmation presentation and text-based confirm/reject handling.
//

import Foundation

@MainActor
enum CoachPendingConfirmationPresenter {

    static let confirmWords = ["confirm", "yes", "yep", "log it", "save it", "do it"]
    private static let rejectWords = ["cancel", "no", "nope", "discard", "reject"]

    static func presentFoodPending(
        originalText: String,
        assistantMessage: String?,
        mealDraft: FoodLogDraft,
        confidence: AIConfidence,
        sanityWarning: String? = nil,
        fromPhotoAnalysis: Bool = false,
        sourceAttribution: CoachTimelineEventSourceAttribution? = nil,
        sanityFailed: Bool = false,
        requiresEditBeforeConfirm: Bool = false
    ) -> CoachActionResult {
        let draft = AIFoodConfirmationDraft(
            originalText: originalText,
            assistantMessage: assistantMessage,
            mealDraft: mealDraft,
            confidence: confidence,
            requiresConfirmation: true,
            sanityWarning: sanityWarning,
            requiresEditBeforeConfirm: requiresEditBeforeConfirm,
            sanityFailed: sanityFailed,
            sourceAttribution: sourceAttribution
        )
        let message = CoachResponseBuilder.aiFoodEstimatePending(
            mealDraft: mealDraft,
            confidence: confidence,
            originalText: originalText,
            sanityWarning: sanityWarning,
            fromPhotoAnalysis: fromPhotoAnalysis
        )
        logFoodEstimateTrustObservability(for: draft)
        return .pending(.food(draft), message: message)
    }

    static func presentWaterPending(
        _ draft: WaterDraft,
        assistantMessage: String?
    ) -> CoachActionResult {
        .pending(
            .water(draft, assistantMessage: assistantMessage),
            message: CoachResponseBuilder.waterPending(draft, assistantMessage: assistantMessage)
        )
    }

    static func presentWeightPending(
        _ draft: WeightDraft,
        assistantMessage: String?
    ) -> CoachActionResult {
        .pending(
            .weight(draft, assistantMessage: assistantMessage),
            message: CoachResponseBuilder.weightPending(draft, assistantMessage: assistantMessage)
        )
    }

    static func presentLocalFoodEstimatePending(
        _ request: LocalFoodEstimateRequest,
        sourceAttribution: CoachTimelineEventSourceAttribution = .localParser
    ) -> CoachActionResult {
        let confidence: AIConfidence = request.estimate.confidence == .high ? .high : .medium
        let mealDraft = FoodLogDraftMapper.fromLegacyDraft(request.estimate.draft)
        let sanity = NutritionSanityValidator.validate(
            meal: mealDraft,
            prompt: request.originalText,
            confidence: confidence
        )
        let trustGate = FoodEstimateTrustPolicy.confirmGate(
            sanityResult: sanity,
            userEditedBeforeConfirm: false
        )
        let draft = AIFoodConfirmationDraft(
            originalText: request.originalText,
            assistantMessage: request.estimate.explanation,
            mealDraft: sanity.mealDraft,
            confidence: sanity.confidence,
            requiresConfirmation: true,
            sanityWarning: sanity.isAcceptable ? nil : NutritionSanityResult.underEstimatedUserMessage,
            requiresEditBeforeConfirm: trustGate.requiresEditBeforeConfirm,
            sanityFailed: trustGate.sanityFailed,
            sourceAttribution: sourceAttribution
        )
        logFoodEstimateTrustObservability(for: draft)
        return .pending(
            .food(draft),
            message: CoachResponseBuilder.localFoodEstimatePending(
                request.estimate,
                originalText: request.originalText
            )
        )
    }

    static func presentMutationPending(
        _ confirmation: CoachPendingConfirmation,
        assistantMessage: String?,
        fallback: String
    ) -> CoachActionResult {
        .pending(
            confirmation,
            message: CoachResponseBuilder.mutationPending(
                assistantMessage: assistantMessage ?? fallback
            )
        )
    }

    /// Returns a response when the user confirms or rejects pending state; nil if input is unrelated.
    static func handleTextInput(
        _ text: String,
        pendingConfirmation: CoachPendingConfirmation?,
        executor: CoachMutationExecutor,
        timelineContext: CoachMutationTimelineContext = CoachMutationTimelineContext()
    ) async -> CoachActionResult? {
        guard pendingConfirmation != nil else { return nil }

        let normalized = CommandParserUtilities.normalized(text)

        if rejectWords.contains(normalized) {
            return .message(CoachResponseBuilder.pendingRejected)
        }

        guard confirmWords.contains(normalized), let confirmation = pendingConfirmation else {
            return nil
        }

        if case .food(let draft) = confirmation, draft.requiresEditBeforeConfirm {
            return .message(FoodEstimateTrustPolicy.editBeforeLoggingMessage)
        }

        let response = await executor.executePendingConfirmation(
            confirmation,
            timelineContext: timelineContext
        )
        return .message(response)
    }

    private static func logFoodEstimateTrustObservability(for draft: AIFoodConfirmationDraft) {
        CoachAccuracyObservabilityLogger.logFoodEstimateTrust(
            CoachFoodEstimateTrustObservabilitySnapshot.from(draft)
        )
    }
}
