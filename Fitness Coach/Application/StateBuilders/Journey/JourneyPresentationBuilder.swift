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
        loggedDays: Int,
        weeklyProgressSummaryBuilder: WeeklyProgressSummaryBuilding = WeeklyProgressSummaryBuilder()
    ) -> JourneyDashboardState {
        let weeklyReview = JourneyDashboardBuilder.weeklyReview(context: context)
        let weeklyProgressSummary = JourneyDashboardBuilder.weeklyProgressSummary(
            context: context,
            builder: weeklyProgressSummaryBuilder
        )
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
                profile: context.profile,
                maturityLogs: context.maturityLogs,
                allWeights: context.allWeights,
                healthWorkoutDayStarts: context.healthWorkoutDayStarts,
                isAppleHealthConnected: context.weeklyTraining.isConnected,
                unlockedMilestoneCount: milestoneResult.unlockedCount,
                checkInStreakDays: streakSummary.checkInStreak,
                weeklyReviewUnlocked: weeklyProgressSummary.foodLoggedDays > 0
                    && weeklyProgressSummary.totalDays >= JourneyThresholds.requiredCalendarSpanDays,
                calendar: context.calendar
            )
        )

        let events = storyEvents(from: timeline, calendar: context.calendar)
        let insightState = personalizedInsights(context: context)
        let projectionState = goalProjection(context: context)
        let recapState = monthlyRecapState(from: monthlyRecap)

        let screenPresentation = JourneyScreenPresentationBuilder.build(
            JourneyScreenPresentationBuilder.Input(
                context: context,
                weeklyProgressSummary: weeklyProgressSummary,
                chapter: chapter,
                storyEvents: events,
                insight: insightState,
                goalProjection: projectionState,
                freshnessInput: nil
            )
        )
        let momentumState = momentum(from: screenPresentation)
        let transformationState = hero(
            context: context,
            loggedDays: loggedDays,
            hasProfile: hasProfile
        )
        let unifiedWeeklyReview = UnifiedWeeklyReviewPresentationBuilder.build(
            UnifiedWeeklyReviewInput(
                summary: weeklyProgressSummary,
                weeklyHabit: weeklyHabit,
                profile: context.profile,
                goalDirection: context.baseline.goalDirection,
                dailyReviewsThisWeekCount: context.weekLogs.filter { $0.dailyReviewId != nil }.count,
                screenPresentation: screenPresentation
            )
        )
        let dashboardHero = JourneyDashboardHeroBuilder.build(
            JourneyDashboardHeroBuilder.Input(
                screenPresentation: screenPresentation,
                weeklySummary: weeklyProgressSummary,
                hasProfile: hasProfile
            )
        )
        let progressSection = JourneyProgressSectionBuilder.build(
            JourneyProgressSectionBuilder.Input(
                screenPresentation: screenPresentation,
                unifiedWeeklyReview: unifiedWeeklyReview,
                goalProjection: projectionState,
                connectHealthCTA: nil
            )
        )

        return JourneyDashboardState(
            hasProfile: hasProfile,
            baseline: context.baseline,
            streaks: context.journeyStreaks,
            screenPresentation: screenPresentation,
            unifiedWeeklyReview: unifiedWeeklyReview,
            dashboardHero: dashboardHero,
            progressSection: progressSection,
            header: header(momentum: momentumState, transformation: transformationState),
            momentum: momentumState,
            transformation: transformationState,
            goalProjection: projectionState,
            milestone: milestoneResult.presentation,
            storyEvents: events,
            insight: insightState,
            weeklyHabit: weeklyHabit,
            monthlyRecap: recapState,
            chapter: chapter,
            weeklyProgressSummary: weeklyProgressSummary,
            dailyReviewsThisWeekCount: context.weekLogs.filter { $0.dailyReviewId != nil }.count
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
        from presentation: JourneyScreenPresentationState
    ) -> JourneyMomentumState {
        let copy = FormaProductCopy.Journey.Momentum.self
        let streaks = presentation.streaks

        guard streaks.primaryMomentumDays > 0 else {
            return JourneyMomentumState(
                isVisible: false,
                sectionTitle: copy.sectionTitle,
                headline: copy.buildingHeadline,
                detail: nil,
                streakDays: 0,
                emptyMessage: copy.buildingHeadline
            )
        }

        return JourneyMomentumState(
            isVisible: true,
            sectionTitle: copy.sectionTitle,
            headline: streaks.primaryMomentumLabel,
            detail: streaks.momentumDetail,
            streakDays: streaks.primaryMomentumDays,
            emptyMessage: nil
        )
    }

    /// Legacy entry point retained for fixture assembly paths.
    static func momentum(
        context: JourneyDashboardBuilder.Context,
        loggedDays: Int
    ) -> JourneyMomentumState {
        let presentation = JourneyScreenPresentationBuilder.build(
            JourneyScreenPresentationBuilder.Input(
                context: context,
                weeklyProgressSummary: JourneyDashboardBuilder.weeklyProgressSummary(context: context),
                chapter: JourneyChapterBuilder.build(
                    JourneyChapterBuilder.Input(
                        profile: context.profile,
                        maturityLogs: context.maturityLogs,
                        allWeights: context.allWeights,
                        healthWorkoutDayStarts: context.healthWorkoutDayStarts,
                        isAppleHealthConnected: context.weeklyTraining.isConnected,
                        unlockedMilestoneCount: 0,
                        checkInStreakDays: StreakCalculator.calculate(
                            logs: context.maturityLogs,
                            workoutDates: context.healthWorkoutDayStarts,
                            asOf: context.asOf,
                            calendar: context.calendar
                        ).checkInStreak,
                        weeklyReviewUnlocked: false,
                        calendar: context.calendar
                    )
                ),
                storyEvents: [],
                insight: personalizedInsights(context: context),
                goalProjection: goalProjection(context: context),
                freshnessInput: nil
            )
        )
        _ = loggedDays
        return momentum(from: presentation)
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
        asOf: Date = Date(),
        weeklyProgressSummaryBuilder: WeeklyProgressSummaryBuilding = WeeklyProgressSummaryBuilder()
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

        let weeklyProgressSummary = JourneyDashboardBuilder.weeklyProgressSummary(
            context: context,
            builder: weeklyProgressSummaryBuilder
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
            return buildDashboard(
                hasProfile: hasProfile,
                context: context,
                loggedDays: loggedDays,
                weeklyProgressSummaryBuilder: weeklyProgressSummaryBuilder
            )
        }

        return buildDashboard(
            hasProfile: hasProfile,
            context: context,
            loggedDays: loggedDays,
            weeklyProgressSummaryBuilder: weeklyProgressSummaryBuilder
        )
    }
}
