//
//  DailyLogEntity+Mapping.swift
//  Fitness Coach
//
//  FitPilot AI — SwiftData mapping between entity and domain model.
//

import Foundation

extension DailyLogEntity {

    convenience init(model: DailyLog) {
        self.init(
            id: model.id,
            date: model.date,
            weightKg: model.weightKg,
            calorieTarget: model.targets.calorieTarget,
            proteinTarget: model.targets.proteinTarget,
            carbTarget: model.targets.carbTarget,
            fatTarget: model.targets.fatTarget,
            waterTargetMl: model.targets.waterTargetMl,
            expectedWeeklyWeightLossKg: model.targets.expectedWeeklyWeightLossKg,
            aggressivenessRawValue: model.targets.aggressiveness.rawValue,
            caloriesConsumed: model.totals.calories,
            proteinConsumed: model.totals.protein,
            carbsConsumed: model.totals.carbs,
            fatConsumed: model.totals.fat,
            fiberConsumed: model.totals.fiber,
            sodiumConsumed: model.totals.sodium,
            waterConsumedMl: model.waterConsumedMl,
            steps: model.steps,
            workoutCaloriesBurned: model.workoutCaloriesBurned,
            dailyReviewId: model.dailyReviewId,
            createdAt: model.createdAt,
            updatedAt: model.updatedAt
        )
    }

    func toModel() -> DailyLog {
        DailyLog(
            id: id,
            date: date,
            weightKg: weightKg,
            targets: UserTargets(
                calorieTarget: calorieTarget,
                proteinTarget: proteinTarget,
                carbTarget: carbTarget,
                fatTarget: fatTarget,
                waterTargetMl: waterTargetMl,
                expectedWeeklyWeightLossKg: expectedWeeklyWeightLossKg,
                aggressiveness: CalorieAggressiveness(rawValue: aggressivenessRawValue) ?? .moderate
            ),
            totals: MacroTotals(
                calories: caloriesConsumed,
                protein: proteinConsumed,
                carbs: carbsConsumed,
                fat: fatConsumed,
                fiber: fiberConsumed,
                sodium: sodiumConsumed
            ),
            waterConsumedMl: waterConsumedMl,
            steps: steps,
            workoutCaloriesBurned: workoutCaloriesBurned,
            dailyReviewId: dailyReviewId,
            createdAt: createdAt,
            updatedAt: updatedAt
        )
    }
}
