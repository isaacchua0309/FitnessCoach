//
//  CoachMutationTestFixtures.swift
//  Fitness CoachTests
//
//  Pure models for Coach response / confirmation formatting tests.
//

import Foundation
@testable import Fitness_Coach

enum CoachMutationTestFixtures {

    static let referenceDate = ProfileTestFixtures.referenceDate

    static var chickenFoodEntry: FoodEntry {
        FoodEntry(
            id: UUID(),
            dailyLogId: UUID(),
            mealType: .lunch,
            name: "Chicken breast",
            quantity: 200,
            unit: "g",
            calories: 330,
            protein: 62,
            carbs: 0,
            fat: 7,
            fiber: nil,
            sodium: nil,
            source: .manual,
            confidence: .high,
            imageUrl: nil,
            notes: nil,
            createdAt: referenceDate,
            updatedAt: referenceDate
        )
    }

    static var sampleDailyLog: DailyLog {
        DailyLog(
            id: UUID(),
            date: referenceDate,
            weightKg: 68,
            targets: ProfileTestFixtures.sampleTargets,
            totals: MacroTotals(
                calories: 900,
                protein: 70,
                carbs: 80,
                fat: 30,
                fiber: nil,
                sodium: nil
            ),
            waterConsumedMl: 1200,
            steps: 5000,
            workoutCaloriesBurned: 0,
            dailyReviewId: nil,
            createdAt: referenceDate,
            updatedAt: referenceDate
        )
    }

    static var chickenConfirmationDraft: AIFoodConfirmationDraft {
        AIFoodConfirmationDraft(
            originalText: "log chicken",
            assistantMessage: nil,
            mealDraft: FoodLogDraft(
                displayName: "Chicken breast",
                mealType: .lunch,
                components: [
                    FoodComponent(
                        name: "Chicken breast",
                        quantity: 200,
                        unit: "g",
                        calories: 330,
                        protein: 62,
                        carbs: 0,
                        fat: 7,
                        confidence: .high,
                        sourceText: "log chicken"
                    )
                ],
                confidence: .high,
                source: .aiTextEstimate
            ),
            confidence: .high,
            requiresConfirmation: true
        )
    }
}
