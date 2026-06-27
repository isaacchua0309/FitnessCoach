//
//  TodayDashboardFixtures.swift
//  Fitness CoachTests
//
//  Builders for Today dashboard / goals tests.
//

import Foundation
@testable import Fitness_Coach

enum TodayDashboardFixtures {

    static func dashboardState(
        proteinConsumed: Double = 31,
        proteinTarget: Double = 180,
        proteinRemaining: Double = 149,
        waterConsumedMl: Int = 500,
        waterTargetMl: Int = 3_150,
        waterRemainingMl: Int = 2_650,
        weightKg: Double? = nil,
        hasWorkout: Bool = false,
        date: Date = Date()
    ) -> TodayDashboardState {
        TodayDashboardState(
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
            stepsSummary: nil,
            workoutSummary: TodayWorkoutSummary(
                workoutCaloriesBurned: hasWorkout ? 200 : 0,
                workoutCount: hasWorkout ? 1 : 0,
                hasWorkout: hasWorkout
            ),
            foodEntries: [],
            hasDailyLog: true,
            dailyReview: nil,
            coachingNote: nil,
            todayFocus: FormaProductCopy.Today.focusOnTrack,
            dailyBrief: TodayDailyBrief(
                greeting: "Good morning.",
                priorities: [],
                recommendation: "Stay consistent today."
            ),
            streaks: StreakSummary(loggingStreak: 0, proteinStreak: 0, hydrationStreak: 0, workoutStreak: 0),
            userName: nil
        )
    }
}
