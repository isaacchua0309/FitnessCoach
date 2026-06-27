//
//  DailyNutritionSummaryBuilder.swift
//  Fitness Coach
//
//  Pure runtime daily nutrition summary from a DailyLog target snapshot and totals.
//  Delegates arithmetic to MacroCalculator and WaterTargetCalculator.
//

import Foundation

struct DailyWaterSummary: Equatable, Sendable {
    let consumedMl: Int
    let targetMl: Int
    let remainingMl: Int
    let progress: Double
    let hasMetTarget: Bool
}

struct DailyNutritionSummary: Equatable, Sendable {
    let targets: MacroTargets
    let totals: MacroTotals
    let remaining: MacroRemaining

    let calorieProgress: Double
    let proteinProgress: Double
    let carbProgress: Double
    let fatProgress: Double

    let isOverCalories: Bool
    let hasMetProteinTarget: Bool
    let hasMetWaterTarget: Bool

    let water: DailyWaterSummary
}

enum DailyNutritionSummaryBuilder {

    static func build(from dailyLog: DailyLog) -> DailyNutritionSummary {
        let targets = MacroCalculator.macroTargets(from: dailyLog.targets)
        let totals = dailyLog.totals
        let remaining = MacroCalculator.remaining(targets: targets, totals: totals)

        let waterRemainingMl = WaterTargetCalculator.remainingMl(
            consumedMl: dailyLog.waterConsumedMl,
            targetMl: dailyLog.targets.waterTargetMl
        )
        let water = DailyWaterSummary(
            consumedMl: dailyLog.waterConsumedMl,
            targetMl: dailyLog.targets.waterTargetMl,
            remainingMl: waterRemainingMl,
            progress: WaterTargetCalculator.progress(
                consumedMl: dailyLog.waterConsumedMl,
                targetMl: dailyLog.targets.waterTargetMl
            ),
            hasMetTarget: waterRemainingMl == 0
        )

        return DailyNutritionSummary(
            targets: targets,
            totals: totals,
            remaining: remaining,
            calorieProgress: MacroCalculator.calorieProgress(totals: totals, targets: targets),
            proteinProgress: MacroCalculator.proteinProgress(totals: totals, targets: targets),
            carbProgress: MacroCalculator.progress(consumed: totals.carbs, target: targets.carbs),
            fatProgress: MacroCalculator.progress(consumed: totals.fat, target: targets.fat),
            isOverCalories: MacroCalculator.isOverCalories(totals: totals, targets: targets),
            hasMetProteinTarget: MacroCalculator.hasMetProteinTarget(totals: totals, targets: targets),
            hasMetWaterTarget: water.hasMetTarget,
            water: water
        )
    }
}
