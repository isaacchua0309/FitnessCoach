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
        await logMockHit(operation: "classifyCoachIntent")
        throw LLMClientError.backendUnavailable
    }

    func parseCommand(request: AIParseCommandRequest) async throws -> AIParseCommandResponse {
        await logMockHit(operation: "parseCommand")
        throw LLMClientError.backendUnavailable
    }

    func estimateFood(request: AIFoodEstimateRequest) async throws -> AIFoodEstimateResponse {
        await logMockHit(operation: "estimateFood")
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
        await logMockHit(operation: "generateMealAdvice")
        return AIMealAdviceResponse(
            response: AICoachResponse(
                message: "Test meal advice response.",
                confidence: .medium
            )
        )
    }

    func generateNutritionEstimate(
        request: AINutritionEstimateRequest
    ) async throws -> AINutritionEstimateResponse {
        await logMockHit(operation: "generateNutritionEstimate")
        return AINutritionEstimateResponse(
            estimate: NutritionEstimateResponse(
                foodName: request.question,
                displayEmoji: "🍔",
                caloriesKcal: 550,
                proteinGrams: 25,
                carbsGrams: 45,
                fatGrams: 30,
                servingDescription: "1 standard serving",
                confidenceLevel: .medium,
                confidenceLabel: "Medium",
                coachSummary: "Estimated for your question.",
                coachTip: "Confirm portion size if unsure.",
                suggestedActions: [
                    NutritionSuggestedAction(title: "Log meal", type: .logMeal, payload: ["foodName": request.question]),
                    NutritionSuggestedAction(title: "Estimate another", type: .estimateAnother)
                ]
            )
        )
    }

    func generateNutritionComparison(
        request: AINutritionComparisonRequest
    ) async throws -> AINutritionComparisonResponse {
        await logMockHit(operation: "generateNutritionComparison")
        return AINutritionComparisonResponse(
            comparison: NutritionComparisonResponse(
                leftItem: NutritionComparisonItem(foodName: "Option A", caloriesKcal: 550, proteinGrams: 25, fatGrams: 30),
                rightItem: NutritionComparisonItem(foodName: "Option B", caloriesKcal: 540, proteinGrams: 27, fatGrams: 29),
                coachPick: "Calories are similar; pick based on preference."
            )
        )
    }

    func generateDailyReview(request: AIDailyReviewRequest) async throws -> AIDailyReviewResponse {
        await logMockHit(operation: "generateDailyReview")
        return AIDailyReviewResponse(
            review: DailyReviewAIResponse(
                statusSummary: "You are still within today's calorie target.",
                bestNextMove: "Add protein at your next meal.",
                tomorrowFocus: "Start hydration earlier tomorrow.",
                detailNote: "Solid pacing today."
            )
        )
    }

    func parseWorkout(request: AIWorkoutParseRequest) async throws -> AIWorkoutParseResponse {
        await logMockHit(operation: "parseWorkout")
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
        await logMockHit(operation: "parseEditOrDelete")
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
        await logMockHit(operation: "parseMultiAction")
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

    func analyzeMealImage(request: AIMealImageAnalysisRequest) async throws -> AIMealImageAnalysisResponse {
        await logMockHit(operation: "analyzeMealImage")
        return AIMealImageAnalysisResponse(
            summary: request.message ?? "Photo meal",
            items: [
                AIMealImageAnalysisItem(
                    name: "Photo meal",
                    quantity: "1 serving",
                    calories: 420,
                    protein: 28,
                    carbs: 35,
                    fat: 14,
                    confidence: .medium,
                    assumptions: ["Test photo estimate"]
                )
            ],
            total: AIMealImageAnalysisTotals(
                calories: 420,
                protein: 28,
                carbs: 35,
                fat: 14
            ),
            needsUserReview: true,
            clarifyingQuestion: nil
        )
    }

    @MainActor
    private func logMockHit(operation: String) {
        FormaPipelineTracer.event(
            stage: .mockLLM,
            level: .warn,
            message: "MockLLMClient invoked",
            fields: ["operation": operation]
        )
    }
}
