//
//  AccountDeletionCoordinator.swift
//  Fitness Coach
//
//  Forma — Orchestrates full account deletion across sync, remote data, Auth, and local wipe (Phase 6).
//

import Foundation

// MARK: - Protocol

protocol AccountDeletionCoordinating: AnyObject {
    func deleteAccount(
        confirmation: String,
        onProgress: (@MainActor (AccountDeletionStatus) -> Void)?
    ) async -> AccountDeletionSummary
    func deleteLocalDeviceDataOnly(
        confirmation: String,
        onProgress: (@MainActor (AccountDeletionStatus) -> Void)?
    ) async -> AccountDeletionSummary
    func retryAfterReauthentication(
        confirmation: String,
        onProgress: (@MainActor (AccountDeletionStatus) -> Void)?
    ) async -> AccountDeletionSummary
    func cancelDeletion()
}

@MainActor
protocol AccountDeletionRouting: AnyObject {
    func routeToSignedOutAfterFullAccountDeletion() async
    func routeToSignedOutAfterLocalDeviceOnlyWipe() async
}

// MARK: - Coordinator

@MainActor
final class AccountDeletionCoordinator: AccountDeletionCoordinating, LocalAccountDataWipeSessionPreparing {

    private struct PendingReauthenticationState {
        let token: UUID
        let uid: String
        let scope: AccountDeletionScope
        let startedAt: Date
        let remoteResult: RemoteAccountDeletionResult
    }

    private let uidProvider: any AccountUIDProviding
    private let crossDeviceCoordinator: CrossDeviceSyncCoordinating
    private let realtimeListener: AccountRealtimeChangeListening
    private let accountSyncCoordinator: AccountSyncCoordinating
    private let restoreCoordinator: AccountRestoreCoordinating
    private let remoteDeletionClient: any AccountDeletionRemoteDeleting
    private let authDeleting: any AccountAuthDeleting
    private let localWiper: any LocalAccountDataWiping
    private let deletionGuard: AccountDeletionGuarding
    private let router: (any AccountDeletionRouting)?
    private let signOutCurrentSession: () -> Void
    private let nowProvider: () -> Date

    private var activeDeletionToken: UUID?
    private var activeDeletionUID: String?
    private var pendingReauthentication: PendingReauthenticationState?

    init(
        uidProvider: any AccountUIDProviding,
        crossDeviceCoordinator: CrossDeviceSyncCoordinating,
        realtimeListener: AccountRealtimeChangeListening,
        accountSyncCoordinator: AccountSyncCoordinating,
        restoreCoordinator: AccountRestoreCoordinating,
        remoteDeletionClient: any AccountDeletionRemoteDeleting,
        authDeleting: any AccountAuthDeleting,
        localWiper: any LocalAccountDataWiping,
        deletionGuard: AccountDeletionGuarding,
        router: (any AccountDeletionRouting)? = nil,
        signOutCurrentSession: @escaping () -> Void = {},
        nowProvider: @escaping () -> Date = Date.init
    ) {
        self.uidProvider = uidProvider
        self.crossDeviceCoordinator = crossDeviceCoordinator
        self.realtimeListener = realtimeListener
        self.accountSyncCoordinator = accountSyncCoordinator
        self.restoreCoordinator = restoreCoordinator
        self.remoteDeletionClient = remoteDeletionClient
        self.authDeleting = authDeleting
        self.localWiper = localWiper
        self.deletionGuard = deletionGuard
        self.router = router
        self.signOutCurrentSession = signOutCurrentSession
        self.nowProvider = nowProvider
    }

    // MARK: - Public API

    func deleteAccount(
        confirmation: String,
        onProgress: (@MainActor (AccountDeletionStatus) -> Void)? = nil
    ) async -> AccountDeletionSummary {
        AccountDeletionDebugEventLogger.coordinatorDeleteAccountInvoked(scope: .fullAccount)
        return await runDeletion(
            scope: .fullAccount,
            confirmation: confirmation,
            resumeFromPendingReauthentication: false,
            onProgress: onProgress
        )
    }

