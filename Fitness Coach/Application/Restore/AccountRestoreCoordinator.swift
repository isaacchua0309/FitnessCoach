//
//  AccountRestoreCoordinator.swift
//  Fitness Coach
//
//  Forma — Single entry point for account restore decisions (Phase 4).
//

import Foundation

protocol AccountRestoreCoordinating: AnyObject {
    func prepareAccountAfterSignIn(uid: String, reason: AccountRestoreReason) async -> AccountRestoreSummary
    func prepareAccountOnAppLaunch(uid: String) async -> AccountRestoreSummary?
    func retryRestore(uid: String) async -> AccountRestoreSummary
    func runBackgroundBackfillIfNeeded(uid: String) async
}

enum AccountRestoreCoordinatorSupport {

    static let accountSwitchedMessage = "Account changed before restore could finish."
    static let restoreDisabledMessage = "Restore is not enabled for this build."
    static let concurrentRestoreMessage = "Restore is already in progress."
    static let permissionDeniedMessage = AccountInitialRestoreServiceSupport.permissionDeniedMessage

    static var isRestoreEnabled: Bool {
        AccountPersistenceFeatureFlags.restoreOnLoginEnabled
            && FormaAbTest.AccountPersistence.restoreOnLoginEnabled
    }
}

@MainActor
final class AccountRestoreCoordinator: AccountRestoreCoordinating {

    private let namespaceService: AccountDataNamespacePreparing
    private let migrationService: AccountMigrationRunning
    private let localInspector: AccountLocalDataInspecting
    private let remoteInspector: AccountRemoteDataInspecting
    private let initialRestoreService: AccountInitialRestoring
    private let stateStore: AccountRestoreStateStoring
    private let syncCoordinator: AccountSyncCoordinating?
    private let diagnostics: AccountRestoreDiagnostics?
    private let currentUIDProvider: () -> String?
    private let restoreEnabledProvider: () -> Bool
    private let dateProvider: DateProviding
    private let onBackgroundBackfillFinished: ((AccountRestoreSummary) -> Void)?
    private let runGuard = AccountRestoreRunGuard()
    private var backgroundBackfillTask: Task<Void, Never>?
    private var backgroundBackfillUID: String?
    private let backgroundBackfillGuard = AccountRestoreRunGuard()

    init(
        namespaceService: AccountDataNamespacePreparing,
        migrationService: AccountMigrationRunning,
        localInspector: AccountLocalDataInspecting,
        remoteInspector: AccountRemoteDataInspecting,
        initialRestoreService: AccountInitialRestoring,
        stateStore: AccountRestoreStateStoring,
        syncCoordinator: AccountSyncCoordinating? = nil,
        diagnostics: AccountRestoreDiagnostics? = nil,
        currentUIDProvider: @escaping () -> String?,
        restoreEnabledProvider: @escaping () -> Bool = { AccountRestoreCoordinatorSupport.isRestoreEnabled },
        dateProvider: DateProviding? = nil,
        onBackgroundBackfillFinished: ((AccountRestoreSummary) -> Void)? = nil
    ) {
        self.namespaceService = namespaceService
        self.migrationService = migrationService
        self.localInspector = localInspector
        self.remoteInspector = remoteInspector
        self.initialRestoreService = initialRestoreService
        self.stateStore = stateStore
        self.syncCoordinator = syncCoordinator
        self.diagnostics = diagnostics
        self.currentUIDProvider = currentUIDProvider
        self.restoreEnabledProvider = restoreEnabledProvider
        self.dateProvider = dateProvider ?? SystemDateProvider()
        self.onBackgroundBackfillFinished = onBackgroundBackfillFinished
    }

    func prepareAccountAfterSignIn(
        uid: String,
        reason: AccountRestoreReason
    ) async -> AccountRestoreSummary {
        await prepareAccount(uid: uid, reason: reason, forceBlocking: false)
    }

    func prepareAccountOnAppLaunch(uid: String) async -> AccountRestoreSummary? {
        guard restoreEnabledProvider() else { return nil }

        let normalizedUID: String
        do {
            normalizedUID = try AccountSyncMutationValidation.normalizedOwnerUID(uid)
        } catch {
            return nil
        }

        guard isUIDStillCurrent(normalizedUID) else { return nil }

        let localStatus: AccountLocalDataStatus
        do {
            localStatus = try await localInspector.inspectLocalData(for: normalizedUID)
        } catch {
            return nil
        }

        let storedState = stateStore.loadState(uid: normalizedUID)
        guard needsAppLaunchRestore(localStatus: localStatus, storedState: storedState) else {
            await runBackgroundBackfillIfNeeded(uid: normalizedUID)
            return nil
        }

        return await prepareAccount(uid: normalizedUID, reason: .appLaunch, forceBlocking: false)
    }

