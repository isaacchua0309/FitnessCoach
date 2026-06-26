//
//  CoachIntentRouter.swift
//  Fitness Coach
//
//  FitPilot AI — maps cheap-LLM CoachIntentResult to CoachRoute (no keyword hacks).
//

import Foundation

enum CoachRouteSource: String, Equatable, Sendable {
    case localGuard
    case cheapClassifier
}

struct RoutedAITask: Equatable, Sendable {
    var task: CoachAITask
    var tier: CoachModelTier
    var intentResult: CoachIntentResult
}

struct CoachIntentRouter: Sendable {

    func route(
        intentResult: CoachIntentResult,
        originalText: String
    ) -> CoachRoute {
        switch intentResult.intent {
        case .unrelatedOrUnsupported:
            return .invalid(CoachResponseBuilder.unknownResponse)

        case .appHelp, .generalConversation:
            return .noOp(.casual(CoachResponseBuilder.greetingResponse))

        case .dailySummary:
            return .localCommand(ParsedCommand(intent: .status, originalText: originalText))

        case .logWater, .logWeight, .undo:
            if let command = parsedCommand(from: intentResult.action, originalText: originalText) {
                return .localCommand(command)
            }
            return .clarification(clarificationMessage(for: intentResult))

        case .logFood:
            if case .logFood(let draft) = intentResult.action {
                return .classifiedFood(draft, originalText: originalText, intentResult: intentResult)
            }
            return aiRoute(.estimateFood(originalText), intentResult: intentResult)

        case .logWorkout:
            return aiRoute(.parseWorkout(originalText), intentResult: intentResult)

        case .editLog:
            return aiRoute(.editEntry(originalText), intentResult: intentResult)

        case .deleteLog:
            return aiRoute(.deleteEntry(originalText), intentResult: intentResult)

        case .calorieLookup, .macroLookup, .mealDecision, .nutritionAdvice:
            return aiRoute(.mealAdvice(originalText), intentResult: intentResult)

        case .workoutAdvice, .weightLossAdvice:
            return aiRoute(.mealAdvice(originalText), intentResult: intentResult)
        }
    }

    // MARK: - Helpers

    private func aiRoute(_ task: CoachAITask, intentResult: CoachIntentResult) -> CoachRoute {
        guard let tier = modelTier(for: intentResult) else {
            return .clarification(clarificationMessage(for: intentResult))
        }
        return .ai(RoutedAITask(task: task, tier: tier, intentResult: intentResult))
    }

    private func modelTier(for result: CoachIntentResult) -> CoachModelTier? {
        if result.requiresEscalation { return .strong }
        if result.canAnswerWithCheapModel { return .cheap }
        return nil
    }

    private func clarificationMessage(for result: CoachIntentResult) -> String {
        result.reason ?? "I need a little more detail before I can help."
    }

    private func parsedCommand(from action: CoachAction?, originalText: String) -> ParsedCommand? {
        guard let action else { return nil }
        switch action {
        case .logWater(let draft):
            return ParsedCommand(intent: .logWater(draft), originalText: originalText)
        case .logWeight(let draft):
            return ParsedCommand(intent: .logWeight(draft), originalText: originalText)
        case .undo(let target):
            return ParsedCommand(intent: .undo(target: target), originalText: originalText)
        case .status:
            return ParsedCommand(intent: .status, originalText: originalText)
        case .dailyReview:
            return ParsedCommand(intent: .dailyReview, originalText: originalText)
        case .logFood, .logWorkout, .editLog, .deleteLog:
            return nil
        }
    }
}
