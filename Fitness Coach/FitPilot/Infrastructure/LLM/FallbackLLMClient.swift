//
//  FallbackLLMClient.swift
//  Fitness Coach
//
//  FitPilot AI — Tries a real backend and falls back to a local mock.
//

import Foundation

final class FallbackLLMClient: LLMClient {

    private let primary: LLMClient
    private let fallback: LLMClient

    init(primary: LLMClient, fallback: LLMClient) {
        self.primary = primary
        self.fallback = fallback
    }

    func classifyCoachIntent(
        request: AICoachIntentClassificationRequest
    ) async throws -> AICoachIntentClassificationResponse {
        do {
            return try await primary.classifyCoachIntent(request: request)
        } catch {
            return try await fallback.classifyCoachIntent(request: request)
        }
    }

    func parseCommand(request: AIParseCommandRequest) async throws -> AIParseCommandResponse {
        do {
            return try await primary.parseCommand(request: request)
        } catch {
            return try await fallback.parseCommand(request: request)
        }
    }

    func estimateFood(request: AIFoodEstimateRequest) async throws -> AIFoodEstimateResponse {
        do {
            return try await primary.estimateFood(request: request)
        } catch {
            return try await fallback.estimateFood(request: request)
        }
    }

    func generateMealAdvice(request: AIMealAdviceRequest) async throws -> AIMealAdviceResponse {
        do {
            return try await primary.generateMealAdvice(request: request)
        } catch {
            return try await fallback.generateMealAdvice(request: request)
        }
    }

    func generateDailyReview(request: AIDailyReviewRequest) async throws -> AIDailyReviewResponse {
        do {
            return try await primary.generateDailyReview(request: request)
        } catch {
            return try await fallback.generateDailyReview(request: request)
        }
    }
}
