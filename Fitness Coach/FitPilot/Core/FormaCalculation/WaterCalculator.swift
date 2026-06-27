//
//  WaterCalculator.swift
//  Fitness Coach
//
//  Forma — Hydration target calculation (Docs/FormaCalculationSpec.md §8).
//

import Foundation

enum WaterCalculator {

    static func targetMl(
        weightKg: Double,
        activityLevel: ActivityLevel,
        averageStepsPerDay: Int,
        isWorkoutDay: Bool
    ) -> Int {
        guard weightKg > 0 else { return 0 }

        var waterMl = Int((weightKg * FormaCalculationConstants.mlPerKgBodyWeight).rounded())

        if isWorkoutDay {
            waterMl += FormaCalculationConstants.workoutDayWaterBonusMl
        }

        if activityLevel == .sedentary,
           averageStepsPerDay < FormaCalculationConstants.sedentaryLowStepsThreshold {
            waterMl -= FormaCalculationConstants.sedentaryLowStepsWaterReductionMl
        }

        return clamp(
            waterMl,
            min: FormaCalculationConstants.waterMinimumMl,
            max: FormaCalculationConstants.waterMaximumMl
        )
    }

    private static func clamp(_ value: Int, min minValue: Int, max maxValue: Int) -> Int {
        Swift.min(Swift.max(value, minValue), maxValue)
    }
}
