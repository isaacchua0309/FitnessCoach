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

    nonisolated init(localCommandParser: LocalCommandParser = .standard) {
        self.localCommandParser = localCommandParser
    }

    func evaluate(_ input: NormalizedCoachInput) -> LocalNoAPIRoute {
        if input.isEmpty {
            let route = LocalNoAPIRoute.noOp(.meaningless(CoachResponseBuilder.tryFitnessPrompt))
            traceGuardRoute(route, input: input, parserResult: "empty")
            return route
        }

        if input.isPunctuationOnly || input.isMeaninglessSingleToken {
            let route = LocalNoAPIRoute.noOp(.meaningless(CoachResponseBuilder.tryFitnessPrompt))
            traceGuardRoute(route, input: input, parserResult: "meaningless")
            return route
        }

        if isStandaloneGreeting(input) {
            let route = LocalNoAPIRoute.greeting(CoachResponseBuilder.greetingResponse)
            traceGuardRoute(route, input: input, parserResult: "greeting")
            return route
        }

        switch localCommandParser.parse(input.originalText) {
        case .success(let command):
            let route = LocalNoAPIRoute.deterministicCommand(command)
            traceGuardRoute(route, input: input, parserResult: "success")
            return route

        case .invalid(_, let reason):
            let route = LocalNoAPIRoute.clarification(reason)
            traceGuardRoute(route, input: input, parserResult: "invalid")
            return route

        case .ambiguous(_, let reason):
            let route = LocalNoAPIRoute.clarification(reason)
            traceGuardRoute(route, input: input, parserResult: "ambiguous")
            return route

        case .needsAI, .unsupported:
            let route = LocalNoAPIRoute.passToCheapLLM
            traceGuardRoute(route, input: input, parserResult: "needsAI")
            return route
        }
    }

    private func traceGuardRoute(
        _ route: LocalNoAPIRoute,
        input: NormalizedCoachInput,
        parserResult: String,
        foodConfidence: String? = nil
    ) {
        var fields: [String: String] = [
            "branch": guardBranchName(route),
            "parserResult": parserResult,
            "normalized": input.normalizedText
        ]
        if let foodConfidence {
            fields["foodConfidence"] = foodConfidence
        }
        FormaPipelineTracer.event(
            stage: .localGuard,
            level: .debug,
            message: "Local guard evaluated",
            fields: fields
        )
    }

    private func guardBranchName(_ route: LocalNoAPIRoute) -> String {
        switch route {
        case .noOp: return "noOp"
        case .greeting: return "greeting"
        case .deterministicCommand: return "deterministicCommand"
        case .localFoodEstimate: return "localFoodEstimate"
        case .clarification: return "clarification"
        case .passToCheapLLM: return "passToCheapLLM"
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
