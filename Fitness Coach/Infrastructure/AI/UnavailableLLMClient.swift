//
//  UnavailableLLMClient.swift
//  Fitness Coach
//
//  Deliberate no-op LLM client for Release when no production backend is configured.
//  Fails fast without contacting localhost or returning mock answers.
//

import Foundation
import OSLog

enum UnavailableLLMReason: Equatable, Sendable {
    case releaseBackendNotConfigured
    case releaseBackendURLRejectedLocalhost
}

final class UnavailableLLMClient: LLMClient, @unchecked Sendable {

    private let reason: UnavailableLLMReason
    private let logger = Logger(subsystem: "FitPilot", category: "UnavailableLLM")

    init(reason: UnavailableLLMReason) {
        self.reason = reason
        logger.error("LLM client unavailable at startup: \(reason.logMessage, privacy: .public)")
    }

    func classifyCoachIntent(
        request: AICoachIntentClassificationRequest
    ) async throws -> AICoachIntentClassificationResponse {
        try unavailable(operation: "classifyCoachIntent")
    }

    func parseCommand(request: AIParseCommandRequest) async throws -> AIParseCommandResponse {
        try unavailable(operation: "parseCommand")
    }

    func estimateFood(request: AIFoodEstimateRequest) async throws -> AIFoodEstimateResponse {
        try unavailable(operation: "estimateFood")
    }

    func generateMealAdvice(request: AIMealAdviceRequest) async throws -> AIMealAdviceResponse {
        try unavailable(operation: "generateMealAdvice")
    }

    func generateDailyReview(request: AIDailyReviewRequest) async throws -> AIDailyReviewResponse {
        try unavailable(operation: "generateDailyReview")
    }

    func parseWorkout(request: AIWorkoutParseRequest) async throws -> AIWorkoutParseResponse {
        try unavailable(operation: "parseWorkout")
    }

    func parseEditOrDelete(request: AIEditDeleteParseRequest) async throws -> AIEditDeleteParseResponse {
        try unavailable(operation: "parseEditOrDelete")
    }

    func parseMultiAction(request: AIMultiActionParseRequest) async throws -> AIMultiActionParseResponse {
        try unavailable(operation: "parseMultiAction")
    }

    private func unavailable(operation: String) throws -> Never {
        logger.info(
            "LLM call blocked (\(operation, privacy: .public)): \(self.reason.logMessage, privacy: .public)"
        )
        throw LLMClientError.missingConfiguration
    }
}

private extension UnavailableLLMReason {
    var logMessage: String {
        switch self {
        case .releaseBackendNotConfigured:
            return "FORMA_AI_BACKEND_URL is not set for Release."
        case .releaseBackendURLRejectedLocalhost:
            return "FORMA_AI_BACKEND_URL points at localhost, which Release builds reject."
        }
    }
}