    func retryRestore(uid: String) async -> AccountRestoreSummary {
        guard let normalizedUID = normalizedUID(uid) else {
            return failedSummary(
                uid: uid.trimmingCharacters(in: .whitespacesAndNewlines),
                reason: .manualRetry,
                startedAt: dateProvider.now,
                message: "Restore could not start for this account."
            )
        }
        stateStore.prepareForManualRetry(uid: normalizedUID, now: dateProvider.now)
        return await prepareAccount(uid: normalizedUID, reason: .manualRetry, forceBlocking: true)
    }

    func runBackgroundBackfillIfNeeded(uid: String) async {
        guard restoreEnabledProvider() else { return }
        guard let normalizedUID = normalizedUID(uid) else { return }
        guard isUIDStillCurrent(normalizedUID) else { return }
        guard stateStore.shouldRunBackgroundBackfill(uid: normalizedUID, now: dateProvider.now) else { return }
        guard backgroundBackfillGuard.tryBegin(uid: normalizedUID) else { return }
        defer { backgroundBackfillGuard.end(uid: normalizedUID) }

        let traceId = UUID().uuidString
        AccountRestoreLogger.runStarted(
            traceId: traceId,
            reason: .appLaunch,
            mode: .backgroundBackfill,
            uid: normalizedUID
        )

        let summary = await initialRestoreService.runBackgroundBackfill(
            uid: normalizedUID,
            reason: .appLaunch
        )

        guard isUIDStillCurrent(normalizedUID) else { return }
        diagnostics?.recordRun(traceId: traceId, summary: summary)
        guard shouldNotifyAfterBackgroundBackfill(summary) else { return }
        onBackgroundBackfillFinished?(summary)
    }

    func cancelOnAccountSwitch() {
        backgroundBackfillUID = nil
        backgroundBackfillTask?.cancel()
        backgroundBackfillTask = nil
        backgroundBackfillGuard.cancel()
        runGuard.cancel()
    }

    // MARK: - Core flow

