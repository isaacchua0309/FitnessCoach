//
//  PlanExplanationStateBuilder.swift
//  Fitness Coach
//
//  Forma — Compact "Why This Works" presentation state.
//

import Foundation

enum PlanExplanationStateBuilder {

    static func build(
        profile: UserProfile,
        planResult: PlanCalculationResult?,
        referenceDate: Date
    ) -> PlanExplanationState {
        guard let result = planResult else {
            return fallback(profile: profile)
        }

        let energyLines = energyLines(for: result)
        let guidanceCopy = guidanceCopy(profile: profile, result: result)
        let calculationDetails = PlanCalculationDetailsBuilder.build(
            profile: profile,
            result: result,
            referenceDate: referenceDate
        )

        var state = PlanExplanationState(
            sectionTitle: FormaProductCopy.PlanRationale.sectionTitle,
            energyLines: energyLines,
            guidanceCopy: guidanceCopy,
            seeCalculationTitle: FormaProductCopy.PlanRationale.seeCalculation,
            calculationDetails: calculationDetails,
            accessibilitySummary: ""
        )
        state.accessibilitySummary = accessibilitySummary(for: state)
        return state
    }

    static func energyLines(for result: PlanCalculationResult) -> [PlanExplanationEnergyLine] {
        var lines = [
            PlanExplanationEnergyLine(
                id: "maintenance",
                label: FormaProductCopy.PlanRationale.maintenanceLine,
                value: PlanDisplayFormatter.formatKcal(result.tdeeKcal)
            )
        ]

        switch result.goalDirection {
        case .cut where result.dailyDeficitKcal > 0:
            lines.append(
                PlanExplanationEnergyLine(
                    id: "adjustment",
                    label: FormaProductCopy.PlanRationale.deficitLine,
                    value: PlanDisplayFormatter.formatKcal(result.dailyDeficitKcal)
                )
            )
            lines.append(targetLine(for: result))
        case .gain:
            let surplus = max(result.calorieTargetKcal - result.tdeeKcal, 0)
            if surplus > 0 {
                lines.append(
                    PlanExplanationEnergyLine(
                        id: "adjustment",
                        label: FormaProductCopy.PlanRationale.surplusLine,
                        value: PlanDisplayFormatter.formatKcal(surplus)
                    )
                )
            }
            lines.append(targetLine(for: result))
        case .maintain, .cut:
            lines.append(targetLine(for: result))
        }

        return lines
    }

    static func guidanceCopy(
        profile: UserProfile,
        result: PlanCalculationResult
    ) -> String {
        switch result.goalDirection {
        case .cut:
            switch profile.targets.aggressiveness {
            case .aggressive:
                return FormaProductCopy.PlanRationale.guidanceAggressiveCut
            case .moderate:
                return FormaProductCopy.PlanRationale.guidanceModerateCut
            case .conservative:
                return FormaProductCopy.PlanRationale.guidanceGentleCut
            }
        case .maintain:
            return FormaProductCopy.PlanRationale.guidanceMaintenance
        case .gain:
            return FormaProductCopy.PlanRationale.guidanceLeanGain
        }
    }

    private static func targetLine(for result: PlanCalculationResult) -> PlanExplanationEnergyLine {
        PlanExplanationEnergyLine(
            id: "target",
            label: FormaProductCopy.PlanRationale.targetLine,
            value: PlanDisplayFormatter.formatKcal(result.calorieTargetKcal)
        )
    }

    private static func fallback(profile: UserProfile) -> PlanExplanationState {
        var lines: [PlanExplanationEnergyLine] = []
        if profile.targets.calorieTarget > 0 {
            lines.append(
                PlanExplanationEnergyLine(
                    id: "target",
                    label: FormaProductCopy.PlanRationale.targetLine,
                    value: PlanFormatter.kcal(profile.targets.calorieTarget)
                )
            )
        }

        return PlanExplanationState(
            sectionTitle: FormaProductCopy.PlanRationale.sectionTitle,
            energyLines: lines,
            guidanceCopy: FormaProductCopy.PlanRationale.guidanceFallback,
            seeCalculationTitle: FormaProductCopy.PlanRationale.seeCalculation,
            calculationDetails: nil,
            accessibilitySummary: [
                FormaProductCopy.PlanRationale.sectionTitle,
                FormaProductCopy.PlanRationale.guidanceFallback
            ].joined(separator: ". ")
        )
    }

    private static func accessibilitySummary(for state: PlanExplanationState) -> String {
        var parts = [state.sectionTitle]
        parts.append(contentsOf: state.energyLines.map { "\($0.label), \($0.value)" })
        parts.append(state.guidanceCopy)
        if state.showsCalculationAction {
            parts.append(state.seeCalculationTitle)
        }
        return parts.joined(separator: ". ")
    }
}
