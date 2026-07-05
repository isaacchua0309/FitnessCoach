//
//  FoodLogFixtures.swift
//  Fitness CoachTests
//
//  Shared food drafts, entries, and water logs for coach and logging tests.
//

import Foundation
@testable import Fitness_Coach

enum FoodLogFixtures {

    static var referenceDate: Date { TestDateFixtures.referenceEpoch }

    static func foodDraft(
        name: String,
        calories: Int,
        protein: Double = 0,
        carbs: Double = 0,
        fat: Double = 0,
        fiber: Double? = nil,
        sodium: Double? = nil,
        mealType: MealType = .lunch
    ) -> FoodDraft {
        FoodDraft(
            mealType: mealType,
            name: name,
            quantity: 1,
            unit: "serving",
            calories: calories,
            protein: protein,
            carbs: carbs,
            fat: fat,
            fiber: fiber,
            sodium: sodium,
            source: .manual,
            confidence: .high,
            imageUrl: nil,
            notes: nil
        )
    }

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
        DailyLogFixtures.dailyLog(
            date: referenceDate,
            weightKg: 68,
            targets: ProfileFixtures.sampleTargets,
            totals: MacroTotals(
                calories: 900,
                protein: 70,
                carbs: 80,
                fat: 30,
                fiber: nil,
                sodium: nil
            ),
            waterConsumedMl: 1_200,
            steps: 5_000
        )
    }

    static func waterEntry(
        amountMl: Int = 250,
        dailyLogId: UUID = UUID(),
        createdAt: Date = referenceDate
    ) -> WaterEntry {
        WaterEntry(
            id: UUID(),
            dailyLogId: dailyLogId,
            amountMl: amountMl,
            createdAt: createdAt
        )
    }
}
