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
        var weekLogs: [DailyLog]
        var previousWeekLogs: [DailyLog]
        var previousWeekWeights: [WeightEntry]
        var previousWeekTrainingDays: Int
        var monthLogs: [DailyLog]
        var allWeights: [WeightEntry]
        var weekWeights: [WeightEntry]
        var journeyStreaks: JourneyStreakState
        var weeklyTraining: JourneyWeeklyTrainingStatus
        var weightSummary: ProgressWeightSummary
        var goalProjection: ProgressProjection?
        var healthWorkoutDayStarts: Set<Date>
        var monthHealthWorkoutCount: Int
        var nutritionSummary: ProgressNutritionSummary
        var waterSummary: ProgressWaterSummary
        var workoutSummary: ProgressWorkoutSummary?
        var selectedRangeDays: Int
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

    // MARK: - Habit insights

    static func habitInsights(context: Context) -> JourneyHabitInsightsState {
        let expectedTraining = JourneyWeeklyReviewBuilder.expectedTrainingDays(profile: context.profile)
        return JourneyHabitInsightsBuilder.build(
            JourneyHabitInsightsBuilder.Input(
                profile: context.profile,
                maturityLogs: context.maturityLogs,
                weekLogs: context.weekLogs,
                weekWeights: context.weekWeights,
                healthWorkoutDayStarts: context.healthWorkoutDayStarts,
                isAppleHealthConnected: context.weeklyTraining.isConnected,
                expectedTrainingDaysPerWeek: expectedTraining,
                hasRealWeightEntries: context.baseline.hasRealWeightEntries,
                asOf: context.asOf,
                calendar: context.calendar
            )
        )
    }

    // MARK: - Progress attribution

    static func progressAttribution(context: Context) -> JourneyProgressAttributionState {
        let weeklyTrainingDays = context.weeklyTraining.workoutDays ?? 0
        return JourneyProgressAttributionBuilder.build(
            JourneyProgressAttributionBuilder.Input(
                currentPeriodLogs: context.maturityLogs,
                previousPeriodLogs: context.previousWeekLogs,
                weekLogs: context.weekLogs,
                previousWeekLogs: context.previousWeekLogs,
                weightSummary: context.weightSummary,
                goalDirection: context.baseline.goalDirection,
                weeklyTrainingDays: weeklyTrainingDays,
                previousWeekTrainingDays: context.previousWeekTrainingDays,
                isAppleHealthConnected: context.weeklyTraining.isConnected,
                asOf: context.asOf,
                calendar: context.calendar
            )
        )
    }

    // MARK: - Before vs today

    static func beforeToday(context: Context) -> JourneyBeforeTodayState {
        JourneyBeforeTodayBuilder.build(
            JourneyBeforeTodayBuilder.Input(
                profile: context.profile,
                baseline: context.baseline,
                asOf: context.asOf,
                calendar: context.calendar
            )
        )
    }

    // MARK: - Personal records

    static func personalRecords(context: Context) -> JourneyPersonalRecordsState {
        JourneyPersonalRecordsBuilder.build(
            JourneyPersonalRecordsBuilder.Input(
                maturityLogs: context.maturityLogs,
                allWeights: context.allWeights,
                healthWorkoutDayStarts: context.healthWorkoutDayStarts,
                goalDirection: context.baseline.goalDirection,
                isAppleHealthConnected: context.weeklyTraining.isConnected,
                calendar: context.calendar
            )
        )
    }

    // MARK: - Monthly recap

    static func monthlyRecap(context: Context) -> JourneyMonthlyRecapState {
        let expectedTraining = JourneyWeeklyReviewBuilder.expectedTrainingDays(profile: context.profile)
        return JourneyMonthlyRecapBuilder.build(
            JourneyMonthlyRecapBuilder.Input(
                monthLogs: context.monthLogs,
                maturityLogs: context.maturityLogs,
                allWeights: context.allWeights,
                healthWorkoutDayStarts: context.healthWorkoutDayStarts,
                monthHealthWorkoutCount: context.monthHealthWorkoutCount,
                goalDirection: context.baseline.goalDirection,
                isAppleHealthConnected: context.weeklyTraining.isConnected,
                expectedTrainingDaysPerWeek: expectedTraining,
                asOf: context.asOf,
                calendar: context.calendar
            )
        )
    }

    // MARK: - Journey level

    static func journeyLevel(context: Context) -> JourneyLevelState {
        let unlockedMilestones = milestones(context: context).unlocked.count
        return JourneyLevelBuilder.build(
            JourneyLevelBuilder.Input(
                maturityLogs: context.maturityLogs,
                allWeights: context.allWeights,
                healthWorkoutDayStarts: context.healthWorkoutDayStarts,
                isAppleHealthConnected: context.weeklyTraining.isConnected,
                unlockedMilestoneCount: unlockedMilestones,
                calendar: context.calendar
            )
        )
    }

    // MARK: - Detailed analytics

    static func detailedAnalytics(
        context: Context,
        weightInterpretation: String
    ) -> JourneyDetailedAnalyticsState {
        let rangeStart = context.calendar.date(
            byAdding: .day,
            value: -context.selectedRangeDays + 1,
            to: context.asOf
        ) ?? context.asOf

        let chartPoints = JourneyBaselineResolver.chartPointsInRange(
            context.baseline.chartPoints,
            from: rangeStart,
            to: context.asOf,
            calendar: context.calendar
        )

        return JourneyDetailedAnalyticsState(
            isCollapsedByDefault: true,
            nutritionSummary: context.nutritionSummary,
            waterSummary: context.waterSummary,
            trainingDisplay: trainingAnalyticsDisplay(
                weeklyTraining: context.weeklyTraining,
                workoutSummary: context.workoutSummary
            ),
            weightChartPoints: chartPoints,
            weightTrendInterpretation: weightInterpretation,
            showsWeightChart: context.baseline.showsWeightChart && !chartPoints.isEmpty,
            weightLogCTA: context.baseline.showsWeightChart && !chartPoints.isEmpty
                ? nil
                : .logWeight
        )
    }

    static func trainingAnalyticsDisplay(
        weeklyTraining: JourneyWeeklyTrainingStatus,
        workoutSummary: ProgressWorkoutSummary?
    ) -> JourneyDetailedAnalyticsTrainingDisplay {
        switch weeklyTraining {
        case .hidden, .locked:
            return .hidden
        case .connectedEmpty:
            return .connectedEmpty
        case .connected:
            if let workoutSummary, workoutSummary.isFromAppleHealth {
                return .metrics(workoutSummary)
            }
            return .hidden
        }
    }

    static func weightTrendInterpretation(summary: ProgressWeightSummary) -> String {
        let copy = FormaProductCopy.Journey.DetailedAnalytics.WeightTrend.self
        if summary.hasSuddenSpike {
            if let change = summary.changeKg, change > 0 {
                return copy.spikeUp
            }
            return copy.spikeGeneral
        }

        switch summary.direction {
        case .decreasing:
            return copy.decreasing
        case .increasing:
            return copy.increasing
        case .stable:
            return copy.stable
        case .insufficientData:
            return copy.insufficientData
        }
    }
}
