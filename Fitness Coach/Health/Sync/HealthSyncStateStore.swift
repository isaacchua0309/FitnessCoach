//
//  HealthSyncStateStore.swift
//  Fitness Coach
//
//  Forma — MainActor bridge that publishes HealthSyncService state to SwiftUI.
//

import Combine
import Foundation

@MainActor
final class HealthSyncStateStore: ObservableObject {

    @Published private(set) var state: HealthSyncState = .idle

    private let syncService: HealthSyncService
    private let syncEnabled: Bool
    private var activeSyncTask: Task<Void, Never>?

    init(
        syncService: HealthSyncService,
        syncEnabled: Bool = HealthIntelligenceFeatureFlags.isSyncEnabled
    ) {
        self.syncService = syncService
        self.syncEnabled = syncEnabled
    }

    deinit {
        activeSyncTask?.cancel()
    }

    func refreshState() async {
        guard syncEnabled else {
            state = .idle
            return
        }
        state = await syncService.getCurrentSyncState()
    }

    func syncInitialHealthData() {
        guard syncEnabled else { return }
        runDetached { await self.syncService.syncInitialHealthData() }
    }

    func syncToday() {
        guard syncEnabled else { return }
        runDetached { await self.syncService.syncToday() }
    }

    func syncLastNDays(_ days: Int) {
        guard syncEnabled else { return }
        runDetached { await self.syncService.syncLastNDays(days) }
    }

    func refreshOnAppForeground() {
        guard syncEnabled else { return }
        runDetached { await self.syncService.refreshOnAppForeground() }
    }

    func refreshOnDayChange() {
        guard syncEnabled else { return }
        runDetached { await self.syncService.syncToday() }
    }

    func cancelActiveSync() {
        activeSyncTask?.cancel()
        activeSyncTask = nil
    }

    // MARK: - Private

    private func runDetached(_ operation: @escaping @Sendable () async -> HealthSyncState) {
        activeSyncTask?.cancel()
        activeSyncTask = Task { [weak self] in
            guard let self else { return }
            let updated = await operation()
            guard !Task.isCancelled else { return }
            self.state = updated
        }
    }
}
