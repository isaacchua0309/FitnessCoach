//
//  OnboardingPlanRevealStatus.swift
//  Fitness Coach
//
//  Forma — User-facing plan reveal status (sustainability / caution).
//

import Foundation

enum OnboardingPlanRevealStatusStyle: Equatable, Sendable {
    case positive
    case caution
}

struct OnboardingPlanRevealStatus: Equatable, Sendable {
    let title: String
    let body: String?
    let style: OnboardingPlanRevealStatusStyle
}

enum OnboardingPlanRevealStatusFormatter {

    static func resolve(
        plan: CalorieTargetResult,
        pacePreview: WeightLossPacePreviewModel,
        goalDirection: PlanGoalDirection
    ) -> OnboardingPlanRevealStatus {
        let copy = FormaProductCopy.Onboarding.V2.PlanReveal.Status.self

        if goalDirection == .maintain {
            return OnboardingPlanRevealStatus(
                title: copy.maintenanceTitle,
                body: copy.maintenanceBody,
                style: .positive
            )
        }

        if let mapped = mapPlanWarningKey(plan.warning) {
            return mapped
        }

        if pacePreview.safetyDisplay == .tooAggressive {
            return OnboardingPlanRevealStatus(
                title: copy.lowCalorieTitle,
                body: copy.lowCalorieBody,
                style: .caution
            )
        }

        if pacePreview.safetyDisplay == .demanding || pacePreview.warningMessage != nil {
            return OnboardingPlanRevealStatus(
                title: copy.aggressiveDeficitTitle,
                body: copy.aggressiveDeficitBody,
                style: .caution
            )
        }

        if plan.isAggressive, suggestsLowCalorieTarget(plan: plan) {
            return OnboardingPlanRevealStatus(
                title: copy.lowCalorieTitle,
                body: copy.lowCalorieBody,
                style: .caution
            )
        }

        if plan.isAggressive {
            return OnboardingPlanRevealStatus(
                title: copy.aggressiveDeficitTitle,
                body: copy.aggressiveDeficitBody,
                style: .caution
            )
        }

        return OnboardingPlanRevealStatus(
            title: copy.sustainableTitle,
            body: nil,
            style: .positive
        )
    }

    private static func mapPlanWarningKey(_ warning: String?) -> OnboardingPlanRevealStatus? {
        guard let key = warning?.trimmingCharacters(in: .whitespacesAndNewlines),
              !key.isEmpty else {
            return nil
        }

        let copy = FormaProductCopy.Onboarding.V2.PlanReveal.Status.self
        switch key {
        case "aggressiveDeficit":
            return OnboardingPlanRevealStatus(
                title: copy.aggressiveDeficitTitle,
                body: copy.aggressiveDeficitBody,
                style: .caution
            )
        case "lowCalorieTarget", "calorieFloorApplied":
            return OnboardingPlanRevealStatus(
                title: copy.lowCalorieTitle,
                body: copy.lowCalorieBody,
                style: .caution
            )
        default:
            return OnboardingPlanRevealStatus(
                title: copy.aggressiveDeficitTitle,
                body: copy.aggressiveDeficitBody,
                style: .caution
            )
        }
    }

    private static func suggestsLowCalorieTarget(plan: CalorieTargetResult) -> Bool {
        let floor = FormaCalculationConstants.calorieFloorFemaleKcal
        return plan.targets.calorieTarget <= floor + 50
    }
}

enum OnboardingPlanRevealStrategyFormatter {

    static func label(
        goalDirection: PlanGoalDirection,
        paceChoice: WeightLossPaceChoice
    ) -> String {
        let copy = FormaProductCopy.Onboarding.V2.PlanReveal.Strategy.self
        switch goalDirection {
        case .maintain:
            return copy.maintenance
        case .gain:
            return copy.leanGain
        case .cut:
            switch paceChoice {
            case .gentle:
                return copy.gentleCut
            case .moderate:
                return copy.moderateCut
            case .aggressive:
                return copy.fasterCut
            case .advanced:
                return copy.customCut
            }
        }
    }

    static func calorieExplanation(goalDirection: PlanGoalDirection) -> String {
        let copy = FormaProductCopy.Onboarding.V2.PlanReveal.self
        switch goalDirection {
        case .cut:
            return copy.cutCalorieExplanation
        case .maintain:
            return copy.maintainCalorieExplanation
        case .gain:
            return copy.gainCalorieExplanation
        }
    }
}
