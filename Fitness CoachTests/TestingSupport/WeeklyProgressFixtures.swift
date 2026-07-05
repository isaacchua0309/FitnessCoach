//
//  WeeklyProgressFixtures.swift
//  Fitness CoachTests
//
//  Shared Journey rolling-week logs, weights, and builder inputs.
//

import Foundation
@testable import Fitness_Coach

enum WeeklyProgressFixtures {

    static var calendar: Calendar {
        TestDateFixtures.utcCalendar(firstWeekday: 2)
    }

    static var asOf: Date { TestDateFixtures.referenceEpoch }

    static func dayOffset(_ offset: Int, from anchor: Date = asOf) -> Date {
        calendar.date(byAdding: .day, value: offset, to: anchor)!
    }

    static func makeLog(
        daysAgo: Int,
        calories: Int = 1_800,
        protein: Double = 140,
        waterMl: Int = 2_500,
        proteinTarget: Double = 150,
        waterTargetMl: Int = 2_500,
        calorieTarget: Int = 2_000,
        asOf: Date = asOf
    ) -> DailyLog {
        let date = calendar.date(byAdding: .day, value: -daysAgo, to: asOf)!
        return DailyLog(
            id: UUID(),
            date: date,
            weightKg: nil,
            targets: UserTargets(
                calorieTarget: calorieTarget,
                proteinTarget: proteinTarget,
                carbTarget: 200,
                fatTarget: 60,
                waterTargetMl: waterTargetMl,
                expectedWeeklyWeightLossKg: 0.5,
                aggressiveness: .moderate
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
            steps: nil,
            workoutCaloriesBurned: 0,
            dailyReviewId: nil,
            createdAt: date,
            updatedAt: date
        )
    }

    static func makeWeight(daysAgo: Int, kg: Double, asOf: Date = asOf) -> WeightEntry {
        let date = calendar.date(byAdding: .day, value: -daysAgo, to: asOf)!
        return WeightEntry(
            id: UUID(),
            date: date,
            weightKg: kg,
            note: nil,
            createdAt: date
        )
    }

    static func makeStreaks(
        logging: Int,
        protein: Int,
        water: Int
    ) -> JourneyStreakState {
        JourneyStreakState(
            currentLoggingStreakDays: logging,
            longestLoggingStreakDays: logging,
            currentProteinStreakDays: protein,
            currentWaterStreakDays: water,
            currentTrainingStreakWeeks: nil,
            isTodayLogged: logging > 0,
            heroStreakChip: .hidden,
            weeklyConsistencyHeadline: "",
            weeklyConsistencyDetail: nil,
            keepStreakAliveCopy: nil
        )
    }

    static func buildWeeklyHabit(
        weekLogs: [DailyLog],
        weekWeights: [WeightEntry] = [],
        maturityLogs: [DailyLog],
        allWeights: [WeightEntry] = [],
        streaks: JourneyStreakState? = nil,
        training: JourneyWeeklyTrainingStatus = .connectedEmpty,
        asOf: Date = asOf
    ) -> JourneyWeeklyHabitState {
        let resolvedStreaks = streaks ?? makeStreaks(logging: 0, protein: 0, water: 0)
        let review = JourneyWeeklyReviewState(
            foodLoggedDays: JourneyLogMetrics.uniqueFoodLoggedDays(in: weekLogs, calendar: calendar),
            foodLoggedDaysTotal: JourneyLogMetrics.weekDayCount,
            proteinGoalDays: JourneyLogMetrics.uniqueProteinGoalDays(in: weekLogs, calendar: calendar),
            proteinGoalDaysTotal: JourneyLogMetrics.weekDayCount,
            waterGoalDays: JourneyLogMetrics.uniqueWaterGoalDays(in: weekLogs, calendar: calendar),
            waterGoalDaysTotal: JourneyLogMetrics.weekDayCount,
            trainingDays: 0,
            expectedTrainingDays: 4,
            training: training,
            weightDeltaThisWeekKg: nil,
            calorieAdherenceDays: JourneyLogMetrics.uniqueCalorieAdherenceDays(in: weekLogs, calendar: calendar),
            calorieAdherenceDaysTotal: JourneyLogMetrics.weekDayCount,
            weekSummaryCopy: "",
            rows: [],
            weekOverWeekDetail: nil
        )

        let streakSummary = StreakCalculator.calculate(
            logs: maturityLogs,
            workoutDates: [],
            asOf: asOf,
            calendar: calendar
        )

        return JourneyWeeklyPatternBuilder.build(
            JourneyWeeklyPatternBuilder.Input(
                weekLogs: weekLogs,
                weekWeights: weekWeights,
                maturityLogs: maturityLogs,
                allWeights: allWeights,
                healthWorkoutDayStarts: [],
                weeklyTraining: training,
                expectedTrainingDays: 4,
                streaks: resolvedStreaks,
                streakSummary: streakSummary,
                weeklyReview: review,
                asOf: asOf,
                calendar: calendar
            )
        )
    }
}