    private func prepareAccount(
        uid: String,
        reason: AccountRestoreReason,
        forceBlocking: Bool
    ) async -> AccountRestoreSummary {
        let startedAt = dateProvider.now
        let traceId = UUID().uuidString
        var lastErrorCategory: String?

        let normalizedUID: String
        do {
            normalizedUID = try AccountSyncMutationValidation.normalizedOwnerUID(uid)
        } catch {
            return failedSummary(
                uid: uid.trimmingCharacters(in: .whitespacesAndNewlines),
                reason: reason,
                startedAt: startedAt,
                message: "Restore could not start for this account."
            )
        }

        guard runGuard.tryBegin(uid: normalizedUID) else {
            return skippedSummary(
                uid: normalizedUID,
                reason: reason,
                startedAt: startedAt,
                message: AccountRestoreCoordinatorSupport.concurrentRestoreMessage
            )
        }
        defer { runGuard.end(uid: normalizedUID) }

        let coordinatorMode: AccountRestoreMode = forceBlocking ? .manualRetry : .blockingInitial
        AccountRestoreLogger.runStarted(
            traceId: traceId,
            reason: reason,
            mode: coordinatorMode,
            uid: normalizedUID
        )

        guard await namespaceService.prepareForSignedInUID(normalizedUID) else {
            return finishRun(
                traceId: traceId,
                summary: accountSwitchedSummary(uid: normalizedUID, reason: reason, startedAt: startedAt),
                errorCategory: lastErrorCategory
            )
        }

        do {
            try await migrationService.runSafeBackfill(for: normalizedUID)
        } catch {
            lastErrorCategory = AccountRestoreLogger.errorCategory(from: error)
            AccountRestoreLogger.error(
                "restore_migration_backfill_failed",
                fields: ["uid": normalizedUID],
                underlying: error
            )
        }

        guard isUIDStillCurrent(normalizedUID) else {
            return finishRun(
                traceId: traceId,
                summary: accountSwitchedSummary(uid: normalizedUID, reason: reason, startedAt: startedAt),
                errorCategory: lastErrorCategory
            )
        }

        guard restoreEnabledProvider() else {
            await uploadPendingIfNeeded(for: normalizedUID)
            return finishRun(
                traceId: traceId,
                summary: skippedSummary(
                    uid: normalizedUID,
                    reason: reason,
                    startedAt: startedAt,
                    message: AccountRestoreCoordinatorSupport.restoreDisabledMessage
                ),
                errorCategory: lastErrorCategory
            )
        }

        let localStatus: AccountLocalDataStatus
        do {
            localStatus = try await localInspector.inspectLocalData(for: normalizedUID)
        } catch {
            lastErrorCategory = AccountRestoreLogger.errorCategory(from: error)
            AccountRestoreLogger.error(
                "restore_local_inspection_failed",
                fields: ["uid": normalizedUID],
                underlying: error
            )
            let summary = failedSummary(
                uid: normalizedUID,
                reason: reason,
                startedAt: startedAt,
                message: "Restore could not inspect local account data."
            )
            return finishRun(traceId: traceId, summary: summary, errorCategory: lastErrorCategory)
        }

        guard isUIDStillCurrent(normalizedUID) else {
            return finishRun(
                traceId: traceId,
                summary: accountSwitchedSummary(uid: normalizedUID, reason: reason, startedAt: startedAt),
                errorCategory: lastErrorCategory
            )
        }

        let remoteStatus = await remoteInspector.inspectRemoteData(
            for: normalizedUID,
            today: dateProvider.now
        )

        guard isUIDStillCurrent(normalizedUID) else {
            return finishRun(
                traceId: traceId,
                summary: accountSwitchedSummary(uid: normalizedUID, reason: reason, startedAt: startedAt),
                errorCategory: lastErrorCategory
            )
        }

        if let failure = remoteStatus.failure,
           shouldFailFast(for: failure, localStatus: localStatus) {
            return finishRun(
                traceId: traceId,
                summary: finishPermissionFailure(
                    uid: normalizedUID,
                    reason: reason,
                    startedAt: startedAt,
                    failure: failure
                ),
                errorCategory: failure.analyticsCategory
            )
        }

        let shouldBlock = forceBlocking || shouldRunBlockingRestore(
            localStatus: localStatus,
            remoteStatus: remoteStatus,
            uid: normalizedUID
        )

        let summary: AccountRestoreSummary
        if shouldBlock {
            summary = await runBlockingRestoreWithTimeout(
                uid: normalizedUID,
                reason: reason
            )
        } else {
            await uploadPendingIfNeeded(for: normalizedUID)
            summary = skippedSummary(
                uid: normalizedUID,
                reason: reason,
                startedAt: startedAt,
                message: AccountInitialRestoreServiceSupport.skippedLocalDataMessage
            )
            stateStore.markSkipped(uid: normalizedUID, reason: reason, now: dateProvider.now)
        }

        guard isUIDStillCurrent(normalizedUID) else {
            return finishRun(
                traceId: traceId,
                summary: accountSwitchedSummary(uid: normalizedUID, reason: reason, startedAt: startedAt),
                errorCategory: lastErrorCategory
            )
        }

        if summary.allowsContinuedEntry {
            scheduleBackgroundBackfill(uid: normalizedUID)
        }
        return finishRun(traceId: traceId, summary: summary, errorCategory: lastErrorCategory)
    }

    private func finishRun(
        traceId: String,
        summary: AccountRestoreSummary,
        errorCategory: String? = nil
    ) -> AccountRestoreSummary {
        diagnostics?.recordRun(traceId: traceId, summary: summary, errorCategory: errorCategory)
        return summary
    }

    // MARK: - Blocking timeout

    private enum BlockingRestoreWaitResult {
        case finished(AccountRestoreSummary)
        case timedOut
    }

    private func runBlockingRestoreWithTimeout(
        uid: String,
        reason: AccountRestoreReason
    ) async -> AccountRestoreSummary {
        let startedAt = dateProvider.now
        let timeoutNanoseconds = UInt64(
            AccountRestorePolicy.preferredBlockingRestoreTimeoutSeconds * 1_000_000_000
        )

        let result = await withTaskGroup(of: BlockingRestoreWaitResult.self) { group in
            group.addTask { [initialRestoreService] in
                let summary = await initialRestoreService.runBlockingInitialRestore(
                    uid: uid,
                    reason: reason
                )
                return .finished(summary)
            }
            group.addTask {
                try? await Task.sleep(nanoseconds: timeoutNanoseconds)
                return .timedOut
            }

            let first = await group.next()
            group.cancelAll()
            return first
        }

        switch result {
        case .finished(let summary):
            return summary
        case .timedOut, .none:
            return await resolveTimedOutBlockingRestore(
                uid: uid,
                reason: reason,
                startedAt: startedAt
            )
        }
    }

