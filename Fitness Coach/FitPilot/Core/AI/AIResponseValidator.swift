//
//  AIResponseValidator.swift
//  Fitness Coach
//
//  FitPilot AI — Validates AI output before it can reach services.
//
//  This validator never mutates state and never calls services. It only inspects
//  AI-produced drafts/commands and reports whether they are safe to execute,
//  require confirmation, or are invalid.
//

import Foundation

enum AIValidationResult: Equatable {
    case valid
    case requiresConfirmation(String)
    case invalid(String)
}

enum AIResponseValidator {

    /// Maximum millilitres allowed for a single water entry.
    static let maxSingleWaterMl = 5000

    // MARK: Parsed Command

    static func validate(_ command: AIParsedCommand) -> AIValidationResult {
        guard !command.actions.isEmpty else {
            // No actions is acceptable for advice/status/review intents.
            switch command.intent {
            case .mealAdvice, .status, .dailyReview, .casual, .unknown:
                return command.requiresConfirmation
                    ? .requiresConfirmation("Please confirm before continuing.")
                    : .valid
            default:
                return .invalid("The AI did not return any action to perform.")
            }
        }

        // Multiple actions always require explicit confirmation in this step.
        if command.actions.count > 1 {
            return .requiresConfirmation("This looks like multiple actions. Please confirm before logging.")
        }

        for action in command.actions {
            let result = validate(action: action, confidence: command.confidence)
            if result != .valid {
                return result
            }
        }

        if command.requiresConfirmation || command.confidence == .low {
            return .requiresConfirmation(
                command.assistantMessage ?? "Please confirm before logging."
            )
        }

        return .valid
    }

    // MARK: Action

    static func validate(action: AICommandAction, confidence: AIConfidence) -> AIValidationResult {
        switch action.type {
        case .logFood:
            guard let draft = action.foodDraft else {
                return .invalid("Missing food details.")
            }
            return validateFood(draft, confidence: confidence)

        case .logWater:
            guard let draft = action.waterDraft else {
                return .invalid("Missing water amount.")
            }
            return validateWater(draft)

        case .logWeight:
            guard let draft = action.weightDraft else {
                return .invalid("Missing weight value.")
            }
            return validateWeight(draft)

        case .logWorkout:
            guard let draft = action.workoutDraft else {
                return .invalid("Missing workout details.")
            }
            return validateWorkout(draft)

        case .startNewDay:
            if let weightKg = action.startNewDayWeightKg, weightKg <= 0 {
                return .invalid("Weight must be greater than zero.")
            }
            return .valid

        case .mealAdvice, .status, .dailyReview:
            return .valid
        case .editEntry, .deleteEntry, .undo:
            return .requiresConfirmation("Please confirm before changing existing entries.")
        }
    }

    // MARK: Draft Validation

    static func validateFood(_ draft: FoodDraft, confidence: AIConfidence) -> AIValidationResult {
        let trimmedName = draft.name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedName.isEmpty else {
            return .invalid("A food name is required.")
        }
        guard draft.calories >= 0 else {
            return .invalid("Calories cannot be negative.")
        }
        guard draft.protein >= 0, draft.carbs >= 0, draft.fat >= 0 else {
            return .invalid("Macros cannot be negative.")
        }

        // AI-estimated food always requires user confirmation before logging.
        return .requiresConfirmation(
            "This is an estimate and needs confirmation before logging."
        )
    }

    static func validateWater(_ draft: WaterDraft) -> AIValidationResult {
        guard draft.amountMl > 0 else {
            return .invalid("Water amount must be greater than zero.")
        }
        guard draft.amountMl <= maxSingleWaterMl else {
            return .invalid("That water amount looks too large for a single entry.")
        }
        return .valid
    }

    static func validateWeight(_ draft: WeightDraft) -> AIValidationResult {
        guard draft.weightKg > 0 else {
            return .invalid("Weight must be greater than zero.")
        }
        return .valid
    }

    static func validateWorkout(_ draft: WorkoutDraft) -> AIValidationResult {
        if let duration = draft.durationMinutes, duration <= 0 {
            return .invalid("Workout duration must be greater than zero.")
        }
        for set in draft.exerciseSets {
            if set.exerciseName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                return .invalid("Each exercise needs a name.")
            }
            if set.reps <= 0 {
                return .invalid("Exercise reps must be greater than zero.")
            }
        }
        // Workouts are always confirmed in this step since they are inferred.
        return .requiresConfirmation("Please confirm this workout before logging.")
    }
}
