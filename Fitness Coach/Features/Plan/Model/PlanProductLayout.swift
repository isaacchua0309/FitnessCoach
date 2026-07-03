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
    case planStatus = "plan_status"
    case whyThisWorks = "why_this_works"
    case planAssumptions = "plan_assumptions"
    case planConfidence = "plan_confidence"
}

enum PlanProductLayout {
    static let sectionOrder: [PlanProductSection] = [
        .goalProgress,
        .todayMission,
        .planStatus,
        .whyThisWorks,
        .planAssumptions,
        .planConfidence
    ]

    /// Legacy section identifiers removed from the Plan screen.
    static let removedSectionIdentifiers: Set<String> = [
        "current_strategy",
        "todays_targets",
        "about_you",
        "what_happens_next",
        "plan_lifestyle",
        "this_week",
        "next_milestone",
        "activity_assumptions",
        "apple_health",
        "adjust_plan"
    ]
}