    private func resolveTimedOutBlockingRestore(
        uid: String,
        reason: AccountRestoreReason,
        startedAt: Date
    ) async -> AccountRestoreSummary {
        let endedAt = dateProvider.now
        let localStatus: AccountLocalDataStatus
        do {
            localStatus = try await localInspector.inspectLocalData(for: uid)
        } catch {
            AccountRestoreLogger.error(
                "restore_timeout_local_inspection_failed",
                fields: ["uid": uid],
                underlying: error
            )
            return failedSummary(
                uid: uid,
                reason: reason,
                startedAt: startedAt,
                message: FormaProductCopy.AccountRestore.Failed.body
            )
        }

        let remoteStatus = await remoteInspector.inspectRemoteData(
            for: uid,
            today: endedAt
        )
        let summary = AccountRestoreOutcomeSupport.timedOutSummary(
            uid: uid,
            reason: reason,
            startedAt: startedAt,
            endedAt: endedAt,
            localStatus: localStatus,
            remoteFailure: remoteStatus.failure
        )

        switch summary.status {
        case .partial:
            stateStore.markPartial(uid: uid, summary: summary, now: endedAt)
            AccountRestoreLogger.warn("restore_timed_out_partial", fields: ["uid": uid])
        case .offline:
            stateStore.markOffline(uid: uid, reason: reason, now: endedAt)
            AccountRestoreLogger.warn("restore_timed_out_offline", fields: ["uid": uid])
        case .failed:
            stateStore.markFailed(
                uid: uid,
                reason: reason,
                message: summary.userFacingMessage ?? FormaProductCopy.AccountRestore.Failed.body,
                now: endedAt
            )
            AccountRestoreLogger.warn("restore_timed_out_failed", fields: ["uid": uid])
        default:
            break
        }

        return summary
    }

    // MARK: - Decision policy

    private func shouldRunBlockingRestore(
        localStatus: AccountLocalDataStatus,
        remoteStatus: AccountRemoteDataStatus,
        uid: String
    ) -> Bool {
        let now = dateProvider.now
        guard stateStore.shouldRunBlockingRestore(
            uid: uid,
            localDataStatus: localStatus,
            now: now
        ) else {
            return false
        }

        if localStatus.needsInitialRestore && remoteStatus.hasAnyRestorableData {
            return true
        }

        if localStatus.needsInitialRestore
            && !remoteStatus.hasAnyRestorableData
            && remoteStatus.failure == nil {
            return true
        }

        if localStatus.pendingMutationCount > 0 || localStatus.failedMutationCount > 0 {
            return localStatus.isEffectivelyEmpty
        }

        return localStatus.needsInitialRestore
    }

    private func shouldFailFast(
        for failure: AccountRemoteDataInspectionFailure,
        localStatus: AccountLocalDataStatus
    ) -> Bool {
        switch failure {
        case .permissionDenied, .unauthenticated:
            return true
        case .offline, .unavailable, .decodingFailed, .unknown:
            return false
        }
    }

    private func needsAppLaunchRestore(
        localStatus: AccountLocalDataStatus,
        storedState: AccountRestoreStoredState
    ) -> Bool {
        if storedState.status.isInProgress {
            return true
        }
        if stateStore.shouldRunBlockingRestore(
            uid: localStatus.uid,
            localDataStatus: localStatus,
            now: dateProvider.now
        ) {
            return true
        }
        if storedState.status == .offline || storedState.status == .failed {
            return localStatus.needsInitialRestore
        }
        return false
    }

    // MARK: - Terminal helpers

    private func finishPermissionFailure(
        uid: String,
        reason: AccountRestoreReason,
        startedAt: Date,
        failure: AccountRemoteDataInspectionFailure
    ) -> AccountRestoreSummary {
        let message: String
        switch failure {
        case .permissionDenied, .unauthenticated:
            message = AccountRestoreCoordinatorSupport.permissionDeniedMessage
        case .decodingFailed:
            message = AccountRestoreOutcomeSupport.safeFailureMessage(for: failure)
        case .offline, .unavailable:
            message = AccountInitialRestoreServiceSupport.offlineRestoreMessage
        case .unknown:
            message = FormaProductCopy.AccountRestore.Failed.body
        }

        let endedAt = dateProvider.now
        let summary = AccountRestoreSummary(
            uid: uid,
            reason: reason,
            mode: .blockingInitial,
            status: failure == .offline || failure == .unavailable ? .offline : .failed,
            startedAt: startedAt,
            endedAt: endedAt,
            profileRestored: false,
            dailyLogsRestored: 0,
            foodEntriesRestored: 0,
            waterEntriesRestored: 0,
            weightEntriesRestored: 0,
            dailyReviewsRestored: 0,
            skippedLocalNewer: 0,
            conflicts: 0,
            failed: 1,
            isPartial: false,
            userFacingMessage: message
        )

        if summary.status == .offline {
            stateStore.markOffline(uid: uid, reason: reason, now: endedAt)
        } else {
            stateStore.markFailed(uid: uid, reason: reason, message: message, now: endedAt)
        }
        return summary
    }

