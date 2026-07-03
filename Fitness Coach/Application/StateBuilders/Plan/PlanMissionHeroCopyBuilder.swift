//
//  PlanMissionHeroCopyBuilder.swift
//  Fitness Coach
//
//  Forma — Hero copy and accessibility for the Plan strategy header.
//

import Foundation

enum PlanMissionHeroCopyBuilder {

    struct Input: Equatable {
        var goalDirection: PlanGoalDirection
        var strategyName: String
        var currentWeightKg: Double
        var goalWeightKg: Double
        var totalChangeKg: Double?
        var progressPercent: Double?
        var expectedCompletionDate: Date?
        var expectedWeeklyChangeKg: Double?
        var usesLoggedCurrentWeight: Bool
        var currentWeightLabel: String
        var goalWeightLabel: String
    }

    private static let scheduleLeadPercent = 5.0
    private static let newPlanGraceDays = 3
    private static let consistentFoodLogDays = 5

    static func buildPresentation(
        input: Input,
        context: PlanDashboardContext,
        profile: UserProfile,
        baseline: JourneyBaseline,
        asOf: Date,
        calendar: Calendar
    ) -> (PlanStrategyState, PlanStatusState) {
        let headline = headlineValue(
            direction: input.goalDirection,
            totalChangeKg: input.totalChangeKg,
            goalWeightKg: input.goalWeightKg
        )
        let progressRouteLabel = progressRouteLabel(
            direction: input.goalDirection,
            currentLabel: input.currentWeightLabel,
            goalLabel: input.goalWeightLabel
        )
        let progressCompleteLabel = progressCompleteLabel(
            direction: input.goalDirection,
            percent: input.progressPercent
        )
        let progressBarFill = progressBarFill(from: input.progressPercent)
        let showsProgressBar = showsProgressBar(
            direction: input.goalDirection,
            totalChangeKg: input.totalChangeKg
        )
        let expectedCompletionLabel = expectedCompletionLabel(date: input.expectedCompletionDate)
        let expectedPaceLabel = expectedProgressLabel(
            weeklyKg: input.expectedWeeklyChangeKg,
            direction: input.goalDirection
        )

        var strategy = PlanStrategyState(
            sectionTitle: FormaProductCopy.PlanMissionControl.heroSectionTitle,
            headline: headline,
            strategyName: input.strategyName,
            goalDirection: input.goalDirection,
            progressRouteLabel: progressRouteLabel,
            progressCompleteLabel: progressCompleteLabel,
            progressBarFill: progressBarFill,
            showsProgressBar: showsProgressBar,
            expectedCompletionLabel: expectedCompletionLabel,
            expectedPaceLabel: expectedPaceLabel,
            usesLoggedCurrentWeight: input.usesLoggedCurrentWeight,
            accessibilitySummary: ""
        )
        strategy.accessibilitySummary = strategyAccessibilitySummary(
            strategy: strategy,
            baseline: baseline
        )

        let status = buildStatus(
            input: input,
            context: context,
            profile: profile,
            baseline: baseline,
            asOf: asOf,
            calendar: calendar
        )

        return (strategy, status)
    }

    // MARK: - Headline

    static func headlineValue(
        direction: PlanGoalDirection,
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
        direction: PlanGoalDirection,
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
        direction: PlanGoalDirection,
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
        direction: PlanGoalDirection,
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
        direction: PlanGoalDirection
    ) -> String? {
        guard direction == .lose, let weeklyKg, weeklyKg > 0 else { return nil }
        return FormaProductCopy.PlanMissionControl.expectedProgress(formatKg(weeklyKg))
    }

    // MARK: - Status

    static func buildStatus(
        input: Input,
        context: PlanDashboardContext,
        profile: UserProfile,
        baseline: JourneyBaseline,
        asOf: Date,
        calendar: Calendar
    ) -> PlanStatusState {
        let hasRecentWeight = PlanConfidenceStateBuilder.hasRecentWeightLog(
            in: context.allWeights,
            asOf: asOf,
            calendar: calendar
        )
        let foodDays = JourneyLogMetrics.foodLoggedDays(in: context.weekLogs)
        let hasFoodLogs = foodDays > 0
        let hasBirthdayAndHeight = profile.birthDate != nil && profile.heightCm > 0
        let planResult = PlanPresentationBuilder.planResult(from: profile, referenceDate: asOf)
        let hasInsufficientData = !hasBirthdayAndHeight || planResult == nil

        if hasInsufficientData {
            return PlanStatusState(
                message: "Add profile details and a weigh-in so Forma can build your plan.",
                tone: .needsData
            )
        }

        if !hasRecentWeight {
            return PlanStatusState(
                message: "Log a recent weigh-in so Forma can track progress.",
                tone: .needsData
            )
        }

        if !hasFoodLogs {
            return PlanStatusState(
                message: "Log meals this week to refine calorie and macro targets.",
                tone: .needsData
            )
        }

        if isNewPlan(baseline: baseline, asOf: asOf, calendar: calendar),
           !input.usesLoggedCurrentWeight {
            return PlanStatusState(
                message: FormaProductCopy.PlanMissionControl.statusStartLogging,
                tone: .newPlan
            )
        }

        if isAheadOfSchedule(baseline: baseline, asOf: asOf, calendar: calendar) {
            return PlanStatusState(
                message: FormaProductCopy.PlanMissionControl.statusAheadOfSchedule,
                tone: .aheadOfSchedule
            )
        }

        if input.goalDirection == .lose {
            let message = PlanStateBuilder.strategySummary(for: profile)
            let tone: PlanStatusTone = profile.targets.aggressiveness == .aggressive
                ? .needsData
                : .onTrack
            return PlanStatusState(message: message, tone: tone)
        }

        return PlanStatusState(
            message: PlanStateBuilder.strategySummary(for: profile),
            tone: .onTrack
        )
    }

    // MARK: - Accessibility

    static func strategyAccessibilitySummary(
        strategy: PlanStrategyState,
        baseline: JourneyBaseline
    ) -> String {
        var parts: [String] = [
            strategy.sectionTitle,
            strategy.headline,
            strategy.progressRouteLabel
        ]

        if let progressCompleteLabel = strategy.progressCompleteLabel {
            parts.append(progressCompleteLabel)
        }

        if let expectedCompletionLabel = strategy.expectedCompletionLabel {
            parts.append(expectedCompletionLabel)
        }

        if let expectedPaceLabel = strategy.expectedPaceLabel {
            parts.append(expectedPaceLabel)
        }

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
