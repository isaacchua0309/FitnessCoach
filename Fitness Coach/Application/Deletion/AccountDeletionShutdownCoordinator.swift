//
//  AccountDeletionShutdownCoordinator.swift
//  Fitness Coach
//
//  Forma — Stops sync, restore, and realtime listeners before destructive deletion (Phase 6).
//

import Foundation

protocol AccountDeletionShutdownCoordinating: AnyObject {
    func prepareForDeletion(uid: String) async
    func completeDeletion(uid: String)
    func abortDeletion(uid: String)
    func isDeletionInProgress(for uid: String) -> Bool
}

@MainActor
final class AccountDeletionShutdownCoordinator: AccountDeletionShutdownCoordinating {

    private let deletionGuard: AccountDeletionGuarding
    private let realtimeListener: AccountRealtimeChangeListening
    private let crossDeviceCoordinator: CrossDeviceSyncCoordinating
    private let accountSyncCoordinator: AccountSyncCoordinating
    private let restoreCoordinator: AccountRestoreCoordinating

    init(
        deletionGuard: AccountDeletionGuarding,
        realtimeListener: AccountRealtimeChangeListening,
        crossDeviceCoordinator: CrossDeviceSyncCoordinating,
        accountSyncCoordinator: AccountSyncCoordinating,
        restoreCoordinator: AccountRestoreCoordinating
    ) {
        self.deletionGuard = deletionGuard
        self.realtimeListener = realtimeListener
        self.crossDeviceCoordinator = crossDeviceCoordinator
        self.accountSyncCoordinator = accountSyncCoordinator
        self.restoreCoordinator = restoreCoordinator
    }

    func prepareForDeletion(uid: String) async {
        guard let normalizedUID = normalizedUID(uid) else { return }

        deletionGuard.beginDeletion(for: normalizedUID)
        await realtimeListener.stopListening(uid: normalizedUID)
        await crossDeviceCoordinator.cancelAllWork(for: normalizedUID)
        await accountSyncCoordinator.cancelAllWork(for: normalizedUID)
        restoreCoordinator.cancelAllWork(for: normalizedUID)
    }

    func completeDeletion(uid: String) {
        deletionGuard.endDeletion(for: uid)
    }

    func abortDeletion(uid: String) {
        guard let normalizedUID = normalizedUID(uid) else { return }
        deletionGuard.endDeletion(for: normalizedUID)
        accountSyncCoordinator.reinstateWork(for: normalizedUID)
        crossDeviceCoordinator.reinstateWork(for: normalizedUID)
    }

    func isDeletionInProgress(for uid: String) -> Bool {
        deletionGuard.isDeletionInProgress(for: uid)
    }

    private func normalizedUID(_ uid: String) -> String? {
        try? AccountSyncMutationValidation.normalizedOwnerUID(uid)
    }
}
