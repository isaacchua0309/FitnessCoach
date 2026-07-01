//
//  PlanDashboardState.swift
//  Fitness Coach
//
//  FitPilot AI — Mission Control view state for the Plan screen.
//

import Foundation

struct PlanDashboardState: Equatable {
    var profile: UserProfile
    /// Product-facing Mission Control read model for the Plan dashboard redesign.
    var missionControl: PlanMissionControlDashboard
    var rationale: PlanRationaleState
}

// MARK: Wizard

enum PlanGoalType: String, CaseIterable, Identifiable {
    case loseFat = "Lose Fat"
    case maintain = "Maintain"
    case gainMuscle = "Gain Muscle"

    var id: String { rawValue }
}
