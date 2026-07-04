//
//  CrossDeviceSyncCoordinator.swift
//  Fitness Coach
//
//  Forma — Upload-then-pull cross-device sync orchestration (Phase 5).
//

import Foundation

protocol CrossDeviceSyncCoordinating: AnyObject {
    func refreshNow(
        uid: String,
        mode: CrossDeviceSyncMode,
        reason: CrossDeviceSyncReason
    ) async -> CrossDeviceSyncSummary

    func foregroundRefreshIfNeeded(uid: String) async -> CrossDeviceSyncSummary?

    func manualRefresh(uid: String) async -> CrossDeviceSyncSummary

    func handleRealtimeHint(uid: String) async -> CrossDeviceSyncSummary?
}

enum CrossDeviceSyncCoordinatorSupport {

    static let syncDisabledMessage = "Cross-device sync is not enabled for this build."
    static let offlineMessage = "You're offline. Your data is saved on this device."
    static let syncAlreadyInProgressMessage = "Cross-device sync is already in progress."
    static let uidChangedMessage = "Account changed before sync could finish."

    static func accountSyncReason(for reason: CrossDeviceSyncReason) -> AccountSyncReason {
        switch reason {
        case .appForeground:
            return .appForeground
        case .manualPullToRefresh:
            return .manual
        case .realtimeSnapshot:
            return .manual
        case .afterLocalMutation:
            return .afterLocalMutation
        case .afterRestore, .accountSwitch:
            return .afterSignIn
        case .retry:
            return .retry
        }
    }

    static func shouldRefreshUI(
        uploadedMutations: Int,
        pullSummary: CrossDeviceSyncSummary
    ) -> Bool {
        if uploadedMutations > 0 {
            return true
        }
        if pullSummary.pulledProfile {
            return true
        }
        return pullSummary.inserted + pullSummary.updated + pullSummary.deleted > 0
    }
}

@MainActor
final class CrossDeviceSyncCoordinator: CrossDeviceSyncCoordinating {

    private let syncCoordinator: AccountSyncCoordinating
    private let incrementalPuller: AccountIncrementalPulling
    private let cursorStore: any AccountSyncCursorStoring
    private let networkChecker: any AccountSyncNetworkChecking
    private let uidProvider: any AccountUIDProviding
    private let refreshCenter: AppRefreshCenter
    private let nowProvider: () -> Date
    private let runGuard = CrossDeviceSyncRunGuard()
    private var debouncedRealtimeTask: Task<Void, Never>?
    private var debouncedRealtimeUID: String?

    init(
        syncCoordinator: AccountSyncCoordinating,
        incrementalPuller: AccountIncrementalPulling,
        cursorStore: any AccountSyncCursorStoring,
        networkChecker: any AccountSyncNetworkChecking = AlwaysAvailableAccountSyncNetworkChecker(),
        uidProvider: any AccountUIDProviding,
        refreshCenter: AppRefreshCenter,
        nowProvider: @escaping () -> Date = Date.init
    ) {
        self.syncCoordinator = syncCoordinator
        self.incrementalPuller = incrementalPuller
        self.cursorStore = cursorStore
        self.networkChecker = networkChecker
        self.uidProvider = uidProvider
        self.refreshCenter = refreshCenter
        self.nowProvider = nowProvider
    }

    convenience init(
        syncCoordinator: AccountSyncCoordinating,
        incrementalPuller: AccountIncrementalPulling,
        cursorStore: any AccountSyncCursorStoring,
        networkChecker: any AccountSyncNetworkChecking = AlwaysAvailableAccountSyncNetworkChecker(),
        currentUIDProvider: @escaping () -> String?,
        refreshCenter: AppRefreshCenter,
        nowProvider: @escaping () -> Date = Date.init
    ) {
        self.init(
            syncCoordinator: syncCoordinator,
            incrementalPuller: incrementalPuller,
            cursorStore: cursorStore,
            networkChecker: networkChecker,
            uidProvider: ClosureAccountUIDProvider(currentUIDProvider),
            refreshCenter: refreshCenter,
            nowProvider: nowProvider
        )
    }

