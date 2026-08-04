//
//  JourneyScreenPresentationBuilder.swift
//  Fitness Coach
//
//  Forma — Builds the Journey tab's single source-of-truth presentation model.
//

import Foundation

enum JourneyScreenPresentationBuilder {

    struct Input {
        var context: JourneyDashboardBuilder.Context
        var weeklyProgressSummary: WeeklyProgressSummary
        var chapter: JourneyChapterState
        var storyEvents: [JourneyStoryEvent]
        var insight: JourneyInsightState
        var goalProjection: JourneyGoalProjectionState
        var freshnessInput: WeeklyProgressFreshnessInput?
        /// Days in the canonical week with usable recovery signals (Health Intelligence).
        var recoveryDaysWithSignals: Int?
        /// Average daily steps in the canonical week when HealthKit step data is available.
        var averageStepsInWeek: Int?
    }

    // MARK: - Public

    static func build(_ input: Input) -> JourneyScreenPresentationState {
        let context = input.context
        let summary = input.weeklyProgressSummary
        let calendar = context.calendar

        let resolvedRange = WeeklyProgressSummaryBuilder.resolveWeekRange(
            referenceDate: context.asOf,
            dailyLogs: context.maturityLogs,
            calendar: calendar
        )
        let weekRange = WeeklyProgressWeekRange(
            kind: resolvedRange.kind,
            startDate: summary.startDate,
            endDate: summary.endDate,
            totalDays: summary.totalDays
        )

        let windowLogs = WeeklyProgressSummaryBuilder.logs(
            in: weekRange,
            from: context.maturityLogs,
            calendar: calendar
        )
        let weekWeights = WeeklyProgressSummaryBuilder.weights(
            in: weekRange,
            from: context.allWeights,
            calendar: calendar
        )

        let stats = weeklyStats(
            windowLogs: windowLogs,
            weekWeights: weekWeights,
            summary: summary,
            context: context,
            recoveryDaysWithSignals: input.recoveryDaysWithSignals,
            averageStepsInWeek: input.averageStepsInWeek
        )

        let unlocks = unlockState(
            summary: summary,
            stats: stats,
            goalProjection: input.goalProjection,
            insight: input.insight
        )
        let streaks = streakBreakdown(context: context)
        let nextBestAction = nextBestAction(
            stats: stats,
            unlocks: unlocks,
            streaks: streaks,
            isAppleHealthConnected: context.weeklyTraining.isConnected
        )
        let copy = copyPolicy(
            summary: summary,
            stats: stats,
            nextBestAction: nextBestAction
        )
        let unlockDashboard = JourneyUnlockChecklistBuilder.buildDashboardState(
            JourneyUnlockChecklistBuilder.Input(
                stats: stats,
                unlocks: unlocks,
                nextBestAction: nextBestAction,
                summary: summary
            )
        )
        let phase = phaseState(context: context, chapter: input.chapter)
        let sync = syncState(freshnessInput: input.freshnessInput)

        return JourneyScreenPresentationState(
            phase: phase,
            streaks: streaks,
            weekly: JourneyWeeklyPresentationState(
                weekRange: weekRange,
                dateRangeText: JourneyFormatter.timelineDateRangeLabel(
                    start: weekRange.startDate,
                    end: weekRange.endDate,
                    calendar: calendar
                ),
                weekTitle: FormaProductCopy.Journey.WeeklyReview.sectionTitle,
                stats: stats,
                confidence: confidencePresentation(for: summary)
            ),
            unlocks: unlocks,
            unlockDashboard: unlockDashboard,
            nextBestAction: nextBestAction,
            copy: copy,
            sync: sync,
            story: storyPresentation(from: input.storyEvents)
        )
    }

