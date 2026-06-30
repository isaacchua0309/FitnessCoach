//
//  RuntimeNutritionSummaryCharacterization.swift
//  Fitness CoachTests
//
//  Projects DailyNutritionSummaryBuilder output for cross-feature parity tests.
//

import Foundation
@testable import Fitness_Coach

enum RuntimeNutritionSummaryCharacterization {

    struct Snapshot: Equatable {
        let calorieTarget: Int
        let caloriesConsumed: Int
        let caloriesRemaining: Int
        let calorieProgress: Double
        let isOverCalorieTarget: Bool

        let proteinTarget: Double
        let proteinConsumed: Double
        let proteinRemaining: Double
        let proteinProgress: Double
        let hasMetProteinTarget: Bool

        let carbsTarget: Double
        let carbsConsumed: Double
        let carbsRemaining: Double
        let carbsProgress: Double

        let fatTarget: Double
        let fatConsumed: Double
        let fatRemaining: Double
        let fatProgress: Double

        let waterTargetMl: Int
        let waterConsumedMl: Int
        let waterRemainingMl: Int
        let waterProgress: Double
        let hasMetWaterTarget: Bool
    }

    static func snapshot(from dailyLog: DailyLog) -> Snapshot {
        snapshot(from: DailyNutritionSummaryBuilder.build(from: dailyLog))
    }

    static func snapshot(from nutrition: DailyNutritionSummary) -> Snapshot {
        Snapshot(
            calorieTarget: nutrition.targets.calories,
            caloriesConsumed: nutrition.totals.calories,
            caloriesRemaining: nutrition.remaining.calories,
            calorieProgress: nutrition.calorieProgress,
            isOverCalorieTarget: nutrition.isOverCalories,
            proteinTarget: nutrition.targets.protein,
            proteinConsumed: nutrition.totals.protein,
            proteinRemaining: nutrition.remaining.protein,
            proteinProgress: nutrition.proteinProgress,
            hasMetProteinTarget: nutrition.hasMetProteinTarget,
            carbsTarget: nutrition.targets.carbs,
            carbsConsumed: nutrition.totals.carbs,
            carbsRemaining: nutrition.remaining.carbs,
            carbsProgress: nutrition.carbProgress,
            fatTarget: nutrition.targets.fat,
            fatConsumed: nutrition.totals.fat,
            fatRemaining: nutrition.remaining.fat,
            fatProgress: nutrition.fatProgress,
            waterTargetMl: nutrition.water.targetMl,
            waterConsumedMl: nutrition.water.consumedMl,
            waterRemainingMl: nutrition.water.remainingMl,
            waterProgress: nutrition.water.progress,
            hasMetWaterTarget: nutrition.hasMetWaterTarget
        )
    }

    /// Core numeric fields produced by `DailyReviewSummaryBuilder` (before note copy).
    static func reviewSummary(from dailyLog: DailyLog) -> DailyReviewSummary {
        DailyReviewSummaryBuilder.build(
            dailyLog: dailyLog,
            foodEntries: [],
            waterEntries: [],
            weightEntry: nil,
            latestWeightEntry: nil,
            workouts: []
        )
    }
}
