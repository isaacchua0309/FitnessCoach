//
//  DailyReviewPayloadBuilder.swift
//  Fitness Coach
//
//  Builds typed DailyReviewPayload values from persisted reviews and deterministic summaries.
//

import Foundation

enum DailyReviewPayloadBuilder {

    private static let maxDetailNoteLength = DailyReviewContentContract.maxDetailNoteLength
    private static let maxStatusSummaryLength = DailyReviewContentContract.maxStatusSummaryLength
    private static let maxBestNextMoveLength = DailyReviewContentContract.maxBestNextMoveLength
    private static let maxTomorrowFocusLength = DailyReviewContentContract.maxTomorrowFocusLength

    // MARK: - Public API

    static func build(
        review: DailyReview,
        summary: DailyReviewSummary,
        aiResponse: DailyReviewAIResponse? = nil,
        contextHints: CoachResponseContextHints? = nil,
        generatedAt: Date = Date(),
        calendar: Calendar = .current
    ) -> DailyReviewPayload {
        let normalizedAI = aiResponse.flatMap {
            DailyReviewAIResponseNormalizer.normalize(
                $0,
                summary: summary,
                contextHints: contextHints
            )
        }

        return DailyReviewPayload(
            title: "Daily Review",
            timezoneLabel: timezoneLabel(for: summary.date, generatedAt: generatedAt, calendar: calendar),
            generatedAt: generatedAt,
            snapshot: snapshot(from: summary),
            statusSummary: normalizedAI?.statusSummary ?? statusSummary(from: summary),
            bestNextMove: normalizedAI?.bestNextMove ?? bestNextMove(from: summary, review: review),
            tomorrowFocus: normalizedAI?.tomorrowFocus ?? tomorrowFocus(from: summary, review: review),
            missingSignals: mergedMissingSignals(
                aiSignals: normalizedAI?.missingSignals,
                contextHints: contextHints
            ),
            detailNote: normalizedAI?.detailNote ?? detailNote(from: review)
        )
    }

    /// Returns a validated structured payload, or a compact local fallback when validation fails.
    static func buildSafely(
        review: DailyReview,
        summary: DailyReviewSummary,
        aiResponse: DailyReviewAIResponse? = nil,
        contextHints: CoachResponseContextHints? = nil,
        generatedAt: Date = Date(),
        calendar: Calendar = .current
    ) -> DailyReviewPayload {
        let payload = build(
            review: review,
            summary: summary,
            aiResponse: aiResponse,
            contextHints: contextHints,
            generatedAt: generatedAt,
            calendar: calendar
        )
        if validates(payload) {
            return payload
        }
        return compactFallback(
            summary: summary,
            contextHints: contextHints,
            generatedAt: generatedAt,
            calendar: calendar
        )
    }

    /// Compact card built only from local deterministic summary data (no AI prose).
    static func compactFallback(
        summary: DailyReviewSummary,
        contextHints: CoachResponseContextHints? = nil,
        generatedAt: Date = Date(),
        calendar: Calendar = .current
    ) -> DailyReviewPayload {
        DailyReviewPayload(
            title: "Daily Review",
            timezoneLabel: timezoneLabel(for: summary.date, generatedAt: generatedAt, calendar: calendar),
            generatedAt: generatedAt,
            snapshot: snapshot(from: summary),
            statusSummary: statusSummary(from: summary),
            bestNextMove: gapActions(from: summary).primary ?? defaultNextMove(for: summary),
            tomorrowFocus: gapActions(from: summary).secondary,
            missingSignals: missingSignalLabels(from: contextHints?.missingData),
            detailNote: nil
        )
    }

    // MARK: - Validation

