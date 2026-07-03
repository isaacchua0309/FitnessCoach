//
//  PlanAdjustmentRulesStateBuilder.swift
//  Fitness Coach
//
//  Forma — "When to Adjust" presentation state.
//

import Foundation

enum PlanAdjustmentRulesStateBuilder {

    private static let minimumWeightEntriesForTrend = 3
    private static let minimumStableDaysForHint = 7
    private static let stableBandKg = 0.2
    private static let aggressiveDeficitKcalThreshold = 550

    static func build(
        profile: UserProfile,
        planResult: PlanCalculationResult?,
        allWeights: [WeightEntry],
        referenceDate: Date,
        calendar: Calendar
    ) -> AdjustmentRulesState {
        let rules = genericRules()
        let trendHint = trendHint(
            weights: allWeights,
            asOf: referenceDate,
            calendar: calendar
        )
        let aggressivePlanNote = isAggressivePlan(profile: profile, planResult: planResult)
            ? FormaProductCopy.PlanMissionControl.adjustmentRuleAggressiveRecoveryNote
            : nil

        var state = AdjustmentRulesState(
            sectionTitle: FormaProductCopy.PlanMissionControl.adjustmentRulesSectionTitle,
            reviewHeading: FormaProductCopy.PlanMissionControl.adjustmentRulesReviewHeading,
            rules: rules,
            trendHint: trendHint,
            aggressivePlanNote: aggressivePlanNote,
            accessibilitySummary: ""
        )
        state.accessibilitySummary = accessibilitySummary(for: state)
        return state
    }

    static func genericRules() -> [AdjustmentRuleItem] {
        [
            AdjustmentRuleItem(
                id: "weightFlat",
                text: FormaProductCopy.PlanMissionControl.adjustmentRuleWeightFlat
            ),
            AdjustmentRuleItem(
                id: "poorEnergy",
                text: FormaProductCopy.PlanMissionControl.adjustmentRulePoorEnergy
            ),
            AdjustmentRuleItem(
                id: "trainingDrops",
                text: FormaProductCopy.PlanMissionControl.adjustmentRuleTrainingDrops
            ),
            AdjustmentRuleItem(
                id: "highHunger",
                text: FormaProductCopy.PlanMissionControl.adjustmentRuleHighHunger
            )
        ]
    }

    static func trendHint(
        weights: [WeightEntry],
        asOf: Date,
        calendar: Calendar
    ) -> String? {
        let validWeights = weights
            .filter { $0.weightKg > 0 }
            .sorted { $0.date < $1.date }

        guard !validWeights.isEmpty else {
            return nil
        }

        guard validWeights.count >= minimumWeightEntriesForTrend else {
            return FormaProductCopy.PlanMissionControl.adjustmentTrendTooEarly
        }

        let trend = WeightTrendCalculator.trend(from: validWeights, endingOn: asOf)

        switch trend.direction {
        case .insufficientData:
            return FormaProductCopy.PlanMissionControl.adjustmentTrendTooEarly
        case .stable:
            let stableDays = stableDayCount(
                weights: validWeights,
                asOf: asOf,
                calendar: calendar
            )
            if stableDays >= minimumStableDaysForHint {
                return FormaProductCopy.PlanMissionControl.adjustmentTrendStable(days: stableDays)
            }
            return FormaProductCopy.PlanMissionControl.adjustmentTrendTooEarly
        case .decreasing, .increasing:
            return nil
        }
    }

    static func stableDayCount(
        weights: [WeightEntry],
        asOf: Date,
        calendar: Calendar
    ) -> Int {
        let sorted = weights.sorted { $0.date < $1.date }
        guard let latest = sorted.last else { return 0 }

        var anchorDate = latest.date
        var bandMin = latest.weightKg
        var bandMax = latest.weightKg

        for entry in sorted.reversed() {
            let newMin = min(bandMin, entry.weightKg)
            let newMax = max(bandMax, entry.weightKg)
            if newMax - newMin <= stableBandKg {
                bandMin = newMin
                bandMax = newMax
                anchorDate = entry.date
            } else {
                break
            }
        }

        let start = calendar.startOfDay(for: anchorDate)
        let end = calendar.startOfDay(for: asOf)
        return max(calendar.dateComponents([.day], from: start, to: end).day ?? 0, 0)
    }

    static func isAggressivePlan(
        profile: UserProfile,
        planResult: PlanCalculationResult?
    ) -> Bool {
        if profile.targets.aggressiveness == .aggressive {
            return true
        }

        guard let result = planResult, result.goalDirection == .cut else {
            return false
        }

        return result.dailyDeficitKcal >= aggressiveDeficitKcalThreshold
    }

    private static func accessibilitySummary(for state: AdjustmentRulesState) -> String {
        var parts = [state.sectionTitle, state.reviewHeading]
        parts.append(contentsOf: state.rules.map(\.text))

        if let trendHint = state.trendHint {
            parts.append(trendHint)
        }

        if let aggressivePlanNote = state.aggressivePlanNote {
            parts.append(aggressivePlanNote)
        }

        return parts.joined(separator: ". ")
    }
}
