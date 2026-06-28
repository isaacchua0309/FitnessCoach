//
//  JourneyTransformationHeroBuilder.swift
//  Fitness Coach
//
//  Forma — Deterministic copy and metrics for the Journey transformation hero.
//

import Foundation

enum JourneyTransformationHeroBuilder {

    struct Input: Equatable {
        var baseline: JourneyBaseline
        var loggedDays: Int
        var heroStreakChip: JourneyStreakChipState
        var weightTrendDirection: WeightTrendDirection
        var asOf: Date
        var calendar: Calendar
    }

    private static let scheduleLeadPercent = 5.0
    private static let weightEqualityToleranceKg = 0.05

    static func build(_ input: Input) -> JourneyTransformationHeroState {
        let baseline = input.baseline
        let changeKg = changeValueKg(baseline: baseline)
        let headline = headlineCopy(goalDirection: baseline.goalDirection)
        let changeValueCopy = ProgressFormatter.heroChangeKg(changeKg)
        let progressPercent = baseline.progressPercent ?? 0
        let progressLabel = Self.progressLabel(percent: baseline.progressPercent)
        let progressBarAccessibilityValue = Self.progressBarAccessibilityValue(percent: baseline.progressPercent)
        let emotionalStatus = emotionalStatusLabel(
            baseline: baseline,
            loggedDays: input.loggedDays,
            weightTrendDirection: input.weightTrendDirection,
            asOf: input.asOf,
            calendar: input.calendar
        )
        let paceForecast = paceForecastText(baseline: baseline)
        let streakChip = input.heroStreakChip
        let startedFootnote = baseline.usesSyntheticBaselinePoint
            ? FormaProductCopy.Journey.Transformation.onboardingBaseline
            : nil

        let accessibilitySummary = accessibilitySummary(
            headline: headline,
            changeValue: changeValueCopy,
            started: ProgressFormatter.heroWeightKg(baseline.startWeightKg),
            today: ProgressFormatter.heroWeightKg(baseline.currentWeightKg),
            goal: ProgressFormatter.heroWeightKg(baseline.goalWeightKg),
            progressLabel: progressLabel,
            emotionalStatus: emotionalStatus,
            startedFootnote: startedFootnote
        )

        return JourneyTransformationHeroState(
            headlineCopy: headline,
            changeValueCopy: changeValueCopy,
            emotionalStatusLabel: emotionalStatus,
            progressBarPercent: progressPercent,
            progressLabel: progressLabel,
            progressBarAccessibilityValue: progressBarAccessibilityValue,
            startedWeightCopy: ProgressFormatter.heroWeightKg(baseline.startWeightKg),
            todayWeightCopy: ProgressFormatter.heroWeightKg(baseline.currentWeightKg),
            goalWeightCopy: ProgressFormatter.heroWeightKg(baseline.goalWeightKg),
            startedFootnote: startedFootnote,
            paceForecastText: paceForecast,
            streakChip: streakChip,
            usesSyntheticBaseline: baseline.usesSyntheticBaselinePoint,
            accessibilitySummary: accessibilitySummary
        )
    }

    // MARK: - Headline & change

    static func headlineCopy(goalDirection: JourneyGoalDirection) -> String {
        switch goalDirection {
        case .lose:
            return FormaProductCopy.Journey.Transformation.lostHeadline
        case .gain:
            return FormaProductCopy.Journey.Transformation.gainedHeadline
        case .maintain:
            return FormaProductCopy.Journey.Transformation.maintainingHeadline
        }
    }

    static func changeValueKg(baseline: JourneyBaseline) -> Double {
        guard let start = baseline.startWeightKg,
              let current = baseline.currentWeightKg else {
            return 0
        }

        switch baseline.goalDirection {
        case .lose:
            return max(0, start - current)
        case .gain:
            return max(0, current - start)
        case .maintain:
            return abs(current - start)
        }
    }

    // MARK: - Progress