    func refreshNow(
        uid: String,
        mode: CrossDeviceSyncMode,
        reason: CrossDeviceSyncReason
    ) async -> CrossDeviceSyncSummary {
        let traceId = UUID().uuidString
        let startedAt = nowProvider()

        guard AccountPersistenceFeatureFlags.syncEngineEnabled else {
            return recordAndReturn(
                traceId: traceId,
                summary: disabledSummary(
                    uid: uid,
                    mode: mode,
                    reason: reason,
                    startedAt: startedAt
                )
            )
        }

        let normalizedUID: String
        do {
            normalizedUID = try AccountSyncMutationValidation.normalizedOwnerUID(uid)
        } catch {
            return recordAndReturn(
                traceId: traceId,
                summary: failedSummary(
                    uid: uid.trimmingCharacters(in: .whitespacesAndNewlines),
                    mode: mode,
                    reason: reason,
                    startedAt: startedAt,
                    message: "Cross-device sync could not start for this account."
                )
            )
        }

        AccountSyncLogger.crossDeviceSyncStarted(
            traceId: traceId,
            mode: mode,
            reason: reason,
            uid: normalizedUID
        )

        guard isUIDStillCurrent(normalizedUID) else {
            return recordAndReturn(
                traceId: traceId,
                summary: cancelledSummary(
                    uid: normalizedUID,
                    mode: mode,
                    reason: reason,
                    startedAt: startedAt,
                    message: CrossDeviceSyncCoordinatorSupport.uidChangedMessage
                )
            )
        }

        guard networkChecker.isNetworkAvailable else {
            return recordAndReturn(
                traceId: traceId,
                summary: offlineSummary(
                    uid: normalizedUID,
                    mode: mode,
                    reason: reason,
                    startedAt: startedAt
                )
            )
        }

        guard runGuard.tryBegin(uid: normalizedUID) else {
            return recordAndReturn(
                traceId: traceId,
                summary: cancelledSummary(
                    uid: normalizedUID,
                    mode: mode,
                    reason: reason,
                    startedAt: startedAt,
                    message: CrossDeviceSyncCoordinatorSupport.syncAlreadyInProgressMessage
                )
            )
        }

        defer {
            runGuard.end(uid: normalizedUID)
        }

        var uploadedMutations = 0
        var uploadFailed = 0

        if CrossDeviceSyncPolicy.shouldUploadBeforePull(for: mode) {
            guard isUIDStillCurrent(normalizedUID) else {
                return recordAndReturn(
                    traceId: traceId,
                    summary: cancelledSummary(
                        uid: normalizedUID,
                        mode: mode,
                        reason: reason,
                        startedAt: startedAt,
                        message: CrossDeviceSyncCoordinatorSupport.uidChangedMessage
                    )
                )
            }

            let uploadRun = await syncCoordinator.uploadPendingOnly(
                for: normalizedUID,
                reason: CrossDeviceSyncCoordinatorSupport.accountSyncReason(for: reason)
            )

            guard isUIDStillCurrent(normalizedUID) else {
                return recordAndReturn(
                    traceId: traceId,
                    summary: cancelledSummary(
                        uid: normalizedUID,
                        mode: mode,
                        reason: reason,
                        startedAt: startedAt,
                        message: CrossDeviceSyncCoordinatorSupport.uidChangedMessage
                    )
                )
            }

            uploadedMutations = uploadRun.uploadSummary?.succeeded ?? 0
            uploadFailed = uploadRun.uploadSummary?.failed ?? 0
        }

        guard isUIDStillCurrent(normalizedUID) else {
            return recordAndReturn(
                traceId: traceId,
                summary: cancelledSummary(
                    uid: normalizedUID,
                    mode: mode,
                    reason: reason,
                    startedAt: startedAt,
                    message: CrossDeviceSyncCoordinatorSupport.uidChangedMessage
                )
            )
        }

        let pullSummary = await incrementalPuller.pullChanges(
            for: normalizedUID,
            mode: mode,
            reason: reason
        )

        guard isUIDStillCurrent(normalizedUID) else {
            return recordAndReturn(
                traceId: traceId,
                summary: cancelledSummary(
                    uid: normalizedUID,
                    mode: mode,
                    reason: reason,
                    startedAt: startedAt,
                    message: CrossDeviceSyncCoordinatorSupport.uidChangedMessage
                )
            )
        }

        let shouldRefreshUI = CrossDeviceSyncCoordinatorSupport.shouldRefreshUI(
            uploadedMutations: uploadedMutations,
            pullSummary: pullSummary
        )
        if shouldRefreshUI {
            refreshCenter.notifyCrossDeviceSyncDidComplete()
        }

        let status = resolvedStatus(
            pullStatus: pullSummary.status,
            uploadFailed: uploadFailed
        )

        let summary = CrossDeviceSyncSummary(
            uid: normalizedUID,
            mode: mode,
            reason: reason,
            status: status,
            startedAt: startedAt,
            endedAt: nowProvider(),
            uploadedMutations: uploadedMutations,
            pulledDailyLogs: pullSummary.pulledDailyLogs,
            pulledFoodEntries: pullSummary.pulledFoodEntries,
            pulledWaterEntries: pullSummary.pulledWaterEntries,
            pulledWeightEntries: pullSummary.pulledWeightEntries,
            pulledDailyReviews: pullSummary.pulledDailyReviews,
            pulledProfile: pullSummary.pulledProfile,
            inserted: pullSummary.inserted,
            updated: pullSummary.updated,
            deleted: pullSummary.deleted,
            skippedLocalNewer: pullSummary.skippedLocalNewer,
            conflicts: pullSummary.conflicts,
            failed: pullSummary.failed + uploadFailed,
            didRefreshUI: shouldRefreshUI,
            userFacingMessage: pullSummary.userFacingMessage
        )

        return recordAndReturn(traceId: traceId, summary: summary)
    }

