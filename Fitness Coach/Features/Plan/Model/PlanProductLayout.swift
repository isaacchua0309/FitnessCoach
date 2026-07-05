//
//  PlanProductLayout.swift
//  Fitness Coach
//
//  Forma — Canonical Plan product section order.
//

import Foundation

enum PlanProductSection: String, CaseIterable, Equatable {
    case header = "header"
    case goalProgress = "goal_progress"
    case todayMission = "today_mission"
    case planStatus = "plan_status"
    case weeklyRecommendation = "weekly_recommendation"
    case whyThisWorks = "why_this_works"
    case planConfidence = "plan_confidence"
    case whenToAdjust = "when_to_adjust"
    case planAssumptions = "plan_assumptions"
    case nextReview = "next_review"
    case adjustPlanCTA = "adjust_plan_cta"
}

enum PlanProductLayout {
    /// Canonical Plan screen order (header → hero → targets → status → rationale → confidence → adjust → assumptions → review → CTA).
    static let sectionOrder: [PlanProductSection] = [
        .header,
        .goalProgress,
        .todayMission,
        .planStatus,
        .weeklyRecommendation,
        .whyThisWorks,
        .planConfidence,
        .whenToAdjust,
        .planAssumptions,
        .nextReview,
        .adjustPlanCTA
    ]

    static let primarySectionOrder: [PlanProductSection] = [
        .header,
        .goalProgress,
        .todayMission,
        .planStatus,
        .weeklyRecommendation,
        .whyThisWorks,
        .planConfidence
    ]

    static let secondarySectionOrder: [PlanProductSection] = [
        .whenToAdjust,
        .planAssumptions,
        .nextReview,
        .adjustPlanCTA
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
