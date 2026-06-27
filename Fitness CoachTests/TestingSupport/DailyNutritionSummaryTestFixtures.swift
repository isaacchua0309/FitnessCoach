//
//  DailyNutritionSummaryTestFixtures.swift
//  Fitness CoachTests
//
//  Pure DailyLog fixtures for runtime nutrition summary characterization (Stage A0).
//

import Foundation
@testable import Fitness_Coach

enum DailyNutritionSummaryTestFixtures {

    static let referenceDate = ProfileTestFixtures.referenceDate

    /// Mid-day log: under calorie target with typical macro progress.
    static var baselineLog: DailyLog {
        dailyLog(
            targets: UserTargets(
                calorieTarget: 2_000,
                proteinTarget: 150,
                carbTarget: 200,
                fatTarget: 65,
                waterTargetMl: 2_500,
                expectedWeeklyWeightLossKg: 0.45,
                aggressiveness: .moderate
            ),
            totals: MacroTotals(
                calories: 1_200,
                protein: 90,
                carbs: 110,
                fat: 40,
                fiber: nil,
                sodium: nil
            ),
            waterConsumedMl: 1_800
        )
    }

    /// Hydration goal exactly met.
    static var waterExactlyAtTargetLog: DailyLog {
        dailyLog(
            targets: UserTargets(
                calorieTarget: 2_000,
                proteinTarget: 150,
                carbTarget: 200,
                fatTarget: 65,
                waterTargetMl: 2_500,
                expectedWeeklyWeightLossKg: nil,
                aggressiveness: .moderate
            ),
            totals: MacroTotals(
                calories: 1_000,
                protein: 80,
                carbs: 100,
                fat: 35,
                fiber: nil,
                sodium: nil
            ),
            waterConsumedMl: 2_500
        )
    }

    /// One milliliter short of hydration goal.
    static var waterOneMlBelowTargetLog: DailyLog {
        dailyLog(
            targets: UserTargets(
                calorieTarget: 2_000,
                proteinTarget: 150,
                carbTarget: 200,
                fatTarget: 65,
                waterTargetMl: 2_500,
                expectedWeeklyWeightLossKg: nil,
                aggressiveness: .moderate
            ),
            totals: MacroTotals(
                calories: 1_000,
                protein: 80,
                carbs: 100,
                fat: 35,
                fiber: nil,
                sodium: nil
            ),
            waterConsumedMl: 2_499
        )
    }

    /// Protein target disabled (zero).
    static var zeroProteinTargetLog: DailyLog {
        dailyLog(
            targets: UserTargets(
                calorieTarget: 2_000,
                proteinTarget: 0,
                carbTarget: 200,
                fatTarget: 65,
                waterTargetMl: 2_500,
                expectedWeeklyWeightLossKg: nil,
                aggressiveness: .moderate
            ),
            totals: MacroTotals(
                calories: 500,
                protein: 0,
                carbs: 50,
                fat: 20,
                fiber: nil,
                sodium: nil
            ),
            waterConsumedMl: 500
        )
    }

    /// Calories consumed above target.
    static var caloriesOverTargetLog: DailyLog {
        dailyLog(
            targets: UserTargets(
                calorieTarget: 2_000,
                proteinTarget: 150,
                carbTarget: 200,
                fatTarget: 65,
                waterTargetMl: 2_500,
                expectedWeeklyWeightLossKg: nil,
                aggressiveness: .moderate
            ),
            totals: MacroTotals(
                calories: 2_100,
                protein: 155,
                carbs: 210,
                fat: 70,
                fiber: nil,
                sodium: nil
            ),
            waterConsumedMl: 2_600
        )
    }

    static func dailyLog(
        targets: UserTargets,
        totals: MacroTotals,
        waterConsumedMl: Int
    ) -> DailyLog {
        DailyLog(
            id: UUID(),
            date: referenceDate,
            weightKg: 72,
            targets: targets,
            totals: totals,
            waterConsumedMl: waterConsumedMl,
            steps: 6_000,
            workoutCaloriesBurned: 0,
            dailyReviewId: nil,
            createdAt: referenceDate,
            updatedAt: referenceDate
        )
    }
}
