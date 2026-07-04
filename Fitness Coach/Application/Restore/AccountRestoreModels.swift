//
//  AccountRestoreModels.swift
//  Fitness Coach
//
//  Forma — Account restore state models (Phase 4).
//
//  Domain types for fresh-install / bootstrap restore. No coordinator wiring yet.
//

import Foundation

/// High-level restore lifecycle status for UI and diagnostics.
enum AccountRestoreStatus: String, Codable, Equatable, Sendable, CaseIterable {
    case notStarted
    case checking
    case restoringProfile
    case restoringRecentData
    case restoringWeightHistory
    case rebuildingLocalViews
    case completed
    case partial
    case offline
    case failed
    case skipped
}

extension AccountRestoreStatus {

    /// Whether restore work has finished (success, partial, skip, or terminal failure).
    var isTerminal: Bool {
        switch self {
        case .notStarted, .checking, .restoringProfile, .restoringRecentData,
             .restoringWeightHistory, .rebuildingLocalViews:
            return false
        case .completed, .partial, .offline, .failed, .skipped:
            return true
        }
    }

    /// Whether the user should see an in-progress restore surface.
    var isInProgress: Bool {
        switch self {
        case .checking, .restoringProfile, .restoringRecentData,
             .restoringWeightHistory, .rebuildingLocalViews:
            return true
        case .notStarted, .completed, .partial, .offline, .failed, .skipped:
            return false
        }
    }
}

/// Why a restore run was started.
enum AccountRestoreReason: String, Codable, Equatable, Sendable, CaseIterable {
    case freshInstall
    case newDevice
    case sameDeviceReinstall
    case accountSwitch
    case appLaunch
    case manualRetry
    case afterSignIn
}

/// How aggressively restore should block the main shell.
enum AccountRestoreMode: String, Codable, Equatable, Sendable, CaseIterable {
    /// Short, user-facing restore before Today / Journey are shown.
    case blockingInitial
    /// Longer history pull after the user can use the app.
    case backgroundBackfill
    /// User-initiated retry from restore UI or settings.
    case manualRetry
}

/// Outcome snapshot for a single restore attempt.
struct AccountRestoreSummary: Equatable, Sendable {
    let uid: String
    let reason: AccountRestoreReason
    let mode: AccountRestoreMode
    let status: AccountRestoreStatus
    let startedAt: Date
    let endedAt: Date?
    let profileRestored: Bool
    let dailyLogsRestored: Int
    let foodEntriesRestored: Int
    let waterEntriesRestored: Int
    let weightEntriesRestored: Int
    let dailyReviewsRestored: Int
    let skippedLocalNewer: Int
    let conflicts: Int
    let failed: Int
    let isPartial: Bool
    let userFacingMessage: String?
}

extension AccountRestoreSummary {

    /// Total nutrition rows written or updated during restore (excluding profile).
    var totalEntitiesRestored: Int {
        dailyLogsRestored
            + foodEntriesRestored
            + waterEntriesRestored
            + weightEntriesRestored
            + dailyReviewsRestored
    }

    var duration: TimeInterval? {
        guard let endedAt else { return nil }
        return endedAt.timeIntervalSince(startedAt)
    }
}
