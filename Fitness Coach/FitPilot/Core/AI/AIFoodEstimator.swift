//
//  AIFoodEstimator.swift
//  Fitness Coach
//
//  FitPilot AI — Estimates food drafts from free text.
//
//  Thin coordinator over the LLM client. It validates output and returns drafts
//  only; it never logs food or mutates state.
//

import Foundation

struct AIFoodEstimator {

    private let llmClient: LLMClient

    init(llmClient: LLMClient) {
        self.llmClient = llmClient
    }

    func estimateFood(from text: String, context: AIContext) async throws -> FoodDraft {
        let request = AIFoodEstimateRequest(text: text, context: context)

        let response: AIFoodEstimateResponse
        do {
            response = try await llmClient.estimateFood(request: request)
        } catch let error as LLMClientError {
            throw AICommandParser.map(error)
        } catch {
            throw AIServiceError.requestFailed(error.localizedDescription)
        }

        guard let draft = response.foodDrafts.first else {
            throw AIServiceError.invalidResponse("No food estimate was returned.")
        }

        if case .invalid(let reason) = AIResponseValidator.validateFood(draft, confidence: response.confidence) {
            throw AIServiceError.validationFailed(reason)
        }

        return draft
    }
}
