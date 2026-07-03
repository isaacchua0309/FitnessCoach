//
//  AIServiceNutritionEstimateTestStubs.swift
//  Fitness CoachTests
//
//  Default AIServiceProtocol stubs for nutrition estimate endpoints in test doubles.
//

import Foundation
@testable import Fitness_Coach

extension AIServiceProtocol {

    func generateNutritionEstimate(
        prompt: String,
        context: AIContext,
        intentResult: CoachIntentResult?,
        tier: CoachModelTier
    ) async throws -> NutritionEstimateResponse {
        NutritionEstimateResponse(
            foodName: prompt,
            caloriesKcal: 500,
            proteinGrams: 25,
            carbsGrams: 45,
            fatGrams: 20,
            confidenceLevel: .medium,
            coachSummary: "Stub estimate.",
            coachTip: "Stub tip.",
            suggestedActions: [
                NutritionSuggestedAction(title: "Log meal", type: .logMeal, payload: ["foodName": prompt])
            ]
        )
    }

    func generateNutritionComparison(
        prompt: String,
        context: AIContext,
        intentResult: CoachIntentResult?,
        tier: CoachModelTier
    ) async throws -> NutritionComparisonResponse {
        NutritionComparisonResponse(
            leftItem: NutritionComparisonItem(foodName: "Option A", caloriesKcal: 500, proteinGrams: 25, fatGrams: 20),
            rightItem: NutritionComparisonItem(foodName: "Option B", caloriesKcal: 480, proteinGrams: 27, fatGrams: 18),
            coachPick: "Stub comparison pick."
        )
    }
}