    private static func validates(_ payload: DailyReviewPayload) -> Bool {
        guard !payload.statusSummary.isEmpty,
              !payload.bestNextMove.isEmpty else {
            return false
        }

        guard payload.statusSummary.count <= maxStatusSummaryLength,
              payload.bestNextMove.count <= maxBestNextMoveLength,
              (payload.tomorrowFocus?.count ?? 0) <= maxTomorrowFocusLength,
              (payload.detailNote?.count ?? 0) <= maxDetailNoteLength else {
            return false
        }

        let fields = [
            payload.statusSummary,
            payload.bestNextMove,
            payload.tomorrowFocus,
            payload.detailNote
        ].compactMap { $0 }

        return fields.allSatisfy { !looksLikeParagraph($0) }
    }

    private static func mergedMissingSignals(
        aiSignals: [String]?,
        contextHints: CoachResponseContextHints?
    ) -> [String] {
        let deterministic = missingSignalLabels(from: contextHints?.missingData)
        guard deterministic.isEmpty else { return deterministic }
        guard let aiSignals else { return [] }
        let allowed = Set(["Steps", "Workout", "Sleep", "HRV"])
        return aiSignals.filter { allowed.contains($0) }
    }

    private static func looksLikeParagraph(_ text: String) -> Bool {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        let sentenceCount = trimmed
            .split(whereSeparator: { ".!?".contains($0) })
            .filter { !$0.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }
            .count
        return sentenceCount > 2 || trimmed.contains("\n\n")
    }

    // MARK: - Snapshot

    private static func snapshot(from summary: DailyReviewSummary) -> DailyReviewSnapshot {
        DailyReviewSnapshot(
            calories: caloriesMetric(from: summary),
            protein: proteinMetric(from: summary),
            water: waterMetric(from: summary)
        )
    }

    private static func caloriesMetric(from summary: DailyReviewSummary) -> ProgressMetric {
        let current = Double(summary.caloriesConsumed)
        let target = Double(summary.calorieTarget)
        return ProgressMetric(
            label: "Calories",
            current: current,
            target: target,
            unit: "kcal",
            remainingText: caloriesRemainingText(from: summary),
            progress: ProgressMetric.progressRatio(current: current, target: target)
        )
    }

    private static func proteinMetric(from summary: DailyReviewSummary) -> ProgressMetric {
        ProgressMetric(
            label: "Protein",
            current: summary.proteinConsumed,
            target: summary.proteinTarget,
            unit: "g",
            remainingText: proteinRemainingText(from: summary),
            progress: ProgressMetric.progressRatio(
                current: summary.proteinConsumed,
                target: summary.proteinTarget
            )
        )
    }

    private static func waterMetric(from summary: DailyReviewSummary) -> ProgressMetric {
        let current = Double(summary.waterConsumedMl)
        let target = Double(summary.waterTargetMl)
        return ProgressMetric(
            label: "Water",
            current: current,
            target: target,
            unit: "ml",
            remainingText: waterRemainingText(from: summary),
            progress: ProgressMetric.progressRatio(current: current, target: target)
        )
    }

    // MARK: - Metric captions (qualitative — numbers live in the metric row only)

    private static func caloriesRemainingText(from summary: DailyReviewSummary) -> String {
        if summary.caloriesConsumed == 0 {
            return "Not logged yet"
        }
        if summary.isOverCalorieTarget {
            return "Over target"
        }
        if summary.caloriesRemaining > 0 {
            return "Under target"
        }
        return "At target"
    }

    private static func proteinRemainingText(from summary: DailyReviewSummary) -> String {
        if summary.proteinConsumed <= 0 {
            return "Not logged yet"
        }
        if summary.hasMetProteinTarget {
            return "Target reached"
        }
        return "Gap to close"
    }

    private static func waterRemainingText(from summary: DailyReviewSummary) -> String {
        if summary.waterConsumedMl == 0 {
            return "Not logged yet"
        }
        if summary.hasMetWaterTarget {
            return "Target reached"
        }
        return "Gap to close"
    }

    // MARK: - Status

    private static func hasAllNutritionZero(_ summary: DailyReviewSummary) -> Bool {
        summary.caloriesConsumed == 0
            && summary.proteinConsumed <= 0
            && summary.waterConsumedMl == 0
    }

