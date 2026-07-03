//
//  WeeklyReviewPresentationBuilder.swift
//  Fitness Coach
//
//  Forma — Maps WeeklyHealthReview into presentation-friendly weekly review state.
//

import Foundation

enum WeeklyReviewPresentationBuilder {

    // MARK: - Public

    static func buildCard(
        from review: WeeklyHealthReview?,
        calendar: Calendar = .current
    ) -> WeeklyReviewCardState {
        guard let review, isRenderable(review) else {
            return .empty
        }

        let dateRangeLabel = dateRangeLabel(
            start: review.weekStartDate,
            end: review.weekEndDate,
            calendar: calendar
        )
        let title = trimmed(review.title) ?? review.title
        let summary = safeSummary(from: review)
        let confidenceLabel = FormaProductCopy.WeeklyReviewPresentation.confidenceLabel(for: review.confidence)
        let headlineStatLabel = headlineStat(from: review.stats)

        return WeeklyReviewCardState(
            phase: .loaded,
            sectionTitle: FormaProductCopy.WeeklyReviewPresentation.sectionTitle,
            dateRangeLabel: dateRangeLabel,
            title: title,
            summary: summary,
            confidenceLabel: confidenceLabel,
            headlineStatLabel: headlineStatLabel,
            accessibilityLabel: cardAccessibilityLabel(
                dateRangeLabel: dateRangeLabel,
                title: title,
                summary: summary,
                confidenceLabel: confidenceLabel,
                headlineStatLabel: headlineStatLabel
            )
        )
    }

    static func buildDetail(
        from review: WeeklyHealthReview?,
        calendar: Calendar = .current
    ) -> WeeklyReviewDetailState? {
        guard let review, isRenderable(review) else {
            return nil
        }

        let copy = FormaProductCopy.WeeklyReviewPresentation.self
        let dateRangeLabel = dateRangeLabel(
            start: review.weekStartDate,
            end: review.weekEndDate,
            calendar: calendar
        )
        let title = trimmed(review.title) ?? review.title
        let summary = safeSummary(from: review)
        let confidenceLabel = copy.confidenceLabel(for: review.confidence)
        let missingDataNotice = missingDataNotice(for: review)
        let generatedAtLabel = copy.generatedAtLabel(for: review.generatedAt, calendar: calendar)
        let statsGrid = statsGrid(from: review)
        let wins = insightItems(from: review.wins, kind: .win)
        let risks = insightItems(from: review.risks, kind: .risk)
        let focus = focusItems(from: review.nextWeekFocus)

        return WeeklyReviewDetailState(
            title: title,
            dateRangeLabel: dateRangeLabel,
            summary: summary,
            statsGrid: statsGrid,
            wins: wins,
            risks: risks,
            nextWeekFocus: focus,
            confidenceLabel: confidenceLabel,
            missingDataNotice: missingDataNotice,
            generatedAtLabel: generatedAtLabel,
            accessibilityLabel: detailAccessibilityLabel(
                dateRangeLabel: dateRangeLabel,
                title: title,
                summary: summary,
                confidenceLabel: confidenceLabel,
                missingDataNotice: missingDataNotice,
                generatedAtLabel: generatedAtLabel,
                statsGrid: statsGrid,
                wins: wins,
                risks: risks,
                focus: focus
            )
        )
    }

    // MARK: - Stats grid

    private static func statsGrid(from review: WeeklyHealthReview) -> WeeklyReviewStatsGridState {
        let stats = review.stats
        let missing = review.missingSignals
        var items: [WeeklyReviewStatItemState] = []

        items.append(
            WeeklyReviewStatItemState(
                id: "workouts",
                title: FormaProductCopy.WeeklyReviewPresentation.workoutsTitle,
                value: FormaProductCopy.WeeklyReviewPresentation.workoutsValue(
                    count: stats.totalWorkouts,
                    minutes: stats.totalWorkoutMinutes
                ),
                detail: missing.contains(.workouts) ? FormaProductCopy.WeeklyReviewPresentation.statUnavailable : nil,
                isLimited: missing.contains(.workouts)
            )
        )

        items.append(stepsItem(from: stats, missing: missing))
        items.append(nutritionItem(
            id: "protein",
            title: FormaProductCopy.WeeklyReviewPresentation.proteinTitle,
            count: stats.proteinHitDays,
            missing: missing.contains(.nutrition)
        ))
        items.append(nutritionItem(
            id: "calories",
            title: FormaProductCopy.WeeklyReviewPresentation.caloriesTitle,
            count: stats.calorieTargetHitDays,
            missing: missing.contains(.nutrition)
        ))
        items.append(nutritionItem(
            id: "water",
            title: FormaProductCopy.WeeklyReviewPresentation.waterTitle,
            count: stats.waterHitDays,
            missing: missing.contains(.nutrition)
        ))
        items.append(recoveryItem(from: stats, missing: missing))
        items.append(weightItem(from: stats, missing: missing))
        items.append(
            WeeklyReviewStatItemState(
                id: "logging",
                title: FormaProductCopy.WeeklyReviewPresentation.loggingTitle,
                value: FormaProductCopy.WeeklyReviewPresentation.dayCountValue(stats.loggingConsistencyDays),
                detail: nil,
                isLimited: missing.contains(.nutrition) && stats.loggingConsistencyDays == 0
            )
        )

        let summaries = items.map { "\($0.title): \($0.value)" }
        return WeeklyReviewStatsGridState(
            items: items,
            accessibilityLabel: "Weekly stats. \(summaries.joined(separator: ". "))"
        )
    }

