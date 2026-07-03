//
//  JourneyHealthIntelligencePresentationBuilder.swift
//  Fitness Coach
//
//  Forma — Maps Health Intelligence data into Journey presentation state.
//  Pure deterministic mapping; no SwiftUI or HealthKit.
//

import Foundation

enum JourneyHealthIntelligencePresentationBuilder {

    private static let defaultTimelineDayCount = 7
    private static let maxTimelineDayCount = 14
    private static let workoutHistoryWindowDays = 30

    // MARK: - Section

    /// Returns `nil` when Health Intelligence UI is disabled so existing Journey output is unchanged.
    static func buildSection(
        input: JourneyHealthIntelligenceBuildInput,
        calendar: Calendar = .current,
        isUIEnabled: Bool = HealthIntelligenceFeatureFlags.isUIEnabled
    ) -> JourneyHealthIntelligenceSectionState? {
        guard isUIEnabled else { return nil }

        if input.isLoading {
            return loadingSection()
        }

        if let errorMessage = trimmed(input.errorMessage) {
            return errorSection(message: errorMessage)
        }

        let context = presentationContext(from: input)
        let lifecycle = HealthIntelligencePresentationStateMapper.resolve(context)

        switch lifecycle {
        case .noHealthPermission, .partialHealthPermission, .unavailableOnDevice:
            return statusSection(for: lifecycle)
        case .syncFailed:
            return errorSection(
                message: HealthIntelligencePresentationStateMapper.message(
                    for: .syncFailed,
                    surface: .journey
                ).bannerMessage
            )
        default:
            break
        }

        let connection = resolvedHealthConnection(from: input)
        if connection == .notConnected {
            return statusSection(for: .noHealthPermission)
        }

        let timelineDayCount = min(max(input.recoveryTimelineDayCount, defaultTimelineDayCount), maxTimelineDayCount)
        let recoveryDays = normalizedRecoveryDays(from: input, calendar: calendar)
        let workoutRecords = normalizedWorkoutRecords(from: input, referenceDate: input.todaySnapshot?.date ?? Date(), calendar: calendar)

        let hasAnyHealthData = !recoveryDays.isEmpty || !workoutRecords.isEmpty || input.weeklyReview != nil
        guard hasAnyHealthData else {
            return emptyDataSection(connection: connection)
        }

        let weeklyPresentation = weeklyReviewPresentation(
            from: input.weeklyReview,
            isLoading: false,
            showBuildingWhenMissing: connection == .connected && hasAnyHealthData,
            calendar: calendar
        )

        return JourneyHealthIntelligenceSectionState(
            weeklyReviewCard: weeklyPresentation.card,
            weeklyReviewDetail: weeklyPresentation.detail,
            recoveryTimeline: recoveryTimeline(
                from: recoveryDays,
                dayCount: timelineDayCount,
                referenceDate: input.todaySnapshot?.date ?? Date(),
                calendar: calendar
            ),
            workoutHistory: workoutHistory(
                from: workoutRecords,
                healthConnection: connection,
                calendar: calendar
            ),
            milestones: milestones(
                workoutRecords: workoutRecords,
                recoveryDays: recoveryDays,
                weeklyReview: input.weeklyReview ?? input.todaySnapshot?.weeklyReview,
                calendar: calendar
            ),
            progress: progress(
                weeklyReview: input.weeklyReview ?? input.todaySnapshot?.weeklyReview,
                planProgress: input.planProgress,
                workoutRecords: workoutRecords
            ),
            connectHealthCTA: nil,
            isLoading: false,
            errorMessage: nil
        )
    }

    // MARK: - Weekly review

    static func weeklyReviewPresentation(
        from review: WeeklyHealthReview?,
        isLoading: Bool,
        showBuildingWhenMissing: Bool,
        calendar: Calendar = .current
    ) -> (card: WeeklyReviewCardState?, detail: WeeklyReviewDetailState?) {
        if isLoading {
            return (WeeklyReviewCardState.loading, nil)
        }

        if let review {
            let card = WeeklyReviewPresentationBuilder.buildCard(from: review, calendar: calendar)
            let detail = WeeklyReviewPresentationBuilder.buildDetail(from: review, calendar: calendar)
            if card.phase == .loaded {
                return (card, detail)
            }
        }

        if showBuildingWhenMissing {
            return (.empty, nil)
        }

        return (nil, nil)
    }

    /// Legacy weekly review preview mapping retained for migration reference.
    static func weeklyReviewPreview(
        from review: WeeklyHealthReview?,
        calendar: Calendar
    ) -> JourneyWeeklyReviewPreviewState? {
        guard let review, !review.title.isEmpty else { return nil }

        let weekRangeLabel = weekRangeLabel(
            start: review.weekStartDate,
            end: review.weekEndDate,
            calendar: calendar
        )
        let title = review.title
        let summary = sanitizedText(review.summary) ?? review.summary
        let winLines = review.wins.map { sanitizedText($0) ?? $0 }.filter { !$0.isEmpty }
        let focusLines = review.nextWeekFocus.map { sanitizedText($0) ?? $0 }.filter { !$0.isEmpty }
        let confidenceNote = review.confidence == .low
            ? FormaProductCopy.Journey.HealthIntelligence.limitedEstimate
            : nil

        return JourneyWeeklyReviewPreviewState(
            phase: .loaded,
            sectionTitle: FormaProductCopy.Journey.HealthIntelligence.WeeklyReview.sectionTitle,
            weekRangeLabel: weekRangeLabel,
            title: title,
            summary: summary,
            winLines: winLines,
            focusLines: focusLines,
            confidenceNote: confidenceNote,
            accessibilityLabel: weeklyReviewAccessibilityLabel(
                weekRangeLabel: weekRangeLabel,
                title: title,
                summary: summary,
                winLines: winLines,
                focusLines: focusLines,
                confidenceNote: confidenceNote
            )
        )
    }

