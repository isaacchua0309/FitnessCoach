//
//  PlanStateBuilder.swift
//  Fitness Coach
//
//  FitPilot AI — Builds Mission Control Plan state from profile.
//

import Foundation

enum PlanStateBuilder {

    static func dashboardState(
        profile: UserProfile,
        context: PlanDashboardContext? = nil,
        referenceDate: Date = Date()
    ) -> PlanDashboardState {
        let dashboardContext = context ?? PlanDashboardContext.profileOnly(
            profile: profile,
            referenceDate: referenceDate
        )
        let missionControl = PlanDashboardBuilder.missionControlDashboard(
            context: dashboardContext,
            referenceDate: referenceDate
        )

        return PlanDashboardState(
            profile: profile,
            missionControl: missionControl,
            rationale: missionControl.rationale
        )
    }

    // MARK: Strategy

    static func strategyName(for profile: UserProfile) -> String {
        let pace = PlanFormatter.aggressiveness(profile.targets.aggressiveness)
        if profile.goalWeightKg < profile.currentWeightKg - 0.5 {
            return "\(pace) Cut"
        }
        if profile.goalWeightKg > profile.currentWeightKg + 0.5 {
            return "\(pace) Build"
        }
        return "Maintenance"
    }

    static func strategySummary(for profile: UserProfile) -> String {
        let isLoss = profile.goalWeightKg < profile.currentWeightKg
        switch profile.targets.aggressiveness {
        case .conservative:
            return isLoss
                ? "Designed for sustainable fat loss while preserving strength."
                : "Designed for gradual progress without rushing recovery."
        case .moderate:
            return isLoss
                ? "Built around recovery and strength — not just fat loss."
                : "Supports lean muscle gain with a controlled surplus."
        case .aggressive:
            return isLoss
                ? "A faster cut — protect sleep, protein, and training quality."
                : "A stronger surplus — consistency and recovery matter most."
        }
    }

    static func goalType(for profile: UserProfile) -> PlanGoalType {
        if profile.goalWeightKg < profile.currentWeightKg - 0.5 { return .loseFat }
        if profile.goalWeightKg > profile.currentWeightKg + 0.5 { return .gainMuscle }
        return .maintain
    }
}