    /// Patches health-derived weekly stats after the Health Intelligence section loads.
    static func patchingHealthIntelligence(
        _ state: JourneyScreenPresentationState,
        recoveryDaysWithSignals: Int?,
        averageStepsInWeek: Int?,
        summary: WeeklyProgressSummary,
        insight: JourneyInsightState,
        goalProjection: JourneyGoalProjectionState,
        isAppleHealthConnected: Bool
    ) -> JourneyScreenPresentationState {
        var patched = state
        patched.weekly.stats.recoveryAvailability = recoveryAvailability(
            daysWithSignals: recoveryDaysWithSignals
        )
        if let averageStepsInWeek {
            patched.weekly.stats.averageSteps = averageStepsInWeek
        }
        patched.unlocks = unlockState(
            summary: summary,
            stats: patched.weekly.stats,
            goalProjection: goalProjection,
            insight: insight
        )
        patched.nextBestAction = nextBestAction(
            stats: patched.weekly.stats,
            unlocks: patched.unlocks,
            streaks: patched.streaks,
            isAppleHealthConnected: isAppleHealthConnected
        )
        patched.copy = copyPolicy(
            summary: summary,
            stats: patched.weekly.stats,
            nextBestAction: patched.nextBestAction
        )
        patched.unlockDashboard = JourneyUnlockChecklistBuilder.buildDashboardState(
            JourneyUnlockChecklistBuilder.Input(
                stats: patched.weekly.stats,
                unlocks: patched.unlocks,
                nextBestAction: patched.nextBestAction,
                summary: summary
            )
        )
        return patched
    }

    // MARK: - Phase

    private static func phaseState(
        context: JourneyDashboardBuilder.Context,
        chapter: JourneyChapterState
    ) -> JourneyPhasePresentationState {
        JourneyPhasePresentationState(
            weekNumber: journeyWeekNumber(
                profile: context.profile,
                maturityLogs: context.maturityLogs,
                asOf: context.asOf,
                calendar: context.calendar
            ),
            chapterTitle: chapter.chapterTitle,
            chapterSubtitle: chapter.nextUnlockLabel
                ?? chapter.emptyMessage
                ?? FormaProductCopy.Journey.Chapters.emptyBody,
            chapterProgressPercent: chapter.progressPercent,
            nextChapterAction: chapter.nextUnlockLabel
        )
    }

    /// 1-based journey week since first meal log or profile creation.
    private static func journeyWeekNumber(
        profile: UserProfile?,
        maturityLogs: [DailyLog],
        asOf: Date,
        calendar: Calendar
    ) -> Int {
        let anchorDay = JourneyLogMetrics.firstFoodLogDate(in: maturityLogs)
            .map { calendar.startOfDay(for: $0) }
            ?? profile.map { calendar.startOfDay(for: $0.createdAt) }
            ?? calendar.startOfDay(for: asOf)

        let daySpan = calendar.dateComponents(
            [.day],
            from: anchorDay,
            to: calendar.startOfDay(for: asOf)
        ).day ?? 0

        return max(1, (daySpan / JourneyLogMetrics.weekDayCount) + 1)
    }

    // MARK: - Streaks

