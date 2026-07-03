//
//  HealthIntelligenceContext+Composition.swift
//  Fitness Coach
//
//  Forma — Input builders for Health Intelligence engine orchestration.
//

import Foundation

struct HealthIntelligenceWeeklyReviewContext: Equatable, Sendable {
    let weekStartDate: Date
    let weekEndDate: Date
    let weekMetrics: [DailyHealthMetrics]
    let weekWorkouts: [NormalizedWorkout]
    let weekLogs: [DailyLog]
    let weightRecords: [NormalizedBodyMass]
    let userPlan: WeeklyReviewUserPlan
    let hasEnoughActivity: Bool
}

extension HealthIntelligenceContext {

    func workoutInput(trainingLoad: TrainingLoadSummary) -> WorkoutIntelligenceInput {
        WorkoutIntelligenceInput(
            targetDate: targetDate,
            workoutsToday: workoutsToday,
            recentWorkouts: workoutsLast28Days,
            trainingLoadSummary: trainingLoad,
            baselineContext: baselineContext,
            calendar: calendar
        )
    }

    func recoveryInput(trainingLoad: TrainingLoadSummary) -> RecoveryEngineInput {
        RecoveryEngineInput(
            targetDate: targetDate,
            todayMetrics: todayMetrics,
            yesterdayMetrics: yesterdayMetrics,
            sleepRecordsRecent: sleepRecords,
            heartMetricsRecent: heartMetrics,
            workoutsLast7Days: workoutsLast7Days,
            workoutsLast28Days: workoutsLast28Days,
            trainingLoadSummary: trainingLoad,
            baselineContext: baselineContext,
            calendar: calendar
        )
    }

    func activitySummary() -> ActivitySummary {
        HealthIntelligenceBaseline.activitySummary(
            metrics: todayMetrics,
            availability: availability
        )
    }

    func adaptiveNutritionInput(
        workout: WorkoutSummary,
        recovery: RecoverySummary,
        activity: ActivitySummary,
        trainingLoad: TrainingLoadSummary
    ) -> AdaptiveNutritionEngineInput {
        AdaptiveNutritionEngineInput(
            targetDate: targetDate,
            nutritionProgress: nutritionProgress,
            userPlan: userPlan,
            workoutSummary: workout,
            recoverySummary: recovery,
            activitySummary: activity,
            trainingLoadSummary: trainingLoad,
            baselineContext: baselineContext,
            calendar: calendar
        )
    }

    func nextBestActionInput(
        workout: WorkoutSummary,
        recovery: RecoverySummary,
        activity: ActivitySummary,
        adaptiveNutrition: AdaptiveNutritionSummary,
        trainingLoad: TrainingLoadSummary
    ) -> NextBestActionEngineInput {
        NextBestActionEngineInput(
            targetDate: targetDate,
            timeOfDay: generatedAt,
            nutritionProgress: nutritionProgress,
            userPlan: userPlan,
            recoverySummary: recovery,
            workoutSummary: workout,
            activitySummary: activity,
            adaptiveNutritionSummary: adaptiveNutrition,
            trainingLoadSummary: trainingLoad,
            hasLoggedWeightRecently: hasLoggedWeightRecently,
            calendar: calendar
        )
    }

    func weeklyReviewInput(
        recoverySummaries: [DailyRecoverySummary],
        generatedAt: Date
    ) -> WeeklyReviewEngineInput? {
        guard let weeklyReviewContext else { return nil }
        guard weeklyReviewContext.hasEnoughActivity else { return nil }

        let nutritionSummaries = weeklyReviewContext.weekLogs.map {
            HealthIntelligenceContextBuilder.weeklyNutritionSummary(from: $0)
        }

        return WeeklyReviewEngineInput(
            weekStartDate: weeklyReviewContext.weekStartDate,
            weekEndDate: weeklyReviewContext.weekEndDate,
            dailyMetrics: weeklyReviewContext.weekMetrics,
            workouts: weeklyReviewContext.weekWorkouts,
            recoverySummaries: recoverySummaries,
            nutritionDailySummaries: nutritionSummaries,
            weightRecords: weeklyReviewContext.weightRecords,
            userPlan: weeklyReviewContext.userPlan,
            calendar: calendar,
            generatedAt: generatedAt
        )
    }
}

enum HealthIntelligenceWeeklyReviewSupport {

    static func recoverySummariesForWeek(
        weekContext: HealthIntelligenceWeeklyReviewContext,
        metrics: [DailyHealthMetrics],
        workouts: [NormalizedWorkout],
        sleepRecords: [NormalizedSleepRecord],
        heartMetrics: [NormalizedHeartMetric],
        baselineContext: HealthBaselineContext,
        recoveryProvider: any RecoveryEngineProviding,
        trainingLoadProvider: any TrainingLoadProviding,
        calendar: Calendar
    ) -> [DailyRecoverySummary] {
        var summaries: [DailyRecoverySummary] = []
        var cursor = weekContext.weekStartDate

        while cursor <= weekContext.weekEndDate {
            let day = calendar.startOfDay(for: cursor)
            let todayMetrics = metrics.first { calendar.isDate($0.date, inSameDayAs: day) }
                ?? .empty(for: day)
            let yesterdayDay = calendar.date(byAdding: .day, value: -1, to: day) ?? day
            let yesterdayMetrics = metrics.first { calendar.isDate($0.date, inSameDayAs: yesterdayDay) }
                ?? .empty(for: yesterdayDay)

            let workoutsToday = HealthIntelligenceContextBuilder.workouts(
                on: day,
                in: workouts,
                calendar: calendar
            )
            let workoutsLast7 = HealthIntelligenceContextBuilder.workouts(
                in: HealthIntelligenceContextBuilder.inclusiveDayRange(
                    endingOn: day,
                    days: 7,
                    calendar: calendar
                ),
                from: workouts,
                calendar: calendar
            )
            let workoutsLast28 = HealthIntelligenceContextBuilder.workouts(
                in: HealthIntelligenceContextBuilder.inclusiveDayRange(
                    endingOn: day,
                    days: 28,
                    calendar: calendar
                ),
                from: workouts,
                calendar: calendar
            )

            let trainingLoad = (try? trainingLoadProvider.evaluate(
                TrainingLoadEngineInput(
                    targetDate: day,
                    workoutsToday: workoutsToday,
                    workoutsLast7Days: workoutsLast7,
                    workoutsLast28Days: workoutsLast28,
                    baselineAverageWeeklyLoad: baselineContext.averageWorkoutLoad28d.map { $0 * 7 },
                    calendar: calendar
                )
            )) ?? .unknown

            let recovery = (try? recoveryProvider.evaluate(
                RecoveryEngineInput(
                    targetDate: day,
                    todayMetrics: todayMetrics,
                    yesterdayMetrics: yesterdayMetrics,
                    sleepRecordsRecent: sleepRecords,
                    heartMetricsRecent: heartMetrics,
                    workoutsLast7Days: workoutsLast7,
                    workoutsLast28Days: workoutsLast28,
                    trainingLoadSummary: trainingLoad,
                    baselineContext: baselineContext,
                    calendar: calendar
                )
            )) ?? .unknown

            summaries.append(DailyRecoverySummary(date: day, summary: recovery))

            guard let next = calendar.date(byAdding: .day, value: 1, to: cursor) else { break }
            cursor = next
        }

        return summaries
    }
}
