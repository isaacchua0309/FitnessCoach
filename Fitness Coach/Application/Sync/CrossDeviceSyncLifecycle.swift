//
//  CrossDeviceSyncLifecycle.swift
//  Fitness Coach
//
//  Forma — App lifecycle hooks for Phase 5 cross-device sync.
//

import Foundation

enum CrossDeviceSyncLifecycle {

    @MainActor
    static func handleAppForeground(
        coordinator: CrossDeviceSyncCoordinating,
        uidProvider: () -> String?
    ) {
        guard isForegroundRefreshEnabled else { return }
        guard let uid = normalizedUID(from: uidProvider()) else { return }
        Task {
            _ = await coordinator.foregroundRefreshIfNeeded(uid: uid)
        }
    }

    @MainActor
    static func handleManualRefresh(
        coordinator: CrossDeviceSyncCoordinating,
        uid: String
    ) async -> CrossDeviceSyncSummary? {
        guard isManualRefreshEnabled else { return nil }
        guard let normalizedUID = normalizedUID(from: uid) else { return nil }
        return await coordinator.manualRefresh(uid: normalizedUID)
    }

    @MainActor
    static func startRealtimeListenerIfEnabled(
        listener: AccountRealtimeChangeListening,
        uid: String
    ) {
        AccountRealtimeChangeListenerLifecycle.startIfEnabled(listener: listener, uid: uid)
    }

    @MainActor
    static func stopRealtimeListener(listener: AccountRealtimeChangeListening) async {
        await listener.stopAll()
    }

    @MainActor
    static func cancelOnAccountSwitch(
        crossDeviceCoordinator: CrossDeviceSyncCoordinator,
        realtimeListener: AccountRealtimeChangeListening
    ) {
        crossDeviceCoordinator.cancelPendingWork()
        AccountRealtimeChangeListenerLifecycle.stopOnAccountSwitch(listener: realtimeListener)
    }

    // MARK: - Policy

    static var isOrchestrationEnabled: Bool {
        AccountPersistenceFeatureFlags.syncEngineEnabled
            && FormaAbTest.AccountPersistence.syncEngineEnabled
    }

    static var isForegroundRefreshEnabled: Bool {
        isOrchestrationEnabled
            && AccountPersistenceFeatureFlags.foregroundCrossDeviceRefreshEnabled
            && FormaAbTest.AccountPersistence.foregroundCrossDeviceRefreshEnabled
    }

    static var isManualRefreshEnabled: Bool {
        isOrchestrationEnabled
            && AccountPersistenceFeatureFlags.manualRefreshEnabled
            && FormaAbTest.AccountPersistence.manualRefreshEnabled
    }

    private static func normalizedUID(from raw: String?) -> String? {
        guard let raw else { return nil }
        return try? AccountSyncMutationValidation.normalizedOwnerUID(raw)
    }
}
