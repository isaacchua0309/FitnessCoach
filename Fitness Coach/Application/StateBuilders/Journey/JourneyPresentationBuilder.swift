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
        let streakSummary = StreakCalculator.calculate(
            logs: context.maturityLogs,
            workoutDates: context.healthWorkoutDayStarts,
            asOf: context.asOf,
            calendar: context.calendar
        )
        let weeklyHabit = JourneyWeeklyPatternBuilder.build(
            JourneyWeeklyPatternBuilder.Input(
                weekLogs: context.weekLogs,
                weekWeights: context.weekWeights,
                maturityLogs: context.maturityLogs,
                allWeights: context.allWeights,
                healthWorkoutDayStarts: context.healthWorkoutDayStarts,
                weeklyTraining: context.weeklyTraining,
                expectedTrainingDays: JourneyWeeklyReviewBuilder.expectedTrainingDays(
                    profile: context.profile
                ),
                streaks: context.journeyStreaks,
                streakSummary: streakSummary,
                weeklyReview: weeklyReview,
                asOf: context.asOf,
                calendar: context.calendar
            )
        )
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
            unlockedMilestoneCount: milestoneResult.unlockedCount
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

        let chapter = JourneyChapterBuilder.build(
            JourneyChapterBuilder.Input(
                maturityLogs: context.maturityLogs,
                allWeights: context.allWeights,
                healthWorkoutDayStarts: context.healthWorkoutDayStarts,
                isAppleHealthConnected: context.weeklyTraining.isConnected,
                unlockedMilestoneCount: milestoneResult.unlockedCount,
                calendar: context.calendar
            )
        )

        let momentumState = momentum(context: context, loggedDays: loggedDays)
        let transformationState = hero(
            context: context,
            loggedDays: loggedDays,
            hasProfile: hasProfile
        )

        return JourneyDashboardState(
            hasProfile: hasProfile,
            baseline: context.baseline,
            streaks: context.journeyStreaks,
            header: header(momentum: momentumState, transformation: transformationState),
            momentum: momentumState,
            transformation: transformationState,
            goalProjection: goalProjection(context: context),
            milestone: milestoneResult.presentation,
            storyEvents: storyEvents(from: timeline, calendar: context.calendar),
            insight: personalizedInsights(context: context),
            weeklyHabit: weeklyHabit,
            monthlyRecap: monthlyRecapState(from: monthlyRecap),
            chapter: chapter
        )
    }

    // MARK: - Header

    static func header(
        momentum: JourneyMomentumState,
        transformation: JourneyTransformationState
    ) -> JourneyHeaderState {
        let copy = FormaProductCopy.Journey.Header.self
        let subtitle = momentum.isVisible
            ? momentum.headline
            : transformation.primaryMessage

        return JourneyHeaderState(
            title: copy.title,
            subtitle: subtitle,
            accessibilitySummary: "\(copy.title). \(subtitle)"
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

    // MARK: - Personalized insights

    static func personalizedInsights(context: JourneyDashboardBuilder.Context) -> JourneyInsightState {
        personalizedInsights(
            profile: context.profile,
            baseline: context.baseline,
            weekLogs: context.weekLogs,
            allWeights: context.allWeights,
            healthWorkoutDayStarts: context.healthWorkoutDayStarts,
            isAppleHealthConnected: context.weeklyTraining.isConnected,
            asOf: context.asOf,
            calendar: context.calendar
        )
    }

    private static func personalizedInsights(
        profile: UserProfile?,
        baseline: JourneyBaseline,
        weekLogs: [DailyLog],
        allWeights: [WeightEntry],
        healthWorkoutDayStarts: Set<Date>,
        isAppleHealthConnected: Bool,
        asOf: Date,
        calendar: Calendar
    ) -> JourneyInsightState {
        JourneyPersonalizedInsightsBuilder.build(
            JourneyPersonalizedInsightsBuilder.Input(
                profile: profile,
                baseline: baseline,
                weekLogs: weekLogs,
                allWeights: allWeights,
                healthWorkoutDayStarts: healthWorkoutDayStarts,
                isAppleHealthConnected: isAppleHealthConnected,
                expectedTrainingDaysPerWeek: JourneyWeeklyReviewBuilder.expectedTrainingDays(
                    profile: profile
                ),
                asOf: asOf,
                calendar: calendar
            )
        )
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

        let streakSummary = StreakCalculator.calculate(
            logs: maturityLogs,
            workoutDates: healthWorkoutDayStarts,
            asOf: asOf,
            calendar: calendar
        )
        let weeklyHabit = JourneyWeeklyPatternBuilder.build(
            JourneyWeeklyPatternBuilder.Input(
                weekLogs: weekLogs,
                weekWeights: weekWeights,
                maturityLogs: maturityLogs,
                allWeights: allWeights,
                healthWorkoutDayStarts: healthWorkoutDayStarts,
                weeklyTraining: training,
                expectedTrainingDays: JourneyWeeklyReviewBuilder.expectedTrainingDays(profile: profile),
                streaks: streaks,
                streakSummary: streakSummary,
                weeklyReview: weeklyReview,
                asOf: asOf,
                calendar: calendar
            )
        )

        if maturityLogs.isEmpty, weekLogs.isEmpty {
            let momentumState = momentum(context: context, loggedDays: loggedDays)
            let transformationState = hero(
                context: context,
                loggedDays: loggedDays,
                hasProfile: hasProfile
            )
            let monthName = asOf.formatted(.dateTime.month(.wide))
            let recapCopy = FormaProductCopy.Journey.MonthlyRecap.self
            let chapterCopy = FormaProductCopy.Journey.Chapters.self

            return JourneyDashboardState(
                hasProfile: hasProfile,
                baseline: baseline,
                streaks: streaks,
                header: header(momentum: momentumState, transformation: transformationState),
                momentum: momentumState,
                transformation: transformationState,
                goalProjection: Self.goalProjection(context: context),
                milestone: milestoneResult.presentation,
                storyEvents: storyEvents(from: storyTimeline, calendar: calendar),
                insight: personalizedInsights(
                    profile: profile,
                    baseline: baseline,
                    weekLogs: [],
                    allWeights: [],
                    healthWorkoutDayStarts: [],
                    isAppleHealthConnected: training.isConnected,
                    asOf: asOf,
                    calendar: calendar
                ),
                weeklyHabit: weeklyHabit,
                monthlyRecap: JourneyMonthlyRecapState(
                    isVisible: false,
                    sectionTitle: recapCopy.sectionTitle(monthName: monthName),
                    showsTeaser: false,
                    teaserTitle: nil,
                    teaserDetail: nil,
                    overallGrade: nil,
                    overallGradeLabel: nil,
                    loggedDays: 0,
                    monthWeightDeltaKg: nil,
                    calorieAdherencePercent: nil,
                    proteinAdherencePercent: nil,
                    waterAdherencePercent: nil,
                    trainingSessions: nil,
                    bestStreakDays: nil,
                    rows: [],
                    accessibilitySummary: recapCopy.sectionTitle(monthName: monthName)
                ),
                chapter: JourneyChapterState(
                    isVisible: true,
                    sectionTitle: chapterCopy.sectionTitle,
                    chapterNumber: 1,
                    chapterTitle: chapterCopy.title(for: 1),
                    nextUnlockLabel: chapterCopy.nextUnlock(chapterCopy.title(for: 2)),
                    progressPercent: 0,
                    emptyMessage: chapterCopy.emptyBody,
                    totalXP: 0,
                    accessibilitySummary: "\(chapterCopy.sectionTitle). \(chapterCopy.chapterLabel(1))"
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
