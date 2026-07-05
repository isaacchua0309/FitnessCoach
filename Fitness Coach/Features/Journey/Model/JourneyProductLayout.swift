//
//  JourneyProductLayout.swift
//  Fitness Coach
//
//  Forma — Canonical Journey product section order.
//

import Foundation

enum JourneyProductSection: String, CaseIterable, Equatable {
    case hero
    case nextAction
    case weeklyProgress
    case progress
    case highlights
    case storyTimeline
    case chapters
}

enum JourneyProductLayout {
    static let sectionOrder: [JourneyProductSection] = [
        .hero,
        .nextAction,
        .weeklyProgress,
        .progress,
        .highlights,
        .storyTimeline,
        .chapters
    ]
}
