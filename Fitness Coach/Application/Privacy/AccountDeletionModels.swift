//
//  AccountDeletionModels.swift
//  Fitness Coach
//
//  Forma — Account deletion state models (Phase 6).
//
//  Domain types for in-app account deletion and local data wipe. No coordinator wiring yet.
//

import Foundation

/// High-level deletion lifecycle status for UI, diagnostics, and coordinator state.
enum AccountDeletionStatus: String, Codable, Equatable, Sendable, CaseIterable {
    case notStarted
    case confirming
    case preparing
    case stoppingSync
    case deletingRemoteData
    case deletingAuthAccount
    case wipingLocalData
    case completed
    case cancelled
    case failed
    case partial
    case reauthenticationRequired
    case offline
}

extension AccountDeletionStatus {

    /// Whether deletion work has finished (success, partial, cancel, or terminal failure).
    var isTerminal: Bool {
        switch self {
        case .notStarted, .confirming, .preparing, .stoppingSync,
             .deletingRemoteData, .deletingAuthAccount, .wipingLocalData:
            return false
        case .completed, .cancelled, .failed, .partial,
             .reauthenticationRequired, .offline:
            return true
        }
    }

    /// Whether the user should see an in-progress deletion surface.
    var isInProgress: Bool {
        switch self {
        case .preparing, .stoppingSync, .deletingRemoteData,
             .deletingAuthAccount, .wipingLocalData:
            return true
        case .notStarted, .confirming, .completed, .cancelled, .failed,
             .partial, .reauthenticationRequired, .offline:
            return false
        }
    }

    /// Whether the user can retry after this terminal state.
    var allowsRetry: Bool {
        switch self {
        case .failed, .partial, .offline:
            return true
        case .reauthenticationRequired:
            return true
        case .notStarted, .confirming, .preparing, .stoppingSync,
             .deletingRemoteData, .deletingAuthAccount, .wipingLocalData,
             .completed, .cancelled:
            return false
        }
    }
}

/// What categories of data deletion the user requested.
enum AccountDeletionScope: String, Codable, Equatable, Sendable, CaseIterable {
    /// Remote app-held data, Firebase Auth account, then local wipe for the signed-in UID.
    case fullAccount
    /// Local SwiftData, caches, and UID-scoped preferences only — no remote or Auth deletion.
    case localDeviceOnly
    /// Remote Firestore data only — disabled by default pending explicit product approval.
    case remoteAccountDataOnly
}

extension AccountDeletionScope {

    var deletesRemoteAccountData: Bool {
        switch self {
        case .fullAccount, .remoteAccountDataOnly:
            return true
        case .localDeviceOnly:
            return false
        }
    }

    var deletesFirebaseAuthAccount: Bool {
        switch self {
        case .fullAccount:
            return true
        case .localDeviceOnly, .remoteAccountDataOnly:
            return false
        }
    }

    var wipesLocalAppData: Bool {
        switch self {
        case .fullAccount, .localDeviceOnly:
            return true
        case .remoteAccountDataOnly:
            return false
        }
    }
}

/// Stable failure taxonomy for analytics and user-facing recovery copy.
enum AccountDeletionFailureCategory: String, Codable, Equatable, Sendable, CaseIterable {
    case unauthenticated
    case reauthenticationRequired
    case offline
    case permissionDenied
    case remoteDataDeleteFailed
    case authDeleteFailed
    case localWipeFailed
    case accountSwitched
    case unknown
}

/// Outcome snapshot for a single deletion attempt.
struct AccountDeletionSummary: Equatable, Sendable {
    let uid: String
    let scope: AccountDeletionScope
    let status: AccountDeletionStatus
    let startedAt: Date
    let endedAt: Date?
    let remoteProfileDeleted: Bool
    let remoteDailyLogsDeleted: Int
    let remoteFoodEntriesDeleted: Int
    let remoteWaterEntriesDeleted: Int
    let remoteWeightEntriesDeleted: Int
    let remoteDailyReviewsDeleted: Int
    let remoteHealthSummariesDeleted: Bool
    let authAccountDeleted: Bool
    let localProfileDeleted: Bool
    let localDailyLogsDeleted: Int
    let localFoodEntriesDeleted: Int
    let localWaterEntriesDeleted: Int
    let localWeightEntriesDeleted: Int
    let localDailyReviewsDeleted: Int
    let localCoachMessagesDeleted: Int
    let localTimelineEventsDeleted: Int
    let localHealthCacheDeleted: Bool
    let localPreferencesDeleted: Bool
    let pendingMutationsDeleted: Int
    let failureCategory: AccountDeletionFailureCategory?
    let userFacingMessage: String?
}

extension AccountDeletionSummary {

    var duration: TimeInterval? {
        guard let endedAt else { return nil }
        return endedAt.timeIntervalSince(startedAt)
    }

    var totalRemoteEntitiesDeleted: Int {
        remoteDailyLogsDeleted
            + remoteFoodEntriesDeleted
            + remoteWaterEntriesDeleted
            + remoteWeightEntriesDeleted
            + remoteDailyReviewsDeleted
    }

    var totalLocalEntitiesDeleted: Int {
        localDailyLogsDeleted
            + localFoodEntriesDeleted
            + localWaterEntriesDeleted
            + localWeightEntriesDeleted
            + localDailyReviewsDeleted
            + localCoachMessagesDeleted
            + localTimelineEventsDeleted
    }

    var didDeleteAnyRemoteData: Bool {
        remoteProfileDeleted
            || remoteHealthSummariesDeleted
            || totalRemoteEntitiesDeleted > 0
    }

    var didDeleteAnyLocalData: Bool {
        localProfileDeleted
            || localHealthCacheDeleted
            || localPreferencesDeleted
            || pendingMutationsDeleted > 0
            || totalLocalEntitiesDeleted > 0
    }

    var isSuccessful: Bool {
        status == .completed
    }
}
