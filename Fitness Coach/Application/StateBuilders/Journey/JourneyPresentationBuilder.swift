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
        let milestones = JourneyDashboardBuilder.milestones(context: context)
        let timeline = JourneyDashboardBuilder.storyTimeline(context: context)

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
                unlockedMilestoneCount: milestones.unlocked.count,
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
            milestone: JourneyMilestoneState.fromMilestones(milestones),
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
        let copy = FormaProductCopy.Journey.GoalProjection.self
        let baseline = context.baseline

        guard baseline.goalWeightKg != nil else {
            return JourneyGoalProjectionState(
                sectionTitle: copy.sectionTitle,
                status: .hidden
            )
        }

        switch baseline.goalDirection {
        case .maintain:
            guard baseline.hasRealWeightEntries else {
                return JourneyGoalProjectionState(
                    sectionTitle: copy.sectionTitle,
                    status: .insufficientData(
                        title: copy.insufficientTitle,
                        detail: copy.insufficientDetail
                    )
                )
            }
            return JourneyGoalProjectionState(
                sectionTitle: copy.sectionTitle,
                status: .projected(
                    title: copy.maintainTitle,
                    detail: copy.maintainDetail,
                    etaLabel: nil,
                    confidenceLabel: nil,
                    remainingLabel: nil
                )
            )

        case .lose, .gain:
            guard let projection = context.goalProjection,
                  let projectedDate = projection.projectedGoalDate,
                  projection.weeklyRateKg != nil else {
                return JourneyGoalProjectionState(
                    sectionTitle: copy.sectionTitle,
                    status: .insufficientData(
                        title: copy.insufficientTitle,
                        detail: copy.insufficientDetail
                    )
                )
            }

            let monthLabel = JourneyFormatter.monthYear(projectedDate)
            let weeksLabel = JourneyFormatter.weeks(projection.estimatedWeeksToGoal)
            let remainingLabel = baseline.remainingChangeKg.map {
                copy.remainingLabel(kg: JourneyFormatter.heroChangeKg($0))
            }
            let confidenceLabel = copy.confidenceLabel(
                JourneyFormatter.shortConfidence(projection.confidence)
            )

            return JourneyGoalProjectionState(
                sectionTitle: copy.sectionTitle,
                status: .projected(
                    title: copy.projectedTitle(month: monthLabel),
                    detail: copy.projectedDetail(weeks: weeksLabel),
                    etaLabel: monthLabel,
                    confidenceLabel: confidenceLabel,
                    remainingLabel: remainingLabel
                )
            )
        }
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
                milestone: JourneyMilestoneState.fromMilestones(milestones),
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
