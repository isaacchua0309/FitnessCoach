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

    static func buildPresentation(
        input: Input
    ) -> PlanStrategyState {
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
        return strategy
    }

    // MARK: - Primary goal

    static func primaryGoalValue(
        direction: PlanGoalDirection,
        totalChangeKg: Double?
    ) -> String {
        switch direction {
        case .cut:
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
        guard direction == .cut, let weeklyKg, weeklyKg > 0 else { return nil }
        return FormaProductCopy.PlanStrategyHero.expectedPace(formatKg(weeklyKg))
    }

    static func strategyStatusValue(
        direction: PlanGoalDirection,
        aggressiveness: CalorieAggressiveness
    ) -> String {
        switch direction {
        case .cut:
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
        case .cut:
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

    // MARK: - Accessibility

    static func strategyAccessibilitySummary(for strategy: PlanStrategyState) -> String {
        var parts = [
            strategy.sectionTitle,
            strategy.primaryGoal,
            "\(strategy.strategyStatusLabel), \(strategy.strategyStatusValue)",
            strategy.supportiveLine
        ]

        if let expectedPaceLabel = strategy.expectedPaceLabel,
           let expectedPaceValue = strategy.expectedPaceValue {
            parts.insert("\(expectedPaceLabel), \(expectedPaceValue)", at: 2)
        }

        return parts.joined(separator: ". ")
    }

    // MARK: - Helpers

    private static func formatKg(_ value: Double) -> String {
        value.truncatingRemainder(dividingBy: 1) == 0
            ? "\(Int(value)) kg"
            : String(format: "%.1f kg", value)
    }
}
