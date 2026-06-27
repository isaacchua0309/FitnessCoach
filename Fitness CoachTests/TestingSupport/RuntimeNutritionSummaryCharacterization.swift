//
//  RuntimeNutritionSummaryCharacterization.swift
//  Fitness CoachTests
//
//  Mirrors current production nutrition summary assembly (TodayModel, Coach AI
//  context, DailyReviewSummaryBuilder) until DailyNutritionSummaryBuilder exists.
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

    /// Same calculator sequence as `TodayModel.makeDashboardState` + review hydration flag.
    static func snapshot(from dailyLog: DailyLog) -> Snapshot {
        let targets = MacroCalculator.macroTargets(from: dailyLog.targets)
        let remaining = MacroCalculator.remaining(targets: targets, totals: dailyLog.totals)
        let waterRemainingMl = WaterTargetCalculator.remainingMl(
            consumedMl: dailyLog.waterConsumedMl,
            targetMl: dailyLog.targets.waterTargetMl
        )

        return Snapshot(
            calorieTarget: targets.calories,
            caloriesConsumed: dailyLog.totals.calories,
            caloriesRemaining: remaining.calories,
            calorieProgress: MacroCalculator.calorieProgress(totals: dailyLog.totals, targets: targets),
            isOverCalorieTarget: MacroCalculator.isOverCalories(
                totals: dailyLog.totals,
                targets: targets
            ),
            proteinTarget: targets.protein,
            proteinConsumed: dailyLog.totals.protein,
            proteinRemaining: remaining.protein,
            proteinProgress: MacroCalculator.proteinProgress(totals: dailyLog.totals, targets: targets),
            hasMetProteinTarget: MacroCalculator.hasMetProteinTarget(
                totals: dailyLog.totals,
                targets: targets
            ),
            carbsTarget: targets.carbs,
            carbsConsumed: dailyLog.totals.carbs,
            carbsRemaining: remaining.carbs,
            carbsProgress: MacroCalculator.progress(
                consumed: dailyLog.totals.carbs,
                target: targets.carbs
            ),
            fatTarget: targets.fat,
            fatConsumed: dailyLog.totals.fat,
            fatRemaining: remaining.fat,
            fatProgress: MacroCalculator.progress(
                consumed: dailyLog.totals.fat,
                target: targets.fat
            ),
            waterTargetMl: dailyLog.targets.waterTargetMl,
            waterConsumedMl: dailyLog.waterConsumedMl,
            waterRemainingMl: waterRemainingMl,
            waterProgress: WaterTargetCalculator.progress(
                consumedMl: dailyLog.waterConsumedMl,
                targetMl: dailyLog.targets.waterTargetMl
            ),
            hasMetWaterTarget: waterRemainingMl == 0
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
