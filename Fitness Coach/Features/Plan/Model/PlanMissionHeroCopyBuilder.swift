//
//  PlanMissionHeroCopyBuilder.swift
//  Fitness Coach
//
//  Forma — Hero copy and accessibility for the Plan Mission Control header.
//

import Foundation

enum PlanMissionHeroCopyBuilder {

    struct Input: Equatable {
        var mission: PlanMissionState
        var baseline: JourneyBaseline
        var week: PlanWeekState
        var asOf: Date
        var calendar: Calendar
    }

    private static let scheduleLeadPercent = 5.0
    private static let newPlanGraceDays = 3

    static func applyHeroPresentation(
        to mission: PlanMissionState,
        baseline: JourneyBaseline,
        week: PlanWeekState,
        asOf: Date,
        calendar: Calendar
    ) -> PlanMissionState {
        var updated = mission
        updated.sectionTitle = FormaProductCopy.PlanMissionControl.heroSectionTitle
        updated.headlineValue = headlineValue(
            direction: mission.goalDirection,
            totalChangeKg: mission.totalToLoseOrGainKg,
            goalWeightKg: mission.goalWeightKg
        )
        updated.progressRouteLabel = progressRouteLabel(
            direction: mission.goalDirection,
            currentLabel: mission.currentWeightLabel,
            goalLabel: mission.goalWeightLabel
        )
        updated.progressCompleteLabel = progressCompleteLabel(
            direction: mission.goalDirection,
            percent: baseline.progressPercent
        )
        updated.progressBarFill = progressBarFill(from: baseline.progressPercent)
        updated.showsProgressBar = showsProgressBar(
            direction: mission.goalDirection,
            totalChangeKg: mission.totalToLoseOrGainKg
        )
        updated.statusCopy = statusCopy(
            baseline: baseline,
            week: week,
            usesLoggedCurrentWeight: mission.usesLoggedCurrentWeight,
            asOf: asOf,
            calendar: calendar
        )
        updated.expectedCompletionLabel = expectedCompletionLabel(date: mission.expectedCompletionDate)
        updated.expectedWeeklyChangeLabel = expectedProgressLabel(
            weeklyKg: mission.expectedWeeklyChangeKg,
            direction: mission.goalDirection
        )
        updated.accessibilitySummary = accessibilitySummary(
            mission: updated,
            baseline: baseline
        )
        updated.adjustPlanTitle = FormaProductCopy.PlanMissionControl.adjustPlan
        return updated
    }

    // MARK: - Headline

    static func headlineValue(
        direction: PlanMissionGoalDirection,
        totalChangeKg: Double?,
        goalWeightKg: Double?
    ) -> String {
        switch direction {
        case .lose:
            guard let totalChangeKg, totalChangeKg > 0.1 else {
                return FormaProductCopy.PlanMissionControl.headlineLoseFallback
            }
            return FormaProductCopy.PlanMissionControl.headlineLose(formatKg(totalChangeKg))
        case .gain:
            guard let totalChangeKg, totalChangeKg > 0.1 else {
                return FormaProductCopy.PlanMissionControl.headlineGainFallback
            }
            return FormaProductCopy.PlanMissionControl.headlineGain(formatKg(totalChangeKg))
        case .maintain:
            if let goalWeightKg {
                return FormaProductCopy.PlanMissionControl.headlineMaintain(formatKg(goalWeightKg))
            }
            return FormaProductCopy.PlanMissionControl.headlineMaintainFallback
        }
    }

    static func progressRouteLabel(
        direction: PlanMissionGoalDirection,
        currentLabel: String,
        goalLabel: String
    ) -> String {
        switch direction {
        case .maintain:
            return FormaProductCopy.PlanMissionControl.progressRouteMaintain(currentLabel)
        case .lose, .gain:
            return FormaProductCopy.PlanMissionControl.progressRoute(currentLabel, goalLabel)
        }
    }

    static func progressCompleteLabel(
        direction: PlanMissionGoalDirection,
        percent: Double?
    ) -> String? {
        guard direction != .maintain else {
            return FormaProductCopy.PlanMissionControl.progressOnPlan
        }
        guard let percent else { return nil }
        let display = Int(min(max(percent, 0), 100).rounded())
        return FormaProductCopy.PlanMissionControl.progressComplete(display)
    }