    // MARK: - Recovery timeline

    static func recoveryTimeline(
        from recoveryDays: [JourneyHealthIntelligenceRecoveryDayInput],
        dayCount: Int = defaultTimelineDayCount,
        referenceDate: Date = Date(),
        calendar: Calendar = .current
    ) -> JourneyRecoveryTimelineState {
        let endDay = calendar.startOfDay(for: referenceDate)
        let days = (0..<dayCount).reversed().compactMap { offset -> JourneyRecoveryDayState? in
            guard let date = calendar.date(byAdding: .day, value: -offset, to: endDay) else { return nil }
            let input = recoveryDays.first {
                calendar.isDate($0.date, inSameDayAs: date)
            }
            return recoveryDay(for: date, input: input, calendar: calendar)
        }

        if days.allSatisfy({ $0.statusKind == .unknown && $0.recoveryScore == nil }) {
            return JourneyRecoveryTimelineState(
                phase: .empty,
                sectionTitle: FormaProductCopy.Journey.HealthIntelligence.RecoveryTimeline.sectionTitle,
                headline: timelineHeadline(dayCount: dayCount),
                days: days,
                dayCount: dayCount,
                emptyMessage: FormaProductCopy.Journey.HealthIntelligence.RecoveryTimeline.emptyMessage,
                errorMessage: nil,
                accessibilityLabel: FormaProductCopy.Journey.HealthIntelligence.RecoveryTimeline.emptyMessage
            )
        }

        return JourneyRecoveryTimelineState(
            phase: .loaded,
            sectionTitle: FormaProductCopy.Journey.HealthIntelligence.RecoveryTimeline.sectionTitle,
            headline: timelineHeadline(dayCount: dayCount),
            days: days,
            dayCount: dayCount,
            emptyMessage: nil,
            errorMessage: nil,
            accessibilityLabel: recoveryTimelineAccessibilityLabel(days: days)
        )
    }

    static func recoveryDay(
        for date: Date,
        input: JourneyHealthIntelligenceRecoveryDayInput?,
        calendar: Calendar
    ) -> JourneyRecoveryDayState {
        let recovery = input?.recovery ?? .unknown
        let statusKind = recoveryStatusKind(from: recovery)
        let statusLabel = recoveryStatusLabel(for: statusKind)
        let statusColorToken = recoveryStatusColorToken(for: statusKind)
        let limited = statusKind == .limitedEstimate
        let limitedEstimateLabel = limited ? FormaProductCopy.Journey.HealthIntelligence.limitedEstimate : nil
        let score = coachSafeRecoveryScore(from: recovery)
        let explanation = coachSafeRecoveryExplanation(from: recovery)
        let dateLabel = JourneyFormatter.timelineDayLabel(date, calendar: calendar)
        let weekdayLabel = weekdayLabel(for: date, calendar: calendar)
        let id = dayIdentifier(for: date, calendar: calendar)

        return JourneyRecoveryDayState(
            id: id,
            date: calendar.startOfDay(for: date),
            dateLabel: dateLabel,
            weekdayLabel: weekdayLabel,
            statusLabel: statusLabel,
            statusKind: statusKind,
            statusColorToken: statusColorToken,
            recoveryScore: score,
            limitedEstimateLabel: limitedEstimateLabel,
            shortExplanation: explanation,
            isLimitedEstimate: limited,
            accessibilityLabel: recoveryDayAccessibilityLabel(
                dateLabel: dateLabel,
                weekdayLabel: weekdayLabel,
                statusLabel: statusLabel,
                score: score,
                explanation: explanation,
                limited: limited
            )
        )
    }

    /// Legacy snapshot-based recovery day mapping.
    static func recoveryDay(
        from snapshot: HealthIntelligenceSnapshot,
        calendar: Calendar
    ) -> JourneyRecoveryDayState {
        recoveryDay(
            for: snapshot.date,
            input: JourneyHealthIntelligenceRecoveryDayInput(
                date: snapshot.date,
                recovery: snapshot.recovery,
                steps: snapshot.activity.steps
            ),
            calendar: calendar
        )
    }

    /// Legacy snapshot-array recovery timeline.
    static func recoveryTimeline(
        from snapshots: [HealthIntelligenceSnapshot],
        calendar: Calendar
    ) -> JourneyRecoveryTimelineState {
        let recoveryDays = snapshots.map {
            JourneyHealthIntelligenceRecoveryDayInput(
                date: $0.date,
                recovery: $0.recovery,
                steps: $0.activity.steps
            )
        }
        let referenceDate = snapshots.last?.date ?? Date()
        return recoveryTimeline(from: recoveryDays, referenceDate: referenceDate, calendar: calendar)
    }

    // MARK: - Workout history

