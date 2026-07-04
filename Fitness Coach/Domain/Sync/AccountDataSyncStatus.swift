//
//  AccountDataSyncStatus.swift
//  Fitness Coach
//
//  Forma — Local sync state for account-backed nutrition log entities (Phase 3).
//

import Foundation

enum AccountDataSyncStatus: String, Codable, CaseIterable, Sendable {
    case localOnly
    case pendingUpload
    case synced
    case pendingDelete
    case failed
    case conflict
}

extension AccountDataSyncStatus {

    /// Whether the row still needs a cloud push or delete attempt.
    var needsSyncWork: Bool {
        switch self {
        case .pendingUpload, .pendingDelete, .failed, .conflict:
            return true
        case .localOnly, .synced:
            return false
        }
    }
}