    static func progressBarFill(from percent: Double?) -> Double {
        guard let percent else { return 0 }
        return min(max(percent / 100.0, 0), 1)
    }

    static func showsProgressBar(
        direction: PlanMissionGoalDirection,
        totalChangeKg: Double?
    ) -> Bool {
        guard direction != .maintain else { return false }
        guard let totalChangeKg else { return false }
        return totalChangeKg > 0.1
    }

    // MARK: - Secondary lines

    static func expectedCompletionLabel(date: Date?) -> String? {
        guard let date else { return nil }
        let formatted = date.formatted(.dateTime.month(.wide).year())
        return FormaProductCopy.PlanMissionControl.expectedCompletion(formatted)
    }

    static func expectedProgressLabel(
        weeklyKg: Double?,
        direction: PlanMissionGoalDirection
    ) -> String? {
        guard direction == .lose, let weeklyKg, weeklyKg > 0 else { return nil }
        return FormaProductCopy.PlanMissionControl.expectedProgress(formatKg(weeklyKg))
    }

    // MARK: - Status copy

    static func statusCopy(
        baseline: JourneyBaseline,
        week: PlanWeekState,
        usesLoggedCurrentWeight: Bool,
        asOf: Date,
        calendar: Calendar
    ) -> String {
        if isNewPlan(baseline: baseline, asOf: asOf, calendar: calendar),
           !usesLoggedCurrentWeight,
           !week.hasWeeklyData {
            return FormaProductCopy.PlanMissionControl.statusStartLogging
        }

        if isAheadOfSchedule(baseline: baseline, asOf: asOf, calendar: calendar) {
            return FormaProductCopy.PlanMissionControl.statusAheadOfSchedule
        }

        switch week.overallStatus {
        case .building, .incomplete:
            return FormaProductCopy.PlanMissionControl.statusBuildingMomentum
        case .strong, .onTrack:
            return FormaProductCopy.PlanMissionControl.statusStayConsistent
        }
    }

    // MARK: - Accessibility

    static func accessibilitySummary(
        mission: PlanMissionState,
        baseline: JourneyBaseline
    ) -> String {
        var parts: [String] = [
            mission.sectionTitle,
            mission.headlineValue,
            mission.progressRouteLabel
        ]

        if let progressCompleteLabel = mission.progressCompleteLabel {
            parts.append(progressCompleteLabel)
        }

        if let expectedCompletionLabel = mission.expectedCompletionLabel {
            parts.append(expectedCompletionLabel)
        }

        if let expectedWeeklyChangeLabel = mission.expectedWeeklyChangeLabel {
            parts.append(expectedWeeklyChangeLabel)
        }

        parts.append(mission.statusCopy)

        if baseline.usesSyntheticBaselinePoint {
            parts.append(FormaProductCopy.PlanMissionControl.accessibilityOnboardingBaseline)
        }

        return parts.joined(separator: ". ")
    }

    static func progressBarAccessibilityValue(percent: Double?) -> String {
        guard let percent else { return FormaProductCopy.PlanMissionControl.accessibilityProgressZero }
        let display = Int(min(max(percent, 0), 100).rounded())
        return FormaProductCopy.PlanMissionControl.accessibilityProgressComplete(display)
    }

    // MARK: - Helpers

    private static func formatKg(_ value: Double) -> String {
        value.truncatingRemainder(dividingBy: 1) == 0
            ? "\(Int(value)) kg"
            : String(format: "%.1f kg", value)
    }

    private static func isNewPlan(
        baseline: JourneyBaseline,
        asOf: Date,
        calendar: Calendar
    ) -> Bool {
        let startDay = calendar.startOfDay(for: baseline.startDate)
        let asOfDay = calendar.startOfDay(for: asOf)
        guard let days = calendar.dateComponents([.day], from: startDay, to: asOfDay).day else {
            return true
        }
        return days <= newPlanGraceDays
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

        return (Double(elapsedDays) / Double(totalDays)) * 100.0
    }
}