    static func workoutHistory(
        from workoutRecords: [JourneyHealthIntelligenceWorkoutRecordInput],
        healthConnection: JourneyHealthConnectionState = .connected,
        calendar: Calendar = .current
    ) -> JourneyWorkoutHistoryState {
        let items = workoutRecords
            .map { workoutItem(from: $0, calendar: calendar) }
            .sorted { $0.date > $1.date }

        if items.isEmpty {
            let emptyKind: JourneyHealthIntelligenceEmptyKind = healthConnection == .connected
                ? .connectedNoWorkouts
                : .insufficientHistory
            let emptyMessage = healthConnection == .connected
                ? FormaProductCopy.Journey.HealthIntelligence.connectedNoWorkoutsMessage
                : FormaProductCopy.Journey.HealthIntelligence.WorkoutHistory.emptyMessage

            return JourneyWorkoutHistoryState(
                phase: .empty,
                sectionTitle: FormaProductCopy.Journey.HealthIntelligence.WorkoutHistory.sectionTitle,
                headline: FormaProductCopy.Journey.HealthIntelligence.WorkoutHistory.headline,
                groups: [],
                items: [],
                emptyKind: emptyKind,
                emptyMessage: emptyMessage,
                errorMessage: nil,
                accessibilityLabel: emptyMessage
            )
        }

        let groups = groupedWorkoutItems(items, calendar: calendar)
        return JourneyWorkoutHistoryState(
            phase: .loaded,
            sectionTitle: FormaProductCopy.Journey.HealthIntelligence.WorkoutHistory.sectionTitle,
            headline: FormaProductCopy.Journey.HealthIntelligence.WorkoutHistory.headline,
            groups: groups,
            items: items,
            emptyKind: nil,
            emptyMessage: nil,
            errorMessage: nil,
            accessibilityLabel: workoutHistoryAccessibilityLabel(items: items)
        )
    }

    static func workoutItem(
        from record: JourneyHealthIntelligenceWorkoutRecordInput,
        calendar: Calendar
    ) -> JourneyWorkoutHistoryItemState {
        let day = calendar.startOfDay(for: record.date)
        let dateLabel = JourneyFormatter.timelineDayLabel(day, calendar: calendar)
        let title = trimmed(record.title) ?? FormaProductCopy.Today.HealthIntelligence.workoutComplete
        let durationLabel = FormaProductCopy.Journey.HealthIntelligence.durationLabel(minutes: record.durationMinutes)
        let caloriesLabel = coachSafeCaloriesLabel(from: record.activeCalories)
        let demandLabel = record.demand == .unknown
            ? nil
            : FormaProductCopy.Journey.HealthIntelligence.demandLabel(record.demand.rawValue)
        let intensityLabel = record.intensity == .unknown
            ? nil
            : record.intensity.rawValue.capitalized

        return JourneyWorkoutHistoryItemState(
            id: record.id,
            date: day,
            dateLabel: dateLabel,
            workoutTitle: title,
            durationLabel: durationLabel,
            caloriesLabel: caloriesLabel,
            demandLabel: demandLabel,
            intensityLabel: intensityLabel,
            shortExplanation: nil,
            accessibilityLabel: workoutItemAccessibilityLabel(
                dateLabel: dateLabel,
                title: title,
                durationLabel: durationLabel,
                caloriesLabel: caloriesLabel,
                demandLabel: demandLabel
            )
        )
    }

    /// Legacy snapshot-based workout history.
    static func workoutHistory(
        from snapshots: [HealthIntelligenceSnapshot],
        calendar: Calendar
    ) -> JourneyWorkoutHistoryState {
        let records = snapshots.compactMap { snapshot -> JourneyHealthIntelligenceWorkoutRecordInput? in
            guard let workout = snapshot.workout, workout.hasWorkout else { return nil }
            return JourneyHealthIntelligenceWorkoutRecordInput(
                id: "\(dayIdentifier(for: snapshot.date, calendar: calendar))-workout",
                date: snapshot.date,
                title: workout.title,
                durationMinutes: workout.totalDurationMinutes,
                activeCalories: workout.totalActiveCalories,
                demand: workout.demand,
                intensity: workout.intensity
            )
        }
        return workoutHistory(from: records, calendar: calendar)
    }

    // MARK: - Milestones

