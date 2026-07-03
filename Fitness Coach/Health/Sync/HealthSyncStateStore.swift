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
    private let remoteSummarySyncService: (any HealthSummarySyncServing)?
    private var snapshotService: (any HealthIntelligenceSnapshotServing)?
    private let syncEnabled: Bool
    private let remoteSummarySyncEnabled: @Sendable () -> Bool
    private var activeSyncTask: Task<Void, Never>?
    private var activeRemoteSyncTask: Task<Void, Never>?
    private var remoteSyncDebounceTask: Task<Void, Never>?
    private var pendingRemoteSyncDays: Int?
    private var hasBootstrappedForeground = false

    /// Debounce window for coalescing rapid local-sync → remote-sync schedules.
    private let remoteSyncDebounceNanoseconds: UInt64 = 750_000_000

    init(
        syncService: HealthSyncService,
        remoteSummarySyncService: (any HealthSummarySyncServing)? = nil,
        snapshotService: (any HealthIntelligenceSnapshotServing)? = nil,
        syncEnabled: Bool = HealthIntelligenceFeatureFlags.isSyncEnabled,
        remoteSummarySyncEnabled: @escaping @Sendable () -> Bool = {
            HealthIntelligenceFeatureFlags.healthSummaryRemoteSyncEnabled
        }
    ) {
        self.syncService = syncService
        self.remoteSummarySyncService = remoteSummarySyncService
        self.snapshotService = snapshotService
        self.syncEnabled = syncEnabled
        self.remoteSummarySyncEnabled = remoteSummarySyncEnabled
    }

    func setSnapshotService(_ service: any HealthIntelligenceSnapshotServing) {
        snapshotService = service
    }

    deinit {
        activeSyncTask?.cancel()
        activeRemoteSyncTask?.cancel()
        remoteSyncDebounceTask?.cancel()
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
        guard hasBootstrappedForeground else {
            hasBootstrappedForeground = true
            return
        }
        runDetached { await self.syncService.refreshOnAppForeground() }
    }

    func markForegroundBootstrapComplete() {
        hasBootstrappedForeground = true
    }

    func refreshOnDayChange() {
        guard syncEnabled else { return }
        runDetached { await self.syncService.syncToday() }
    }

    func cancelActiveSync() {
        HealthSyncLogger.warn("Sync state store cancelling active sync")
        activeSyncTask?.cancel()
        activeSyncTask = nil
        cancelRemoteSyncWork()
    }

    func cancelRemoteSyncWork() {
        activeRemoteSyncTask?.cancel()
        activeRemoteSyncTask = nil
        remoteSyncDebounceTask?.cancel()
        remoteSyncDebounceTask = nil
        pendingRemoteSyncDays = nil
    }

    // MARK: - Private

    private func runDetached(_ operation: @escaping @Sendable () async -> HealthSyncState) {
        activeSyncTask?.cancel()
        HealthSyncLogger.event("Sync state store task started")
        activeSyncTask = Task { [weak self] in
            guard let self else { return }
            let updated = await operation()
            guard !Task.isCancelled else {
                HealthSyncLogger.warn("Sync state store task cancelled")
                return
            }
            self.state = updated
            await self.invalidateSnapshotsIfNeeded(after: updated)
            self.scheduleRemoteSummarySync(after: updated)
            HealthSyncLogger.event(
                "Sync state store task finished",
                fields: ["phase": updated.phase.rawValue]
            )
        }
    }

    private func invalidateSnapshotsIfNeeded(after localState: HealthSyncState) async {
        guard let snapshotService else { return }
        guard localState.phase == .succeeded || localState.phase == .partialSuccess else { return }

        let days = max(localState.progress.daysRequested, 1)
        let calendar = Calendar.current
        let endDay = calendar.startOfDay(for: Date())
        guard let startDay = calendar.date(byAdding: .day, value: -(days - 1), to: endDay) else {
            HealthSyncLogger.event(
                "Invalidating intelligence snapshots",
                fields: ["dayCount": "1"]
            )
            await snapshotService.invalidateSnapshots(from: endDay, through: endDay, calendar: calendar)
            return
        }

        HealthSyncLogger.event(
            "Invalidating intelligence snapshots",
            fields: ["dayCount": String(days)]
        )

        await snapshotService.invalidateSnapshots(
            from: calendar.startOfDay(for: startDay),
            through: endDay,
            calendar: calendar
        )
    }

    private func scheduleRemoteSummarySync(after localState: HealthSyncState) {
        guard remoteSummarySyncEnabled(), let remoteSummarySyncService else { return }
        guard localState.phase == .succeeded || localState.phase == .partialSuccess else { return }

        let days = max(localState.progress.daysRequested, 1)
        pendingRemoteSyncDays = max(pendingRemoteSyncDays ?? 0, days)

        HealthSummarySyncDebugLogger.localRefreshCompleted(
            phase: localState.phase.rawValue,
            trigger: localState.trigger?.rawValue ?? "none",
            daysRequested: localState.progress.daysRequested,
            daysCompleted: localState.progress.daysCompleted
        )

        remoteSyncDebounceTask?.cancel()
        remoteSyncDebounceTask = Task { [weak self] in
            try? await Task.sleep(nanoseconds: self?.remoteSyncDebounceNanoseconds ?? 750_000_000)
            guard !Task.isCancelled, let self else { return }
            await self.flushPendingRemoteSync(using: remoteSummarySyncService)
        }
    }

    private func flushPendingRemoteSync(using remoteSummarySyncService: any HealthSummarySyncServing) async {
        guard let days = pendingRemoteSyncDays else { return }
        pendingRemoteSyncDays = nil

        HealthSyncLogger.event(
            "Remote summary sync flush started",
            fields: ["days": String(days)]
        )

        activeRemoteSyncTask?.cancel()
        activeRemoteSyncTask = Task {
            await remoteSummarySyncService.syncAfterLocalHealthRefresh(days: days)
        }
        await activeRemoteSyncTask?.value
        activeRemoteSyncTask = nil
    }
}