    private func uploadPendingIfNeeded(for uid: String) async {
        guard let syncCoordinator,
              AccountPersistenceFeatureFlags.uploadPendingMutationsEnabled else {
            return
        }
        _ = await syncCoordinator.uploadPendingOnly(for: uid, reason: .afterSignIn)
    }

    private func scheduleBackgroundBackfill(uid: String) {
        backgroundBackfillTask?.cancel()
        backgroundBackfillUID = uid
        let scheduledUID = uid
        backgroundBackfillTask = Task { [weak self] in
            guard let self else { return }
            await self.runBackgroundBackfillIfNeeded(uid: scheduledUID)
            if self.backgroundBackfillUID == scheduledUID {
                self.backgroundBackfillUID = nil
            }
        }
    }

    private func shouldNotifyAfterBackgroundBackfill(_ summary: AccountRestoreSummary) -> Bool {
        guard summary.mode == .backgroundBackfill else { return false }
        switch summary.status {
        case .completed, .partial:
            return true
        case .skipped, .failed, .offline, .notStarted, .checking,
             .restoringProfile, .restoringRecentData, .restoringWeightHistory,
             .rebuildingLocalViews:
            return false
        }
    }

    private func accountSwitchedSummary(
        uid: String,
        reason: AccountRestoreReason,
        startedAt: Date
    ) -> AccountRestoreSummary {
        skippedSummary(
            uid: uid,
            reason: reason,
            startedAt: startedAt,
            message: AccountRestoreCoordinatorSupport.accountSwitchedMessage
        )
    }

    private func skippedSummary(
        uid: String,
        reason: AccountRestoreReason,
        startedAt: Date,
        message: String
    ) -> AccountRestoreSummary {
        AccountRestoreSummary(
            uid: uid,
            reason: reason,
            mode: .blockingInitial,
            status: .skipped,
            startedAt: startedAt,
            endedAt: dateProvider.now,
            profileRestored: false,
            dailyLogsRestored: 0,
            foodEntriesRestored: 0,
            waterEntriesRestored: 0,
            weightEntriesRestored: 0,
            dailyReviewsRestored: 0,
            skippedLocalNewer: 0,
            conflicts: 0,
            failed: 0,
            isPartial: false,
            userFacingMessage: message
        )
    }

    private func failedSummary(
        uid: String,
        reason: AccountRestoreReason,
        startedAt: Date,
        message: String
    ) -> AccountRestoreSummary {
        let endedAt = dateProvider.now
        let summary = AccountRestoreSummary(
            uid: uid,
            reason: reason,
            mode: .blockingInitial,
            status: .failed,
            startedAt: startedAt,
            endedAt: endedAt,
            profileRestored: false,
            dailyLogsRestored: 0,
            foodEntriesRestored: 0,
            waterEntriesRestored: 0,
            weightEntriesRestored: 0,
            dailyReviewsRestored: 0,
            skippedLocalNewer: 0,
            conflicts: 0,
            failed: 1,
            isPartial: false,
            userFacingMessage: message
        )
        stateStore.markFailed(uid: uid, reason: reason, message: message, now: endedAt)
        return summary
    }

    private func normalizedUID(_ uid: String) -> String? {
        try? AccountSyncMutationValidation.normalizedOwnerUID(uid)
    }

    private func isUIDStillCurrent(_ uid: String) -> Bool {
        guard let currentUID = currentUIDProvider()?.trimmingCharacters(in: .whitespacesAndNewlines),
              !currentUID.isEmpty else {
            return false
        }
        return (try? AccountSyncMutationValidation.normalizedOwnerUID(currentUID)) == uid
    }
}

// MARK: - Run guard

private final class AccountRestoreRunGuard: @unchecked Sendable {

    private let lock = NSLock()
    private var activeUID: String?

    func tryBegin(uid: String) -> Bool {
        lock.lock()
        defer { lock.unlock() }
        if activeUID != nil {
            return false
        }
        activeUID = uid
        return true
    }

    func end(uid: String) {
        lock.lock()
        defer { lock.unlock() }
        if activeUID == uid {
            activeUID = nil
        }
    }

    func cancel() {
        lock.lock()
        defer { lock.unlock() }
        activeUID = nil
    }
}