    private static func hasLoggedFood(_ summary: DailyReviewSummary) -> Bool {
        summary.foodEntryCount > 0
            || summary.caloriesConsumed > 0
            || summary.proteinConsumed > 0
    }

    private static func statusSummary(from summary: DailyReviewSummary) -> String {
        if hasAllNutritionZero(summary) {
            return "No food or water has been logged yet today."
        }
        if summary.isOverCalorieTarget {
            return "You are over today's calorie target."
        }
        if hasLoggedFood(summary) || summary.caloriesConsumed > 0 || summary.waterConsumedMl > 0 {
            return "You are still within today's calorie target."
        }
        return "No food or water has been logged yet today."
    }

    // MARK: - Next actions

    private struct GapActions {
        let primary: String?
        let secondary: String?
    }

    private static func gapActions(from summary: DailyReviewSummary) -> GapActions {
        var actions: [String] = []

        if summary.proteinConsumed > 0,
           !summary.hasMetProteinTarget,
           summary.proteinRemaining > 0 {
            let grams = FoodEntryFormFormatter.formatMacro(summary.proteinRemaining)
            actions.append("Add \(grams)g protein at your next meal.")
        } else if hasLoggedFood(summary), summary.proteinConsumed <= 0 {
            actions.append("Log protein at your next meal.")
        }

        if summary.waterConsumedMl > 0,
           !summary.hasMetWaterTarget,
           summary.waterRemainingMl > 0 {
            actions.append("Drink \(summary.waterRemainingMl)ml more water today.")
        } else if !hasAllNutritionZero(summary), summary.waterConsumedMl == 0 {
            actions.append("Log your next water entry.")
        }

        return GapActions(
            primary: actions.first,
            secondary: actions.count > 1 ? actions[1] : nil
        )
    }

    private static func bestNextMove(from summary: DailyReviewSummary, review: DailyReview) -> String {
        let gaps = gapActions(from: summary)
        if let primary = gaps.primary {
            return primary
        }
        return sanitizedRecommendation(review.tomorrowRecommendation, for: summary)
    }

    private static func tomorrowFocus(from summary: DailyReviewSummary, review: DailyReview) -> String? {
        if let secondary = gapActions(from: summary).secondary {
            return secondary
        }
        if summary.hasWorkout {
            return "Keep tomorrow's workout on the calendar."
        }
        let recommendation = sanitizedRecommendation(review.tomorrowRecommendation, for: summary)
        let best = bestNextMove(from: summary, review: review)
        guard recommendation != best else { return nil }
        return recommendation
    }

    private static func defaultNextMove(for summary: DailyReviewSummary) -> String {
        if hasAllNutritionZero(summary) {
            return "Log your first meal or water entry."
        }
        if !summary.hasMetProteinTarget {
            return "Prioritize protein at your next meal."
        }
        if !summary.hasMetWaterTarget {
            return "Catch up on water before the day ends."
        }
        return "Keep logging to close the day."
    }

    private static func sanitizedRecommendation(
        _ recommendation: String,
        for summary: DailyReviewSummary
    ) -> String {
        let trimmed = recommendation.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else {
            return defaultNextMove(for: summary)
        }
        if containsWinLanguage(trimmed), !hasCompletedPositiveOutcome(summary) {
            return defaultNextMove(for: summary)
        }
        return compactText(trimmed, maxLength: maxBestNextMoveLength)
    }

    private static func hasCompletedPositiveOutcome(_ summary: DailyReviewSummary) -> Bool {
        guard hasLoggedFood(summary) || summary.waterConsumedMl > 0 else { return false }
        let metCalories = summary.caloriesConsumed > 0 && !summary.isOverCalorieTarget
        let metProtein = summary.proteinConsumed > 0 && summary.hasMetProteinTarget
        let metWater = summary.waterConsumedMl > 0 && summary.hasMetWaterTarget
        return metCalories || metProtein || metWater
    }

    private static func containsWinLanguage(_ text: String) -> Bool {
        let normalized = text.lowercased()
        return normalized.contains("win")
            || normalized.contains("great job")
            || normalized.contains("crushed it")
            || normalized.contains("amazing")
    }