    static func milestones(
        workoutRecords: [JourneyHealthIntelligenceWorkoutRecordInput],
        recoveryDays: [JourneyHealthIntelligenceRecoveryDayInput],
        weeklyReview: WeeklyHealthReview?,
        calendar: Calendar = .current
    ) -> JourneyHealthMilestonesState {
        var items: [JourneyHealthMilestoneState] = []

        if let streak = workoutStreak(from: workoutRecords, calendar: calendar), streak > 1 {
            let title = FormaProductCopy.Journey.HealthIntelligence.workoutStreak(streak)
            items.append(
                JourneyHealthMilestoneState(
                    id: "workout-streak",
                    kind: .workoutStreak,
                    title: title,
                    detail: "Keep showing up — consistency builds momentum.",
                    status: .achieved,
                    statusLabel: FormaProductCopy.Journey.HealthIntelligence.milestoneAchieved,
                    progressLabel: nil,
                    accessibilityLabel: "\(title). \(FormaProductCopy.Journey.HealthIntelligence.milestoneAchieved)."
                )
            )
        }

        if let longest = longestWorkout(from: workoutRecords) {
            let title = FormaProductCopy.Journey.HealthIntelligence.longestWorkout(
                minutes: longest.durationMinutes,
                title: longest.title
            )
            items.append(
                JourneyHealthMilestoneState(
                    id: "longest-workout",
                    kind: .longestWorkout,
                    title: title,
                    detail: "Your longest session in the last 30 days.",
                    status: .achieved,
                    statusLabel: FormaProductCopy.Journey.HealthIntelligence.milestoneAchieved,
                    progressLabel: nil,
                    accessibilityLabel: "\(title). \(FormaProductCopy.Journey.HealthIntelligence.milestoneAchieved)."
                )
            )
        }

        if let mostActive = mostActiveDay(from: recoveryDays, calendar: calendar) {
            let title = FormaProductCopy.Journey.HealthIntelligence.mostActiveDay(
                steps: mostActive.steps,
                dateLabel: mostActive.dateLabel
            )
            items.append(
                JourneyHealthMilestoneState(
                    id: "most-active-day",
                    kind: .mostActiveDay,
                    title: title,
                    detail: "Your highest step day in the recent window.",
                    status: .achieved,
                    statusLabel: FormaProductCopy.Journey.HealthIntelligence.milestoneAchieved,
                    progressLabel: nil,
                    accessibilityLabel: "\(title). \(FormaProductCopy.Journey.HealthIntelligence.milestoneAchieved)."
                )
            )
        }

        let workoutDayCount = Set(
            workoutRecords.map { calendar.startOfDay(for: $0.date) }
        ).count
        if workoutDayCount >= 2 {
            let title = FormaProductCopy.Journey.HealthIntelligence.workoutConsistency(
                days: workoutDayCount,
                windowDays: workoutHistoryWindowDays
            )
            items.append(
                JourneyHealthMilestoneState(
                    id: "workout-consistency",
                    kind: .consistency,
                    title: title,
                    detail: "Steady training adds up over time.",
                    status: workoutDayCount >= 4 ? .achieved : .inProgress,
                    statusLabel: workoutDayCount >= 4
                        ? FormaProductCopy.Journey.HealthIntelligence.milestoneAchieved
                        : FormaProductCopy.Journey.HealthIntelligence.milestoneInProgress,
                    progressLabel: nil,
                    accessibilityLabel: "\(title)."
                )
            )
        }

        if let review = weeklyReview {
            for (index, win) in review.wins.enumerated() {
                let title = sanitizedText(win) ?? win
                guard !title.isEmpty else { continue }
                items.append(
                    JourneyHealthMilestoneState(
                        id: "weekly-win-\(index)",
                        kind: .weeklyWin,
                        title: title,
                        detail: FormaProductCopy.Journey.HealthIntelligence.WeeklyReview.sectionTitle,
                        status: .achieved,
                        statusLabel: FormaProductCopy.Journey.HealthIntelligence.milestoneAchieved,
                        progressLabel: nil,
                        accessibilityLabel: "\(title). \(FormaProductCopy.Journey.HealthIntelligence.milestoneAchieved)."
                    )
                )
            }
        }

        if items.isEmpty {
            return JourneyHealthMilestonesState(
                phase: .empty,
                sectionTitle: FormaProductCopy.Journey.HealthIntelligence.Milestones.sectionTitle,
                headline: FormaProductCopy.Journey.HealthIntelligence.Milestones.headline,
                items: [],
                emptyMessage: FormaProductCopy.Journey.HealthIntelligence.Milestones.emptyMessage,
                errorMessage: nil,
                accessibilityLabel: FormaProductCopy.Journey.HealthIntelligence.Milestones.emptyMessage
            )
        }

        return JourneyHealthMilestonesState(
            phase: .loaded,
            sectionTitle: FormaProductCopy.Journey.HealthIntelligence.Milestones.sectionTitle,
            headline: FormaProductCopy.Journey.HealthIntelligence.Milestones.headline,
            items: items,
            emptyMessage: nil,
            errorMessage: nil,
            accessibilityLabel: milestonesAccessibilityLabel(items: items)
        )
    }

    /// Legacy weekly-review-only milestones.
    static func milestones(from review: WeeklyHealthReview?) -> JourneyHealthMilestonesState {
        milestones(
            workoutRecords: [],
            recoveryDays: [],
            weeklyReview: review
        )
    }

    // MARK: - Progress

    static func progress(
        weeklyReview: WeeklyHealthReview?,
        planProgress: JourneyHealthIntelligencePlanProgressInput?,
        workoutRecords: [JourneyHealthIntelligenceWorkoutRecordInput]
    ) -> JourneyHealthProgressState {
        let stats = weeklyReview?.stats
        let progress = planProgress

        var detailLines: [String] = []
        var metrics: [JourneyHealthProgressMetricRow] = []

        let totalWorkouts = progress?.totalWorkouts ?? stats?.totalWorkouts ?? workoutRecords.count
        if totalWorkouts > 0 {
            detailLines.append(
                "\(FormaProductCopy.Journey.HealthIntelligence.workoutsThisWeek(totalWorkouts)) logged recently."
            )
            metrics.append(
                JourneyHealthProgressMetricRow(
                    id: "workouts",
                    title: "Workouts",
                    value: "\(totalWorkouts)",
                    detail: stats.map {
                        FormaProductCopy.Journey.HealthIntelligence.durationLabel(minutes: $0.totalWorkoutMinutes)
                    }
                )
            )
        }

        let averageSteps = progress?.averageSteps ?? stats?.averageSteps
        if let averageSteps, averageSteps > 0 {
            metrics.append(
                JourneyHealthProgressMetricRow(
                    id: "steps",
                    title: "Average steps",
                    value: averageSteps.formatted(),
                    detail: "Daily average"
                )
            )
        }

        let proteinHitDays = progress?.proteinHitDays ?? stats?.proteinHitDays ?? 0
        if proteinHitDays > 0 {
            metrics.append(
                JourneyHealthProgressMetricRow(
                    id: "protein",
                    title: "Protein days",
                    value: "\(proteinHitDays)",
                    detail: "Days on target"
                )
            )
        }

        if let weightChange = progress?.weightChangeKg ?? stats?.weightChangeKg {
            let trend = FormaProductCopy.Journey.HealthIntelligence.weightTrend(weightChange)
            detailLines.append(trend + ".")
            metrics.append(
                JourneyHealthProgressMetricRow(
                    id: "weight",
                    title: "Weight trend",
                    value: trend,
                    detail: "This week"
                )
            )
        }

        if stats?.lowRecoveryDays ?? 0 > 0 {
            detailLines.append(
                FormaProductCopy.Journey.HealthIntelligence.limitedRecoveryDays(stats!.lowRecoveryDays) + "."
            )
        }

        guard !metrics.isEmpty else {
            return JourneyHealthProgressState(
                phase: .empty,
                sectionTitle: FormaProductCopy.Journey.HealthIntelligence.Progress.sectionTitle,
                headline: FormaProductCopy.Journey.HealthIntelligence.Progress.headline,
                detailLines: [],
                metrics: [],
                emptyMessage: FormaProductCopy.Journey.HealthIntelligence.Progress.emptyMessage,
                errorMessage: nil,
                accessibilityLabel: FormaProductCopy.Journey.HealthIntelligence.Progress.emptyMessage
            )
        }

        let headline = weeklyReview?.title.isEmpty == false
            ? weeklyReview!.title
            : FormaProductCopy.Journey.HealthIntelligence.Progress.headline

        return JourneyHealthProgressState(
            phase: .loaded,
            sectionTitle: FormaProductCopy.Journey.HealthIntelligence.Progress.sectionTitle,
            headline: headline,
            detailLines: detailLines,
            metrics: metrics,
            emptyMessage: nil,
            errorMessage: nil,
            accessibilityLabel: progressAccessibilityLabel(
                headline: headline,
                detailLines: detailLines,
                metrics: metrics
            )
        )
    }

