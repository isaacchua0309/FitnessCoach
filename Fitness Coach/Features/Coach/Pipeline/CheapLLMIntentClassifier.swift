//
//  CheapLLMIntentClassifier.swift
//  Fitness Coach
//
//  FitPilot AI — cheap-model intent classification for fuzzy Coach messages.
//

import Foundation

struct CheapLLMIntentClassifier: Sendable {
    private let aiService: AIServiceProtocol

    init(aiService: AIServiceProtocol) {
        self.aiService = aiService
    }

    func classify(
        text: String,
        context: AIContext,
        config: CoachModelConfig
    ) async throws -> CoachIntentResult {
        try await aiService.classifyCoachIntent(text, context: context, config: config)
    }
}
