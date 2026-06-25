//
//  LLMClient.swift
//  Fitness Coach
//
//  FitPilot AI — Boundary to the AI backend gateway.
//
//  The iOS app talks to a FitPilot backend AI gateway through this protocol.
//  The backend (added later) calls the actual LLM provider, so no provider API
//  keys live in the app. This protocol knows nothing about SwiftUI or SwiftData.
//

import Foundation

protocol LLMClient: Sendable {
    func parseCommand(request: AIParseCommandRequest) async throws -> AIParseCommandResponse
    func estimateFood(request: AIFoodEstimateRequest) async throws -> AIFoodEstimateResponse
    func generateMealAdvice(request: AIMealAdviceRequest) async throws -> AIMealAdviceResponse
    func generateDailyReview(request: AIDailyReviewRequest) async throws -> AIDailyReviewResponse
}
