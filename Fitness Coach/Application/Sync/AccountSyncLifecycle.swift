//
//  AccountSyncLifecycle.swift
//  Fitness Coach
//
//  Forma — App lifecycle hooks for account data sync (Phase 3).
//

import Foundation

enum AccountSyncLifecycle {

    @MainActor
    static func scheduleAfterLocalMutation(
        coordinator: AccountSyncCoordinating,
        uidProvider: () -> String?
    ) {
        guard isSyncOrchestrationEnabled else { return }
        guard let uid = normalizedUID(from: uidProvider()) else { return }
        Task {
            _ = await coordinator.uploadPendingOnly(for: uid, reason: .afterLocalMutation)
        }
    }

    @MainActor
    static func handleAppForeground(
        coordinator: AccountSyncCoordinating,
        uidProvider: () -> String?
    ) {
        guard isSyncOrchestrationEnabled else { return }
        guard let uid = normalizedUID(from: uidProvider()) else { return }
        Task {
            _ = await coordinator.syncNow(for: uid, reason: .appForeground)
        }
    }

    @MainActor
    static func handleAfterSignIn(
        coordinator: AccountSyncCoordinating,
        uid: String
    ) {
        guard isSyncOrchestrationEnabled else { return }
        guard let normalizedUID = normalizedUID(from: uid) else { return }
        Task {
            _ = await coordinator.syncNow(for: normalizedUID, reason: .afterSignIn)
        }
    }

    @MainActor
    static func cancelOnAccountSwitch(coordinator: AccountSyncCoordinating) {
        coordinator.cancelPendingWork()
    }

    // MARK: - Helpers

    private static var isSyncOrchestrationEnabled: Bool {
        AccountPersistenceFeatureFlags.syncEngineEnabled
            && FormaAbTest.AccountPersistence.syncEngineEnabled
    }

    private static func normalizedUID(from raw: String?) -> String? {
        guard let raw else { return nil }
        return try? AccountSyncMutationValidation.normalizedOwnerUID(raw)
    }
}
