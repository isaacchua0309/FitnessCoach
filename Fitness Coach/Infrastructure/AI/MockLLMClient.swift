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
        logMockHit(operation: "classifyCoachIntent")
        throw LLMClientError.backendUnavailable
    }

    func parseCommand(request: AIParseCommandRequest) async throws -> AIParseCommandResponse {
        logMockHit(operation: "parseCommand")
        throw LLMClientError.backendUnavailable
    }

    func estimateFood(request: AIFoodEstimateRequest) async throws -> AIFoodEstimateResponse {
        logMockHit(operation: "estimateFood")
        let isPhoto = request.imageJPEGBase64?.isEmpty == false
        return AIFoodEstimateResponse(
            foodLogDrafts: [
                FoodLogDraft(
                    displayName: isPhoto ? "Photo meal" : request.text,
                    components: [
                        FoodComponent(
                            name: isPhoto ? "Photo meal" : request.text,
                            calories: 500,
                            protein: 25,
                            carbs: 60,
                            fat: 18,
                            confidence: .medium,
                            sourceText: isPhoto ? "Photo estimate." : request.text
                        )
                    ],
                    confidence: .medium,
                    source: isPhoto ? .aiPhotoEstimate : .aiTextEstimate,
                    notes: isPhoto ? "Photo estimate." : "Test estimate."
                )
            ],
            confidence: .medium,
            requiresConfirmation: true,
            assistantMessage: "Test estimate — confirm before logging."
        )
    }

    func generateMealAdvice(request: AIMealAdviceRequest) async throws -> AIMealAdviceResponse {
        logMockHit(operation: "generateMealAdvice")
        return AIMealAdviceResponse(
            response: AICoachResponse(
                message: "Test meal advice response.",
                confidence: .medium
            )
        )
    }

    func generateDailyReview(request: AIDailyReviewRequest) async throws -> AIDailyReviewResponse {
        logMockHit(operation: "generateDailyReview")
        return AIDailyReviewResponse(
            response: AICoachResponse(
                message: "Test daily review.",
                confidence: .medium
            )
        )
    }

    func parseWorkout(request: AIWorkoutParseRequest) async throws -> AIWorkoutParseResponse {
        logMockHit(operation: "parseWorkout")
        return AIWorkoutParseResponse(
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
        logMockHit(operation: "parseEditOrDelete")
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
        logMockHit(operation: "parseMultiAction")
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

    private func logMockHit(operation: String) {
        FormaPipelineTracer.event(
            stage: .mockLLM,
            level: .warn,
            message: "MockLLMClient invoked",
            fields: ["operation": operation]
        )
    }
}
