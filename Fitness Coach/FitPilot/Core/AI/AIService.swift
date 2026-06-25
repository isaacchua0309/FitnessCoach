//
//  AIService.swift
//  Fitness Coach
//
//  FitPilot AI — The AI boundary.
//
//  AIService parses, estimates, and explains. It returns structured drafts and
//  intents only. It does NOT import SwiftData, access ModelContext, call app
//  services (Food/Water/Weight/DailyLog/Workout), or own final arithmetic.
//  Validation and mutation happen elsewhere.
//

import Foundation

protocol AIServiceProtocol: Sendable {
    func parseCommand(_ text: String, context: AIContext) async throws -> AIParsedCommand
    func estimateFood(from text: String, context: AIContext) async throws -> FoodDraft
    func generateMealAdvice(request: MealAdviceAIRequest, context: AIContext) async throws -> AICoachResponse
    func generateDailyReviewText(input: DailyReviewAIInput, context: AIContext) async throws -> AICoachResponse
}

final class AIService: AIServiceProtocol {

    private let llmClient: LLMClient
    private let commandParser: AICommandParser
    private let foodEstimator: AIFoodEstimator

    init(llmClient: LLMClient) {
        self.llmClient = llmClient
        self.commandParser = AICommandParser(llmClient: llmClient)
        self.foodEstimator = AIFoodEstimator(llmClient: llmClient)
    }

    func parseCommand(_ text: String, context: AIContext) async throws -> AIParsedCommand {
        try await commandParser.parseCommand(text, context: context)
    }

    func estimateFood(from text: String, context: AIContext) async throws -> FoodDraft {
        try await foodEstimator.estimateFood(from: text, context: context)
    }

    func generateMealAdvice(
        request: MealAdviceAIRequest,
        context: AIContext
    ) async throws -> AICoachResponse {
        let llmRequest = AIMealAdviceRequest(question: request.question, context: context)
        do {
            return try await llmClient.generateMealAdvice(request: llmRequest).response
        } catch let error as LLMClientError {
            throw AICommandParser.map(error)
        } catch {
            throw AIServiceError.requestFailed(error.localizedDescription)
        }
    }

    func generateDailyReviewText(
        input: DailyReviewAIInput,
        context: AIContext
    ) async throws -> AICoachResponse {
        let llmRequest = AIDailyReviewRequest(input: input, context: context)
        do {
            return try await llmClient.generateDailyReview(request: llmRequest).response
        } catch let error as LLMClientError {
            throw AICommandParser.map(error)
        } catch {
            throw AIServiceError.requestFailed(error.localizedDescription)
        }
    }
}
