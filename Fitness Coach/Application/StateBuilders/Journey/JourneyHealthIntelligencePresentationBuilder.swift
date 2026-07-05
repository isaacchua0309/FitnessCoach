//
//  JourneyHealthIntelligencePresentationBuilder.swift
//  Fitness Coach
//
//  Forma — Maps Health Intelligence data into Journey presentation state.
//  Pure deterministic mapping; no SwiftUI or HealthKit.
//

import Foundation

enum JourneyHealthIntelligencePresentationBuilder {

    private static let surface: HealthIntelligenceSurface = .journey
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

        let uiState = resolveUIState(from: input)

        if input.isLoading || uiState.kind == .loading {
            return loadingSection(uiState: uiState)
        }

        if uiState.kind == .syncFailed, !uiState.canShowInsight {
            return errorSection(
                from: uiState,
                message: HealthIntelligencePresentationCore.trimmed(input.errorMessage)
            )
        }

        if shouldShowConnectOnlySection(uiState: uiState) {
            return connectHealthSection(from: uiState)
        }

        let connection = resolvedHealthConnection(from: input)
        let timelineDayCount = min(max(input.recoveryTimelineDayCount, defaultTimelineDayCount), maxTimelineDayCount)
        let recoveryDays = normalizedRecoveryDays(from: input, calendar: calendar)
        let workoutRecords = normalizedWorkoutRecords(
            from: input,
            referenceDate: input.todaySnapshot?.date ?? Date(),
            calendar: calendar
        )

        let hasAnyHealthData = !recoveryDays.isEmpty || !workoutRecords.isEmpty || input.weeklyReview != nil
        if !hasAnyHealthData {
            return emptyDataSection(connection: connection, uiState: uiState)
        }

        let staleLabel = HealthIntelligencePresentationCore.staleDataLabel(for: uiState, surface: surface)
        let weeklyPresentation = weeklyReviewPresentation(
            from: input.weeklyReview,
            isLoading: false,
            showBuildingWhenMissing: connection == .connected && hasAnyHealthData,
            uiState: uiState,
            calendar: calendar
        )

        let timeline = recoveryTimeline(
            from: recoveryDays,
            dayCount: timelineDayCount,
            referenceDate: input.todaySnapshot?.date ?? Date(),
            uiState: uiState,
            calendar: calendar
        )

        return JourneyHealthIntelligenceSectionState(
            weeklyReviewCard: weeklyPresentation.card,
            weeklyReviewDetail: weeklyPresentation.detail,
            recoveryTimeline: timeline,
            workoutHistory: workoutHistory(
                from: workoutRecords,
                healthConnection: connection,
                uiState: uiState,
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
            connectHealthCTA: connectHealthCTA(from: uiState),
            isLoading: false,
            errorMessage: HealthIntelligencePresentationPolicy.syncFailureSectionMessage(for: uiState),
            fallbackMessage: HealthIntelligencePresentationCore.fallbackMessage(for: uiState, surface: surface),
            staleDataLabel: staleLabel,
            partialSignalsNote: HealthIntelligencePresentationCore.partialSignalsNote(for: uiState, surface: surface),
            uiState: uiState
        )
    }

    // MARK: - Weekly review

    static func weeklyReviewPresentation(
        from review: WeeklyHealthReview?,
        isLoading: Bool,
        showBuildingWhenMissing: Bool,
        uiState: HealthIntelligenceUIState? = nil,
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
            return (weeklyReviewBuildingCard(uiState: uiState), nil)
        }

