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

    nonisolated init() {}

    func route(
        intentResult: CoachIntentResult,
        originalText: String
    ) -> CoachRoute {
        let route: CoachRoute
        switch intentResult.intent {
        case .unrelatedOrUnsupported:
            route = .invalid(CoachResponseBuilder.unknownResponse)

        case .appHelp, .generalConversation:
            route = .noOp(.casual(CoachResponseBuilder.greetingResponse))

        case .dailySummary:
            route = .localCommand(ParsedCommand(intent: .status, originalText: originalText))

        case .logWater, .logWeight, .undo:
            if let command = parsedCommand(from: intentResult.action, originalText: originalText) {
                route = .localCommand(command)
            } else {
                route = .clarification(clarificationMessage(for: intentResult))
            }

        case .logFood:
            route = aiRoute(.estimateFood(originalText), intentResult: intentResult)

        case .logWorkout:
            route = .trainingLogRedirect

        case .editLog:
            route = aiRoute(.editEntry(originalText), intentResult: intentResult)

        case .deleteLog:
            route = aiRoute(.deleteEntry(originalText), intentResult: intentResult)

        case .calorieLookup, .macroLookup, .mealDecision, .nutritionAdvice:
            route = aiRoute(.mealAdvice(originalText), intentResult: intentResult)

        case .workoutAdvice, .weightLossAdvice:
            route = aiRoute(.mealAdvice(originalText), intentResult: intentResult)
        }

        traceRoute(route, intentResult: intentResult)
        return route
    }

    // MARK: - Helpers

    private func aiRoute(_ task: CoachAITask, intentResult: CoachIntentResult) -> CoachRoute {
        guard let tier = modelTier(for: intentResult, task: task) else {
            return .clarification(clarificationMessage(for: intentResult))
        }
        return .ai(RoutedAITask(task: task, tier: tier, intentResult: intentResult))
    }

    private func traceRoute(_ route: CoachRoute, intentResult: CoachIntentResult) {
        var fields: [String: String] = [
            "intent": intentResult.intent.rawValue,
            "requiresEscalation": String(intentResult.requiresEscalation),
            "canAnswerWithCheapModel": String(intentResult.canAnswerWithCheapModel),
            "route": routeName(route)
        ]
        if case .ai(let task) = route {
            fields["tier"] = task.tier.rawValue
            fields["task"] = aiTaskName(task.task)
        }
        FitPilotPipelineTracer.event(
            stage: .intentRoute,
            level: .debug,
            message: "Intent routed to handler",
            fields: fields
        )
    }

    private func routeName(_ route: CoachRoute) -> String {
        switch route {
        case .noOp: return "noOp"
        case .localCommand: return "localCommand"
        case .localFoodEstimate: return "localFoodEstimate"
        case .classifiedFood: return "classifiedFood"
        case .ai: return "ai"
        case .trainingLogRedirect: return "trainingLogRedirect"
        case .clarification: return "clarification"
        case .invalid: return "invalid"
        }
    }

    private func aiTaskName(_ task: CoachAITask) -> String {
        switch task {
        case .estimateFood: return "estimateFood"
        case .mealAdvice: return "mealAdvice"
        case .parseWorkout: return "parseWorkout"
        case .editEntry: return "editEntry"
        case .deleteEntry: return "deleteEntry"
        case .multiAction: return "multiAction"
        case .photoFoodAnalysis: return "photoFoodAnalysis"
        case .parseCommand: return "parseCommand"
        }
    }

    private func modelTier(for result: CoachIntentResult, task: CoachAITask) -> CoachModelTier? {
        if result.requiresEscalation { return .strong }

        switch task {
        case .estimateFood, .parseWorkout, .editEntry, .deleteEntry, .photoFoodAnalysis:
            // Dedicated mutation endpoints always run; classifier uncertainty means
            // "no inline draft", not "skip AI".
            return .cheap
        case .mealAdvice, .multiAction, .parseCommand:
            if result.canAnswerWithCheapModel { return .cheap }
            return nil
        }
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
