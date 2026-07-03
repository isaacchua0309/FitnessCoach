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

    init(syncService: HealthSyncService) {
        self.syncService = syncService
    }

    func refreshState() async {
        state = await syncService.getCurrentSyncState()
    }

    func syncInitialHealthData() {
        runDetached { await self.syncService.syncInitialHealthData() }
    }

    func syncToday() {
        runDetached { await self.syncService.syncToday() }
    }

    func syncLastNDays(_ days: Int) {
        runDetached { await self.syncService.syncLastNDays(days) }
    }

    func refreshOnAppForeground() {
        runDetached { await self.syncService.refreshOnAppForeground() }
    }

    func refreshOnDayChange() {
        runDetached { await self.syncService.syncToday() }
    }

    // MARK: - Private

    private func runDetached(_ operation: @escaping @Sendable () async -> HealthSyncState) {
        Task {
            let updated = await operation()
            state = updated
        }
    }
}
