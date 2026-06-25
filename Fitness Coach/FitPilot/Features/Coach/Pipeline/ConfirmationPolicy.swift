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
        case .logWater, .logWeight, .logFood, .status, .dailyReview:
            return .executeImmediately
        case .undo:
            return .executeImmediately
        case .logSteps:
            return .executeImmediately
        case .unsupported, .needsAI:
            return .reject(CoachResponseBuilder.unsupportedResponse)
        }
    }

    static func decision(for request: LocalFoodEstimateRequest) -> ConfirmationDecision {
        if request.estimate.confidence == .high, request.userAskedToLog {
            return .executeImmediately
        }

        let message = """
        I estimated \(request.estimate.foodDraft.name). Please confirm before I log it.
        """
        return .requiresConfirmation(message)
    }

    static func decision(for command: AIParsedCommand) -> ConfirmationDecision {
        switch AIResponseValidator.validate(command) {
        case .valid:
            return .executeImmediately
        case .requiresConfirmation(let message):
            return .requiresConfirmation(message)
        case .invalid(let message):
            return .reject(message)
        }
    }
}
