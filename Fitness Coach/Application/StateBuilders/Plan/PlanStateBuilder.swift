//
//  PlanStateBuilder.swift
//  Fitness Coach
//
//  FitPilot AI — Builds Plan presentation state from profile.
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
        return PlanPresentationBuilder.dashboardState(
            context: dashboardContext,
            referenceDate: referenceDate
        )
    }

    static func goalType(for profile: UserProfile) -> PlanGoalType {
        if profile.goalWeightKg < profile.currentWeightKg - 0.5 { return .loseFat }
        if profile.goalWeightKg > profile.currentWeightKg + 0.5 { return .gainMuscle }
        return .maintain
    }
}