    private static func streakBreakdown(
        context: JourneyDashboardBuilder.Context
    ) -> JourneyStreakBreakdownState {
        let copy = FormaProductCopy.Journey.Streaks.self
        let momentumCopy = FormaProductCopy.Journey.Momentum.self
        let streakSummary = StreakCalculator.calculate(
            logs: context.maturityLogs,
            workoutDates: context.healthWorkoutDayStarts,
            asOf: context.asOf,
            calendar: context.calendar
        )

        let mealLoggingStreak = streakSummary.mealLoggingStreak
        let checkInStreak = streakSummary.checkInStreak
        let activityStreak = streakSummary.workoutStreak

        let longestMeal = StreakCalculator.longestMealLoggingStreak(
            in: context.maturityLogs,
            calendar: context.calendar
        )
        let longestCheckIn = StreakCalculator.longestLoggingStreak(
            in: context.maturityLogs,
            calendar: context.calendar
        )

        let isTodayCheckedIn = StreakCalculator.isLogged(
            on: context.asOf,
            in: context.maturityLogs,
            calendar: context.calendar
        )
        let isTodayMealLogged = StreakCalculator.isMealLogged(
            on: context.asOf,
            in: context.maturityLogs,
            calendar: context.calendar
        )

        let primaryKind: JourneyStreakKind
        let primaryDays: Int
        let primaryLabel: String

        if mealLoggingStreak > 0 {
            primaryKind = .mealLogging
            primaryDays = mealLoggingStreak
            primaryLabel = copy.mealStreak(days: mealLoggingStreak)
        } else if checkInStreak > 0 {
            primaryKind = .checkIn
            primaryDays = checkInStreak
            primaryLabel = copy.checkInStreak(days: checkInStreak)
        } else if activityStreak > 0 {
            primaryKind = .activity
            primaryDays = activityStreak
            primaryLabel = copy.activityStreak(days: activityStreak)
        } else {
            primaryKind = .checkIn
            primaryDays = 0
            primaryLabel = copy.buildingConsistency
        }

        var momentumDetail: String?
        if longestCheckIn > checkInStreak, checkInStreak > 0 {
            momentumDetail = copy.longestCheckInStreak(days: longestCheckIn)
        } else if longestMeal > mealLoggingStreak, mealLoggingStreak > 0 {
            momentumDetail = copy.longestMealStreak(days: longestMeal)
        } else if !isTodayCheckedIn, checkInStreak > 0 {
            momentumDetail = momentumCopy.keepStreakAlive
        } else if let keepAlive = context.journeyStreaks.keepStreakAliveCopy {
            momentumDetail = keepAlive
        }

        return JourneyStreakBreakdownState(
            mealLoggingStreakDays: mealLoggingStreak,
            checkInStreakDays: checkInStreak,
            activityStreakDays: activityStreak,
            longestMealLoggingStreakDays: longestMeal,
            longestCheckInStreakDays: longestCheckIn,
            isTodayCheckedIn: isTodayCheckedIn,
            isTodayMealLogged: isTodayMealLogged,
            primaryMomentumKind: primaryKind,
            primaryMomentumDays: primaryDays,
            primaryMomentumLabel: primaryLabel,
            momentumDetail: momentumDetail,
            keepStreakAliveCopy: context.journeyStreaks.keepStreakAliveCopy
        )
    }

    // MARK: - Weekly stats

    private static func weeklyStats(
        windowLogs: [DailyLog],
        weekWeights: [WeightEntry],
        summary: WeeklyProgressSummary,
        context: JourneyDashboardBuilder.Context,
        recoveryDaysWithSignals: Int?,
        averageStepsInWeek: Int?
    ) -> JourneyWeeklyStatsState {
        let calendar = context.calendar
        let mealLoggingDays = JourneyLogMetrics.uniqueFoodLoggedDays(in: windowLogs, calendar: calendar)

        let stepsValues = windowLogs.compactMap(\.steps).filter { $0 > 0 }
        let resolvedAverageSteps = averageStepsInWeek
            ?? (stepsValues.count >= JourneyThresholds.requiredStepDays
                ? stepsValues.reduce(0, +) / stepsValues.count
                : nil)

        return JourneyWeeklyStatsState(
            mealsLogged: mealLoggingDays,
            mealLoggingDays: mealLoggingDays,
            proteinLoggingDays: JourneyLogMetrics.uniqueProteinGoalDays(in: windowLogs, calendar: calendar),
            waterLoggingDays: JourneyLogMetrics.uniqueWaterGoalDays(in: windowLogs, calendar: calendar),
            weighIns: JourneyLogMetrics.weightDays(
                in: windowLogs,
                weights: weekWeights,
                calendar: calendar
            ).count,
            workouts: JourneyLogMetrics.workoutDaySet(
                in: windowLogs,
                healthWorkoutDayStarts: context.healthWorkoutDayStarts,
                calendar: calendar
            ).count,
            averageSteps: resolvedAverageSteps,
            recoveryAvailability: recoveryAvailability(daysWithSignals: recoveryDaysWithSignals)
        )
    }

    private static func recoveryAvailability(
        daysWithSignals: Int?
    ) -> JourneyRecoveryAvailabilityState {
        guard let daysWithSignals else { return .unavailable }
        if daysWithSignals >= JourneyThresholds.requiredRecoveryDays {
            return .available
        }
        if daysWithSignals > 0 {
            return .partial(
                daysWithSignals: daysWithSignals,
                requiredDays: JourneyThresholds.requiredRecoveryDays
            )
        }
        return .unavailable
    }