    static func progressLabel(percent: Double?) -> String {
        guard let percent else {
            return FormaProductCopy.Journey.Transformation.progressStarting
        }
        let clampedDisplay = Int(min(max(percent, 0), 999).rounded())
        return FormaProductCopy.Journey.Transformation.progressComplete(clampedDisplay)
    }

    static func progressBarAccessibilityValue(percent: Double?) -> String {
        guard let percent else { return "0 percent" }
        let clampedDisplay = Int(min(max(percent, 0), 999).rounded())
        return "\(clampedDisplay) percent complete"
    }

    // MARK: - Emotional status

    static func emotionalStatusLabel(
        baseline: JourneyBaseline,
        loggedDays: Int,
        weightTrendDirection: WeightTrendDirection,
        asOf: Date,
        calendar: Calendar
    ) -> String {
        if loggedDays < 7 {
            return FormaProductCopy.Journey.Transformation.emotionalLayingFoundation
        }

        if let progress = baseline.progressPercent, progress >= 75 {
            return FormaProductCopy.Journey.Transformation.emotionalClosingIn
        }

        if isAheadOfSchedule(baseline: baseline, asOf: asOf, calendar: calendar) {
            return FormaProductCopy.Journey.Transformation.emotionalAheadOfSchedule
        }

        if isMomentumBuilding(
            baseline: baseline,
            weightTrendDirection: weightTrendDirection
        ) {
            return FormaProductCopy.Journey.Transformation.emotionalMomentumBuilding
        }

        return FormaProductCopy.Journey.Transformation.emotionalLayingFoundation
    }

    private static func isAheadOfSchedule(
        baseline: JourneyBaseline,
        asOf: Date,
        calendar: Calendar
    ) -> Bool {
        guard let progress = baseline.progressPercent,
              let expected = expectedLinearProgressPercent(
                  baseline: baseline,
                  asOf: asOf,
                  calendar: calendar
              ) else {
            return false
        }
        return progress >= expected + scheduleLeadPercent
    }

    private static func expectedLinearProgressPercent(
        baseline: JourneyBaseline,
        asOf: Date,
        calendar: Calendar
    ) -> Double? {
        guard let completion = baseline.estimatedCompletionDate else { return nil }

        let startDay = calendar.startOfDay(for: baseline.startDate)
        let asOfDay = calendar.startOfDay(for: asOf)
        let completionDay = calendar.startOfDay(for: completion)

        guard let totalDays = calendar.dateComponents([.day], from: startDay, to: completionDay).day,
              totalDays > 0,
              let elapsedDays = calendar.dateComponents([.day], from: startDay, to: asOfDay).day else {
            return nil
        }

        return min(100, (Double(elapsedDays) / Double(totalDays)) * 100)
    }

    private static func isMomentumBuilding(
        baseline: JourneyBaseline,
        weightTrendDirection: WeightTrendDirection
    ) -> Bool {
        switch (baseline.goalDirection, weightTrendDirection) {
        case (.lose, .decreasing), (.gain, .increasing):
            return true
        case (.maintain, .stable):
            return true
        default:
            return baseline.progressPercent.map { $0 >= 10 } ?? false
        }
    }

    // MARK: - Forecast & streak

    static func paceForecastText(baseline: JourneyBaseline) -> String {
        if let monthLabel = baseline.estimatedCompletionMonthLabel {
            return FormaProductCopy.Journey.Transformation.paceForecast(month: monthLabel)
        }
        return FormaProductCopy.Journey.Transformation.paceForecastFallback
    }

    // MARK: - Accessibility

    private static func accessibilitySummary(
        headline: String,
        changeValue: String,
        started: String,
        today: String,
        goal: String,
        progressLabel: String,
        emotionalStatus: String,
        startedFootnote: String?
    ) -> String {
        var parts = [
            "\(headline) \(changeValue).",
            "Started \(started), today \(today), goal \(goal).",
            progressLabel + ".",
            emotionalStatus + "."
        ]
        if let startedFootnote {
            parts.insert("Started weight from \(startedFootnote.lowercased()).", at: 2)
        }
        return parts.joined(separator: " ")
    }
}