    /// Legacy weekly-review-only progress.
    static func progress(from review: WeeklyHealthReview?) -> JourneyHealthProgressState {
        progress(weeklyReview: review, planProgress: nil, workoutRecords: [])
    }

    // MARK: - Private section builders

    private static func loadingSection() -> JourneyHealthIntelligenceSectionState {
        JourneyHealthIntelligenceSectionState(
            weeklyReviewCard: .loading,
            weeklyReviewDetail: nil,
            recoveryTimeline: .loading,
            workoutHistory: .loading,
            milestones: .loading,
            progress: .loading,
            connectHealthCTA: nil,
            isLoading: true,
            errorMessage: nil
        )
    }

    private static func presentationContext(
        from input: JourneyHealthIntelligenceBuildInput
    ) -> HealthIntelligencePresentationContext {
        HealthIntelligencePresentationContext(
            explicitErrorMessage: input.errorMessage,
            availability: input.availability,
            snapshot: input.todaySnapshot,
            isAppleHealthConnected: input.healthConnection == .connected,
            cachedDayCount: input.cachedDayCount
        )
    }

    private static func statusSection(
        for lifecycle: HealthIntelligencePresentationLifecycle
    ) -> JourneyHealthIntelligenceSectionState {
        let presentation = HealthIntelligencePresentationStateMapper.message(
            for: lifecycle,
            surface: .journey
        )

        let cta: JourneyHealthConnectCTAState?
        switch presentation.primaryAction {
        case .connectAppleHealth, .manageHealthPermissions:
            cta = JourneyHealthConnectCTAState(
                title: presentation.title,
                message: presentation.bannerMessage,
                ctaTitle: presentation.primaryActionTitle ?? presentation.title,
                accessibilityLabel: presentation.accessibilityLabel
            )
        case .continueLogging, .askCoach, .none:
            cta = JourneyHealthConnectCTAState(
                title: presentation.title,
                message: presentation.bannerMessage,
                ctaTitle: presentation.primaryActionTitle ?? FormaProductCopy.Journey.HealthIntelligence.connectHealthCTA,
                accessibilityLabel: presentation.accessibilityLabel
            )
        }

        return connectHealthSection(cta: cta, presentation: presentation)
    }

    private static func emptyDataSection(
        connection: JourneyHealthConnectionState
    ) -> JourneyHealthIntelligenceSectionState {
        let presentation = HealthIntelligencePresentationStateMapper.message(
            for: .noHealthDataYet,
            surface: .journey
        )
        let cta = JourneyHealthConnectCTAState(
            title: presentation.title,
            message: presentation.bannerMessage,
            ctaTitle: presentation.primaryActionTitle ?? FormaProductCopy.Journey.HealthIntelligence.connectHealthCTA,
            accessibilityLabel: presentation.accessibilityLabel
        )

        return JourneyHealthIntelligenceSectionState(
            weeklyReviewCard: nil,
            weeklyReviewDetail: nil,
            recoveryTimeline: JourneyRecoveryTimelineState(
                phase: .empty,
                sectionTitle: FormaProductCopy.Journey.HealthIntelligence.RecoveryTimeline.sectionTitle,
                headline: presentation.title,
                days: [],
                dayCount: defaultTimelineDayCount,
                emptyMessage: FormaProductCopy.Journey.HealthIntelligence.RecoveryTimeline.emptyMessage,
                errorMessage: nil,
                accessibilityLabel: presentation.accessibilityLabel
            ),
            workoutHistory: JourneyWorkoutHistoryState(
                phase: .empty,
                sectionTitle: FormaProductCopy.Journey.HealthIntelligence.WorkoutHistory.sectionTitle,
                headline: presentation.title,
                groups: [],
                items: [],
                emptyKind: connection == .connected ? .connectedNoWorkouts : .noHealthData,
                emptyMessage: connection == .connected
                    ? FormaProductCopy.Journey.HealthIntelligence.connectedNoWorkoutsMessage
                    : presentation.message,
                errorMessage: nil,
                accessibilityLabel: presentation.accessibilityLabel
            ),
            milestones: JourneyHealthMilestonesState(
                phase: .empty,
                sectionTitle: FormaProductCopy.Journey.HealthIntelligence.Milestones.sectionTitle,
                headline: presentation.title,
                items: [],
                emptyMessage: FormaProductCopy.Journey.HealthIntelligence.Milestones.emptyMessage,
                errorMessage: nil,
                accessibilityLabel: presentation.accessibilityLabel
            ),
            progress: JourneyHealthProgressState(
                phase: .empty,
                sectionTitle: FormaProductCopy.Journey.HealthIntelligence.Progress.sectionTitle,
                headline: presentation.title,
                detailLines: [],
                metrics: [],
                emptyMessage: FormaProductCopy.Journey.HealthIntelligence.Progress.emptyMessage,
                errorMessage: nil,
                accessibilityLabel: presentation.accessibilityLabel
            ),
            connectHealthCTA: cta,
            isLoading: false,
            errorMessage: nil
        )
    }