    func deleteLocalDeviceDataOnly(
        confirmation: String,
        onProgress: (@MainActor (AccountDeletionStatus) -> Void)? = nil
    ) async -> AccountDeletionSummary {
        guard AccountDeletionPolicy.isScopeEnabled(.localDeviceOnly) else {
            return invalidScopeSummary(scope: .localDeviceOnly)
        }

        return await runDeletion(
            scope: .localDeviceOnly,
            confirmation: confirmation,
            resumeFromPendingReauthentication: false,
            onProgress: onProgress
        )
    }

    func retryAfterReauthentication(
        confirmation: String,
        onProgress: (@MainActor (AccountDeletionStatus) -> Void)? = nil
    ) async -> AccountDeletionSummary {
        guard let pending = pendingReauthentication else {
            return failureSummary(
                uid: uidProvider.currentUID ?? "",
                scope: .fullAccount,
                startedAt: nowProvider(),
                status: .failed,
                category: .unknown,
                message: "No account deletion is waiting for reauthentication."
            )
        }

        return await runDeletion(
            scope: pending.scope,
            confirmation: confirmation,
            resumeFromPendingReauthentication: true,
            resumedState: pending,
            onProgress: onProgress
        )
    }

    func cancelDeletion() {
        if let uid = activeDeletionUID ?? pendingReauthentication?.uid {
            abortDeletion(uid: uid)
        }
        pendingReauthentication = nil
        clearActiveDeletionRun()
    }

