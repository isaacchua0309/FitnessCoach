//
//  DailyLogFixtures.swift
//  Fitness CoachTests
//
//  Pure DailyLog fixtures for nutrition summary, review, and coach mapper tests.
//

import Foundation
@testable import Fitness_Coach

enum DailyLogFixtures {

    static let referenceDate = TestDateFixtures.referenceEpoch

    /// Named nutrition scenarios used across summary, review, and coach tests.
    enum NutritionScenario: CaseIterable {
        case baseline
        case waterExactlyAtTarget
        case waterOneMlBelowTarget
        case zeroProteinTarget
        case caloriesOverTarget
        case proteinTargetMet
        case zeroMacroTargets
    }

    static var baselineLog: DailyLog { log(for: .baseline) }
    static var waterExactlyAtTargetLog: DailyLog { log(for: .waterExactlyAtTarget) }
    static var waterOneMlBelowTargetLog: DailyLog { log(for: .waterOneMlBelowTarget) }
    static var zeroProteinTargetLog: DailyLog { log(for: .zeroProteinTarget) }
    static var caloriesOverTargetLog: DailyLog { log(for: .caloriesOverTarget) }

    static func log(for scenario: NutritionScenario) -> DailyLog {
        switch scenario {
        case .baseline:
            return dailyLog(
                targets: ProfileFixtures.nutritionSummaryTargets,
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
        case .waterExactlyAtTarget:
            return dailyLog(
                targets: ProfileFixtures.nutritionSummaryTargets,
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
        case .waterOneMlBelowTarget:
            return dailyLog(
                targets: ProfileFixtures.nutritionSummaryTargets,
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
        case .zeroProteinTarget:
            return dailyLog(
                targets: targets(proteinTarget: 0),
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
        case .caloriesOverTarget:
            return dailyLog(
                targets: ProfileFixtures.nutritionSummaryTargets,
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
        case .proteinTargetMet:
            return dailyLog(
                targets: ProfileFixtures.nutritionSummaryTargets,
                totals: MacroTotals(
                    calories: 1_800,
                    protein: 150,
                    carbs: 180,
                    fat: 60,
                    fiber: nil,
                    sodium: nil
                ),
                waterConsumedMl: 1_000
            )
        case .zeroMacroTargets:
            return dailyLog(
                targets: targets(
                    calorieTarget: 0,
                    proteinTarget: 0,
                    carbTarget: 0,
                    fatTarget: 0,
                    waterTargetMl: 0
                ),
                totals: MacroTotals(
                    calories: 100,
                    protein: 10,
                    carbs: 20,
                    fat: 5,
                    fiber: nil,
                    sodium: nil
                ),
                waterConsumedMl: 250
            )
        }
    }

    static func targets(
        calorieTarget: Int = 2_000,
        proteinTarget: Double = 150,
        carbTarget: Double = 200,
        fatTarget: Double = 65,
        waterTargetMl: Int = 2_500,
        expectedWeeklyWeightLossKg: Double? = 0.45,
        aggressiveness: CalorieAggressiveness = .moderate
    ) -> UserTargets {
        UserTargets(
            calorieTarget: calorieTarget,
            proteinTarget: proteinTarget,
            carbTarget: carbTarget,
            fatTarget: fatTarget,
            waterTargetMl: waterTargetMl,
            expectedWeeklyWeightLossKg: expectedWeeklyWeightLossKg,
            aggressiveness: aggressiveness
        )
    }

    static func dailyLog(
        date: Date = referenceDate,
        weightKg: Double = 72,
        targets: UserTargets,
        totals: MacroTotals,
        waterConsumedMl: Int,
        steps: Int = 6_000,
        workoutCaloriesBurned: Int = 0
    ) -> DailyLog {
        DailyLog(
            id: UUID(),
            date: date,
            weightKg: weightKg,
            targets: targets,
            totals: totals,
            waterConsumedMl: waterConsumedMl,
            steps: steps,
            workoutCaloriesBurned: workoutCaloriesBurned,
            dailyReviewId: nil,
            createdAt: date,
            updatedAt: date
        )
    }

    /// Rolling-week log relative to an anchor day (Journey / weekly progress).
    static func rollingWeekLog(
        daysAgo: Int,
        asOf: Date = referenceDate,
        calendar: Calendar = TestDateFixtures.utcCalendar(firstWeekday: 2),
        calories: Int = 1_800,
        protein: Double = 140,
        waterMl: Int = 2_500,
        proteinTarget: Double = 150,
        waterTargetMl: Int = 2_500,
        calorieTarget: Int = 2_000
    ) -> DailyLog {
        let date = calendar.date(byAdding: .day, value: -daysAgo, to: asOf)!
        return dailyLog(
            date: date,
            weightKg: 72,
            targets: targets(
                calorieTarget: calorieTarget,
                proteinTarget: proteinTarget,
                waterTargetMl: waterTargetMl,
                expectedWeeklyWeightLossKg: 0.5
            ),
            totals: MacroTotals(
                calories: calories,
                protein: protein,
                carbs: 0,
                fat: 0,
                fiber: nil,
                sodium: nil
            ),
            waterConsumedMl: waterMl,
            workoutCaloriesBurned: 0
        )
    }
}
