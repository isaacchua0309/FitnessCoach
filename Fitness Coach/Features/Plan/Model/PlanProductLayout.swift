//
//  PlanProductLayout.swift
//  Fitness Coach
//
//  Forma — Canonical Plan product section order.
//

import Foundation

enum PlanProductSection: String, CaseIterable, Equatable {
    case goalProgress = "goal_progress"
    case todayMission = "today_mission"
    case thisWeek = "this_week"
    case nextMilestone = "next_milestone"
    case whyThisWorks = "why_this_works"
    case activityAssumptions = "activity_assumptions"
    case planConfidence = "plan_confidence"
    case appleHealth = "apple_health"
    case adjustPlan = "adjust_plan"
}

enum PlanProductLayout {
    static let sectionOrder: [PlanProductSection] = [
        .goalProgress,
        .todayMission,
        .thisWeek,
        .nextMilestone,
        .whyThisWorks,
        .activityAssumptions,
        .planConfidence,
        .appleHealth,
        .adjustPlan
    ]

    /// Legacy section identifiers removed from the Plan dashboard.
    static let removedSectionIdentifiers: Set<String> = [
        "current_strategy",
        "todays_targets",
        "about_you",
        "what_happens_next",
        "plan_lifestyle"
    ]
}