        return (nil, nil)
    }

    private static func weeklyReviewBuildingCard(
        uiState: HealthIntelligenceUIState?
    ) -> WeeklyReviewCardState {
        let content = HealthIntelligencePresentationCore.buildWeeklyReviewBuildingContent(uiState: uiState)
        let copy = FormaProductCopy.WeeklyReviewPresentation.self

        return WeeklyReviewCardState(
            phase: .empty,
            sectionTitle: copy.sectionTitle,
            dateRangeLabel: content.dateRangeLabel,
            title: content.title,
            summary: content.summary,
            confidenceLabel: content.confidenceLabel,
            headlineStatLabel: nil,
            accessibilityLabel: content.accessibilityLabel
        )
    }

    // MARK: - Recovery timeline

    static func recoveryTimeline(
        from recoveryDays: [JourneyHealthIntelligenceRecoveryDayInput],
        dayCount: Int = defaultTimelineDayCount,
        referenceDate: Date = Date(),
        uiState: HealthIntelligenceUIState? = nil,
        calendar: Calendar = .current
    ) -> JourneyRecoveryTimelineState {
        let endDay = calendar.startOfDay(for: referenceDate)
        // Inclusive span of `dayCount` days ending on referenceDate (oldest first in UI).
        let days = (0..<dayCount).reversed().compactMap { offset -> JourneyRecoveryDayState? in
            guard let date = calendar.date(byAdding: .day, value: -offset, to: endDay) else { return nil }
            let input = recoveryDays.first {
                calendar.isDate($0.date, inSameDayAs: date)
            }
            return recoveryDay(for: date, input: input, calendar: calendar)
        }

        let knownDays = days.filter { $0.statusKind != .unknown || $0.recoveryScore != nil }
        let limitedNote = limitedTimelineNote(for: days, uiState: uiState)

        if knownDays.isEmpty {
            return JourneyRecoveryTimelineState(
                phase: .empty,
                sectionTitle: FormaProductCopy.Journey.HealthIntelligence.RecoveryTimeline.sectionTitle,
                headline: timelineHeadline(dayCount: dayCount),
                days: days,
                dayCount: dayCount,
                emptyMessage: FormaProductCopy.Journey.HealthIntelligence.RecoveryTimeline.emptyMessage,
                limitedTimelineNote: limitedNote,
                errorMessage: nil,
                accessibilityLabel: [
                    FormaProductCopy.Journey.HealthIntelligence.RecoveryTimeline.emptyMessage,
                    limitedNote
                ].compactMap { $0 }.joined(separator: ". ")
            )
        }

        return JourneyRecoveryTimelineState(
            phase: .loaded,
            sectionTitle: FormaProductCopy.Journey.HealthIntelligence.RecoveryTimeline.sectionTitle,
            headline: timelineHeadline(dayCount: dayCount),
            days: days,
            dayCount: dayCount,
            emptyMessage: nil,
            limitedTimelineNote: limitedNote,
            errorMessage: nil,
            accessibilityLabel: recoveryTimelineAccessibilityLabel(days: days, limitedNote: limitedNote)
        )
    }

    static func recoveryDay(
        for date: Date,
        input: JourneyHealthIntelligenceRecoveryDayInput?,
        calendar: Calendar
    ) -> JourneyRecoveryDayState {
        let recovery = input?.recovery ?? .unknown
        let phase = HealthIntelligencePresentationCore.recoveryPhase(from: recovery)
        let statusKind = journeyStatusKind(from: phase)
        let statusLabel = HealthIntelligencePresentationCore.journeyRecoveryStatusLabel(for: phase)
        let statusColorToken = HealthIntelligencePresentationCore.journeyRecoveryStatusColorToken(for: phase)
        let limited = statusKind == .limitedEstimate
        let limitedEstimateLabel = limited ? FormaProductCopy.Journey.HealthIntelligence.limitedEstimate : nil
        let score = HealthIntelligencePresentationCore.coachSafeRecoveryScore(from: recovery)
        let explanation = HealthIntelligencePresentationCore.recoverySubtitle(
            from: recovery,
            surface: surface
        )
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

    // MARK: - Workout history

    static func workoutHistory(
        from workoutRecords: [JourneyHealthIntelligenceWorkoutRecordInput],
        healthConnection: JourneyHealthConnectionState = .connected,
        uiState: HealthIntelligenceUIState? = nil,
        calendar: Calendar = .current
    ) -> JourneyWorkoutHistoryState {
        let items = workoutRecords
            .map { workoutItem(from: $0, calendar: calendar) }
            .sorted { $0.date > $1.date }

        if items.isEmpty {
            let emptyKind: JourneyHealthIntelligenceEmptyKind = healthConnection == .connected
                ? .connectedNoWorkouts
                : .insufficientHistory
            let emptyMessage = workoutHistoryEmptyMessage(
                healthConnection: healthConnection,
                uiState: uiState
            )

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
        let title = HealthIntelligencePresentationCore.trimmed(record.title)
            ?? FormaProductCopy.Today.HealthIntelligence.workoutComplete
        let durationLabel = FormaProductCopy.Journey.HealthIntelligence.durationLabel(minutes: record.durationMinutes)
        let caloriesLabel = HealthIntelligencePresentationCore.coachSafeCaloriesLabel(from: record.activeCalories)
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
                let title = HealthIntelligencePresentationCore.sanitizedText(win) ?? win
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

    // MARK: - Private section builders

    private static func loadingSection(
        uiState: HealthIntelligenceUIState? = nil
    ) -> JourneyHealthIntelligenceSectionState {
        JourneyHealthIntelligenceSectionState(
            weeklyReviewCard: .loading,
            weeklyReviewDetail: nil,
            recoveryTimeline: .loading,
            workoutHistory: .loading,
            milestones: .loading,
            progress: .loading,
            connectHealthCTA: nil,
            isLoading: true,
            errorMessage: nil,
            fallbackMessage: nil,
            staleDataLabel: nil,
            partialSignalsNote: nil,
            uiState: uiState
        )
    }

    private static func resolveUIState(from input: JourneyHealthIntelligenceBuildInput) -> HealthIntelligenceUIState {
        let presentationContext = HealthIntelligencePresentationCore.presentationContext(
            snapshot: input.todaySnapshot,
            isLoading: input.isLoading,
            availability: input.availability,
            isAppleHealthConnected: input.healthConnection == .connected,
            cachedDayCount: input.cachedDayCount,
            errorMessage: input.errorMessage,
            syncPhase: input.syncPhase
        )

        return HealthIntelligencePresentationCore.resolveUIState(
            from: HealthIntelligenceUIResolutionInput(
                presentationContext: presentationContext,
                baseline: input.baseline,
                lastSuccessfulLocalSyncAt: input.lastSuccessfulLocalSyncAt,
                isRemoteSyncCapabilityEnabled: input.isRemoteSyncCapabilityEnabled,
                remoteSyncConsentDecision: input.remoteSyncConsentDecision,
                surface: surface
            )
        )
    }

    private static func shouldShowConnectOnlySection(uiState: HealthIntelligenceUIState) -> Bool {
        switch uiState.kind {
        case .noHealthPermission, .healthKitUnavailable:
            return !uiState.canShowInsight
        default:
            return false
        }
    }

    private static func emptyDataSection(
        connection: JourneyHealthConnectionState,
        uiState: HealthIntelligenceUIState
    ) -> JourneyHealthIntelligenceSectionState {
        let copy = FormaProductCopy.HealthIntelligence.UIState.message(
            for: uiState.kind,
            surface: .journey,
            explicitErrorMessage: nil
        )
        let cta = connectHealthCTA(from: uiState)

        return JourneyHealthIntelligenceSectionState(
            weeklyReviewCard: nil,
            weeklyReviewDetail: nil,
            recoveryTimeline: JourneyRecoveryTimelineState(
                phase: .empty,
                sectionTitle: FormaProductCopy.Journey.HealthIntelligence.RecoveryTimeline.sectionTitle,
                headline: copy.title.isEmpty
                    ? FormaProductCopy.Journey.HealthIntelligence.RecoveryTimeline.sectionTitle
                    : copy.title,
                days: [],
                dayCount: defaultTimelineDayCount,
                emptyMessage: FormaProductCopy.Journey.HealthIntelligence.RecoveryTimeline.emptyMessage,
                limitedTimelineNote: FormaProductCopy.Journey.HealthIntelligence.RecoveryTimeline.limitedTimelineNote,
                errorMessage: nil,
                accessibilityLabel: copy.message
            ),
            workoutHistory: JourneyWorkoutHistoryState(
                phase: .empty,
                sectionTitle: FormaProductCopy.Journey.HealthIntelligence.WorkoutHistory.sectionTitle,
                headline: copy.title.isEmpty
                    ? FormaProductCopy.Journey.HealthIntelligence.WorkoutHistory.sectionTitle
                    : copy.title,
                groups: [],
                items: [],
                emptyKind: connection == .connected ? .connectedNoWorkouts : .noHealthData,
                emptyMessage: workoutHistoryEmptyMessage(
                    healthConnection: connection,
                    uiState: uiState
                ),
                errorMessage: nil,
                accessibilityLabel: copy.message
            ),
            milestones: JourneyHealthMilestonesState(
                phase: .empty,
                sectionTitle: FormaProductCopy.Journey.HealthIntelligence.Milestones.sectionTitle,
                headline: copy.title.isEmpty
                    ? FormaProductCopy.Journey.HealthIntelligence.Milestones.headline
                    : copy.title,
                items: [],
                emptyMessage: FormaProductCopy.Journey.HealthIntelligence.Milestones.emptyMessage,
                errorMessage: nil,
                accessibilityLabel: copy.message
            ),
            progress: JourneyHealthProgressState(
                phase: .empty,
                sectionTitle: FormaProductCopy.Journey.HealthIntelligence.Progress.sectionTitle,
                headline: copy.title.isEmpty
                    ? FormaProductCopy.Journey.HealthIntelligence.Progress.headline
                    : copy.title,
                detailLines: [],
                metrics: [],
                emptyMessage: FormaProductCopy.Journey.HealthIntelligence.Progress.emptyMessage,
                errorMessage: nil,
                accessibilityLabel: copy.message
            ),
            connectHealthCTA: cta,
            isLoading: false,
            errorMessage: nil,
            fallbackMessage: HealthIntelligencePresentationCore.fallbackMessage(for: uiState, surface: surface),
            staleDataLabel: nil,
            partialSignalsNote: HealthIntelligencePresentationCore.partialSignalsNote(for: uiState, surface: surface),
            uiState: uiState
        )
    }

    private static func connectHealthSection(
        from uiState: HealthIntelligenceUIState
    ) -> JourneyHealthIntelligenceSectionState {
        let copy = FormaProductCopy.HealthIntelligence.UIState.message(
            for: uiState.kind,
            surface: .journey,
            explicitErrorMessage: nil
        )
        let cta = connectHealthCTA(from: uiState)
            ?? JourneyHealthConnectCTAState(
                title: copy.title,
                message: copy.message,
                ctaTitle: copy.primaryActionTitle ?? FormaProductCopy.Journey.HealthIntelligence.connectHealthCTA,
                accessibilityLabel: "\(copy.title). \(copy.message)"
            )

        return JourneyHealthIntelligenceSectionState(
            weeklyReviewCard: nil,
            weeklyReviewDetail: nil,
            recoveryTimeline: JourneyRecoveryTimelineState(
                phase: .empty,
                sectionTitle: FormaProductCopy.Journey.HealthIntelligence.RecoveryTimeline.sectionTitle,
                headline: copy.title,
                days: [],
                dayCount: defaultTimelineDayCount,
                emptyMessage: copy.message,
                limitedTimelineNote: nil,
                errorMessage: nil,
                accessibilityLabel: cta.accessibilityLabel
            ),
            workoutHistory: JourneyWorkoutHistoryState(
                phase: .empty,
                sectionTitle: FormaProductCopy.Journey.HealthIntelligence.WorkoutHistory.sectionTitle,
                headline: copy.title,
                groups: [],
                items: [],
                emptyKind: .noHealthData,
                emptyMessage: copy.message,
                errorMessage: nil,
                accessibilityLabel: cta.accessibilityLabel
            ),
            milestones: JourneyHealthMilestonesState(
                phase: .empty,
                sectionTitle: FormaProductCopy.Journey.HealthIntelligence.Milestones.sectionTitle,
                headline: copy.title,
                items: [],
                emptyMessage: copy.message,
                errorMessage: nil,
                accessibilityLabel: cta.accessibilityLabel
            ),
            progress: JourneyHealthProgressState(
                phase: .empty,
                sectionTitle: FormaProductCopy.Journey.HealthIntelligence.Progress.sectionTitle,
                headline: copy.title,
                detailLines: [copy.message],
                metrics: [],
                emptyMessage: copy.message,
                errorMessage: nil,
                accessibilityLabel: cta.accessibilityLabel
            ),
            connectHealthCTA: cta,
            isLoading: false,
            errorMessage: nil,
            fallbackMessage: HealthIntelligencePresentationCore.fallbackMessage(for: uiState, surface: surface),
            staleDataLabel: nil,
            partialSignalsNote: nil,
            uiState: uiState
        )
    }

    private static func errorSection(
        from uiState: HealthIntelligenceUIState,
        message: String?
    ) -> JourneyHealthIntelligenceSectionState {
        let copy = FormaProductCopy.HealthIntelligence.UIState.message(
            for: .syncFailed,
            surface: .journey,
            explicitErrorMessage: message
        )
        let resolvedMessage = message ?? copy.message

        return JourneyHealthIntelligenceSectionState(
            weeklyReviewCard: nil,
            weeklyReviewDetail: nil,
            recoveryTimeline: JourneyRecoveryTimelineState(
                phase: .error,
                sectionTitle: FormaProductCopy.Journey.HealthIntelligence.RecoveryTimeline.sectionTitle,
                headline: copy.title,
                days: [],
                dayCount: defaultTimelineDayCount,
                emptyMessage: nil,
                limitedTimelineNote: nil,
                errorMessage: resolvedMessage,
                accessibilityLabel: resolvedMessage
            ),
            workoutHistory: JourneyWorkoutHistoryState(
                phase: .error,
                sectionTitle: FormaProductCopy.Journey.HealthIntelligence.WorkoutHistory.sectionTitle,
                headline: copy.title,
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
                headline: copy.title,
                items: [],
                emptyMessage: nil,
                errorMessage: resolvedMessage,
                accessibilityLabel: resolvedMessage
            ),
            progress: JourneyHealthProgressState(
                phase: .error,
                sectionTitle: FormaProductCopy.Journey.HealthIntelligence.Progress.sectionTitle,
                headline: copy.title,
                detailLines: [resolvedMessage],
                metrics: [],
                emptyMessage: nil,
                errorMessage: resolvedMessage,
                accessibilityLabel: resolvedMessage
            ),
            connectHealthCTA: nil,
            isLoading: false,
            errorMessage: resolvedMessage,
            fallbackMessage: HealthIntelligencePresentationCore.fallbackMessage(for: uiState, surface: surface),
            staleDataLabel: nil,
            partialSignalsNote: nil,
            uiState: uiState
        )
    }

    private static func connectHealthCTA(
        from uiState: HealthIntelligenceUIState
    ) -> JourneyHealthConnectCTAState? {
        guard let copy = HealthIntelligencePresentationCore.connectCTACopy(
            for: uiState,
            surface: surface,
            defaultCTATitle: FormaProductCopy.Journey.HealthIntelligence.connectHealthCTA
        ) else {
            return nil
        }

        return JourneyHealthConnectCTAState(
            title: copy.title,
            message: copy.message,
            ctaTitle: copy.ctaTitle ?? FormaProductCopy.Journey.HealthIntelligence.connectHealthCTA,
            accessibilityLabel: copy.accessibilityLabel
        )
    }

    private static func limitedTimelineNote(
        for days: [JourneyRecoveryDayState],
        uiState: HealthIntelligenceUIState?
    ) -> String? {
        let knownDays = days.filter { $0.statusKind != .unknown || $0.recoveryScore != nil }
        if knownDays.isEmpty {
            return FormaProductCopy.Journey.HealthIntelligence.RecoveryTimeline.limitedTimelineNote
        }
        if knownDays.count < days.count / 2 {
            return FormaProductCopy.Journey.HealthIntelligence.RecoveryTimeline.limitedTimelineNote
        }
        if uiState?.kind == .partialPermission || uiState?.kind == .notEnoughBaseline {
            return FormaProductCopy.Journey.HealthIntelligence.RecoveryTimeline.limitedTimelineNote
        }
        return nil
    }

    private static func workoutHistoryEmptyMessage(
        healthConnection: JourneyHealthConnectionState,
        uiState: HealthIntelligenceUIState?
    ) -> String {
        if healthConnection == .connected {
            if uiState?.kind == .noWorkoutHistory {
                return FormaProductCopy.HealthIntelligence.UIState.message(
                    for: .noWorkoutHistory,
                    surface: .journey,
                    explicitErrorMessage: nil
                ).message
            }
            return FormaProductCopy.Journey.HealthIntelligence.connectedNoWorkoutsMessage
        }
        return FormaProductCopy.Journey.HealthIntelligence.WorkoutHistory.emptyMessage
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

    private static func journeyStatusKind(
        from phase: HealthIntelligenceRecoveryPhase
    ) -> JourneyRecoveryDayStatusKind {
        switch phase {
        case .ready: return .ready
        case .moderate: return .moderate
        case .low: return .low
        case .limitedEstimate: return .limitedEstimate
        case .unknown: return .unknown
        }
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
        let cutoff = JourneyLogMetrics.lookbackStart(
            endingOn: referenceDate,
            dayCount: workoutHistoryWindowDays,
            calendar: calendar
        )
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
        JourneyFormatter.timelineDateRangeLabel(start: start, end: end, calendar: calendar)
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

    private static func recoveryTimelineAccessibilityLabel(
        days: [JourneyRecoveryDayState],
        limitedNote: String? = nil
    ) -> String {
        let summaries = days.map(\.accessibilityLabel).joined(separator: ". ")
        var parts = ["Recovery timeline.", summaries]
        if let limitedNote {
            parts.append(limitedNote)
        }
        return parts.joined(separator: " ")
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
