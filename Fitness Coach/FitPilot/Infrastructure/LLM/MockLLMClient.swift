//
//  MockLLMClient.swift
//  Fitness Coach
//
//  FitPilot AI — Minimal test/preview LLM double. Does not drive production routing.
//

import Foundation

final class MockLLMClient: LLMClient {

    init() {}

    func classifyCoachIntent(
        request: AICoachIntentClassificationRequest
    ) async throws -> AICoachIntentClassificationResponse {
        throw LLMClientError.backendUnavailable
    }

    func parseCommand(request: AIParseCommandRequest) async throws -> AIParseCommandResponse {
        throw LLMClientError.backendUnavailable
    }

    func estimateFood(request: AIFoodEstimateRequest) async throws -> AIFoodEstimateResponse {
        let draft = FoodDraft(
            mealType: nil,
            name: request.text,
            quantity: nil,
            unit: nil,
            calories: 500,
            protein: 25,
            carbs: 60,
            fat: 18,
            fiber: nil,
            sodium: nil,
            source: .aiTextEstimate,
            confidence: .medium,
            imageUrl: nil,
            notes: "Test estimate."
        )
        return AIFoodEstimateResponse(
            foodDrafts: [draft],
            confidence: .medium,
            requiresConfirmation: true,
            assistantMessage: "Test estimate — confirm before logging."
        )
    }

    func generateMealAdvice(request: AIMealAdviceRequest) async throws -> AIMealAdviceResponse {
        AIMealAdviceResponse(
            response: AICoachResponse(
                message: "Test meal advice response.",
                confidence: .medium
            )
        )
    }

    func generateDailyReview(request: AIDailyReviewRequest) async throws -> AIDailyReviewResponse {
        AIDailyReviewResponse(
            response: AICoachResponse(
                message: "Test daily review.",
                confidence: .medium
            )
        )
    }

    func parseWorkout(request: AIWorkoutParseRequest) async throws -> AIWorkoutParseResponse {
        AIWorkoutParseResponse(
            workoutDraft: WorkoutDraft(
                name: "Test workout",
                durationMinutes: 45,
                estimatedCaloriesBurned: 250,
                intensity: .moderate,
                recoveryDemand: .moderate,
                notes: nil,
                exerciseSets: []
            ),
            assistantMessage: "Parsed test workout. Confirm before logging.",
            confidence: .medium
        )
    }

    func parseEditOrDelete(request: AIEditDeleteParseRequest) async throws -> AIEditDeleteParseResponse {
        let command = AIParsedCommand(
            originalText: request.text,
            intent: .editEntry,
            actions: [
                AICommandAction(type: .editEntry, targetEntrySelector: request.text)
            ],
            confidence: .medium,
            requiresConfirmation: true,
            assistantMessage: "Confirm this change before applying it."
        )
        return AIEditDeleteParseResponse(parsedCommand: command)
    }

    func parseMultiAction(request: AIMultiActionParseRequest) async throws -> AIMultiActionParseResponse {
        let command = AIParsedCommand(
            originalText: request.text,
            intent: .multiAction,
            actions: [],
            confidence: .low,
            requiresConfirmation: true,
            assistantMessage: "This looks like multiple actions. Please confirm."
        )
        return AIMultiActionParseResponse(parsedCommand: command)
    }
}
