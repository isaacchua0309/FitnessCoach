//
//  TodayDashboardNutritionMapper.swift
//  Fitness Coach
//
//  Maps DailyNutritionSummary into Today dashboard nutrition view state.
//

import Foundation

enum TodayDashboardNutritionMapper {

    static func maps(from dailyLog: DailyLog) -> (CalorieSummary, MacroSummary, WaterSummary) {
        let nutrition = DailyNutritionSummaryBuilder.build(from: dailyLog)
        return (
            calorieSummary(from: nutrition),
            macroSummary(from: nutrition),
            waterSummary(from: nutrition)
        )
    }

    static func calorieSummary(from nutrition: DailyNutritionSummary) -> CalorieSummary {
        CalorieSummary(
            consumed: nutrition.totals.calories,
            target: nutrition.targets.calories,
            remaining: nutrition.remaining.calories,
            progress: nutrition.calorieProgress,
            isOverTarget: nutrition.isOverCalories
        )
    }

    static func macroSummary(from nutrition: DailyNutritionSummary) -> MacroSummary {
        MacroSummary(
            protein: macroProgress(
                consumed: nutrition.totals.protein,
                target: nutrition.targets.protein,
                remaining: nutrition.remaining.protein,
                progress: nutrition.proteinProgress
            ),
            carbs: macroProgress(
                consumed: nutrition.totals.carbs,
                target: nutrition.targets.carbs,
                remaining: nutrition.remaining.carbs,
                progress: nutrition.carbProgress
            ),
            fat: macroProgress(
                consumed: nutrition.totals.fat,
                target: nutrition.targets.fat,
                remaining: nutrition.remaining.fat,
                progress: nutrition.fatProgress
            )
        )
    }

    static func waterSummary(from nutrition: DailyNutritionSummary) -> WaterSummary {
        WaterSummary(
            consumedMl: nutrition.water.consumedMl,
            targetMl: nutrition.water.targetMl,
            remainingMl: nutrition.water.remainingMl,
            progress: nutrition.water.progress
        )
    }

    private static func macroProgress(
        consumed: Double,
        target: Double,
        remaining: Double,
        progress: Double
    ) -> MacroProgress {
        MacroProgress(
            consumed: consumed,
            target: target,
            remaining: remaining,
            progress: progress
        )
    }
}
