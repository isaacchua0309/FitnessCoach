//
//  JourneyHealthIntelligencePresentationBuilder.swift
//  Fitness Coach
//
//  Forma — Maps HealthIntelligenceSnapshot history into Journey presentation state.
//  Pure deterministic mapping; no SwiftUI or HealthKit.
//

import Foundation

enum JourneyHealthIntelligencePresentationBuilder {

    private static let timelineDayCount = 7
    private static let workoutHistoryLimit = 8

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

        let snapshots = normalizedSnapshots(
            current: input.currentSnapshot,
            historical: input.historicalSnapshots,
            calendar: calendar
        )

        guard !snapshots.isEmpty else {
            return unavailableSection()
        }

        let weeklyReview = weeklyReviewPreview(
            from: input.currentSnapshot?.weeklyReview,
            calendar: calendar
        )

        return JourneyHealthIntelligenceSectionState(
            weeklyReviewPreview: weeklyReview,
            recoveryTimeline: recoveryTimeline(from: snapshots, calendar: calendar),
            workoutHistory: workoutHistory(from: snapshots, calendar: calendar),
            milestones: milestones(from: input.currentSnapshot?.weeklyReview),
            progress: progress(from: input.currentSnapshot?.weeklyReview),
            isLoading: false,
            errorMessage: nil
        )
    }

    // MARK: - Weekly review

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
        from snapshots: [HealthIntelligenceSnapshot],
        calendar: Calendar
    ) -> JourneyRecoveryTimelineState {
        let timelineSnapshots = Array(snapshots.suffix(timelineDayCount))
        let days = timelineSnapshots.map { recoveryDay(from: $0, calendar: calendar) }

        if days.isEmpty {
            return JourneyRecoveryTimelineState(
                phase: .empty,
                sectionTitle: FormaProductCopy.Journey.HealthIntelligence.RecoveryTimeline.sectionTitle,
                headline: FormaProductCopy.Journey.HealthIntelligence.RecoveryTimeline.headline,
                days: [],
                emptyMessage: FormaProductCopy.Journey.HealthIntelligence.RecoveryTimeline.emptyMessage,
                errorMessage: nil,
                accessibilityLabel: FormaProductCopy.Journey.HealthIntelligence.RecoveryTimeline.emptyMessage
            )
        }

        return JourneyRecoveryTimelineState(
            phase: .loaded,
            sectionTitle: FormaProductCopy.Journey.HealthIntelligence.RecoveryTimeline.sectionTitle,
            headline: FormaProductCopy.Journey.HealthIntelligence.RecoveryTimeline.headline,
            days: days,
            emptyMessage: nil,
            errorMessage: nil,
            accessibilityLabel: recoveryTimelineAccessibilityLabel(days: days)
        )
    }

    static func recoveryDay(
        from snapshot: HealthIntelligenceSnapshot,
        calendar: Calendar
    ) -> JourneyRecoveryDayState {
        let recovery = snapshot.recovery
        let statusKind = recoveryStatusKind(from: recovery)
        let statusLabel = recoveryStatusLabel(for: statusKind)
        let explanation = coachSafeRecoveryExplanation(from: recovery)
        let limited = statusKind == .limitedEstimate
        let dateLabel = JourneyFormatter.timelineDayLabel(snapshot.date, calendar: calendar)
        let weekdayLabel = weekdayLabel(for: snapshot.date, calendar: calendar)
        let id = dayIdentifier(for: snapshot.date, calendar: calendar)

        return JourneyRecoveryDayState(
            id: id,
            date: calendar.startOfDay(for: snapshot.date),
            dateLabel: dateLabel,
            weekdayLabel: weekdayLabel,
            statusLabel: statusLabel,
            statusKind: statusKind,
            shortExplanation: explanation,
            isLimitedEstimate: limited,
            accessibilityLabel: recoveryDayAccessibilityLabel(
                dateLabel: dateLabel,
                weekdayLabel: weekdayLabel,
                statusLabel: statusLabel,
                explanation: explanation,
                limited: limited
            )
        )
    }

    // MARK: - Workout history

    static func workoutHistory(
        from snapshots: [HealthIntelligenceSnapshot],
        calendar: Calendar
    ) -> JourneyWorkoutHistoryState {
        let items = snapshots
            .compactMap { workoutItem(from: $0, calendar: calendar) }
            .sorted { $0.date > $1.date }
            .prefix(workoutHistoryLimit)

        if items.isEmpty {
            return JourneyWorkoutHistoryState(
                phase: .empty,
                sectionTitle: FormaProductCopy.Journey.HealthIntelligence.WorkoutHistory.sectionTitle,
                headline: FormaProductCopy.Journey.HealthIntelligence.WorkoutHistory.headline,
                items: [],
                emptyMessage: FormaProductCopy.Journey.HealthIntelligence.WorkoutHistory.emptyMessage,
                errorMessage: nil,
                accessibilityLabel: FormaProductCopy.Journey.HealthIntelligence.WorkoutHistory.emptyMessage
            )
        }

        let mapped = Array(items)
        return JourneyWorkoutHistoryState(
            phase: .loaded,
            sectionTitle: FormaProductCopy.Journey.HealthIntelligence.WorkoutHistory.sectionTitle,
            headline: FormaProductCopy.Journey.HealthIntelligence.WorkoutHistory.headline,
            items: mapped,
            emptyMessage: nil,
            errorMessage: nil,
            accessibilityLabel: workoutHistoryAccessibilityLabel(items: mapped)
        )
    }

    static func workoutItem(
        from snapshot: HealthIntelligenceSnapshot,
        calendar: Calendar
    ) -> JourneyWorkoutHistoryItemState? {
        guard let workout = snapshot.workout, workout.hasWorkout else { return nil }

        let dateLabel = JourneyFormatter.timelineDayLabel(snapshot.date, calendar: calendar)
        let title = trimmed(workout.title) ?? FormaProductCopy.Today.HealthIntelligence.workoutComplete
        let durationLabel = FormaProductCopy.Journey.HealthIntelligence.durationLabel(
            minutes: workout.totalDurationMinutes
        )
        let demandLabel = workout.demand == .unknown
            ? nil
            : FormaProductCopy.Journey.HealthIntelligence.demandLabel(workout.demand.rawValue)
        let intensityLabel = workout.intensity == .unknown
            ? nil
            : workout.intensity.rawValue.capitalized
        let explanation = sanitizedText(workout.explanation)
        let id = "\(dayIdentifier(for: snapshot.date, calendar: calendar))-workout"

        return JourneyWorkoutHistoryItemState(
            id: id,
            date: calendar.startOfDay(for: snapshot.date),
            dateLabel: dateLabel,
            workoutTitle: title,
            durationLabel: durationLabel,
            demandLabel: demandLabel,
            intensityLabel: intensityLabel,
            shortExplanation: explanation,
            accessibilityLabel: workoutItemAccessibilityLabel(
                dateLabel: dateLabel,
                title: title,
                durationLabel: durationLabel,
                demandLabel: demandLabel,
                explanation: explanation
            )
        )
    }

    // MARK: - Milestones

    static func milestones(from review: WeeklyHealthReview?) -> JourneyHealthMilestonesState {
        guard let review else {
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

        var items: [JourneyHealthMilestoneState] = []

        for (index, win) in review.wins.enumerated() {
            let title = sanitizedText(win) ?? win
            guard !title.isEmpty else { continue }
            items.append(
                JourneyHealthMilestoneState(
                    id: "win-\(index)",
                    title: title,
                    detail: FormaProductCopy.Journey.HealthIntelligence.WeeklyReview.sectionTitle,
                    status: .achieved,
                    statusLabel: FormaProductCopy.Journey.HealthIntelligence.milestoneAchieved,
                    progressLabel: nil,
                    accessibilityLabel: "\(title). \(FormaProductCopy.Journey.HealthIntelligence.milestoneAchieved)."
                )
            )
        }

        for (index, focus) in review.nextWeekFocus.enumerated() {
            let title = sanitizedText(focus) ?? focus
            guard !title.isEmpty else { continue }
            items.append(
                JourneyHealthMilestoneState(
                    id: "focus-\(index)",
                    title: title,
                    detail: "Focus for next week",
                    status: .inProgress,
                    statusLabel: FormaProductCopy.Journey.HealthIntelligence.milestoneInProgress,
                    progressLabel: nil,
                    accessibilityLabel: "\(title). \(FormaProductCopy.Journey.HealthIntelligence.milestoneInProgress)."
                )
            )
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

    static func progress(from review: WeeklyHealthReview?) -> JourneyHealthProgressState {
        guard let review, review.stats.totalWorkouts > 0 || review.stats.loggingConsistencyDays > 0 else {
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

        let stats = review.stats
        var detailLines: [String] = []
        var metrics: [JourneyHealthProgressMetricRow] = []

        if stats.totalWorkouts > 0 {
            let value = FormaProductCopy.Journey.HealthIntelligence.workoutsThisWeek(stats.totalWorkouts)
            detailLines.append("\(value) logged this week.")
            metrics.append(
                JourneyHealthProgressMetricRow(
                    id: "workouts",
                    title: "Workouts",
                    value: "\(stats.totalWorkouts)",
                    detail: FormaProductCopy.Journey.HealthIntelligence.durationLabel(minutes: stats.totalWorkoutMinutes)
                )
            )
        }

        if stats.lowRecoveryDays > 0 {
            detailLines.append(
                FormaProductCopy.Journey.HealthIntelligence.limitedRecoveryDays(stats.lowRecoveryDays) + "."
            )
            metrics.append(
                JourneyHealthProgressMetricRow(
                    id: "recovery",
                    title: "Limited recovery",
                    value: "\(stats.lowRecoveryDays)",
                    detail: "Days this week"
                )
            )
        }

        if let averageSteps = stats.averageSteps, averageSteps > 0 {
            metrics.append(
                JourneyHealthProgressMetricRow(
                    id: "steps",
                    title: "Average steps",
                    value: averageSteps.formatted(),
                    detail: "Daily average"
                )
            )
        }

        if stats.proteinHitDays > 0 {
            metrics.append(
                JourneyHealthProgressMetricRow(
                    id: "protein",
                    title: "Protein days",
                    value: "\(stats.proteinHitDays)",
                    detail: "Days on target"
                )
            )
        }

        let headline = review.title.isEmpty
            ? FormaProductCopy.Journey.HealthIntelligence.Progress.headline
            : review.title

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

    private static func loadingSection() -> JourneyHealthIntelligenceSectionState {
        JourneyHealthIntelligenceSectionState(
            weeklyReviewPreview: .loading,
            recoveryTimeline: .loading,
            workoutHistory: .loading,
            milestones: .loading,
            progress: .loading,
            isLoading: true,
            errorMessage: nil
        )
    }

    private static func unavailableSection() -> JourneyHealthIntelligenceSectionState {
        let emptyTimeline = JourneyRecoveryTimelineState(
            phase: .empty,
            sectionTitle: FormaProductCopy.Journey.HealthIntelligence.RecoveryTimeline.sectionTitle,
            headline: FormaProductCopy.Journey.HealthIntelligence.unavailableTitle,
            days: [],
            emptyMessage: FormaProductCopy.Journey.HealthIntelligence.unavailableSubtitle,
            errorMessage: nil,
            accessibilityLabel: FormaProductCopy.Journey.HealthIntelligence.unavailableSubtitle
        )

        return JourneyHealthIntelligenceSectionState(
            weeklyReviewPreview: nil,
            recoveryTimeline: emptyTimeline,
            workoutHistory: JourneyWorkoutHistoryState(
                phase: .empty,
                sectionTitle: FormaProductCopy.Journey.HealthIntelligence.WorkoutHistory.sectionTitle,
                headline: FormaProductCopy.Journey.HealthIntelligence.unavailableTitle,
                items: [],
                emptyMessage: FormaProductCopy.Journey.HealthIntelligence.unavailableSubtitle,
                errorMessage: nil,
                accessibilityLabel: FormaProductCopy.Journey.HealthIntelligence.unavailableSubtitle
            ),
            milestones: JourneyHealthMilestonesState(
                phase: .empty,
                sectionTitle: FormaProductCopy.Journey.HealthIntelligence.Milestones.sectionTitle,
                headline: FormaProductCopy.Journey.HealthIntelligence.unavailableTitle,
                items: [],
                emptyMessage: FormaProductCopy.Journey.HealthIntelligence.unavailableSubtitle,
                errorMessage: nil,
                accessibilityLabel: FormaProductCopy.Journey.HealthIntelligence.unavailableSubtitle
            ),
            progress: JourneyHealthProgressState(
                phase: .empty,
                sectionTitle: FormaProductCopy.Journey.HealthIntelligence.Progress.sectionTitle,
                headline: FormaProductCopy.Journey.HealthIntelligence.unavailableTitle,
                detailLines: [FormaProductCopy.Journey.HealthIntelligence.unavailableSubtitle],
                metrics: [],
                emptyMessage: FormaProductCopy.Journey.HealthIntelligence.unavailableSubtitle,
                errorMessage: nil,
                accessibilityLabel: FormaProductCopy.Journey.HealthIntelligence.unavailableSubtitle
            ),
            isLoading: false,
            errorMessage: FormaProductCopy.Journey.HealthIntelligence.unavailableSubtitle
        )
    }

    private static func errorSection(message: String) -> JourneyHealthIntelligenceSectionState {
        JourneyHealthIntelligenceSectionState(
            weeklyReviewPreview: JourneyWeeklyReviewPreviewState(
                phase: .error,
                sectionTitle: FormaProductCopy.Journey.HealthIntelligence.WeeklyReview.sectionTitle,
                weekRangeLabel: "",
                title: FormaProductCopy.Journey.HealthIntelligence.errorTitle,
                summary: message,
                winLines: [],
                focusLines: [],
                confidenceNote: nil,
                accessibilityLabel: message
            ),
            recoveryTimeline: JourneyRecoveryTimelineState(
                phase: .error,
                sectionTitle: FormaProductCopy.Journey.HealthIntelligence.RecoveryTimeline.sectionTitle,
                headline: FormaProductCopy.Journey.HealthIntelligence.errorTitle,
                days: [],
                emptyMessage: nil,
                errorMessage: message,
                accessibilityLabel: message
            ),
            workoutHistory: JourneyWorkoutHistoryState(
                phase: .error,
                sectionTitle: FormaProductCopy.Journey.HealthIntelligence.WorkoutHistory.sectionTitle,
                headline: FormaProductCopy.Journey.HealthIntelligence.errorTitle,
                items: [],
                emptyMessage: nil,
                errorMessage: message,
                accessibilityLabel: message
            ),
            milestones: JourneyHealthMilestonesState(
                phase: .error,
                sectionTitle: FormaProductCopy.Journey.HealthIntelligence.Milestones.sectionTitle,
                headline: FormaProductCopy.Journey.HealthIntelligence.errorTitle,
                items: [],
                emptyMessage: nil,
                errorMessage: message,
                accessibilityLabel: message
            ),
            progress: JourneyHealthProgressState(
                phase: .error,
                sectionTitle: FormaProductCopy.Journey.HealthIntelligence.Progress.sectionTitle,
                headline: FormaProductCopy.Journey.HealthIntelligence.errorTitle,
                detailLines: [message],
                metrics: [],
                emptyMessage: nil,
                errorMessage: message,
                accessibilityLabel: message
            ),
            isLoading: false,
            errorMessage: message
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

    // MARK: - Normalization

    private static func normalizedSnapshots(
        current: HealthIntelligenceSnapshot?,
        historical: [HealthIntelligenceSnapshot],
        calendar: Calendar
    ) -> [HealthIntelligenceSnapshot] {
        var byDay: [Date: HealthIntelligenceSnapshot] = [:]

        for snapshot in historical {
            let day = calendar.startOfDay(for: snapshot.date)
            byDay[day] = snapshot
        }

        if let current {
            let day = calendar.startOfDay(for: current.date)
            byDay[day] = current
        }

        return byDay.values.sorted { $0.date < $1.date }
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
        explanation: String?,
        limited: Bool
    ) -> String {
        var parts = ["\(weekdayLabel) \(dateLabel)", statusLabel]
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
        demandLabel: String?,
        explanation: String?
    ) -> String {
        var parts = ["\(dateLabel)", title, durationLabel]
        if let demandLabel {
            parts.append(demandLabel)
        }
        if let explanation {
            parts.append(explanation)
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