    private static func connectHealthSection(
        cta: JourneyHealthConnectCTAState? = nil,
        presentation: HealthIntelligencePresentationMessage? = nil
    ) -> JourneyHealthIntelligenceSectionState {
        let resolvedPresentation = presentation
            ?? HealthIntelligencePresentationStateMapper.message(for: .noHealthPermission, surface: .journey)
        let resolvedCTA = cta ?? JourneyHealthConnectCTAState(
            title: resolvedPresentation.title,
            message: resolvedPresentation.bannerMessage,
            ctaTitle: resolvedPresentation.primaryActionTitle
                ?? FormaProductCopy.Journey.HealthIntelligence.connectHealthCTA,
            accessibilityLabel: resolvedPresentation.accessibilityLabel
        )

        return JourneyHealthIntelligenceSectionState(
            weeklyReviewCard: nil,
            weeklyReviewDetail: nil,
            recoveryTimeline: JourneyRecoveryTimelineState(
                phase: .empty,
                sectionTitle: FormaProductCopy.Journey.HealthIntelligence.RecoveryTimeline.sectionTitle,
                headline: resolvedPresentation.title,
                days: [],
                dayCount: defaultTimelineDayCount,
                emptyMessage: resolvedPresentation.bannerMessage,
                errorMessage: nil,
                accessibilityLabel: resolvedCTA.accessibilityLabel
            ),
            workoutHistory: JourneyWorkoutHistoryState(
                phase: .empty,
                sectionTitle: FormaProductCopy.Journey.HealthIntelligence.WorkoutHistory.sectionTitle,
                headline: resolvedPresentation.title,
                groups: [],
                items: [],
                emptyKind: .noHealthData,
                emptyMessage: resolvedPresentation.bannerMessage,
                errorMessage: nil,
                accessibilityLabel: resolvedCTA.accessibilityLabel
            ),
            milestones: JourneyHealthMilestonesState(
                phase: .empty,
                sectionTitle: FormaProductCopy.Journey.HealthIntelligence.Milestones.sectionTitle,
                headline: resolvedPresentation.title,
                items: [],
                emptyMessage: resolvedPresentation.bannerMessage,
                errorMessage: nil,
                accessibilityLabel: resolvedCTA.accessibilityLabel
            ),
            progress: JourneyHealthProgressState(
                phase: .empty,
                sectionTitle: FormaProductCopy.Journey.HealthIntelligence.Progress.sectionTitle,
                headline: resolvedPresentation.title,
                detailLines: [resolvedPresentation.bannerMessage],
                metrics: [],
                emptyMessage: resolvedPresentation.bannerMessage,
                errorMessage: nil,
                accessibilityLabel: resolvedCTA.accessibilityLabel
            ),
            connectHealthCTA: resolvedCTA,
            isLoading: false,
            errorMessage: nil
        )
    }

    private static func errorSection(message: String) -> JourneyHealthIntelligenceSectionState {
        let presentation = HealthIntelligencePresentationStateMapper.message(
            for: .syncFailed,
            surface: .journey
        )
        let resolvedMessage = message.isEmpty ? presentation.bannerMessage : message

        return JourneyHealthIntelligenceSectionState(
            weeklyReviewCard: nil,
            weeklyReviewDetail: nil,
            recoveryTimeline: JourneyRecoveryTimelineState(
                phase: .error,
                sectionTitle: FormaProductCopy.Journey.HealthIntelligence.RecoveryTimeline.sectionTitle,
                headline: presentation.title,
                days: [],
                dayCount: defaultTimelineDayCount,
                emptyMessage: nil,
                errorMessage: resolvedMessage,
                accessibilityLabel: resolvedMessage
            ),
            workoutHistory: JourneyWorkoutHistoryState(
                phase: .error,
                sectionTitle: FormaProductCopy.Journey.HealthIntelligence.WorkoutHistory.sectionTitle,
                headline: presentation.title,
                groups: [],
                items: [],
                emptyKind: nil,
                emptyMessage: nil,
                errorMessage: resolvedMessage,
                accessibilityLabel: resolvedMessage
            ),
            milestones: JourneyHealthMilestonesState(
                phase: .error,
                sectionTitle: FormaProductCopy.Journey.HealthIntelligence.Milestones.sectionTitle,
                headline: presentation.title,
                items: [],
                emptyMessage: nil,
                errorMessage: resolvedMessage,
                accessibilityLabel: resolvedMessage
            ),
            progress: JourneyHealthProgressState(
                phase: .error,
                sectionTitle: FormaProductCopy.Journey.HealthIntelligence.Progress.sectionTitle,
                headline: presentation.title,
                detailLines: [resolvedMessage],
                metrics: [],
                emptyMessage: nil,
                errorMessage: resolvedMessage,
                accessibilityLabel: resolvedMessage
            ),
            connectHealthCTA: nil,
            isLoading: false,
            errorMessage: resolvedMessage
        )
    }

    // MARK: - Milestone calculations

    private static func workoutStreak(
        from records: [JourneyHealthIntelligenceWorkoutRecordInput],
        calendar: Calendar
    ) -> Int? {
        let workoutDays = Set(records.map { calendar.startOfDay(for: $0.date) })
        guard let latest = workoutDays.max() else { return nil }

        var streak = 0
        var cursor = latest
        while workoutDays.contains(cursor) {
            streak += 1
            guard let previous = calendar.date(byAdding: .day, value: -1, to: cursor) else { break }
            cursor = calendar.startOfDay(for: previous)
        }
        return streak > 0 ? streak : nil
    }

