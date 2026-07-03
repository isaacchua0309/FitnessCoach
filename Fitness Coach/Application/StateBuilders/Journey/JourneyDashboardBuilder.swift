//
//  JourneyDashboardBuilder.swift
//  Fitness Coach
//
//  Forma — Deterministic builders for the unified Journey dashboard payload.
//

import Foundation

enum JourneyDashboardBuilder {

    // MARK: - Context

    struct Context {
        var profile: UserProfile?
        var baseline: JourneyBaseline
        var maturityLogs: [DailyLog]
        var monthLogs: [DailyLog]
        var weekLogs: [DailyLog]
        var previousWeekLogs: [DailyLog]
        var previousWeekWeights: [WeightEntry]
        var previousWeekTrainingDays: Int
        var allWeights: [WeightEntry]
        var weekWeights: [WeightEntry]
        var journeyStreaks: JourneyStreakState
        var weeklyTraining: JourneyWeeklyTrainingStatus
        var weightSummary: ProgressWeightSummary
        var goalProjection: ProgressProjection?
        var healthWorkoutDayStarts: Set<Date>
        var monthHealthWorkoutCount: Int
        var asOf: Date
        var calendar: Calendar
    }

    // MARK: - Transformation

    static func transformation(
        context: Context,
        loggedDays: Int
    ) -> JourneyTransformationHeroState {
        JourneyTransformationHeroBuilder.build(
            JourneyTransformationHeroBuilder.Input(
                baseline: context.baseline,
                loggedDays: loggedDays,
                heroStreakChip: context.journeyStreaks.heroStreakChip,
                weightTrendDirection: context.weightSummary.direction,
                asOf: context.asOf,
                calendar: context.calendar
            )
        )
    }

    // MARK: - Weekly review

    static func weeklyReview(context: Context) -> JourneyWeeklyReviewState {
        let weekLogs = context.weekLogs
        let previousWeekLogs = context.previousWeekLogs
        let total = JourneyLogMetrics.weekDayCount

        let foodDays = JourneyLogMetrics.foodLoggedDays(in: weekLogs)
        let proteinDays = JourneyLogMetrics.proteinGoalDays(in: weekLogs)
        let waterDays = JourneyLogMetrics.waterGoalDays(in: weekLogs)
        let calorieDays = JourneyLogMetrics.calorieAdherenceDays(in: weekLogs)

        let proteinEligible = weekLogs.filter { $0.targets.proteinTarget > 0 }
        let waterEligible = weekLogs.filter { $0.targets.waterTargetMl > 0 }
        let calorieEligible = weekLogs.filter { $0.targets.calorieTarget > 0 }

        let trainingDays = context.weeklyTraining.workoutDays ?? 0
        let expectedTraining = JourneyWeeklyReviewBuilder.expectedTrainingDays(profile: context.profile)

        let weightDelta = JourneyLogMetrics.weightDelta(in: context.weekWeights)

        let weekSummaryCopy = JourneyWeeklyReviewBuilder.weekSummaryCopy(
            foodDays: foodDays,
            proteinDays: proteinDays,
            trainingDays: trainingDays,
            goalDirection: context.baseline.goalDirection,
            weightDelta: weightDelta
        )

        let previousWeek = JourneyWeeklyReviewBuilder.previousWeekMetrics(
            logs: previousWeekLogs,
            weekWeights: context.previousWeekWeights,
            trainingDays: context.previousWeekTrainingDays
        )

        var review = JourneyWeeklyReviewState(
            foodLoggedDays: foodDays,
            foodLoggedDaysTotal: total,
            proteinGoalDays: proteinDays,
            proteinGoalDaysTotal: max(proteinEligible.count, total),
            waterGoalDays: waterDays,
            waterGoalDaysTotal: max(waterEligible.count, total),
            trainingDays: trainingDays,
            expectedTrainingDays: expectedTraining,
            training: context.weeklyTraining,
            weightDeltaThisWeekKg: weightDelta,
            calorieAdherenceDays: calorieDays,
            calorieAdherenceDaysTotal: max(calorieEligible.count, total),
            weekSummaryCopy: weekSummaryCopy,
            rows: [],
            weekOverWeekDetail: nil
        )

        return JourneyWeeklyReviewBuilder.enrich(
            review: review,
            previousWeek: previousWeek.hasComparableData ? previousWeek : nil,
            goalDirection: context.baseline.goalDirection,
            streaks: context.journeyStreaks
        )
    }

    // MARK: - Milestones

    static func milestones(context: Context) -> JourneyMilestonesState {
        JourneyMilestonesBuilder.build(
            JourneyMilestonesBuilder.Input(
                baseline: context.baseline,
                maturityLogs: context.maturityLogs,
                journeyStreaks: context.journeyStreaks,
                healthWorkoutDayStarts: context.healthWorkoutDayStarts,
                calendar: context.calendar
            )
        )
    }

    // MARK: - Story timeline

    static func storyTimeline(context: Context) -> JourneyStoryTimelineState {
        JourneyTimelineBuilder.build(
            JourneyTimelineBuilder.Input(
                profile: context.profile,
                baseline: context.baseline,
                maturityLogs: context.maturityLogs,
                allWeights: context.allWeights,
                healthWorkoutDayStarts: context.healthWorkoutDayStarts,
                isAppleHealthConnected: context.weeklyTraining.isConnected,
                journeyStreaks: context.journeyStreaks,
                asOf: context.asOf,
                calendar: context.calendar
            )
        )
    }
}
