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
        if request.estimate.confidence == .high, request.userAskedToLog {
            return .executeImmediately
        }

        return .requiresConfirmation(
            "I estimated \(request.estimate.draft.name). Please confirm before I log it."
        )
    }

    static func decision(forWorkout draft: WorkoutDraft) -> ConfirmationDecision {
        .reject(TrainingIntegrationCopy.coachWorkoutMutationUnavailable)
    }

    static func decision(for food: FoodDraft) -> ConfirmationDecision {
        switch AIResponseValidator.validateFood(food, confidence: aiConfidence(from: food.confidence)) {
        case .valid, .requiresConfirmation:
            return .requiresConfirmation(CoachResponseBuilder.aiFoodPendingConfirmation)
        case .invalid(let message):
            return .reject(message.isEmpty ? CoachResponseBuilder.aiNotUnderstood : message)
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
        guard let draft = photoEstimate.foodDrafts.first else {
            return .reject(CoachResponseBuilder.aiNotUnderstood)
        }
        return decision(for: draft)
    }

    private static func aiConfidence(from level: ConfidenceLevel) -> AIConfidence {
        switch level {
        case .high: return .high
        case .medium: return .medium
        case .low: return .low
        }
    }
}