    private static func longestWorkout(
        from records: [JourneyHealthIntelligenceWorkoutRecordInput]
    ) -> JourneyHealthIntelligenceWorkoutRecordInput? {
        records.max(by: { $0.durationMinutes < $1.durationMinutes })
    }

    private static func mostActiveDay(
        from recoveryDays: [JourneyHealthIntelligenceRecoveryDayInput],
        calendar: Calendar
    ) -> (steps: Int, dateLabel: String)? {
        guard let best = recoveryDays.compactMap({ input -> (Int, Date)? in
            guard let steps = input.steps, steps > 0 else { return nil }
            return (steps, input.date)
        }).max(by: { $0.0 < $1.0 }) else {
            return nil
        }

        return (
            steps: best.0,
            dateLabel: JourneyFormatter.timelineDayLabel(best.1, calendar: calendar)
        )
    }

    // MARK: - Recovery mapping

    private static func recoveryStatusKind(from recovery: RecoverySummary) -> JourneyRecoveryDayStatusKind {
        if recovery.confidence == .low || recovery.confidence == .unknown {
            switch recovery.status {
            case .ready, .moderate:
                return .limitedEstimate
            case .low:
                return .low
            case .unknown:
                return .unknown
            }
        }

        switch recovery.status {
        case .ready: return .ready
        case .moderate: return .moderate
        case .low: return .low
        case .unknown: return .unknown
        }
    }

    private static func recoveryStatusLabel(for kind: JourneyRecoveryDayStatusKind) -> String {
        switch kind {
        case .ready: return "Ready"
        case .moderate: return "Moderate"
        case .low: return "Low"
        case .limitedEstimate: return FormaProductCopy.Journey.HealthIntelligence.limitedEstimate
        case .unknown: return "Unknown"
        }
    }

    private static func recoveryStatusColorToken(for kind: JourneyRecoveryDayStatusKind) -> String {
        switch kind {
        case .ready: return "recoveryReady"
        case .moderate: return "recoveryModerate"
        case .low: return "recoveryLow"
        case .limitedEstimate: return "recoveryLimited"
        case .unknown: return "recoveryUnknown"
        }
    }

    private static func coachSafeRecoveryScore(from recovery: RecoverySummary) -> Int? {
        guard let score = recovery.score else { return nil }
        guard recovery.confidence == .moderate || recovery.confidence == .high else { return nil }
        guard recoveryStatusKind(from: recovery) != .limitedEstimate else { return nil }
        guard recovery.status != .unknown else { return nil }
        return score
    }

    private static func coachSafeRecoveryExplanation(from recovery: RecoverySummary) -> String? {
        if shouldPreferLimitedRecoveryWording(for: recovery) {
            return limitedRecoveryExplanation(for: recovery)
        }

        if let sanitized = sanitizedText(recovery.explanation) {
            return sanitized
        }

        if let title = sanitizedText(recovery.title) {
            return title
        }

        return recoveryStatusLabel(for: recoveryStatusKind(from: recovery))
    }

    private static func shouldPreferLimitedRecoveryWording(for recovery: RecoverySummary) -> Bool {
        if recovery.confidence == .low || recovery.confidence == .unknown {
            return true
        }
        if recovery.status == .unknown {
            return true
        }
        return hasMissingHeartOrSleepSignals(recovery.missingSignals)
    }

    private static func limitedRecoveryExplanation(for recovery: RecoverySummary) -> String {
        if hasMissingHeartOrSleepSignals(recovery.missingSignals) {
            return "Limited estimate because key recovery signals are missing."
        }
        if recovery.status == .unknown {
            return "Not enough recovery signals yet."
        }
        return "Limited estimate from partial recovery signals."
    }

    private static func hasMissingHeartOrSleepSignals(_ signals: Set<RecoveryMissingSignal>) -> Bool {
        signals.contains(.sleep)
            && (signals.contains(.hrv) || signals.contains(.restingHeartRate))
    }

    private static func coachSafeCaloriesLabel(from calories: Int?) -> String? {
        guard let calories, calories > 0 else { return nil }
        return "\(calories.formatted()) kcal est."
    }

    // MARK: - Normalization

    private static func resolvedHealthConnection(from input: JourneyHealthIntelligenceBuildInput) -> JourneyHealthConnectionState {
        if input.healthConnection != .unknown {
            return input.healthConnection
        }
        if input.todaySnapshot?.nextBestAction.reason == .connectHealth,
           input.todaySnapshot?.nextBestAction.id.isEmpty == false {
            return .notConnected
        }
        return .connected
    }

    private static func normalizedRecoveryDays(
        from input: JourneyHealthIntelligenceBuildInput,
        calendar: Calendar
    ) -> [JourneyHealthIntelligenceRecoveryDayInput] {
        if !input.recoveryDays.isEmpty {
            return input.recoveryDays
        }

        return JourneyHealthIntelligenceBuildInput(
            currentSnapshot: input.todaySnapshot,
            historicalSnapshots: [],
            calendar: calendar
        ).recoveryDays
    }

    private static func normalizedWorkoutRecords(
        from input: JourneyHealthIntelligenceBuildInput,
        referenceDate: Date,
        calendar: Calendar
    ) -> [JourneyHealthIntelligenceWorkoutRecordInput] {
        let cutoff = calendar.date(byAdding: .day, value: -workoutHistoryWindowDays, to: calendar.startOfDay(for: referenceDate)) ?? referenceDate
        let source = input.workoutRecords.isEmpty
            ? JourneyHealthIntelligenceBuildInput(currentSnapshot: input.todaySnapshot, historicalSnapshots: [], calendar: calendar).workoutRecords
            : input.workoutRecords

        return source.filter { calendar.startOfDay(for: $0.date) >= cutoff }
    }

