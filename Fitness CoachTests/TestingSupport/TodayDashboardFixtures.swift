//
//  TodayDashboardFixtures.swift
//  Fitness CoachTests
//
//  Builders for Today dashboard / goals tests.
//

import Foundation
@testable import Fitness_Coach

enum TodayDashboardFixtures {

    /// Fixed calendar date for deterministic next-action tests (2026-06-28).
    static func date(hour: Int, minute: Int = 0) -> Date {
        var components = DateComponents()
        components.year = 2026
        components.month = 6
        components.day = 28
        components.hour = hour
        components.minute = minute
        return Calendar.current.date(from: components) ?? Date()
    }

    /// Default partial day — incomplete nutrition goals, no meals logged.
    static func dashboardState(
        proteinConsumed: Double = 31,
        proteinTarget: Double = 180,
        proteinRemaining: Double = 149,
        waterConsumedMl: Int = 500,
        waterTargetMl: Int = 3_150,
        waterRemainingMl: Int = 2_650,
        weightKg: Double? = nil,
        hasWorkout: Bool = false,
        foodEntries: [FoodEntry] = [],
        date: Date = date(hour: 14),
        activityContext: TodayActivityContext = .default
    ) -> TodayDashboardState {
        partialDay(
            proteinConsumed: proteinConsumed,
            proteinTarget: proteinTarget,
            proteinRemaining: proteinRemaining,
            waterConsumedMl: waterConsumedMl,
            waterTargetMl: waterTargetMl,
            waterRemainingMl: waterRemainingMl,
            weightKg: weightKg,
            hasWorkout: hasWorkout,
            foodEntries: foodEntries,
            date: date,
            activityContext: activityContext
        )
    }

    static func emptyDay(date: Date = date(hour: 9)) -> TodayDashboardState {
        TodayMissionControlStateBuilder.build(
            from: TodayMissionControlInputs(
                date: date,
                calorieSummary: CalorieSummary(
                    consumed: 0,
                    target: 1_800,
                    remaining: 1_800,
                    progress: 0,
                    isOverTarget: false
                ),
                macroSummary: MacroSummary(
                    protein: MacroProgress(consumed: 0, target: 180, remaining: 180, progress: 0),
                    carbs: MacroProgress(consumed: 0, target: 160, remaining: 160, progress: 0),
                    fat: MacroProgress(consumed: 0, target: 60, remaining: 60, progress: 0)
                ),
                waterSummary: WaterSummary(
                    consumedMl: 0,
                    targetMl: 3_150,
                    remainingMl: 3_150,
                    progress: 0
                ),
                weightSummary: TodayWeightSummary(
                    weightKg: nil,
                    displayText: "Not logged today"
                ),
                weightLoggedToday: false,
                hasRecentWeight: true,
                workoutSummary: TodayWorkoutSummary(
                    workoutCaloriesBurned: 0,
                    workoutCount: 0,
                    hasWorkout: false
                ),
                foodEntries: [],
                hasPriorFoodLogs: false,
                streaks: StreakSummary(
                    loggingStreak: 0,
                    proteinStreak: 0,
                    hydrationStreak: 0,
                    workoutStreak: 0
                ),
                weekLoggedDays: 0,
                dailyBrief: TodayDailyBrief(
                    greeting: "Good morning.",
                    priorities: [],
                    recommendation: "Log your first meal to start today's picture."
                ),
                dailyReview: nil,
                goalWeightKg: 65,
                profileWeightKg: 70,
                userName: nil,
                activityContext: .default
            )
        )
    }

    static func partialDay(
        proteinConsumed: Double = 31,
        proteinTarget: Double = 180,
        proteinRemaining: Double = 149,
        waterConsumedMl: Int = 500,
        waterTargetMl: Int = 3_150,
        waterRemainingMl: Int = 2_650,
        weightKg: Double? = nil,
        hasWorkout: Bool = false,
        foodEntries: [FoodEntry] = [],
        date: Date = date(hour: 14),
        activityContext: TodayActivityContext = .default
    ) -> TodayDashboardState {
        TodayMissionControlStateBuilder.build(
            from: TodayMissionControlInputs(
                date: date,
                calorieSummary: CalorieSummary(
                    consumed: 500,
                    target: 1_800,
                    remaining: 1_300,
                    progress: 0.28,
                    isOverTarget: false
                ),
                macroSummary: MacroSummary(
                    protein: MacroProgress(
                        consumed: proteinConsumed,
                        target: proteinTarget,
                        remaining: proteinRemaining,
                        progress: proteinConsumed / proteinTarget
                    ),
                    carbs: MacroProgress(consumed: 0, target: 160, remaining: 160, progress: 0),
                    fat: MacroProgress(consumed: 0, target: 60, remaining: 60, progress: 0)
                ),
                waterSummary: WaterSummary(
                    consumedMl: waterConsumedMl,
                    targetMl: waterTargetMl,
                    remainingMl: waterRemainingMl,
                    progress: Double(waterConsumedMl) / Double(waterTargetMl)
                ),
                weightSummary: TodayWeightSummary(
                    weightKg: weightKg,
                    displayText: weightKg.map { String(format: "%.2f kg", $0) } ?? "Not logged today"
                ),
                weightLoggedToday: weightKg != nil,
                hasRecentWeight: weightKg != nil || true,
                workoutSummary: TodayWorkoutSummary(
                    workoutCaloriesBurned: hasWorkout ? 200 : 0,
                    workoutCount: hasWorkout ? 1 : 0,
                    hasWorkout: hasWorkout
                ),
                foodEntries: foodEntries,
                hasPriorFoodLogs: !foodEntries.isEmpty,
                streaks: StreakSummary(
                    loggingStreak: 0,
                    proteinStreak: 0,
                    hydrationStreak: 0,
                    workoutStreak: 0
                ),
                weekLoggedDays: 0,
                dailyBrief: TodayDailyBrief(
                    greeting: "Good morning.",
                    priorities: [],
                    recommendation: "Stay consistent today."
                ),
                dailyReview: nil,
                goalWeightKg: 65,
                profileWeightKg: weightKg ?? 70,
                userName: nil,
                activityContext: activityContext
            )
        )
    }