    private static func stepsItem(
        from stats: WeeklyStats,
        missing: Set<WeeklyReviewMissingSignal>
    ) -> WeeklyReviewStatItemState {
        if missing.contains(.activity) || stats.averageSteps == nil {
            return WeeklyReviewStatItemState(
                id: "steps",
                title: FormaProductCopy.WeeklyReviewPresentation.stepsTitle,
                value: FormaProductCopy.WeeklyReviewPresentation.statUnavailable,
                detail: FormaProductCopy.WeeklyReviewPresentation.activityLimitedDetail,
                isLimited: true
            )
        }

        return WeeklyReviewStatItemState(
            id: "steps",
            title: FormaProductCopy.WeeklyReviewPresentation.stepsTitle,
            value: stats.averageSteps!.formatted(),
            detail: stats.totalSteps.map { "\($0.formatted()) total steps" },
            isLimited: false
        )
    }

    private static func nutritionItem(
        id: String,
        title: String,
        count: Int,
        missing: Bool
    ) -> WeeklyReviewStatItemState {
        WeeklyReviewStatItemState(
            id: id,
            title: title,
            value: FormaProductCopy.WeeklyReviewPresentation.dayCountValue(count),
            detail: missing ? FormaProductCopy.WeeklyReviewPresentation.nutritionLimitedDetail : nil,
            isLimited: missing
        )
    }

    private static func recoveryItem(
        from stats: WeeklyStats,
        missing: Set<WeeklyReviewMissingSignal>
    ) -> WeeklyReviewStatItemState {
        if missing.contains(.recovery) && stats.averageRecoveryScore == nil {
            return WeeklyReviewStatItemState(
                id: "recovery",
                title: FormaProductCopy.WeeklyReviewPresentation.recoveryTitle,
                value: FormaProductCopy.WeeklyReviewPresentation.statUnavailable,
                detail: FormaProductCopy.WeeklyReviewPresentation.recoveryLimitedDetail,
                isLimited: true
            )
        }

        var detail: String?
        if stats.lowRecoveryDays > 0 {
            detail = FormaProductCopy.Journey.HealthIntelligence.limitedRecoveryDays(stats.lowRecoveryDays)
        }

        return WeeklyReviewStatItemState(
            id: "recovery",
            title: FormaProductCopy.WeeklyReviewPresentation.recoveryTitle,
            value: FormaProductCopy.WeeklyReviewPresentation.recoveryValue(score: stats.averageRecoveryScore),
            detail: detail,
            isLimited: missing.contains(.recovery)
        )
    }

    private static func weightItem(
        from stats: WeeklyStats,
        missing: Set<WeeklyReviewMissingSignal>
    ) -> WeeklyReviewStatItemState {
        if missing.contains(.weight) || stats.weightChangeKg == nil {
            return WeeklyReviewStatItemState(
                id: "weight",
                title: FormaProductCopy.WeeklyReviewPresentation.weightTitle,
                value: FormaProductCopy.WeeklyReviewPresentation.weightUnavailable,
                detail: nil,
                isLimited: true
            )
        }

        return WeeklyReviewStatItemState(
            id: "weight",
            title: FormaProductCopy.WeeklyReviewPresentation.weightTitle,
            value: FormaProductCopy.WeeklyReviewPresentation.weightTrendValue(stats.weightChangeKg!),
            detail: nil,
            isLimited: false
        )
    }

    // MARK: - Insights