    // MARK: - Shutdown support (sync/listener cancellation)

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
        pendingReauthentication = nil
        clearActiveDeletionRun()
    }

    func abortDeletion(uid: String) {
        guard let normalizedUID = normalizedUID(uid) else { return }
        deletionGuard.endDeletion(for: normalizedUID)
        accountSyncCoordinator.reinstateWork(for: normalizedUID)
        crossDeviceCoordinator.reinstateWork(for: normalizedUID)
        pendingReauthentication = nil
        clearActiveDeletionRun()
    }

    func isDeletionInProgress(for uid: String) -> Bool {
        deletionGuard.isDeletionInProgress(for: uid)
    }

    func prepareForLocalWipe(uid: String) async {
        await prepareForDeletion(uid: uid)
    }

    // MARK: - Orchestration

    private func runDeletion(
        scope: AccountDeletionScope,
        confirmation: String,
        resumeFromPendingReauthentication: Bool,
        resumedState: PendingReauthenticationState? = nil,
        onProgress: (@MainActor (AccountDeletionStatus) -> Void)? = nil
    ) async -> AccountDeletionSummary {
        let flowStartedAt = nowProvider()

        guard validateConfirmation(confirmation) else {
            return failureSummary(
                uid: uidProvider.currentUID ?? "",
                scope: scope,
                startedAt: flowStartedAt,
                status: .failed,
                category: .unknown,
                message: "Type DELETE to confirm account deletion."
            )
        }

        let token = UUID()
        let uid: String
        let startedAt: Date
        var remoteResult: RemoteAccountDeletionResult?
        var authAccountDeleted = false

        if resumeFromPendingReauthentication, let resumedState {
            guard resumedState.scope == scope else {
                return failureSummary(
                    uid: resumedState.uid,
                    scope: scope,
                    startedAt: flowStartedAt,
                    status: .failed,
                    category: .unknown,
                    message: "Account deletion could not be resumed."
                )
            }
            uid = resumedState.uid
            startedAt = resumedState.startedAt
            remoteResult = resumedState.remoteResult
            activeDeletionToken = resumedState.token
            activeDeletionUID = uid
        } else {
            guard let resolvedUID = resolveSessionUID() else {
                return failureSummary(
                    uid: "",
                    scope: scope,
                    startedAt: flowStartedAt,
                    status: .failed,
                    category: .unauthenticated,
                    message: "Sign in is required before deleting account data."
                )
            }
            uid = resolvedUID
            startedAt = flowStartedAt
            beginDeletionRun(token: token, uid: uid)
        }

        let uidField = AccountDeletionPolicy.privacySafeUIDField(uid)
        AccountDeletionCoordinatorLogger.flowStarted(scope: scope, uidField: uidField)
        AccountDeletionDebugEventLogger.coordinatorRunDeletionStarted(
            scope: scope,
            runToken: token,
            resumeFromReauth: resumeFromPendingReauthentication,
            uidHash: uidField
        )
        reportProgress(.preparing, onProgress: onProgress)
        AccountDeletionDebugEventLogger.coordinatorPhaseTransition(
            phase: .preparing,
            scope: scope,
            runToken: token,
            uidHash: uidField
        )

        guard isRunStillValid(uid: uid, token: token) else {
            abortDeletion(uid: uid)
            return accountSwitchedSummary(uid: uid, scope: scope, startedAt: startedAt)
        }

        if scope == .localDeviceOnly {
            return await runLocalDeviceOnlyFlow(
                uid: uid,
                token: token,
                startedAt: startedAt,
                uidField: uidField,
                onProgress: onProgress
            )
        }

        if !resumeFromPendingReauthentication {
            AccountDeletionCoordinatorLogger.phaseChanged(
                scope: scope,
                status: .preparing,
                uidField: uidField
            )
            reportProgress(.stoppingSync, onProgress: onProgress)
            await prepareForDeletion(uid: uid)

            guard isRunStillValid(uid: uid, token: token) else {
                abortDeletion(uid: uid)
                return accountSwitchedSummary(uid: uid, scope: scope, startedAt: startedAt)
            }

            AccountDeletionCoordinatorLogger.phaseChanged(
                scope: scope,
                status: .deletingRemoteData,
                uidField: uidField
            )
            reportProgress(.deletingRemoteData, onProgress: onProgress)
            AccountDeletionDebugEventLogger.coordinatorPhaseTransition(
                phase: .deletingRemoteData,
                scope: scope,
                runToken: token,
                uidHash: uidField
            )

            do {
                let remote = try await remoteDeletionClient.deleteRemoteAccountData(
                    confirmation: AccountDeletionPolicy.confirmationPhrase
                )
                guard AccountDeletionPolicy.mayContinueDeletion(
                    for: uid,
                    authorizedUID: remote.uid
                ) else {
                    abortDeletion(uid: uid)
                    return accountSwitchedSummary(uid: uid, scope: scope, startedAt: startedAt)
                }
                remoteResult = remote
            } catch let error as AccountDeletionRemoteError {
                abortDeletion(uid: uid)
                return remoteFailureSummary(
                    uid: uid,
                    scope: scope,
                    startedAt: startedAt,
                    error: error
                )
            } catch {
                abortDeletion(uid: uid)
                return remoteFailureSummary(
                    uid: uid,
                    scope: scope,
                    startedAt: startedAt,
                    error: .unknown(nil)
                )
            }
        }

        guard let remoteResult else {
            abortDeletion(uid: uid)
            return failureSummary(
                uid: uid,
                scope: scope,
                startedAt: startedAt,
                status: .failed,
                category: .remoteDataDeleteFailed,
                message: "Remote account data could not be deleted."
            )
        }

        guard isRunStillValid(uid: uid, token: token) else {
            abortDeletion(uid: uid)
            return partialSummary(
                uid: uid,
                scope: scope,
                startedAt: startedAt,
                remoteResult: remoteResult,
                authAccountDeleted: false,
                localSummary: nil,
                status: .partial,
                category: .accountSwitched,
                message: "Account changed before authentication could be removed."
            )
        }

        if resumeFromPendingReauthentication {
            reportProgress(.deletingAuthAccount, onProgress: onProgress)
            do {
                try await authDeleting.reauthenticateForAccountDeletion()
            } catch let error as AccountAuthDeletionError {
                return authFailureSummary(
                    uid: uid,
                    scope: scope,
                    startedAt: startedAt,
                    remoteResult: remoteResult,
                    error: error
                )
            } catch {
                return authFailureSummary(
                    uid: uid,
                    scope: scope,
                    startedAt: startedAt,
                    remoteResult: remoteResult,
                    error: .unknown(nil)
                )
            }
        }

        AccountDeletionCoordinatorLogger.phaseChanged(
            scope: scope,
            status: .deletingAuthAccount,
            uidField: uidField
        )
        reportProgress(.deletingAuthAccount, onProgress: onProgress)
        AccountDeletionDebugEventLogger.coordinatorPhaseTransition(
            phase: .deletingFirebaseAuth,
            scope: scope,
            runToken: token,
            uidHash: uidField
        )

        do {
            try await authDeleting.deleteCurrentAuthAccount()
            authAccountDeleted = true
            pendingReauthentication = nil
        } catch let error as AccountAuthDeletionError {
            switch error {
            case .reauthenticationRequired:
                pendingReauthentication = PendingReauthenticationState(
                    token: token,
                    uid: uid,
                    scope: scope,
                    startedAt: startedAt,
                    remoteResult: remoteResult
                )
                return reauthenticationRequiredSummary(
                    uid: uid,
                    scope: scope,
                    startedAt: startedAt,
                    remoteResult: remoteResult
                )
            case .cancelled:
                return authFailureSummary(
                    uid: uid,
                    scope: scope,
                    startedAt: startedAt,
                    remoteResult: remoteResult,
                    error: error
                )
            default:
                return authFailureSummary(
                    uid: uid,
                    scope: scope,
                    startedAt: startedAt,
                    remoteResult: remoteResult,
                    error: error
                )
            }
        } catch {
            return authFailureSummary(
                uid: uid,
                scope: scope,
                startedAt: startedAt,
                remoteResult: remoteResult,
                error: .unknown(nil)
            )
        }

        guard authAccountDeleted else {
            return authFailureSummary(
                uid: uid,
                scope: scope,
                startedAt: startedAt,
                remoteResult: remoteResult,
                error: .unknown(nil)
            )
        }

        AccountDeletionCoordinatorLogger.phaseChanged(
            scope: scope,
            status: .wipingLocalData,
            uidField: uidField
        )
        reportProgress(.wipingLocalData, onProgress: onProgress)
        AccountDeletionDebugEventLogger.coordinatorPhaseTransition(
            phase: .wipingLocalData,
            scope: scope,
            runToken: token,
            uidHash: uidField
        )

        let localSummary = await localWiper.wipeLocalData(
            for: uid,
            scope: scope,
            authorization: .deletionInProgress(uid: uid)
        )

        if localSummary.status == .completed {
            completeDeletion(uid: uid)
            reportProgress(.completed, onProgress: onProgress)
            AccountDeletionDebugEventLogger.coordinatorPhaseTransition(
                phase: .routingSignedOut,
                scope: scope,
                runToken: token,
                uidHash: uidField
            )
            await router?.routeToSignedOutAfterFullAccountDeletion()
            let summary = mergeSummary(
                uid: uid,
                scope: scope,
                startedAt: startedAt,
                status: .completed,
                remoteResult: remoteResult,
                authAccountDeleted: true,
                localSummary: localSummary,
                failureCategory: nil,
                userFacingMessage: nil
            )
            logTerminalSuccess(summary: summary, uidField: uidField, startedAt: startedAt)
            AccountDeletionDebugEventLogger.coordinatorTerminalSummary(
                summary: summary,
                runToken: token
            )
            AccountDeletionDebugEventLogger.coordinatorPhaseTransition(
                phase: .completed,
                scope: scope,
                runToken: token,
                uidHash: uidField
            )
            return summary
        }

        completeDeletion(uid: uid)
        AccountDeletionDebugEventLogger.coordinatorPhaseTransition(
            phase: .routingSignedOut,
            scope: scope,
            runToken: token,
            uidHash: uidField
        )
        await router?.routeToSignedOutAfterFullAccountDeletion()

        let partial = mergeSummary(
            uid: uid,
            scope: scope,
            startedAt: startedAt,
            status: .partial,
            remoteResult: remoteResult,
            authAccountDeleted: true,
            localSummary: localSummary,
            failureCategory: .localWipeFailed,
            userFacingMessage: localSummary.userFacingMessage
                ?? "Your account was removed, but some on-device data may remain."
        )
        AccountDeletionCoordinatorLogger.flowFailed(
            scope: scope,
            category: AccountDeletionFailureCategory.localWipeFailed.rawValue,
            uidField: uidField
        )
        AccountDeletionDebugEventLogger.coordinatorTerminalSummary(
            summary: partial,
            runToken: token
        )
        AccountDeletionDebugEventLogger.coordinatorPhaseTransition(
            phase: .partial,
            scope: scope,
            runToken: token,
            uidHash: uidField
        )
        return partial
    }

    private func runLocalDeviceOnlyFlow(
        uid: String,
        token: UUID,
        startedAt: Date,
        uidField: String,
        onProgress: (@MainActor (AccountDeletionStatus) -> Void)? = nil
    ) async -> AccountDeletionSummary {
        AccountDeletionCoordinatorLogger.phaseChanged(
            scope: .localDeviceOnly,
            status: .preparing,
            uidField: uidField
        )
        reportProgress(.preparing, onProgress: onProgress)
        reportProgress(.stoppingSync, onProgress: onProgress)
        await prepareForDeletion(uid: uid)

        guard isRunStillValid(uid: uid, token: token) else {
            abortDeletion(uid: uid)
            return accountSwitchedSummary(uid: uid, scope: .localDeviceOnly, startedAt: startedAt)
        }

        AccountDeletionCoordinatorLogger.phaseChanged(
            scope: .localDeviceOnly,
            status: .wipingLocalData,
            uidField: uidField
        )
        reportProgress(.wipingLocalData, onProgress: onProgress)

        let localSummary = await localWiper.wipeLocalData(
            for: uid,
            scope: .localDeviceOnly,
            authorization: .activeSession
        )

        switch localSummary.status {
        case .completed:
            completeDeletion(uid: uid)
            reportProgress(.completed, onProgress: onProgress)
            signOutCurrentSession()
            await router?.routeToSignedOutAfterLocalDeviceOnlyWipe()
            let summary = mergeSummary(
                uid: uid,
                scope: .localDeviceOnly,
                startedAt: startedAt,
                status: .completed,
                remoteResult: nil,
                authAccountDeleted: false,
                localSummary: localSummary,
                failureCategory: nil,
                userFacingMessage: nil
            )
            logTerminalSuccess(summary: summary, uidField: uidField, startedAt: startedAt)
            return summary
        case .partial:
            abortDeletion(uid: uid)
            return mergeSummary(
                uid: uid,
                scope: .localDeviceOnly,
                startedAt: startedAt,
                status: .partial,
                remoteResult: nil,
                authAccountDeleted: false,
                localSummary: localSummary,
                failureCategory: .localWipeFailed,
                userFacingMessage: localSummary.userFacingMessage
            )
        default:
            abortDeletion(uid: uid)
            return mergeSummary(
                uid: uid,
                scope: .localDeviceOnly,
                startedAt: startedAt,
                status: .failed,
                remoteResult: nil,
                authAccountDeleted: false,
                localSummary: localSummary,
                failureCategory: localSummary.failureCategory ?? .localWipeFailed,
                userFacingMessage: localSummary.userFacingMessage
            )
        }
    }

    // MARK: - Helpers

    private func beginDeletionRun(token: UUID, uid: String) {
        activeDeletionToken = token
        activeDeletionUID = uid
    }

    private func clearActiveDeletionRun() {
        activeDeletionToken = nil
        activeDeletionUID = nil
    }

    private func isRunStillValid(uid: String, token: UUID) -> Bool {
        guard activeDeletionToken == token else { return false }
        if pendingReauthentication?.token == token {
            return AccountDeletionPolicy.mayContinueDeletion(
                for: uid,
                authorizedUID: uid
            )
        }
        guard let sessionUID = uidProvider.currentUID else { return false }
        return AccountDeletionPolicy.mayDeleteData(for: uid, sessionUID: sessionUID)
    }

    private func resolveSessionUID() -> String? {
        guard let raw = uidProvider.currentUID?.trimmingCharacters(in: .whitespacesAndNewlines),
              !raw.isEmpty else {
            return nil
        }
        return try? AccountSyncMutationValidation.normalizedOwnerUID(raw)
    }

    private func normalizedUID(_ uid: String) -> String? {
        try? AccountSyncMutationValidation.normalizedOwnerUID(uid)
    }

    private func validateConfirmation(_ confirmation: String) -> Bool {
        guard AccountDeletionPolicy.requiresTypedConfirmation else { return true }
        return confirmation == AccountDeletionPolicy.confirmationPhrase
    }

    private func reportProgress(
        _ status: AccountDeletionStatus,
        onProgress: (@MainActor (AccountDeletionStatus) -> Void)?
    ) {
        onProgress?(status)
    }

    private func logTerminalSuccess(
        summary: AccountDeletionSummary,
        uidField: String,
        startedAt: Date
    ) {
        let durationMs = Int(nowProvider().timeIntervalSince(startedAt) * 1_000)
        AccountDeletionCoordinatorLogger.flowFinished(
            scope: summary.scope,
            status: summary.status,
            uidField: uidField,
            durationMs: durationMs
        )
    }

    // MARK: - Summary builders

    private func mergeSummary(
        uid: String,
        scope: AccountDeletionScope,
        startedAt: Date,
        status: AccountDeletionStatus,
        remoteResult: RemoteAccountDeletionResult?,
        authAccountDeleted: Bool,
        localSummary: AccountDeletionSummary?,
        failureCategory: AccountDeletionFailureCategory?,
        userFacingMessage: String?
    ) -> AccountDeletionSummary {
        AccountDeletionSummary(
            uid: uid,
            scope: scope,
            status: status,
            startedAt: startedAt,
            endedAt: nowProvider(),
            remoteProfileDeleted: remoteResult?.profileDeleted ?? false,
            remoteDailyLogsDeleted: remoteResult?.dailyLogsDeleted ?? 0,
            remoteFoodEntriesDeleted: remoteResult?.foodEntriesDeleted ?? 0,
            remoteWaterEntriesDeleted: remoteResult?.waterEntriesDeleted ?? 0,
            remoteWeightEntriesDeleted: remoteResult?.weightEntriesDeleted ?? 0,
            remoteDailyReviewsDeleted: remoteResult?.dailyReviewsDeleted ?? 0,
            remoteHealthSummariesDeleted: remoteResult?.healthSummariesDeleted ?? false,
            authAccountDeleted: authAccountDeleted,
            localProfileDeleted: localSummary?.localProfileDeleted ?? false,
            localDailyLogsDeleted: localSummary?.localDailyLogsDeleted ?? 0,
            localFoodEntriesDeleted: localSummary?.localFoodEntriesDeleted ?? 0,
            localWaterEntriesDeleted: localSummary?.localWaterEntriesDeleted ?? 0,
            localWeightEntriesDeleted: localSummary?.localWeightEntriesDeleted ?? 0,
            localDailyReviewsDeleted: localSummary?.localDailyReviewsDeleted ?? 0,
            localCoachMessagesDeleted: localSummary?.localCoachMessagesDeleted ?? 0,
            localTimelineEventsDeleted: localSummary?.localTimelineEventsDeleted ?? 0,
            localHealthCacheDeleted: localSummary?.localHealthCacheDeleted ?? false,
            localPreferencesDeleted: localSummary?.localPreferencesDeleted ?? false,
            pendingMutationsDeleted: localSummary?.pendingMutationsDeleted ?? 0,
            failureCategory: failureCategory,
            userFacingMessage: userFacingMessage
        )
    }

    private func failureSummary(
        uid: String,
        scope: AccountDeletionScope,
        startedAt: Date,
        status: AccountDeletionStatus,
        category: AccountDeletionFailureCategory,
        message: String
    ) -> AccountDeletionSummary {
        AccountDeletionSummary(
            uid: uid,
            scope: scope,
            status: status,
            startedAt: startedAt,
            endedAt: nowProvider(),
            remoteProfileDeleted: false,
            remoteDailyLogsDeleted: 0,
            remoteFoodEntriesDeleted: 0,
            remoteWaterEntriesDeleted: 0,
            remoteWeightEntriesDeleted: 0,
            remoteDailyReviewsDeleted: 0,
            remoteHealthSummariesDeleted: false,
            authAccountDeleted: false,
            localProfileDeleted: false,
            localDailyLogsDeleted: 0,
            localFoodEntriesDeleted: 0,
            localWaterEntriesDeleted: 0,
            localWeightEntriesDeleted: 0,
            localDailyReviewsDeleted: 0,
            localCoachMessagesDeleted: 0,
            localTimelineEventsDeleted: 0,
            localHealthCacheDeleted: false,
            localPreferencesDeleted: false,
            pendingMutationsDeleted: 0,
            failureCategory: category,
            userFacingMessage: message
        )
    }

    private func invalidScopeSummary(scope: AccountDeletionScope) -> AccountDeletionSummary {
        failureSummary(
            uid: uidProvider.currentUID ?? "",
            scope: scope,
            startedAt: nowProvider(),
            status: .failed,
            category: .unknown,
            message: "This deletion option is not available."
        )
    }

    private func accountSwitchedSummary(
        uid: String,
        scope: AccountDeletionScope,
        startedAt: Date
    ) -> AccountDeletionSummary {
        failureSummary(
            uid: uid,
            scope: scope,
            startedAt: startedAt,
            status: .failed,
            category: .accountSwitched,
            message: "Account changed before deletion could finish."
        )
    }

    private func remoteFailureSummary(
        uid: String,
        scope: AccountDeletionScope,
        startedAt: Date,
        error: AccountDeletionRemoteError
    ) -> AccountDeletionSummary {
        let category: AccountDeletionFailureCategory
        let status: AccountDeletionStatus
        let message: String

        switch error {
        case .unauthenticated:
            category = .unauthenticated
            status = .failed
            message = "Sign in is required before deleting account data."
        case .reauthenticationRequired:
            category = .reauthenticationRequired
            status = .reauthenticationRequired
            message = "Confirm your identity to continue account deletion."
        case .offline:
            category = .offline
            status = .offline
            message = "Connect to the internet to delete your account data."
        case .permissionDenied:
            category = .permissionDenied
            status = .failed
            message = "You do not have permission to delete this account data."
        case .serverUnavailable, .timeout:
            category = .remoteDataDeleteFailed
            status = .failed
            message = "Cloud account data could not be deleted. Try again."
        case .unknown:
            category = .unknown
            status = .failed
            message = "Cloud account data could not be deleted. Try again."
        }

        AccountDeletionCoordinatorLogger.flowFailed(
            scope: scope,
            category: category.rawValue,
            uidField: AccountDeletionPolicy.privacySafeUIDField(uid)
        )

        let summary = failureSummary(
            uid: uid,
            scope: scope,
            startedAt: startedAt,
            status: status,
            category: category,
            message: message
        )
        logDebugTerminal(summary)
        return summary
    }

    private func authFailureSummary(
        uid: String,
        scope: AccountDeletionScope,
        startedAt: Date,
        remoteResult: RemoteAccountDeletionResult,
        error: AccountAuthDeletionError
    ) -> AccountDeletionSummary {
        switch error {
        case .reauthenticationRequired:
            pendingReauthentication = PendingReauthenticationState(
                token: activeDeletionToken ?? UUID(),
                uid: uid,
                scope: scope,
                startedAt: startedAt,
                remoteResult: remoteResult
            )
            return reauthenticationRequiredSummary(
                uid: uid,
                scope: scope,
                startedAt: startedAt,
                remoteResult: remoteResult
            )
        case .cancelled:
            return partialSummary(
                uid: uid,
                scope: scope,
                startedAt: startedAt,
                remoteResult: remoteResult,
                authAccountDeleted: false,
                localSummary: nil,
                status: .cancelled,
                category: nil,
                message: nil
            )
        case .unauthenticated:
            return partialSummary(
                uid: uid,
                scope: scope,
                startedAt: startedAt,
                remoteResult: remoteResult,
                authAccountDeleted: false,
                localSummary: nil,
                status: .partial,
                category: .authDeleteFailed,
                message: "Cloud data was deleted, but sign-in is required to finish account removal."
            )
        case .providerMismatch:
            return partialSummary(
                uid: uid,
                scope: scope,
                startedAt: startedAt,
                remoteResult: remoteResult,
                authAccountDeleted: false,
                localSummary: nil,
                status: .partial,
                category: .authDeleteFailed,
                message: "Cloud data was deleted, but this sign-in method cannot be removed here."
            )
        case .network:
            return partialSummary(
                uid: uid,
                scope: scope,
                startedAt: startedAt,
                remoteResult: remoteResult,
                authAccountDeleted: false,
                localSummary: nil,
                status: .partial,
                category: .authDeleteFailed,
                message: "Cloud data was deleted, but account removal needs a network connection."
            )
        case .unknown:
            return partialSummary(
                uid: uid,
                scope: scope,
                startedAt: startedAt,
                remoteResult: remoteResult,
                authAccountDeleted: false,
                localSummary: nil,
                status: .partial,
                category: .authDeleteFailed,
                message: "Cloud data was deleted, but the account could not be removed."
            )
        }
    }

    private func reauthenticationRequiredSummary(
        uid: String,
        scope: AccountDeletionScope,
        startedAt: Date,
        remoteResult: RemoteAccountDeletionResult
    ) -> AccountDeletionSummary {
        let summary = mergeSummary(
            uid: uid,
            scope: scope,
            startedAt: startedAt,
            status: .reauthenticationRequired,
            remoteResult: remoteResult,
            authAccountDeleted: false,
            localSummary: nil,
            failureCategory: .reauthenticationRequired,
            userFacingMessage: "Confirm your identity to finish deleting your account."
        )
        logDebugTerminal(summary)
        return summary
    }

    private func partialSummary(
        uid: String,
        scope: AccountDeletionScope,
        startedAt: Date,
        remoteResult: RemoteAccountDeletionResult,
        authAccountDeleted: Bool,
        localSummary: AccountDeletionSummary?,
        status: AccountDeletionStatus,
        category: AccountDeletionFailureCategory?,
        message: String?
    ) -> AccountDeletionSummary {
        let summary = mergeSummary(
            uid: uid,
            scope: scope,
            startedAt: startedAt,
            status: status,
            remoteResult: remoteResult,
            authAccountDeleted: authAccountDeleted,
            localSummary: localSummary,
            failureCategory: category,
            userFacingMessage: message
        )
        logDebugTerminal(summary)
        return summary
    }

    private func logDebugTerminal(_ summary: AccountDeletionSummary) {
        AccountDeletionDebugEventLogger.coordinatorTerminalSummary(
            summary: summary,
            runToken: activeDeletionToken
        )
        AccountDeletionDebugEventLogger.coordinatorPhaseTransition(
            phase: AccountDeletionDebugEventLogger.terminalPhase(for: summary),
            scope: summary.scope,
            runToken: activeDeletionToken,
            uidHash: summary.uid.isEmpty
                ? nil
                : AccountDeletionPolicy.privacySafeUIDField(summary.uid)
        )
    }
}
