//
//  WaterTargetCalculator.swift
//  Fitness Coach
//
//  FitPilot AI — Hydration progress arithmetic; target generation delegates to WaterCalculator.
//

import Foundation

struct WaterTargetCalculator {

    /// Delegates to `WaterCalculator` (FormaCalculationEngine). Uses moderate activity defaults
    /// when lifestyle context is unavailable.
    static func targetMl(bodyWeightKg: Double, isWorkoutDay: Bool) -> Int {
        PlanCalculationBridge.waterTargetMl(
            bodyWeightKg: bodyWeightKg,
            activityLevel: .moderatelyActive,
            averageStepsPerDay: FormaCalculationConstants.stepBaselinePerDay,
            isWorkoutDay: isWorkoutDay
        )
    }

    static func remainingMl(consumedMl: Int, targetMl: Int) -> Int {
        max(targetMl - consumedMl, 0)
    }

    static func progress(consumedMl: Int, targetMl: Int) -> Double {
        guard targetMl > 0 else { return 0 }
        let ratio = Double(consumedMl) / Double(targetMl)
        return min(max(ratio, 0), 1)
    }
}