    // MARK: - Unlocks

    private static func unlockState(
        summary: WeeklyProgressSummary,
        stats: JourneyWeeklyStatsState,
        goalProjection: JourneyGoalProjectionState,
        insight: JourneyInsightState
    ) -> JourneyUnlockPresentationState {
        let sufficiency = summary.maintenanceEstimate.sufficiency

        return JourneyUnlockPresentationState(
            projection: goalProjection.isVisible && stats.mealLoggingDays > 0,
            maintenanceEstimate: sufficiency.isEligibleForMaintenanceEstimate
                && stats.mealLoggingDays >= JourneyThresholds.requiredMealLoggingDays,
            weightTrend: stats.weighIns >= JourneyThresholds.requiredWeighIns
                || summary.endingWeightKg != nil,
            weeklyReview: stats.mealLoggingDays > 0
                && summary.totalDays >= JourneyThresholds.requiredCalendarSpanDays,
            nutritionInsight: insight.isUnlocked
                && stats.mealLoggingDays >= JourneyThresholds.requiredMealLoggingDays,
            recoveryBaseline: {
                if case .available = stats.recoveryAvailability { return true }
                return false
            }()
        )
    }

    // MARK: - Next best action

    private static func nextBestAction(
        stats: JourneyWeeklyStatsState,
        unlocks: JourneyUnlockPresentationState,
        streaks: JourneyStreakBreakdownState,
        isAppleHealthConnected: Bool
    ) -> JourneyNextBestActionState {
        let copy = FormaProductCopy.Journey.NextBestAction.self

        if stats.mealsLogged == 0 {
            return action(.logFirstMeal, title: copy.logFirstMeal, detail: copy.logFirstMealDetail)
        }

        if stats.mealLoggingDays < JourneyThresholds.requiredMealLoggingDays {
            return action(
                .logMealsConsistently,
                title: copy.logMealsConsistently,
                detail: copy.logMealsConsistentlyDetail
            )
        }

        if stats.weighIns < JourneyThresholds.requiredWeighIns {
            return action(
                .logWeightMoreOften,
                title: copy.logWeightMoreOften,
                detail: copy.logWeightMoreOftenDetail(
                    logged: stats.weighIns,
                    required: JourneyThresholds.requiredWeighIns
                )
            )
        }

        if stats.workouts == 0 {
            return action(
                .completeFirstWorkout,
                title: copy.completeFirstWorkout,
                detail: isAppleHealthConnected
                    ? copy.completeFirstWorkoutHealthDetail
                    : copy.completeFirstWorkoutDetail
            )
        }

        if !unlocks.recoveryBaseline {
            return action(
                .syncRecoveryData,
                title: copy.syncRecoveryData,
                detail: isAppleHealthConnected
                    ? copy.syncRecoveryDataDetail
                    : copy.connectHealthForRecoveryDetail
            )
        }

        let streakDays = max(streaks.mealLoggingStreakDays, streaks.checkInStreakDays)
        return action(
            .keepStreakGoing,
            title: copy.keepStreakGoing,
            detail: copy.keepStreakGoingDetail(days: max(streakDays, stats.mealLoggingDays))
        )
    }

    private static func action(
        _ kind: JourneyNextBestActionKind,
        title: String,
        detail: String?
    ) -> JourneyNextBestActionState {
        JourneyNextBestActionState(
            kind: kind,
            title: title,
            detail: detail,
            accessibilityLabel: [title, detail].compactMap { $0 }.joined(separator: ". ")
        )
    }

    // MARK: - Copy

