//
//  JourneyUnlockPresentationModels.swift
//  Fitness Coach
//
//  Forma — Positive unlock / locked-state presentation for the Journey tab.
//

import Foundation

// MARK: - Checklist

enum JourneyUnlockChecklistItemStatus: Equatable, Sendable {
    case completed
    case inProgress(current: Int, total: Int)
    case pending
}

struct JourneyUnlockChecklistItem: Equatable, Identifiable, Sendable {
    let id: String
    let title: String
    let status: JourneyUnlockChecklistItemStatus
    let accessibilityLabel: String

    var isCompleted: Bool {
        if case .completed = status { return true }
        return false
    }
}

struct JourneyUnlockChecklistState: Equatable, Sendable {
    let title: String
    let items: [JourneyUnlockChecklistItem]
    let completedCount: Int
    let totalCount: Int
    let accessibilityLabel: String

    var progressFraction: Double {
        guard totalCount > 0 else { return 0 }
        return Double(completedCount) / Double(totalCount)
    }
}

// MARK: - Next action card

struct JourneyNextActionCardState: Equatable, Sendable {
    let sectionTitle: String
    let title: String
    let progressLabel: String
    let detail: String
    let cta: WeeklyProgressCTA?
    let accessibilityLabel: String
}

// MARK: - Dashboard unlock bundle

struct JourneyUnlockDashboardState: Equatable, Sendable {
    /// When true, Journey shows a single prominent next-action card near the top.
    var showsProminentNextActionCard: Bool
    var nextActionCard: JourneyNextActionCardState?
    var checklist: JourneyUnlockChecklistState?
    /// When true, milestone section is hidden to avoid duplicating next-action messaging.
    var suppressesMilestonesSection: Bool
}

// MARK: - Compact locked insight

struct JourneyInsightLockedState: Equatable, Sendable {
    let headline: String
    let detail: String?
    let progressLabel: String?
    let isCompact: Bool
    let accessibilityLabel: String
}
