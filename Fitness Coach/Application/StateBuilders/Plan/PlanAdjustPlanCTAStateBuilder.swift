//
//  PlanAdjustPlanCTAStateBuilder.swift
//  Fitness Coach
//
//  Forma — Compact Adjust Plan call-to-action state.
//

import Foundation

enum PlanAdjustPlanCTAStateBuilder {

    static func build(isEnabled: Bool = true) -> AdjustPlanCTAState {
        AdjustPlanCTAState(
            heading: FormaProductCopy.PlanMissionControl.adjustPlanCTAHeading,
            bodyCopy: FormaProductCopy.PlanMissionControl.adjustPlanCTABody,
            buttonTitle: FormaProductCopy.PlanMissionControl.adjustPlan,
            isEnabled: isEnabled,
            accessibilitySummary: [
                FormaProductCopy.PlanMissionControl.adjustPlanCTAHeading,
                FormaProductCopy.PlanMissionControl.adjustPlanCTABody,
                FormaProductCopy.PlanMissionControl.adjustPlan
            ].joined(separator: ". "),
            accessibilityHint: FormaProductCopy.PlanMissionControl.adjustPlanAccessibilityHint
        )
    }
}