    private static func insightItems(
        from messages: [String],
        kind: WeeklyReviewInsightKind
    ) -> [WeeklyReviewInsightState] {
        messages.enumerated().compactMap { index, message in
            let text = displayText(message) ?? trimmed(message)
            guard let text, !text.isEmpty else { return nil }
            let prefix = kind == .win
                ? FormaProductCopy.WeeklyReviewPresentation.winsHeader
                : FormaProductCopy.WeeklyReviewPresentation.risksHeader
            return WeeklyReviewInsightState(
                id: "\(kind)-\(index)",
                kind: kind,
                message: text,
                accessibilityLabel: "\(prefix). \(text)"
            )
        }
    }

    private static func focusItems(from messages: [String]) -> [WeeklyReviewFocusItemState] {
        messages.enumerated().compactMap { index, message in
            let text = displayText(message) ?? trimmed(message)
            guard let text, !text.isEmpty else { return nil }
            return WeeklyReviewFocusItemState(
                id: "focus-\(index)",
                message: text,
                accessibilityLabel: "\(FormaProductCopy.WeeklyReviewPresentation.focusHeader). \(text)"
            )
        }
    }

    // MARK: - Helpers

    private static func safeSummary(from review: WeeklyHealthReview) -> String {
        if let summary = displayText(review.summary) {
            return summary
        }
        return FormaProductCopy.WeeklyReviewPresentation.partialDataSummary
    }

    private static func isRenderable(_ review: WeeklyHealthReview) -> Bool {
        !(trimmed(review.title)?.isEmpty ?? true)
    }

    private static func headlineStat(from stats: WeeklyStats) -> String? {
        if stats.totalWorkouts > 0 {
            return FormaProductCopy.Journey.HealthIntelligence.workoutsThisWeek(stats.totalWorkouts)
        }
        if stats.loggingConsistencyDays > 0 {
            return FormaProductCopy.WeeklyReviewPresentation.dayCountValue(stats.loggingConsistencyDays)
        }
        if let steps = stats.averageSteps, steps > 0 {
            return "\(steps.formatted()) avg steps"
        }
        return nil
    }

    private static func missingDataNotice(for review: WeeklyHealthReview) -> String? {
        let notice = FormaProductCopy.WeeklyReviewPresentation.missingDataNotice(for: review.missingSignals)
        return notice.isEmpty ? nil : notice
    }

    private static func dateRangeLabel(start: Date, end: Date, calendar: Calendar) -> String {
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

    private static func displayText(_ text: String) -> String? {
        guard let sanitized = sanitizedText(text) else { return nil }
        return sanitized
    }

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

    private static func cardAccessibilityLabel(
        dateRangeLabel: String,
        title: String,
        summary: String,
        confidenceLabel: String,
        headlineStatLabel: String?
    ) -> String {
        var parts = [
            FormaProductCopy.WeeklyReviewPresentation.sectionTitle,
            dateRangeLabel,
            title,
            summary,
            confidenceLabel
        ]
        if let headlineStatLabel {
            parts.append(headlineStatLabel)
        }
        return parts.joined(separator: ". ")
    }

    private static func detailAccessibilityLabel(
        dateRangeLabel: String,
        title: String,
        summary: String,
        confidenceLabel: String,
        missingDataNotice: String?,
        generatedAtLabel: String,
        statsGrid: WeeklyReviewStatsGridState,
        wins: [WeeklyReviewInsightState],
        risks: [WeeklyReviewInsightState],
        focus: [WeeklyReviewFocusItemState]
    ) -> String {
        var parts = [
            FormaProductCopy.WeeklyReviewPresentation.sectionTitle,
            dateRangeLabel,
            title,
            summary,
            confidenceLabel,
            generatedAtLabel,
            statsGrid.accessibilityLabel
        ]
        if let missingDataNotice {
            parts.append(missingDataNotice)
        }
        if !wins.isEmpty {
            parts.append("\(FormaProductCopy.WeeklyReviewPresentation.winsHeader): \(wins.map(\.message).joined(separator: ", "))")
        }
        if !risks.isEmpty {
            parts.append("\(FormaProductCopy.WeeklyReviewPresentation.risksHeader): \(risks.map(\.message).joined(separator: ", "))")
        }
        if !focus.isEmpty {
            parts.append("\(FormaProductCopy.WeeklyReviewPresentation.focusHeader): \(focus.map(\.message).joined(separator: ", "))")
        }
        return parts.joined(separator: ". ")
    }
}
