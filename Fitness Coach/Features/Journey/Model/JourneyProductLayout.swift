//
//  JourneyProductLayout.swift
//  Fitness Coach
//
//  Forma — Canonical Journey product section order.
//

import Foundation

enum JourneyProductSection: String, CaseIterable, Equatable {
    case header
    case transformation
    case goalProjection
    case healthIntelligence
    case milestones
    case weeklyReview
    case storyTimeline
    case insights
    case monthlyRecap
    case chapters
    case startingEmptyState
}

enum JourneyProductLayout {
    static let sectionOrder: [JourneyProductSection] = [
        .header,
        .transformation,
        .goalProjection,
        .healthIntelligence,
        .milestones,
        .weeklyReview,
        .storyTimeline,
        .insights,
        .monthlyRecap,
        .chapters,
        .startingEmptyState
    ]
}
