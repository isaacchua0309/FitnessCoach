//
//  CheapLLMIntentClassifier.swift
//  Fitness Coach
//
//  FitPilot AI — cheap-model intent classification for fuzzy Coach messages.
//

import Foundation

struct CheapLLMIntentClassifier: Sendable {
    private let aiService: AIServiceProtocol
    private let retryBackoffNanoseconds: UInt64

    init(aiService: AIServiceProtocol, retryBackoffNanoseconds: UInt64 = 300_000_000) {
        self.aiService = aiService
        self.retryBackoffNanoseconds = retryBackoffNanoseconds
    }

    func classify(
        text: String,
        context: AIContext,
        config: CoachModelConfig
    ) async throws -> CoachIntentResult {
        do {
            return try await aiService.classifyCoachIntent(text, context: context, config: config)
        } catch let error as AIServiceError where error.isTransientClassifierFailure {
            try await Task.sleep(nanoseconds: retryBackoffNanoseconds)
            return try await aiService.classifyCoachIntent(text, context: context, config: config)
        }
    }
}