    static func completeDay(date: Date = date(hour: 14)) -> TodayDashboardState {
        TodayMissionControlStateBuilder.build(
            from: TodayMissionControlInputs(
                date: date,
                calorieSummary: CalorieSummary(
                    consumed: 1_750,
                    target: 1_800,
                    remaining: 50,
                    progress: 0.97,
                    isOverTarget: false
                ),
                macroSummary: MacroSummary(
                    protein: MacroProgress(consumed: 175, target: 180, remaining: 5, progress: 0.97),
                    carbs: MacroProgress(consumed: 155, target: 160, remaining: 5, progress: 0.97),
                    fat: MacroProgress(consumed: 58, target: 60, remaining: 2, progress: 0.97)
                ),
                waterSummary: WaterSummary(
                    consumedMl: 3_100,
                    targetMl: 3_150,
                    remainingMl: 50,
                    progress: 0.98
                ),
                weightSummary: TodayWeightSummary(
                    weightKg: 68.5,
                    displayText: "68.50 kg"
                ),
                weightLoggedToday: true,
                hasRecentWeight: true,
                workoutSummary: TodayWorkoutSummary(
                    workoutCaloriesBurned: 250,
                    workoutCount: 1,
                    hasWorkout: true
                ),
                foodEntries: TodayPreviewData.foodEntries,
                hasPriorFoodLogs: true,
                streaks: StreakSummary(
                    loggingStreak: 7,
                    proteinStreak: 5,
                    hydrationStreak: 3,
                    workoutStreak: 2
                ),
                weekLoggedDays: 5,
                dailyBrief: TodayDailyBrief(
                    greeting: "Good evening.",
                    priorities: ["Protein is on track — keep it up."],
                    recommendation: "Stay consistent today. Small wins compound."
                ),
                dailyReview: nil,
                goalWeightKg: 65,
                profileWeightKg: 68.5,
                userName: "Test",
                activityContext: TodayActivityContext(
                    trainingIntegration: .connected,
                    trainingDataSource: .appleHealth,
                    appleHealthWorkoutCount: 1
                )
            )
        )
    }

    static func overTargetDay(date: Date = date(hour: 14)) -> TodayDashboardState {
        TodayMissionControlStateBuilder.build(
            from: TodayMissionControlInputs(
                date: date,
                calorieSummary: CalorieSummary(
                    consumed: 2_100,
                    target: 1_800,
                    remaining: 0,
                    progress: 1.17,
                    isOverTarget: true
                ),
                macroSummary: MacroSummary(
                    protein: MacroProgress(consumed: 120, target: 180, remaining: 60, progress: 0.67),
                    carbs: MacroProgress(consumed: 220, target: 160, remaining: 0, progress: 1.38),
                    fat: MacroProgress(consumed: 80, target: 60, remaining: 0, progress: 1.33)
                ),
                waterSummary: WaterSummary(
                    consumedMl: 2_000,
                    targetMl: 3_150,
                    remainingMl: 1_150,
                    progress: 0.63
                ),
                weightSummary: TodayWeightSummary(
                    weightKg: 70,
                    displayText: "70.00 kg"
                ),
                weightLoggedToday: true,
                hasRecentWeight: true,
                workoutSummary: TodayWorkoutSummary(
                    workoutCaloriesBurned: 0,
                    workoutCount: 0,
                    hasWorkout: false
                ),
                foodEntries: TodayPreviewData.foodEntries,
                hasPriorFoodLogs: true,
                streaks: StreakSummary(
                    loggingStreak: 2,
                    proteinStreak: 0,
                    hydrationStreak: 0,
                    workoutStreak: 0
                ),
                weekLoggedDays: 2,
                dailyBrief: TodayDailyBrief(
                    greeting: "Good evening.",
                    priorities: ["0 kcal remaining for today."],
                    recommendation: "You're above today's target. Log honestly tonight — we care about the weekly trend, not one meal."
                ),
                dailyReview: nil,
                goalWeightKg: 65,
                profileWeightKg: 70,
                userName: nil,
                activityContext: .default
            )
        )
    }
}
