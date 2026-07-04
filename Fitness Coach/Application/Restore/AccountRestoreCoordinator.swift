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
    private let currentUIDProvider: () -> String?
    private let restoreEnabledProvider: () -> Bool
    private let dateProvider: DateProviding
    private let runGuard = AccountRestoreRunGuard()
    private var backgroundBackfillTask: Task<Void, Never>?

    init(
        namespaceService: AccountDataNamespacePreparing,
        migrationService: AccountMigrationRunning,
        localInspector: AccountLocalDataInspecting,
        remoteInspector: AccountRemoteDataInspecting,
        initialRestoreService: AccountInitialRestoring,
        stateStore: AccountRestoreStateStoring,
        syncCoordinator: AccountSyncCoordinating? = nil,
        currentUIDProvider: @escaping () -> String?,
        restoreEnabledProvider: @escaping () -> Bool = { AccountRestoreCoordinatorSupport.isRestoreEnabled },
        dateProvider: DateProviding? = nil
    ) {
        self.namespaceService = namespaceService
        self.migrationService = migrationService
        self.localInspector = localInspector
        self.remoteInspector = remoteInspector
        self.initialRestoreService = initialRestoreService
        self.stateStore = stateStore
        self.syncCoordinator = syncCoordinator
        self.currentUIDProvider = currentUIDProvider
        self.restoreEnabledProvider = restoreEnabledProvider
        self.dateProvider = dateProvider ?? SystemDateProvider()
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
        await prepareAccount(uid: uid, reason: .manualRetry, forceBlocking: true)
    }

    func runBackgroundBackfillIfNeeded(uid: String) async {
        guard restoreEnabledProvider() else { return }
        guard let normalizedUID = normalizedUID(uid) else { return }
        guard isUIDStillCurrent(normalizedUID) else { return }
        guard stateStore.shouldRunBackgroundBackfill(uid: normalizedUID, now: dateProvider.now) else { return }

        _ = await initialRestoreService.runBackgroundBackfill(
            uid: normalizedUID,
            reason: .appLaunch
        )
    }

    func cancelOnAccountSwitch() {
        backgroundBackfillTask?.cancel()
        backgroundBackfillTask = nil
        runGuard.cancel()
    }

    // MARK: - Core flow

    private func prepareAccount(
        uid: String,
        reason: AccountRestoreReason,
        forceBlocking: Bool
    ) async -> AccountRestoreSummary {
        let startedAt = dateProvider.now

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

        AccountRestoreLogger.event(
            "restore_coordinator_started",
            fields: [
                "uid": normalizedUID,
                "reason": reason.rawValue
            ]
        )

        guard await namespaceService.prepareForSignedInUID(normalizedUID) else {
            return accountSwitchedSummary(uid: normalizedUID, reason: reason, startedAt: startedAt)
        }

        do {
            try await migrationService.runSafeBackfill(for: normalizedUID)
        } catch {
            AccountRestoreLogger.error(
                "restore_migration_backfill_failed",
                fields: ["uid": normalizedUID],
                underlying: error
            )
        }

        guard isUIDStillCurrent(normalizedUID) else {
            return accountSwitchedSummary(uid: normalizedUID, reason: reason, startedAt: startedAt)
        }

        guard restoreEnabledProvider() else {
            await uploadPendingIfNeeded(for: normalizedUID)
            return skippedSummary(
                uid: normalizedUID,
                reason: reason,
                startedAt: startedAt,
                message: AccountRestoreCoordinatorSupport.restoreDisabledMessage
            )
        }

        let localStatus: AccountLocalDataStatus
        do {
            localStatus = try await localInspector.inspectLocalData(for: normalizedUID)
        } catch {
            AccountRestoreLogger.error(
                "restore_local_inspection_failed",
                fields: ["uid": normalizedUID],
                underlying: error
            )
            return failedSummary(
                uid: normalizedUID,
                reason: reason,
                startedAt: startedAt,
                message: "Restore could not inspect local account data."
            )
        }

        guard isUIDStillCurrent(normalizedUID) else {
            return accountSwitchedSummary(uid: normalizedUID, reason: reason, startedAt: startedAt)
        }

        let remoteStatus = await remoteInspector.inspectRemoteData(
            for: normalizedUID,
            today: dateProvider.now
        )

        guard isUIDStillCurrent(normalizedUID) else {
            return accountSwitchedSummary(uid: normalizedUID, reason: reason, startedAt: startedAt)
        }

        if let failure = remoteStatus.failure,
           shouldFailFast(for: failure, localStatus: localStatus) {
            return finishPermissionFailure(
                uid: normalizedUID,
                reason: reason,
                startedAt: startedAt,
                failure: failure
            )
        }

        let shouldBlock = forceBlocking || shouldRunBlockingRestore(
            localStatus: localStatus,
            remoteStatus: remoteStatus,
            uid: normalizedUID
        )

        let summary: AccountRestoreSummary
        if shouldBlock {
            summary = await initialRestoreService.runBlockingInitialRestore(
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
            return accountSwitchedSummary(uid: normalizedUID, reason: reason, startedAt: startedAt)
        }

        scheduleBackgroundBackfill(uid: normalizedUID)
        AccountRestoreLogger.event(
            "restore_coordinator_finished",
            fields: [
                "uid": normalizedUID,
                "status": summary.status.rawValue
            ]
        )
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
            message = "Some account data could not be read. You can retry restore later."
        case .offline, .unavailable:
            message = AccountInitialRestoreServiceSupport.offlineRestoreMessage
        case .unknown:
            message = "Restore could not reach your account data."
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
        backgroundBackfillTask = Task { [weak self] in
            guard let self else { return }
            await self.runBackgroundBackfillIfNeeded(uid: uid)
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
