//
//  ConfirmationPolicy.swift
//  Fitness Coach
//
//  FitPilot AI — central confirmation rules for Coach actions.
//

import Foundation

enum ConfirmationDecision: Equatable, Sendable {
    case executeImmediately
    case requiresConfirmation(String)
    case requiresClarificationBeforePending(String)
    case reject(String)
}

enum FoodConfirmationPresentation: Equatable, Sendable {
    case clarifyFirst(String)
    case pending(FoodLogDraft, AIConfidence)
    case reject(String)
}

enum ConfirmationPolicy {
    static func decision(for command: ParsedCommand) -> ConfirmationDecision {
        switch command.intent {
        case .logWater, .logWeight, .logFood, .status, .dailyReview, .undo, .logSteps:
            return .executeImmediately
        case .unsupported, .needsAI:
            return .reject(CoachResponseBuilder.unsupportedResponse)
        }
    }

    static func decision(for request: LocalFoodEstimateRequest) -> ConfirmationDecision {
        .requiresConfirmation(
            CoachResponseBuilder.localFoodEstimatePending(
                request.estimate,
                originalText: request.originalText
            )
        )
    }

    static func decision(for food: FoodDraft) -> ConfirmationDecision {
        decision(for: FoodLogDraftMapper.fromLegacyDraft(food))
    }

    static func decision(for meal: FoodLogDraft) -> ConfirmationDecision {
        switch AIResponseValidator.validateFood(meal, confidence: aiConfidence(from: meal.confidence)) {
        case .valid, .requiresConfirmation:
            return .requiresConfirmation(CoachResponseBuilder.aiFoodPendingConfirmation)
        case .invalid(let message):
            return .reject(message.isEmpty ? CoachResponseBuilder.aiNotUnderstood : message)
        }
    }

    /// Applies ambiguity policy, then structural validation, for AI food pending cards.
    static func foodPresentation(
        meal: FoodLogDraft,
        prompt: String,
        confidence: AIConfidence,
        fromPhotoAnalysis: Bool = false,
        clarifyingQuestion: String? = nil,
        photoNeedsUserReview: Bool = false
    ) -> FoodConfirmationPresentation {
        let ambiguityInput = CoachFoodAmbiguityPostEstimateInput(
            prompt: prompt,
            meal: meal,
            confidence: confidence,
            fromPhotoAnalysis: fromPhotoAnalysis,
            clarifyingQuestion: clarifyingQuestion,
            photoNeedsUserReview: photoNeedsUserReview
        )

        switch CoachFoodAmbiguityPolicy.postEstimateOutcome(input: ambiguityInput) {
        case .clarifyFirst(let question):
            return .clarifyFirst(question)
        case .proceedAmbiguous(let adjustedMeal, let adjustedConfidence):
            switch AIResponseValidator.validateFood(adjustedMeal, confidence: adjustedConfidence) {
            case .valid, .requiresConfirmation:
                return .pending(adjustedMeal, adjustedConfidence)
            case .invalid(let message):
                return .reject(message.isEmpty ? CoachResponseBuilder.aiNotUnderstood : message)
            }
        case .proceed:
            switch AIResponseValidator.validateFood(meal, confidence: confidence) {
            case .valid, .requiresConfirmation:
                return .pending(meal, confidence)
            case .invalid(let message):
                return .reject(message.isEmpty ? CoachResponseBuilder.aiNotUnderstood : message)
            }
        }
    }

    static func decision(for parsed: AIParsedCommand) -> ConfirmationDecision {
        switch AIResponseValidator.validate(parsed) {
        case .valid:
            if parsed.actions.count == 1, let action = parsed.actions.first {
                return decision(for: action)
            }
            return .executeImmediately
        case .requiresConfirmation(let message):
            return .requiresConfirmation(message)
        case .invalid(let message):
            return .reject(message)
        }
    }

    static func decision(for action: AICommandAction) -> ConfirmationDecision {
        switch action.type {
        case .logFood:
            guard let draft = action.foodDraft else {
                return .reject("Missing food details.")
            }
            return decision(for: draft)
        case .logWorkout:
            return .reject(TrainingIntegrationCopy.coachWorkoutMutationUnavailable)
        case .editEntry, .deleteEntry, .undo:
            return .requiresConfirmation("Please confirm before changing existing entries.")
        case .logWater, .logWeight:
            return .executeImmediately
        case .mealAdvice, .status, .dailyReview, .startNewDay:
            return .executeImmediately
        }
    }

    static func decision(for photoEstimate: AIFoodEstimateResponse) -> ConfirmationDecision {
        guard let meal = FoodLogDraftMapper.primaryMeal(from: photoEstimate) else {
            return .reject(CoachResponseBuilder.aiNotUnderstood)
        }
        return decision(for: meal)
    }

    private static func aiConfidence(from level: ConfidenceLevel) -> AIConfidence {
        switch level {
        case .high: return .high
        case .medium: return .medium
        case .low: return .low
        }
    }
}
