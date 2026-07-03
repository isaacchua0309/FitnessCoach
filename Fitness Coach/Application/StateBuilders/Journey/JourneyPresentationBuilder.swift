//
//  JourneyPresentationBuilder.swift
//  Fitness Coach
//
//  Forma — Assembles Journey presentation sections from dashboard builder context.
//

import Foundation

enum JourneyPresentationBuilder {

    // MARK: - Dashboard

    static func buildDashboard(
        hasProfile: Bool,
        context: JourneyDashboardBuilder.Context,
        loggedDays: Int
    ) -> JourneyDashboardState {
        let weeklyReview = JourneyDashboardBuilder.weeklyReview(context: context)
        let milestoneResult = JourneyNextMilestoneBuilder.build(
            JourneyNextMilestoneBuilder.Input(
                profile: context.profile,
                baseline: context.baseline,
                maturityLogs: context.maturityLogs,
                allWeights: context.allWeights,
                healthWorkoutDayStarts: context.healthWorkoutDayStarts,
                asOf: context.asOf,
                calendar: context.calendar
            )
        )
        let timeline = JourneyDashboardBuilder.storyTimeline(
            context: context,
            additionalEvents: milestoneResult.completedTimelineEvents
        )

        let habitInsights = JourneyHabitInsightsBuilder.build(
            JourneyHabitInsightsBuilder.Input(
                profile: context.profile,
                maturityLogs: context.maturityLogs,
                weekLogs: context.weekLogs,
                weekWeights: context.weekWeights,
                healthWorkoutDayStarts: context.healthWorkoutDayStarts,
                isAppleHealthConnected: context.weeklyTraining.isConnected,
                expectedTrainingDaysPerWeek: context.profile?.trainingFrequencyPerWeek ?? 0,
                hasRealWeightEntries: context.baseline.hasRealWeightEntries,
                asOf: context.asOf,
                calendar: context.calendar
            )
        )

        let monthlyRecap = JourneyMonthlyRecapBuilder.build(
            JourneyMonthlyRecapBuilder.Input(
                monthLogs: context.monthLogs,
                maturityLogs: context.maturityLogs,
                allWeights: context.allWeights,
                healthWorkoutDayStarts: context.healthWorkoutDayStarts,
                monthHealthWorkoutCount: context.monthHealthWorkoutCount,
                goalDirection: context.baseline.goalDirection,
                isAppleHealthConnected: context.weeklyTraining.isConnected,
                expectedTrainingDaysPerWeek: context.profile?.trainingFrequencyPerWeek ?? 0,
                asOf: context.asOf,
                calendar: context.calendar
            )
        )

        let level = JourneyLevelBuilder.build(
            JourneyLevelBuilder.Input(
                maturityLogs: context.maturityLogs,
                allWeights: context.allWeights,
                healthWorkoutDayStarts: context.healthWorkoutDayStarts,
                isAppleHealthConnected: context.weeklyTraining.isConnected,
                unlockedMilestoneCount: milestoneResult.unlockedCount,
                calendar: context.calendar
            )
        )

        return JourneyDashboardState(
            hasProfile: hasProfile,
            baseline: context.baseline,
            streaks: context.journeyStreaks,
            momentum: momentum(context: context, loggedDays: loggedDays),
            transformation: hero(context: context, loggedDays: loggedDays, hasProfile: hasProfile),
            goalProjection: goalProjection(context: context),
            milestone: milestoneResult.presentation,
            storyEvents: storyEvents(from: timeline, calendar: context.calendar),
            insight: JourneyInsightState.fromHabitInsights(habitInsights),
            weeklyHabit: JourneyWeeklyHabitState.fromWeeklyReview(weeklyReview),
            monthlyRecap: monthlyRecapState(from: monthlyRecap),
            chapter: JourneyChapterState.fromLevel(level)
        )
    }

    // MARK: - Momentum

    static func momentum(
        context: JourneyDashboardBuilder.Context,
        loggedDays: Int
    ) -> JourneyMomentumState {
        let copy = FormaProductCopy.Journey.Momentum.self
        let streaks = context.journeyStreaks
        let loggingStreak = streaks.currentLoggingStreakDays
        let longestStreak = streaks.longestLoggingStreakDays

        guard loggedDays > 0 || loggingStreak > 0 else {
            return JourneyMomentumState(
                isVisible: false,
                sectionTitle: copy.sectionTitle,
                headline: copy.buildingHeadline,
                detail: nil,
                streakDays: 0,
                emptyMessage: copy.buildingHeadline
            )
        }

        let headline = loggingStreak > 0
            ? copy.activeHeadline(days: loggingStreak)
            : copy.buildingHeadline

        var detail: String?
        if longestStreak > loggingStreak {
            detail = copy.longestStreakDetail(days: longestStreak)
        } else if !streaks.isTodayLogged, loggingStreak > 0 {
            detail = copy.keepStreakAlive
        } else if let keepAlive = streaks.keepStreakAliveCopy {
            detail = keepAlive
        }

        return JourneyMomentumState(
            isVisible: true,
            sectionTitle: copy.sectionTitle,
            headline: headline,
            detail: detail,
            streakDays: loggingStreak,
            emptyMessage: nil
        )
    }

    // MARK: - Hero

    static func hero(
        context: JourneyDashboardBuilder.Context,
        loggedDays: Int,
        hasProfile: Bool
    ) -> JourneyTransformationState {
        JourneyHeroBuilder.build(
            JourneyHeroBuilder.Input(
                baseline: context.baseline,
                loggedDays: loggedDays,
                journeyStreaks: context.journeyStreaks,
                hasProfile: hasProfile,
                asOf: context.asOf,
                calendar: context.calendar
            )
        )
    }

    // MARK: - Goal projection

