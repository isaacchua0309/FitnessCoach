//
//  CoachModelTimelineSupport.swift
//  Fitness Coach
//
//  Maps CoachModel actions to CoachTimelineRecording payloads and attributions.
//

import Foundation

enum CoachModelTimelineSupport {

    static func timelineAttribution(for decision: CoachRouteDecision) -> CoachTimelineEventSourceAttribution {
        switch decision.chosenHandler {
        case "local_food_estimate":
            return .localParser
        case "classified_food":
            return .classifier
        case "ai_estimate_food":
            return .estimateFood
        case "ai_photo_food":
            return .mealImage
        case "ai_edit_entry", "ai_delete_entry", "ai_multi_action", "ai_parse_command",
             "cheap_meal_advice", "strong_meal_advice",
             "cheap_nutrition_estimate", "strong_nutrition_estimate",
             "cheap_nutrition_comparison", "strong_nutrition_comparison":
            return .classifier
        case "local_command":
            return .localParser
        default:
            return decision.requiresAPI ? .classifier : .localParser
        }
    }

    static func assistantAttribution(
        for decision: CoachRouteDecision?
    ) -> CoachTimelineEventSourceAttribution {
        guard let decision else { return .localParser }
        return timelineAttribution(for: decision)
    }

    static func confirmationPayload(
        from confirmation: CoachPendingConfirmation,
        userInputMethod: String? = nil
    ) -> ConfirmationPayload {
        switch confirmation {
        case .food(let draft):
            return ConfirmationPayload(
                kind: "food",
                originalText: draft.originalText,
                assistantMessagePreview: draft.assistantMessage,
                pendingConfirmationId: draft.id,
                relatedPhotoSessionId: draft.imageAnalysisSessionID,
                userInputMethod: userInputMethod
            )
        case .water(let draft, let assistantMessage):
            return ConfirmationPayload(
                kind: "water",
                originalText: "\(draft.amountMl) ml water",
                assistantMessagePreview: assistantMessage,
                userInputMethod: userInputMethod
            )
        case .weight(let draft, let assistantMessage):
            return ConfirmationPayload(
                kind: "weight",
                originalText: String(format: "%.2f kg", draft.weightKg),
                assistantMessagePreview: assistantMessage,
                userInputMethod: userInputMethod
            )
        case .edit(let action, let originalText, let assistantMessage):
            return ConfirmationPayload(
                kind: "edit",
                originalText: originalText,
                assistantMessagePreview: assistantMessage,
                linkedEntryId: action.linkedEntryId,
                relatedTimelineEventId: action.linkedTimelineEventId,
                userInputMethod: userInputMethod
            )
        case .delete(let action, let originalText, let assistantMessage):
            return ConfirmationPayload(
                kind: "delete",
                originalText: originalText,
                assistantMessagePreview: assistantMessage,
                linkedEntryId: action.linkedEntryId,
                relatedTimelineEventId: action.linkedTimelineEventId,
                userInputMethod: userInputMethod
            )
        case .undo(_, let originalText, let assistantMessage):
            return ConfirmationPayload(
                kind: "undo",
                originalText: originalText,
                assistantMessagePreview: assistantMessage,
                userInputMethod: userInputMethod
            )
        }
    }

    static func foodEstimatePayload(from draft: AIFoodConfirmationDraft) -> FoodEstimatePayload {
        let meal = draft.primaryMealDraft
        return FoodEstimatePayload(
            estimateId: draft.id,
            mealName: meal.displayName,
            mealType: meal.mealType?.rawValue,
            calories: meal.hasUsableNutritionEstimate ? meal.totalCalories : nil,
            proteinGrams: meal.hasUsableNutritionEstimate ? meal.totalProtein : nil,
            requiresConfirmation: draft.requiresConfirmation
        )
    }

    static func backendErrorCategory(for error: AIServiceError) -> String {
        switch error {
        case .authenticationFailed:
            return "authentication"
        case .requestTimedOut:
            return "timeout"
        case .networkUnavailable:
            return "network_unavailable"
        case .payloadTooLarge:
            return "payload_too_large"
        case .modelUnavailable:
            return "model_unavailable"
        case .backendUnavailable, .requestFailed:
            return "backend_unavailable"
        case .invalidNutritionJSON, .parsingFailed, .backendRejectedImage:
            return "nutrition_extraction"
        case .imageEncodingFailed:
            return "image_encoding"
        case .invalidResponse, .decodingFailed, .validationFailed:
            return "validation"
        case .featureDisabled:
            return "feature_disabled"
        }
    }

    static func isRetryableBackendError(_ error: AIServiceError) -> Bool {
        error.isTransientClassifierFailure
    }
}
