//
//  FallbackLLMClient.swift
//  Fitness Coach
//
//  FitPilot AI — Primary backend client with graceful failure (no mock answers).
//

import Foundation
import OSLog

final class FallbackLLMClient: LLMClient {

    private let primary: LLMClient
    private let logger = Logger(subsystem: "FitPilot", category: "LLMFallback")

    init(primary: LLMClient) {
        self.primary = primary
    }

    func classifyCoachIntent(
        request: AICoachIntentClassificationRequest
    ) async throws -> AICoachIntentClassificationResponse {
        try await perform(operation: "classifyCoachIntent") {
            try await primary.classifyCoachIntent(request: request)
        }
    }

    func parseCommand(request: AIParseCommandRequest) async throws -> AIParseCommandResponse {
        try await perform(operation: "parseCommand") {
            try await primary.parseCommand(request: request)
        }
    }

    func estimateFood(request: AIFoodEstimateRequest) async throws -> AIFoodEstimateResponse {
        try await perform(operation: "estimateFood") {
            try await primary.estimateFood(request: request)
        }
    }

    func generateMealAdvice(request: AIMealAdviceRequest) async throws -> AIMealAdviceResponse {
        try await perform(operation: "generateMealAdvice") {
            try await primary.generateMealAdvice(request: request)
        }
    }

    func generateDailyReview(request: AIDailyReviewRequest) async throws -> AIDailyReviewResponse {
        try await perform(operation: "generateDailyReview") {
            try await primary.generateDailyReview(request: request)
        }
    }

    func parseWorkout(request: AIWorkoutParseRequest) async throws -> AIWorkoutParseResponse {
        try await perform(operation: "parseWorkout") {
            try await primary.parseWorkout(request: request)
        }
    }

    func parseEditOrDelete(request: AIEditDeleteParseRequest) async throws -> AIEditDeleteParseResponse {
        try await perform(operation: "parseEditOrDelete") {
            try await primary.parseEditOrDelete(request: request)
        }
    }

    func parseMultiAction(request: AIMultiActionParseRequest) async throws -> AIMultiActionParseResponse {
        try await perform(operation: "parseMultiAction") {
            try await primary.parseMultiAction(request: request)
        }
    }

    private func perform<Output>(
        operation: String,
        primary work: () async throws -> Output
    ) async throws -> Output {
        do {
            return try await work()
        } catch let error as LLMClientError where error == .authenticationFailed {
            throw error
        } catch {
            logger.info("LLM backend unavailable for \(operation, privacy: .public).")
            throw LLMClientError.backendUnavailable
        }
    }
}