    static func goalProjection(
        context: JourneyDashboardBuilder.Context
    ) -> JourneyGoalProjectionState {
        JourneyGoalProjectionBuilder.build(
            JourneyGoalProjectionBuilder.Input(
                baseline: context.baseline,
                allWeights: context.allWeights,
                asOf: context.asOf,
                calendar: context.calendar
            )
        )
    }

    // MARK: - Story events

    static func storyEvents(
        from timeline: JourneyStoryTimelineState,
        calendar: Calendar
    ) -> [JourneyStoryEvent] {
        timeline.displayEvents.map {
            JourneyStoryEvent.fromTimelineEvent($0, calendar: calendar)
        }
    }

    // MARK: - Monthly recap

    static func monthlyRecapState(
        from recap: JourneyMonthlyRecapState
    ) -> JourneyMonthlyRecapState {
        var state = recap
        state.isVisible = recap.loggedDays > 0 || recap.isComplete
        return state
    }

    // MARK: - Preview / fixture assembly

    static func assembleFromLegacy(
        hasProfile: Bool,
        baseline: JourneyBaseline,
        streaks: JourneyStreakState,
        loggedDays: Int,
        weeklyReview: JourneyWeeklyReviewState,
        milestones: JourneyMilestonesState,
        storyTimeline: JourneyStoryTimelineState,
        goalProjection: ProgressProjection? = nil,
        profile: UserProfile? = nil,
        maturityLogs: [DailyLog] = [],
        monthLogs: [DailyLog] = [],
        weekLogs: [DailyLog] = [],
        allWeights: [WeightEntry] = [],
        weekWeights: [WeightEntry] = [],
        weeklyTraining: JourneyWeeklyTrainingStatus? = nil,
        healthWorkoutDayStarts: Set<Date> = [],
        monthHealthWorkoutCount: Int = 0,
        weightTrendDirection: WeightTrendDirection = .insufficientData,
        calendar: Calendar = .current,
        asOf: Date = Date()
    ) -> JourneyDashboardState {
        let training = weeklyTraining ?? weeklyReview.training
        let weightSummary = ProgressWeightSummary(
            latestWeightKg: baseline.currentWeightKg,
            changeKg: baseline.totalChangeKg,
            direction: weightTrendDirection,
            hasSuddenSpike: false
        )

        let context = JourneyDashboardBuilder.Context(
            profile: profile,
            baseline: baseline,
            maturityLogs: maturityLogs,
            monthLogs: monthLogs.isEmpty ? weekLogs : monthLogs,
            weekLogs: weekLogs.isEmpty ? maturityLogs : weekLogs,
            previousWeekLogs: [],
            previousWeekWeights: [],
            previousWeekTrainingDays: 0,
            allWeights: allWeights,
            weekWeights: weekWeights.isEmpty ? allWeights : weekWeights,
            journeyStreaks: streaks,
            weeklyTraining: training,
            weightSummary: weightSummary,
            goalProjection: goalProjection,
            healthWorkoutDayStarts: healthWorkoutDayStarts,
            monthHealthWorkoutCount: monthHealthWorkoutCount,
            asOf: asOf,
            calendar: calendar
        )

        let milestoneResult = JourneyNextMilestoneBuilder.build(
            JourneyNextMilestoneBuilder.Input(
                profile: profile,
                baseline: baseline,
                maturityLogs: maturityLogs,
                allWeights: allWeights,
                healthWorkoutDayStarts: healthWorkoutDayStarts,
                asOf: asOf,
                calendar: calendar
            )
        )

        if maturityLogs.isEmpty, weekLogs.isEmpty {
            return JourneyDashboardState(
                hasProfile: hasProfile,
                baseline: baseline,
                streaks: streaks,
                momentum: momentum(context: context, loggedDays: loggedDays),
                transformation: hero(
                    context: context,
                    loggedDays: loggedDays,
                    hasProfile: hasProfile
                ),
                goalProjection: goalProjection(context: context),
                milestone: milestoneResult.presentation,
                storyEvents: storyEvents(from: storyTimeline, calendar: calendar),
                insight: JourneyInsightState.fromHabitInsights(.locked),
                weeklyHabit: JourneyWeeklyHabitState.fromWeeklyReview(weeklyReview),
                monthlyRecap: JourneyMonthlyRecapState(
                    isVisible: false,
                    sectionTitle: FormaProductCopy.Journey.MonthlyRecap.sectionTitle(
                        monthName: asOf.formatted(.dateTime.month(.wide))
                    ),
                    isComplete: false,
                    buildingMessage: FormaProductCopy.Journey.MonthlyRecap.buildingBody,
                    monthWeightDeltaKg: nil,
                    calorieAdherencePercent: nil,
                    proteinAdherencePercent: nil,
                    waterAdherencePercent: nil,
                    trainingSessions: nil,
                    showsTrainingRow: training.isConnected,
                    loggedDays: 0,
                    bestHabitCopy: nil,
                    summaryCopy: "",
                    rows: []
                ),
                chapter: JourneyChapterState(
                    isVisible: false,
                    sectionTitle: FormaProductCopy.Journey.Level.sectionTitle,
                    levelLabel: FormaProductCopy.Journey.Level.levelLabel(1),
                    levelTitle: FormaProductCopy.Journey.Level.title(for: 1),
                    xpProgressLabel: FormaProductCopy.Journey.Level.xpProgress(current: 0, required: 100),
                    progressPercent: 0,
                    totalXP: 0,
                    explanation: FormaProductCopy.Journey.Level.emptyBody,
                    emptyMessage: FormaProductCopy.Journey.Level.emptyBody
                )
            )
        }

        return buildDashboard(
            hasProfile: hasProfile,
            context: context,
            loggedDays: loggedDays
        )
    }
}
