//
//  JourneyDashboardSectionTypes.swift
//  Fitness Coach
//
//  Forma — Presentation models for the consolidated Journey dashboard IA.
//

import Foundation

// MARK: - Hero

struct JourneyDashboardHeroStat: Equatable, Identifiable, Sendable {
    let id: String
    let label: String
}

struct JourneyDashboardHeroState: Equatable, Sendable {
    var weekLabel: String
    var chapterTitle: String
    var encouragingSentence: String
    var compactStats: [JourneyDashboardHeroStat]
    var accessibilitySummary: String

    var isVisible: Bool { !weekLabel.isEmpty }
}

// MARK: - Progress

enum JourneyProgressRowStatus: Equatable, Sendable {
    case notStarted
    case building
    case limited
    case ready
}

struct JourneyProgressRowState: Equatable, Identifiable, Sendable {
    let id: String
    let title: String
    let value: String
    let status: JourneyProgressRowStatus
    let accessibilityLabel: String
}

struct JourneyProgressSectionState: Equatable, Sendable {
    var sectionTitle: String
    var rows: [JourneyProgressRowState]
    var connectHealthCTA: JourneyHealthConnectCTAState?
    var accessibilitySummary: String

    var isVisible: Bool {
        !rows.isEmpty || connectHealthCTA != nil
    }
}
