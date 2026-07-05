//
//  DailyReviewPayloadBuilder.swift
//  Fitness Coach
//
//  Builds typed DailyReviewPayload values from persisted reviews and deterministic summaries.
//

import Foundation

enum DailyReviewPayloadBuilder {

    static func build(
        review: DailyReview,
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
            bestNextMove: review.tomorrowRecommendation,
            tomorrowFocus: tomorrowFocus(from: summary, review: review),
            missingSignals: missingSignalMessages(from: contextHints?.missingData),
            detailNote: detailNote(from: review)
        )
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

    // MARK: - Remaining text

    private static func caloriesRemainingText(from summary: DailyReviewSummary) -> String {
        if summary.caloriesConsumed == 0 {
            return "No calories logged yet"
        }
        if summary.isOverCalorieTarget {
            return "\(abs(summary.caloriesRemaining)) kcal over target"
        }
        if summary.caloriesRemaining > 0 {
            return "\(summary.caloriesRemaining) kcal remaining"
        }
        return "At calorie target"
    }

    private static func proteinRemainingText(from summary: DailyReviewSummary) -> String {
        if summary.proteinConsumed <= 0 {
            return "No protein logged yet"
        }
        if summary.hasMetProteinTarget {
            return "Protein target met"
        }
        let shortfall = max(summary.proteinRemaining, 0)
        return "\(FoodEntryFormFormatter.formatMacro(shortfall))g to go"
    }

    private static func waterRemainingText(from summary: DailyReviewSummary) -> String {
        if summary.waterConsumedMl == 0 {
            return "No water logged yet"
        }
        if summary.hasMetWaterTarget {
            return "Hydration target met"
        }
        return "\(summary.waterRemainingMl) ml remaining"
    }

    // MARK: - Summary copy

    private static func statusSummary(from summary: DailyReviewSummary) -> String {
        if summary.foodEntryCount == 0, summary.caloriesConsumed == 0 {
            return "No food logged yet today."
        }
        if summary.isOverCalorieTarget {
            return "You logged \(summary.caloriesConsumed) kcal, ending \(abs(summary.caloriesRemaining)) kcal above target."
        }
        if summary.caloriesConsumed == 0 {
            return "No calories logged yet today."
        }
        if summary.caloriesRemaining > 0 {
            return "You logged \(summary.caloriesConsumed) kcal with \(summary.caloriesRemaining) kcal remaining."
        }
        return "You logged \(summary.caloriesConsumed) kcal and reached your calorie target."
    }

    private static func tomorrowFocus(from summary: DailyReviewSummary, review: DailyReview) -> String? {
        guard let workoutSummary = review.workoutSummary?.trimmingCharacters(in: .whitespacesAndNewlines),
              !workoutSummary.isEmpty,
              summary.hasWorkout else {
            return nil
        }
        return workoutSummary
    }

    private static func detailNote(from review: DailyReview) -> String? {
        let trimmed = review.summaryText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return nil }
        return trimmed
    }

    // MARK: - Missing signals

    static func missingSignalMessages(from missing: CoachMissingDataContext?) -> [String] {
        guard let missing, missing.hasAnyMissingSignals else { return [] }

        var messages: [String] = []
        var seen = Set<String>()

        func add(_ message: String) {
            guard seen.insert(message).inserted else { return }
            messages.append(message)
        }

        if missing.stepsMissing || missing.stepsUnavailable {
            add("Steps aren't available from Apple Health right now.")
        }
        if missing.workoutPermissionDeniedOrUnavailable || missing.workoutsUnavailable {
            add("Workout data isn't available from Apple Health right now.")
        }
        if missing.sleepMissing || missing.sleepUnavailable {
            add("Sleep data isn't available right now.")
        }
        if missing.hrvMissing || missing.hrvUnavailable {
            add("Heart-rate variability isn't available right now.")
        }
        if missing.healthKitDenied || missing.healthKitUnavailable {
            add("Some Apple Health signals are unavailable.")
        }
        if missing.weightMissing {
            add("No weight logged today.")
        }
        if missing.noRecentMeals {
            add("No meals logged yet today.")
        }
        if missing.healthIntelligenceTimedOut {
            add("Recovery insights timed out.")
        }
        if missing.healthIntelligenceFailed {
            add("Recovery insights are unavailable right now.")
        }
        if missing.contextGenerationFailed {
            add("Some coaching context could not be loaded.")
        }

        return messages
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

        sections.append("")
        sections.append(payload.statusSummary)
        sections.append(metricLine(payload.snapshot.calories))
        sections.append(metricLine(payload.snapshot.protein))
        sections.append(metricLine(payload.snapshot.water))

        if let detailNote = payload.detailNote, !detailNote.isEmpty {
            sections += ["", "Coach note:", detailNote]
        }

        sections += ["", "Best next move:", payload.bestNextMove]

        if let tomorrowFocus = payload.tomorrowFocus, !tomorrowFocus.isEmpty {
            sections += ["", "Tomorrow focus:", tomorrowFocus]
        }

        if !payload.missingSignals.isEmpty {
            sections += ["", "Missing signals:"]
            sections.append(contentsOf: payload.missingSignals.map { "• \($0)" })
        }

        return sections.joined(separator: "\n")
    }

    private static func metricLine(_ metric: ProgressMetric) -> String {
        let current = formattedValue(metric.current, unit: metric.unit)
        let target = formattedValue(metric.target, unit: metric.unit)
        return "\(metric.label): \(current) / \(target). \(metric.remainingText)."
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
