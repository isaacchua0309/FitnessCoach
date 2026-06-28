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
    case habitInsights
    case whyProgress
    case beforeToday
    case personalRecords
    case monthlyRecap
    case journeyLevel
    case detailedAnalytics
}

enum JourneyProductLayout {
    static let sectionOrder: [JourneyProductSection] = [
        .transformation,
        .weeklyReview,
        .milestones,
        .storyTimeline,
        .habitInsights,
        .whyProgress,
        .beforeToday,
        .personalRecords,
        .monthlyRecap,
        .journeyLevel,
        .detailedAnalytics
    ]
}
