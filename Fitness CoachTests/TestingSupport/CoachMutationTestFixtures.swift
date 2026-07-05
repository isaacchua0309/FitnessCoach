//
//  CoachMutationTestFixtures.swift
//  Fitness CoachTests
//
//  Pure models for Coach response / confirmation formatting tests.
//

import Foundation
@testable import Fitness_Coach

enum CoachMutationTestFixtures {

    static let referenceDate = TestDateFixtures.referenceEpoch

    static var chickenFoodEntry: FoodEntry { FoodLogFixtures.chickenFoodEntry }

    static var sampleDailyLog: DailyLog { FoodLogFixtures.sampleDailyLog }

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
