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
        foodDraft: FoodDraft,
        confidence: AIConfidence
    ) -> CoachActionResult {
        let draft = AIFoodConfirmationDraft(
            originalText: originalText,
            assistantMessage: assistantMessage,
            foodDrafts: [foodDraft],
            confidence: confidence,
            requiresConfirmation: true
        )
        let message = CoachResponseBuilder.aiFoodEstimatePending(
            draft: foodDraft,
            confidence: confidence,
            originalText: originalText
        )
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
        _ request: LocalFoodEstimateRequest
    ) -> CoachActionResult {
        let confidence: AIConfidence = request.estimate.confidence == .high ? .high : .medium
        let draft = AIFoodConfirmationDraft(
            originalText: request.originalText,
            assistantMessage: request.estimate.explanation,
            foodDrafts: [request.estimate.draft],
            confidence: confidence,
            requiresConfirmation: true
        )
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
        executor: CoachMutationExecutor
    ) async -> CoachActionResult? {
        guard pendingConfirmation != nil else { return nil }

        let normalized = CommandParserUtilities.normalized(text)

        if rejectWords.contains(normalized) {
            return .message(CoachResponseBuilder.pendingRejected)
        }

        guard confirmWords.contains(normalized), let confirmation = pendingConfirmation else {
            return nil
        }

        let response = await executor.executePendingConfirmation(confirmation)
        return .message(response)
    }
}
