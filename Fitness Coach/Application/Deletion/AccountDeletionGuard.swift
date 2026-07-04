//
//  AccountDeletionGuard.swift
//  Fitness Coach
//
//  Forma — Blocks sync, restore, and realtime hints while account deletion runs (Phase 6).
//

import Foundation

protocol AccountDeletionGuarding: AnyObject {
    func beginDeletion(for uid: String)
    func endDeletion(for uid: String)
    func isDeletionInProgress(for uid: String) -> Bool
}

enum AccountDeletionGuardSupport {

    static let deletionInProgressMessage = "Account deletion is in progress."
}

@MainActor
final class AccountDeletionGuard: AccountDeletionGuarding {

    private var deletingUIDs = Set<String>()

    func beginDeletion(for uid: String) {
        guard let normalizedUID = normalizedUID(uid) else { return }
        deletingUIDs.insert(normalizedUID)
    }

    func endDeletion(for uid: String) {
        guard let normalizedUID = normalizedUID(uid) else { return }
        deletingUIDs.remove(normalizedUID)
    }

    func isDeletionInProgress(for uid: String) -> Bool {
        guard let normalizedUID = normalizedUID(uid) else { return false }
        return deletingUIDs.contains(normalizedUID)
    }

    private func normalizedUID(_ uid: String) -> String? {
        try? AccountSyncMutationValidation.normalizedOwnerUID(uid)
    }
}
