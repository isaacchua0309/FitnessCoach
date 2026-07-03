//
//  JourneyProductLayout.swift
//  Fitness Coach
//
//  Forma — Canonical Journey product section order.
//

import Foundation

enum JourneyProductSection: String, CaseIterable, Equatable {
    case transformation
    case weeklyReview
    case milestones
    case storyTimeline
    case startingEmptyState
}

enum JourneyProductLayout {
    static let sectionOrder: [JourneyProductSection] = [
        .transformation,
        .weeklyReview,
        .milestones,
        .storyTimeline,
        .startingEmptyState
    ]
}
