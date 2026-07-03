//
//  PlanMissionHeroCopyBuilder.swift
//  Fitness Coach
//
//  Forma — Strategy hero copy and accessibility for the Plan dashboard.
//

import Foundation

enum PlanMissionHeroCopyBuilder {

    struct Input: Equatable {
        var goalDirection: PlanGoalDirection
        var totalChangeKg: Double?
        var calorieTargetKcal: Int
        var expectedWeeklyChangeKg: Double?
        var aggressiveness: CalorieAggressiveness
    }

    private static let scheduleLeadPercent = 5.0
    private static let newPlanGraceDays = 3

    static func buildPresentation(
        input: Input,
        context: PlanDashboardContext,
        profile: UserProfile,
        baseline: JourneyBaseline,
        asOf: Date,
        calendar: Calendar
    ) -> (PlanStrategyState, PlanStatusState) {
        let primaryGoal = primaryGoalValue(
            direction: input.goalDirection,
            totalChangeKg: input.totalChangeKg
        )
        let dailyTargetValue = dailyTargetValue(for: input.calorieTargetKcal)
        let expectedPaceValue = expectedPaceValue(
            weeklyKg: input.expectedWeeklyChangeKg,
            direction: input.goalDirection
        )
        let strategyStatusValue = strategyStatusValue(
            direction: input.goalDirection,
            aggressiveness: input.aggressiveness
        )
        let supportiveLine = supportiveLine(
            direction: input.goalDirection,
            aggressiveness: input.aggressiveness
        )

        var strategy = PlanStrategyState(
            sectionTitle: FormaProductCopy.PlanStrategyHero.sectionTitle,
            primaryGoal: primaryGoal,
            goalDirection: input.goalDirection,
            dailyTargetLabel: FormaProductCopy.PlanStrategyHero.dailyTargetLabel,
            dailyTargetValue: dailyTargetValue,
            expectedPaceLabel: expectedPaceValue == nil
                ? nil
                : FormaProductCopy.PlanStrategyHero.expectedPaceLabel,
            expectedPaceValue: expectedPaceValue,
            strategyStatusLabel: FormaProductCopy.PlanStrategyHero.statusLabel,
            strategyStatusValue: strategyStatusValue,
            supportiveLine: supportiveLine,
            accessibilitySummary: ""
        )
        strategy.accessibilitySummary = strategyAccessibilitySummary(for: strategy)

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

    // MARK: - Primary goal

    static func primaryGoalValue(
        direction: PlanGoalDirection,
        totalChangeKg: Double?
    ) -> String {
        switch direction {
        case .lose:
            guard let totalChangeKg, totalChangeKg > 0.1 else {
                return FormaProductCopy.PlanStrategyHero.primaryGoalLoseFallback
            }
            return FormaProductCopy.PlanStrategyHero.primaryGoalLose(formatKg(totalChangeKg))
        case .maintain:
            return FormaProductCopy.PlanStrategyHero.primaryGoalMaintain
        case .gain:
            return FormaProductCopy.PlanStrategyHero.primaryGoalGain
        }
    }

    static func dailyTargetValue(for calorieTargetKcal: Int) -> String {
        guard calorieTargetKcal > 0 else {
            return FormaProductCopy.PlanMissionControl.targetUnavailable
        }
        return PlanFormatter.kcal(calorieTargetKcal)
    }

    static func expectedPaceValue(
        weeklyKg: Double?,
        direction: PlanGoalDirection
    ) -> String? {
        guard direction == .lose, let weeklyKg, weeklyKg > 0 else { return nil }
        return FormaProductCopy.PlanStrategyHero.expectedPace(formatKg(weeklyKg))
    }

    static func strategyStatusValue(
        direction: PlanGoalDirection,
        aggressiveness: CalorieAggressiveness
    ) -> String {
        switch direction {
        case .lose:
            switch aggressiveness {
            case .aggressive:
                return FormaProductCopy.PlanStrategyHero.statusAggressiveCut
            case .moderate, .conservative:
                return FormaProductCopy.PlanStrategyHero.statusModerateCut
            }
        case .maintain:
            return FormaProductCopy.PlanStrategyHero.statusMaintenance
        case .gain:
            return FormaProductCopy.PlanStrategyHero.statusLeanGain
        }
    }

    static func supportiveLine(
        direction: PlanGoalDirection,
        aggressiveness: CalorieAggressiveness
    ) -> String {
        switch direction {
        case .lose:
            switch aggressiveness {
            case .aggressive:
                return FormaProductCopy.PlanStrategyHero.supportiveAggressiveCut
            case .moderate, .conservative:
                return FormaProductCopy.PlanStrategyHero.supportiveModerateCut
            }
        case .maintain:
            return FormaProductCopy.PlanStrategyHero.supportiveMaintenance
        case .gain:
            return FormaProductCopy.PlanStrategyHero.supportiveLeanGain
        }
    }

    // MARK: - Status (dashboard-level, not shown in strategy hero)

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
           !baseline.hasRealWeightEntries {
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

    static func strategyAccessibilitySummary(for strategy: PlanStrategyState) -> String {
        var parts = [
            strategy.sectionTitle,
            strategy.primaryGoal,
            "\(strategy.dailyTargetLabel), \(strategy.dailyTargetValue)",
            "\(strategy.strategyStatusLabel), \(strategy.strategyStatusValue)",
            strategy.supportiveLine
        ]

        if let expectedPaceLabel = strategy.expectedPaceLabel,
           let expectedPaceValue = strategy.expectedPaceValue {
            parts.insert("\(expectedPaceLabel), \(expectedPaceValue)", at: 3)
        }

        return parts.joined(separator: ". ")
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
