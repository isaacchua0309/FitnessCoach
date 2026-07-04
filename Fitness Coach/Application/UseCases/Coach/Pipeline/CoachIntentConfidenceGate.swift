//
//  CoachIntentConfidenceGate.swift
//  Fitness Coach
//
//  FitPilot AI — confidence thresholds before routing classifier mutations.
//

import Foundation

enum CoachIntentConfidenceDecision: Equatable, Sendable {
    case proceed(CoachIntentResult)
    case clarify(String)
}

enum CoachIntentConfidenceGate {
    static let highThreshold = 0.70
    static let mediumThreshold = 0.45

    static func evaluate(_ result: CoachIntentResult) -> CoachIntentConfidenceDecision {
        let result = normalizedForRouting(result)

        if result.confidence >= highThreshold {
            return .proceed(result)
        }

        if isHarmlessNonMutation(result) {
            return .proceed(result)
        }

        if result.confidence >= mediumThreshold {
            if shouldClarifyMediumConfidenceMutation(result) {
                traceConfidenceGate(
                    result: result,
                    branch: "medium_clarify",
                    message: CoachResponseBuilder.lowConfidenceClarification
                )
                return .clarify(CoachResponseBuilder.lowConfidenceClarification)
            }
            return .proceed(result)
        }

        if shouldClarifyLowConfidenceMutation(result) {
            traceConfidenceGate(
                result: result,
                branch: "low_mutation_blocked",
                message: CoachResponseBuilder.unsupportedScopeResponse
            )
            return .clarify(CoachResponseBuilder.lowConfidenceClarification)
        }

        if result.intent == .unrelatedOrUnsupported {
            return .clarify(CoachResponseBuilder.unsupportedScopeResponse)
        }

        return .proceed(result)
    }

    static func sanitizedResult(_ result: CoachIntentResult) -> CoachIntentResult {
        switch evaluate(result) {
        case .proceed(let sanitized):
            return sanitized
        case .clarify:
            return strippedMutationResult(from: result)
        }
    }

    private static func strippedMutationResult(from result: CoachIntentResult) -> CoachIntentResult {
        var copy = result
        copy.action = nil
        copy.requiresAppMutation = false
        return copy
    }

    private static func isHarmlessNonMutation(_ result: CoachIntentResult) -> Bool {
        guard !result.requiresAppMutation else { return false }
        switch result.intent {
        case .generalConversation, .appHelp, .calorieLookup, .macroLookup,
             .mealDecision, .nutritionEstimateQuery, .nutritionComparisonQuery,
             .nutritionAdvice, .workoutAdvice, .weightLossAdvice,
             .dailySummary:
            return true
        default:
            return result.action == nil
        }
    }

    private static func normalizedForRouting(_ result: CoachIntentResult) -> CoachIntentResult {
        guard !result.requiresAppMutation, shouldIgnoreAction(for: result.intent) else {
            return result
        }
        guard result.action != nil else { return result }
        var copy = result
        copy.action = nil
        return copy
    }

    private static func shouldIgnoreAction(for intent: CoachIntent) -> Bool {
        switch intent {
        case .generalConversation, .appHelp, .calorieLookup, .macroLookup,
             .mealDecision, .nutritionAdvice, .workoutAdvice, .weightLossAdvice,
             .dailySummary:
            return true
        default:
            return false
        }
    }

    /// Mutations that always run through a dedicated AI step plus confirmation before persisting.
    private static func defersMutationToDedicatedPipeline(_ intent: CoachIntent) -> Bool {
        switch intent {
        case .logFood, .logWorkout:
            return true
        default:
            return false
        }
    }

    private static func shouldClarifyMediumConfidenceMutation(_ result: CoachIntentResult) -> Bool {
        guard !defersMutationToDedicatedPipeline(result.intent) else { return false }
        return result.requiresAppMutation || result.action != nil
    }

    private static func shouldClarifyLowConfidenceMutation(_ result: CoachIntentResult) -> Bool {
        guard !defersMutationToDedicatedPipeline(result.intent) else { return false }
        return result.requiresAppMutation || result.action != nil
    }

    private static func traceConfidenceGate(
        result: CoachIntentResult,
        branch: String,
        message: String
    ) {
        FormaPipelineTracer.event(
            stage: .classify,
            level: .debug,
            message: "Classifier confidence gate",
            fields: [
                "branch": branch,
                "confidence": String(format: "%.2f", result.confidence),
                "intent": result.intent.rawValue,
                "hasAction": String(result.action != nil)
            ]
        )
    }
}