    private static func groupedWorkoutItems(
        _ items: [JourneyWorkoutHistoryItemState],
        calendar: Calendar
    ) -> [JourneyWorkoutHistoryGroupState] {
        let grouped = Dictionary(grouping: items) { item in
            dayIdentifier(for: item.date, calendar: calendar)
        }

        return grouped.keys.sorted(by: >).compactMap { key in
            guard let groupItems = grouped[key]?.sorted(by: { $0.workoutTitle < $1.workoutTitle }) else {
                return nil
            }
            guard let first = groupItems.first else { return nil }
            return JourneyWorkoutHistoryGroupState(
                id: key,
                date: first.date,
                dateLabel: first.dateLabel,
                items: groupItems,
                accessibilityLabel: "\(first.dateLabel). \(groupItems.map(\.accessibilityLabel).joined(separator: ". "))"
            )
        }
    }

    private static func timelineHeadline(dayCount: Int) -> String {
        dayCount > defaultTimelineDayCount
            ? FormaProductCopy.Journey.HealthIntelligence.RecoveryTimeline.headline14Days
            : FormaProductCopy.Journey.HealthIntelligence.RecoveryTimeline.headline
    }

    // MARK: - Formatting

    private static func dayIdentifier(for date: Date, calendar: Calendar) -> String {
        let formatter = DateFormatter()
        formatter.calendar = calendar
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.timeZone = calendar.timeZone
        formatter.dateFormat = "yyyy-MM-dd"
        return formatter.string(from: calendar.startOfDay(for: date))
    }

    private static func weekdayLabel(for date: Date, calendar: Calendar) -> String {
        date.formatted(
            .dateTime
                .weekday(.abbreviated)
                .locale(calendar.locale ?? .current)
        )
    }

    private static func weekRangeLabel(start: Date, end: Date, calendar: Calendar) -> String {
        let startLabel = JourneyFormatter.timelineDayLabel(start, calendar: calendar)
        let endLabel = JourneyFormatter.timelineDayLabel(end, calendar: calendar)
        return "\(startLabel) – \(endLabel)"
    }

    private static func trimmed(_ value: String?) -> String? {
        guard let value else { return nil }
        let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? nil : trimmed
    }

    private static let riskyMetricSubstrings = [
        "hrv",
        "heart rate",
        "resting heart",
        "bpm",
        " ms",
        "millisecond",
        "baseline",
        "below your recent",
        "above your recent"
    ]

    private static func sanitizedText(_ text: String) -> String? {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return nil }
        guard !containsRiskyMetricLanguage(trimmed) else { return nil }
        return trimmed
    }

    private static func containsRiskyMetricLanguage(_ text: String) -> Bool {
        let lower = text.lowercased()
        return riskyMetricSubstrings.contains { lower.contains($0) }
    }

    // MARK: - Accessibility

    private static func weeklyReviewAccessibilityLabel(
        weekRangeLabel: String,
        title: String,
        summary: String,
        winLines: [String],
        focusLines: [String],
        confidenceNote: String?
    ) -> String {
        var parts = ["Weekly health review", weekRangeLabel, title, summary]
        if !winLines.isEmpty {
            parts.append("Wins: \(winLines.joined(separator: ", "))")
        }
        if !focusLines.isEmpty {
            parts.append("Focus: \(focusLines.joined(separator: ", "))")
        }
        if let confidenceNote {
            parts.append(confidenceNote)
        }
        return parts.joined(separator: ". ")
    }

    private static func recoveryTimelineAccessibilityLabel(days: [JourneyRecoveryDayState]) -> String {
        let summaries = days.map(\.accessibilityLabel)
        return "Recovery timeline. \(summaries.joined(separator: ". "))"
    }

    private static func recoveryDayAccessibilityLabel(
        dateLabel: String,
        weekdayLabel: String,
        statusLabel: String,
        score: Int?,
        explanation: String?,
        limited: Bool
    ) -> String {
        var parts = ["\(weekdayLabel) \(dateLabel)", statusLabel]
        if let score {
            parts.append(FormaProductCopy.Journey.HealthIntelligence.recoveryScoreLabel(score))
        }
        if let explanation {
            parts.append(explanation)
        }
        if limited {
            parts.append(FormaProductCopy.Journey.HealthIntelligence.limitedEstimate)
        }
        return parts.joined(separator: ". ")
    }

    private static func workoutHistoryAccessibilityLabel(items: [JourneyWorkoutHistoryItemState]) -> String {
        "Recent workouts. \(items.map(\.accessibilityLabel).joined(separator: ". "))"
    }

    private static func workoutItemAccessibilityLabel(
        dateLabel: String,
        title: String,
        durationLabel: String,
        caloriesLabel: String?,
        demandLabel: String?
    ) -> String {
        var parts = ["\(dateLabel)", title, durationLabel]
        if let caloriesLabel {
            parts.append(caloriesLabel)
        }
        if let demandLabel {
            parts.append(demandLabel)
        }
        return parts.joined(separator: ". ")
    }

    private static func milestonesAccessibilityLabel(items: [JourneyHealthMilestoneState]) -> String {
        "Health milestones. \(items.map(\.accessibilityLabel).joined(separator: ". "))"
    }

    private static func progressAccessibilityLabel(
        headline: String,
        detailLines: [String],
        metrics: [JourneyHealthProgressMetricRow]
    ) -> String {
        var parts = ["Health progress", headline]
        parts.append(contentsOf: detailLines)
        for metric in metrics {
            parts.append("\(metric.title): \(metric.value)")
        }
        return parts.joined(separator: ". ")
    }
}
