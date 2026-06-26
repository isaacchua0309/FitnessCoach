//
//  LocalNoAPIGuard.swift
//  Fitness Coach
//
//  FitPilot AI — narrow deterministic local guard (no fuzzy NL classification).
//

import Foundation

enum LocalNoAPIRoute: Equatable, Sendable {
    case noOp(NoOpResponse)
    case greeting(String)
    case deterministicCommand(ParsedCommand)
    case localFoodEstimate(LocalFoodEstimateRequest)
    case clarification(String)
    case passToCheapLLM
}

struct LocalNoAPIGuard: Sendable {
    private let localCommandParser: LocalCommandParser
    private let nutritionEstimator: LocalNutritionEstimator

    init(
        localCommandParser: LocalCommandParser = .standard,
        nutritionEstimator: LocalNutritionEstimator = .standard
    ) {
        self.localCommandParser = localCommandParser
        self.nutritionEstimator = nutritionEstimator
    }

    func evaluate(_ input: NormalizedCoachInput) -> LocalNoAPIRoute {
        if input.isEmpty {
            return .noOp(.meaningless(CoachResponseBuilder.tryFitnessPrompt))
        }

        if input.isPunctuationOnly || input.isMeaninglessSingleToken {
            return .noOp(.meaningless(CoachResponseBuilder.tryFitnessPrompt))
        }

        if isStandaloneGreeting(input) {
            return .greeting(CoachResponseBuilder.greetingResponse)
        }

        switch localCommandParser.parse(input.originalText) {
        case .success(let command):
            return .deterministicCommand(command)

        case .invalid(_, let reason):
            return .clarification(reason)

        case .ambiguous(_, let reason):
            return .clarification(reason)

        case .needsAI, .unsupported:
            if let estimate = nutritionEstimator.estimate(input),
               estimate.confidence == .high {
                return .localFoodEstimate(
                    LocalFoodEstimateRequest(
                        estimate: estimate,
                        originalText: input.originalText,
                        userAskedToLog: nutritionEstimator.userAskedToLog(input)
                    )
                )
            }
            return .passToCheapLLM
        }
    }

    private func isStandaloneGreeting(_ input: NormalizedCoachInput) -> Bool {
        let greetings = [
            "hi", "hello", "hey", "hiya", "yo", "thanks", "thank you", "thx",
            "ok", "okay", "cheers", "good morning", "good afternoon", "good evening"
        ]
        guard input.tokens.count <= 3 else { return false }
        let text = input.routingText
        return greetings.contains(text)
    }
}