    private static func copyPolicy(
        summary: WeeklyProgressSummary,
        stats: JourneyWeeklyStatsState,
        nextBestAction: JourneyNextBestActionState
    ) -> JourneyCopyPresentationState {
        let confidence = confidencePresentation(for: summary)
        let emptyCopy = FormaProductCopy.Journey.EmptyState.self

        let emptyState: JourneyInsightEmptyState?
        let insufficientSummary: String?

        if summary.maintenanceEstimate.sufficiency.confidence == .unavailable {
            let mealsNeeded = max(
                JourneyThresholds.requiredMealLoggingDays - stats.mealsLogged,
                0
            )
            let weighInsNeeded = max(
                JourneyThresholds.requiredWeighIns - stats.weighIns,
                0
            )
            let progressParts = [
                stats.mealsLogged > 0
                    ? emptyCopy.mealProgressLabel(
                        logged: stats.mealsLogged,
                        required: JourneyThresholds.requiredMealLoggingDays
                    )
                    : nil,
                stats.weighIns > 0
                    ? emptyCopy.weighInProgressLabel(
                        logged: stats.weighIns,
                        required: JourneyThresholds.requiredWeighIns
                    )
                    : nil
            ].compactMap { $0 }

            emptyState = JourneyInsightEmptyState(
                headline: emptyCopy.buildingFirstTrend,
                requirement: emptyCopy.unlockRequirement(
                    mealsNeeded: mealsNeeded,
                    weighInsNeeded: weighInsNeeded
                ),
                nextActionTitle: nextBestAction.title,
                nextActionDetail: nextBestAction.detail,
                progressLabel: progressParts.isEmpty ? nil : progressParts.joined(separator: " · ")
            )
            insufficientSummary = emptyState?.requirement
        } else {
            emptyState = nil
            insufficientSummary = nil
        }

        return JourneyCopyPresentationState(
            allowsFewMoreMealsCopy: stats.mealsLogged > 0,
            confidenceLabel: confidence.label,
            confidenceAccessibilityLabel: confidence.accessibilityLabel,
            insufficientDataSummary: insufficientSummary,
            emptyState: emptyState
        )
    }

    private static func confidencePresentation(
        for summary: WeeklyProgressSummary
    ) -> JourneyWeeklyConfidencePresentationState {
        let copy = FormaProductCopy.Journey.WeeklyConfidence.self
        let level = summary.maintenanceEstimate.sufficiency.confidence

        let label: String
        switch level {
        case .unavailable, .low:
            label = copy.building
        case .medium:
            label = copy.moderate
        case .high:
            label = copy.high
        }

        return JourneyWeeklyConfidencePresentationState(
            level: level,
            label: label,
            accessibilityLabel: "\(FormaProductCopy.WeeklyReviewPresentation.sectionTitle). \(label)"
        )
    }

    // MARK: - Sync

    static func syncPresentation(
        freshnessInput: WeeklyProgressFreshnessInput?
    ) -> JourneySyncPresentationState {
        syncState(freshnessInput: freshnessInput)
    }

    private static func syncState(
        freshnessInput: WeeklyProgressFreshnessInput?
    ) -> JourneySyncPresentationState {
        guard let freshnessInput else {
            return JourneySyncPresentationState(showsHealthSyncNotice: false, healthSyncNotice: nil)
        }

        let isActive = freshnessInput.isCrossDeviceRefreshing
            || (freshnessInput.pendingUploadCount ?? 0) > 0
            || freshnessInput.isRestoringAccount

        guard isActive else {
            return JourneySyncPresentationState(showsHealthSyncNotice: false, healthSyncNotice: nil)
        }

        return JourneySyncPresentationState(
            showsHealthSyncNotice: true,
            healthSyncNotice: FormaProductCopy.Journey.Sync.healthDataSyncing
        )
    }

    // MARK: - Story

    /// Story events are shown **newest first** (same ordering policy as `JourneyTimelineBuilder`).
    private static func storyPresentation(
        from events: [JourneyStoryEvent]
    ) -> JourneyStoryPresentationState {
        let sorted = events.sorted { lhs, rhs in
            if lhs.date != rhs.date {
                return lhs.date > rhs.date
            }
            return lhs.id < rhs.id
        }
        return JourneyStoryPresentationState(
            events: Array(sorted.prefix(JourneyThresholds.maxDisplayedStoryEvents))
        )
    }
}

