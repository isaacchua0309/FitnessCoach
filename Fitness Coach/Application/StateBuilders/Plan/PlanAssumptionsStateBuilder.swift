//
//  PlanAssumptionsStateBuilder.swift
//  Fitness Coach
//
//  Forma — Compact Plan Assumptions presentation state.
//

import Foundation

enum PlanAssumptionsStateBuilder {

    static func build(context: PlanDashboardContext, asOf: Date) -> PlanAssumptionsState {
        let profile = context.profile
        let rows = assumptionRows(profile: profile, asOf: asOf)

        var state = PlanAssumptionsState(
            sectionTitle: FormaProductCopy.PlanMissionControl.planAssumptionsSectionTitle,
            rows: rows,
            adjustActivityTitle: FormaProductCopy.PlanMissionControl.adjustActivity,
            accessibilitySummary: ""
        )
        state.accessibilitySummary = accessibilitySummary(for: state)
        return state
    }

    static func assumptionRows(profile: UserProfile, asOf: Date) -> [PlanAssumptionRow] {
        let ageYears = profile.resolvedAge(referenceDate: asOf)
        let hasHeight = profile.heightCm > 0
        let hasWeight = profile.currentWeightKg > 0
        let hasGoalWeight = profile.goalWeightKg > 0

        return [
            PlanAssumptionRow(
                id: "age",
                label: FormaProductCopy.PlanMissionControl.planAssumptionsAge,
                value: ageYears > 0
                    ? "\(ageYears)"
                    : FormaProductCopy.PlanMissionControl.planAssumptionsNotSet,
                isMissing: ageYears <= 0
            ),
            PlanAssumptionRow(
                id: "height",
                label: FormaProductCopy.PlanMissionControl.planAssumptionsHeight,
                value: hasHeight
                    ? PlanFormatter.cm(profile.heightCm)
                    : FormaProductCopy.PlanMissionControl.planAssumptionsNotSet,
                isMissing: !hasHeight
            ),
            PlanAssumptionRow(
                id: "weight",
                label: FormaProductCopy.PlanMissionControl.planAssumptionsWeight,
                value: hasWeight
                    ? PlanFormatter.kg(profile.currentWeightKg)
                    : FormaProductCopy.PlanMissionControl.planAssumptionsNotSet,
                isMissing: !hasWeight
            ),
            PlanAssumptionRow(
                id: "sex",
                label: FormaProductCopy.PlanMissionControl.planAssumptionsSex,
                value: PlanFormatter.sex(profile.sex),
                isMissing: false
            ),
            PlanAssumptionRow(
                id: "activity",
                label: FormaProductCopy.PlanMissionControl.planAssumptionsActivity,
                value: PlanFormatter.activityLevel(profile.activityLevel),
                isMissing: false
            ),
            PlanAssumptionRow(
                id: "goalWeight",
                label: FormaProductCopy.PlanMissionControl.planAssumptionsGoalWeight,
                value: hasGoalWeight
                    ? PlanFormatter.kg(profile.goalWeightKg)
                    : FormaProductCopy.PlanMissionControl.planAssumptionsNotSet,
                isMissing: !hasGoalWeight
            )
        ]
    }

    private static func accessibilitySummary(for state: PlanAssumptionsState) -> String {
        var parts = [state.sectionTitle]
        parts.append(contentsOf: state.rows.map { "\($0.label), \($0.value)" })
        parts.append(state.adjustActivityTitle)
        return parts.joined(separator: ". ")
    }
}
