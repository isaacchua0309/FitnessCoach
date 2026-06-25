//
//  WaterTargetCalculator.swift
//  Fitness Coach
//
//  FitPilot AI — Deterministic hydration target arithmetic.
//

import Foundation

struct WaterTargetCalculator {

    /// Base hydration estimate of roughly 35 ml per kg of body weight, with an
    /// additional allowance on workout days.
    private static let mlPerKg = 35.0
    private static let workoutDayBonusMl = 500

    static func targetMl(bodyWeightKg: Double, isWorkoutDay: Bool) -> Int {
        guard bodyWeightKg > 0 else { return 0 }
        let base = Int((bodyWeightKg * mlPerKg).rounded())
        return base + (isWorkoutDay ? workoutDayBonusMl : 0)
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
