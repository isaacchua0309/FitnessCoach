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
    case weeklyRecommendation = "weekly_recommendation"
    case planConfidence = "plan_confidence"
    case nextReview = "next_review"

    // Retained for analytics / fixture compatibility; not rendered on the dashboard.
    case planStatus = "plan_status"
    case whyThisWorks = "why_this_works"
    case whenToAdjust = "when_to_adjust"
    case planAssumptions = "plan_assumptions"
    case adjustPlanCTA = "adjust_plan_cta"
}

enum PlanProductLayout {
    /// Canonical Plan screen order (header → strategy → targets → weekly → confidence → review).
    static let sectionOrder: [PlanProductSection] = [
        .header,
        .goalProgress,
        .todayMission,
        .weeklyRecommendation,
        .planConfidence,
        .nextReview
    ]

    static let primarySectionOrder: [PlanProductSection] = [
        .header,
        .goalProgress,
        .todayMission,
        .weeklyRecommendation,
        .planConfidence
    ]

    static let secondarySectionOrder: [PlanProductSection] = [
        .nextReview
    ]

    /// Section identifiers removed from the Plan screen scroll.
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
        "adjust_plan",
        "plan_status",
        "why_this_works",
        "when_to_adjust",
        "plan_assumptions",
        "adjust_plan_cta"
    ]
}