    func foregroundRefreshIfNeeded(uid: String) async -> CrossDeviceSyncSummary? {
        guard let normalizedUID = normalizedUID(uid) else { return nil }
        guard isUIDStillCurrent(normalizedUID) else { return nil }
        guard shouldRunForegroundRefresh(uid: normalizedUID) else { return nil }

        Task { [weak self] in
            _ = await self?.refreshNow(
                uid: normalizedUID,
                mode: .foregroundRefresh,
                reason: .appForeground
            )
        }
        return nil
    }

    func manualRefresh(uid: String) async -> CrossDeviceSyncSummary {
        let normalizedUID = normalizedUID(uid) ?? uid.trimmingCharacters(in: .whitespacesAndNewlines)
        return await refreshNow(
            uid: normalizedUID,
            mode: .manualRefresh,
            reason: .manualPullToRefresh
        )
    }

    func handleRealtimeHint(uid: String) async -> CrossDeviceSyncSummary? {
        guard let normalizedUID = normalizedUID(uid) else { return nil }
        guard isUIDStillCurrent(normalizedUID) else { return nil }

        debouncedRealtimeTask?.cancel()
        debouncedRealtimeUID = normalizedUID

        debouncedRealtimeTask = Task { [weak self] in
            try? await Task.sleep(for: CrossDeviceSyncPolicy.realtimeDebounceInterval())
            guard !Task.isCancelled else { return }
            guard let self else { return }
            guard self.debouncedRealtimeUID == normalizedUID else { return }
            guard self.isUIDStillCurrent(normalizedUID) else { return }
            _ = await self.refreshNow(
                uid: normalizedUID,
                mode: .realtimeListener,
                reason: .realtimeSnapshot
            )
        }
        return nil
    }

    func cancelPendingWork() {
        debouncedRealtimeTask?.cancel()
        debouncedRealtimeTask = nil
        debouncedRealtimeUID = nil
    }

    // MARK: - Helpers

    private func recordAndReturn(traceId: String, summary: CrossDeviceSyncSummary) -> CrossDeviceSyncSummary {
        AccountSyncLogger.crossDeviceSyncCompleted(traceId: traceId, summary: summary)
        return summary
    }

    private func normalizedUID(_ uid: String) -> String? {
        try? AccountSyncMutationValidation.normalizedOwnerUID(uid)
    }

    private func isUIDStillCurrent(_ uid: String) -> Bool {
        guard let currentUID = uidProvider.currentUID() else { return false }
        return (try? AccountSyncMutationValidation.normalizedOwnerUID(currentUID)) == uid
    }