    // MARK: - Coach note

    private static func detailNote(from review: DailyReview) -> String? {
        let trimmed = review.summaryText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return nil }
        if trimmed == DailyReviewFormatter.fallbackSummaryText() {
            return nil
        }
        let compact = compactCoachNote(trimmed)
        guard !compact.isEmpty, !looksLikeParagraph(compact) else { return nil }
        return compact
    }

    private static func compactCoachNote(_ text: String) -> String {
        let singleSentence = text
            .components(separatedBy: CharacterSet(charactersIn: ".!?"))
            .first?
            .trimmingCharacters(in: .whitespacesAndNewlines) ?? text
        return compactText(singleSentence, maxLength: maxDetailNoteLength)
    }

    private static func compactText(_ text: String, maxLength: Int) -> String {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard trimmed.count > maxLength else { return trimmed }
        let index = trimmed.index(trimmed.startIndex, offsetBy: maxLength)
        return String(trimmed[..<index]).trimmingCharacters(in: .whitespacesAndNewlines) + "…"
    }

    // MARK: - Missing Apple Health signals

    static func missingSignalLabels(from missing: CoachMissingDataContext?) -> [String] {
        guard let missing else { return [] }

        var labels: [String] = []
        if missing.stepsMissing || missing.stepsUnavailable {
            labels.append("Steps")
        }
        if missing.workoutPermissionDeniedOrUnavailable || missing.workoutsUnavailable {
            labels.append("Workout")
        }
        if missing.sleepMissing || missing.sleepUnavailable {
            labels.append("Sleep")
        }
        if missing.hrvMissing || missing.hrvUnavailable {
            labels.append("HRV")
        }
        return labels
    }

    // MARK: - Timezone

    private static func timezoneLabel(
        for date: Date,
        generatedAt: Date,
        calendar: Calendar
    ) -> String? {
        let timeZone = calendar.timeZone
        let abbreviation = timeZone.abbreviation(for: generatedAt) ?? timeZone.identifier

        let formatter = DateFormatter()
        formatter.calendar = calendar
        formatter.timeZone = timeZone
        formatter.dateStyle = .medium
        formatter.timeStyle = .none

        let dateLabel = formatter.string(from: date)
        return "\(dateLabel) · \(abbreviation)"
    }
}

// MARK: - Accessibility

enum DailyReviewPayloadAccessibilityFormatter {

    static func text(from payload: DailyReviewPayload) -> String {
        var sections = [payload.title]

        if let timezoneLabel = payload.timezoneLabel, !timezoneLabel.isEmpty {
            sections.append(timezoneLabel)
        }

        sections.append(payload.statusSummary)
        sections.append(metricLine(payload.snapshot.calories))
        sections.append(metricLine(payload.snapshot.protein))
        sections.append(metricLine(payload.snapshot.water))
        sections.append("Next: \(payload.bestNextMove)")

        if let tomorrowFocus = payload.tomorrowFocus, !tomorrowFocus.isEmpty {
            sections.append("Also: \(tomorrowFocus)")
        }

        if let detailNote = payload.detailNote, !detailNote.isEmpty {
            sections.append("Coach note: \(detailNote)")
        }

        if !payload.missingSignals.isEmpty {
            sections.append("Missing signals: \(payload.missingSignals.joined(separator: ", "))")
        }

        return sections.joined(separator: "\n")
    }

    private static func metricLine(_ metric: ProgressMetric) -> String {
        "\(metric.label): \(formattedValue(metric.current, unit: metric.unit)) of \(formattedValue(metric.target, unit: metric.unit)). \(metric.remainingText)."
    }

    private static func formattedValue(_ value: Double, unit: String) -> String {
        if unit == "g" {
            return "\(FoodEntryFormFormatter.formatMacro(value))\(unit)"
        }
        if value.rounded() == value {
            return "\(Int(value)) \(unit)"
        }
        return String(format: "%.1f %@", value, unit)
    }
}
