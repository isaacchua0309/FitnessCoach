//
//  PlanDashboardState.swift
//  Fitness Coach
//
//  Forma — Presentation state for the Plan strategy screen.
//

import Foundation

struct PlanDashboardState: Equatable, Sendable {
    var profile: UserProfile
    var header: PlanHeaderState
    var strategy: PlanStrategyState
    var dailyTargets: DailyTargetsState
    var status: PlanStatusState
    var explanation: PlanExplanationState
    var confidence: PlanConfidenceState
    var adjustmentRules: AdjustmentRulesState
    var assumptions: PlanAssumptionsState
    var review: PlanReviewState
    var adjustPlanCTA: AdjustPlanCTAState
}

// MARK: Wizard

enum PlanGoalType: String, CaseIterable, Identifiable {
    case loseFat = "Lose Fat"
    case maintain = "Maintain"
    case gainMuscle = "Gain Muscle"

    var id: String { rawValue }
}