    private func shouldRunForegroundRefresh(uid: String) -> Bool {
        let cursor = cursorStore.loadCursor(uid: uid)
        guard let lastForegroundRefreshAt = cursor.lastForegroundRefreshAt else { return true }
        let elapsed = nowProvider().timeIntervalSince(lastForegroundRefreshAt)
        return elapsed >= CrossDeviceSyncPolicy.foregroundRefreshThrottleInterval()
    }

    private func resolvedStatus(
        pullStatus: CrossDeviceSyncStatus,
        uploadFailed: Int
    ) -> CrossDeviceSyncStatus {
        if uploadFailed > 0 || pullStatus == .partial {
            return .partial
        }
        return pullStatus
    }

    private func emptySummary(
        uid: String,
        mode: CrossDeviceSyncMode,
        reason: CrossDeviceSyncReason,
        status: CrossDeviceSyncStatus,
        startedAt: Date,
        endedAt: Date,
        message: String?
    ) -> CrossDeviceSyncSummary {
        CrossDeviceSyncSummary(
            uid: uid,
            mode: mode,
            reason: reason,
            status: status,
            startedAt: startedAt,
            endedAt: endedAt,
            uploadedMutations: 0,
            pulledDailyLogs: 0,
            pulledFoodEntries: 0,
            pulledWaterEntries: 0,
            pulledWeightEntries: 0,
            pulledDailyReviews: 0,
            pulledProfile: false,
            inserted: 0,
            updated: 0,
            deleted: 0,
            skippedLocalNewer: 0,
            conflicts: 0,
            failed: 0,
            didRefreshUI: false,
            userFacingMessage: message
        )
    }

    private func offlineSummary(
        uid: String,
        mode: CrossDeviceSyncMode,
        reason: CrossDeviceSyncReason,
        startedAt: Date
    ) -> CrossDeviceSyncSummary {
        emptySummary(
            uid: uid,
            mode: mode,
            reason: reason,
            status: .offline,
            startedAt: startedAt,
            endedAt: nowProvider(),
            message: CrossDeviceSyncCoordinatorSupport.offlineMessage
        )
    }

    private func cancelledSummary(
        uid: String,
        mode: CrossDeviceSyncMode,
        reason: CrossDeviceSyncReason,
        startedAt: Date,
        message: String
    ) -> CrossDeviceSyncSummary {
        emptySummary(
            uid: uid,
            mode: mode,
            reason: reason,
            status: .cancelled,
            startedAt: startedAt,
            endedAt: nowProvider(),
            message: message
        )
    }

    private func disabledSummary(
        uid: String,
        mode: CrossDeviceSyncMode,
        reason: CrossDeviceSyncReason,
        startedAt: Date
    ) -> CrossDeviceSyncSummary {
        emptySummary(
            uid: uid,
            mode: mode,
            reason: reason,
            status: .cancelled,
            startedAt: startedAt,
            endedAt: nowProvider(),
            message: CrossDeviceSyncCoordinatorSupport.syncDisabledMessage
        )
    }

    private func failedSummary(
        uid: String,
        mode: CrossDeviceSyncMode,
        reason: CrossDeviceSyncReason,
        startedAt: Date,
        message: String
    ) -> CrossDeviceSyncSummary {
        CrossDeviceSyncSummary(
            uid: uid,
            mode: mode,
            reason: reason,
            status: .failed,
            startedAt: startedAt,
            endedAt: nowProvider(),
            uploadedMutations: 0,
            pulledDailyLogs: 0,
            pulledFoodEntries: 0,
            pulledWaterEntries: 0,
            pulledWeightEntries: 0,
            pulledDailyReviews: 0,
            pulledProfile: false,
            inserted: 0,
            updated: 0,
            deleted: 0,
            skippedLocalNewer: 0,
            conflicts: 0,
            failed: 1,
            didRefreshUI: false,
            userFacingMessage: message
        )
    }
}

// MARK: - Per-UID run guard

@MainActor
private final class CrossDeviceSyncRunGuard {

    private var activeUIDs = Set<String>()

    func tryBegin(uid: String) -> Bool {
        guard !activeUIDs.contains(uid) else { return false }
        activeUIDs.insert(uid)
        return true
    }

    func end(uid: String) {
        activeUIDs.remove(uid)
    }
}
