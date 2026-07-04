//
//  AccountInitialRestoreService.swift
//  Fitness Coach
//
//  Forma — Blocking and background account restore orchestration (Phase 4).
//
//  Coordinates profile bootstrap, bounded cloud pulls, and restore metadata.
//  Does not merge outside AccountSyncPuller or overwrite pending local edits.
//

import Foundation

protocol AccountInitialRestoring {
    func runBlockingInitialRestore(
        uid: String,
        reason: AccountRestoreReason
    ) async -> AccountRestoreSummary

    func runBackgroundBackfill(
        uid: String,
        reason: AccountRestoreReason
    ) async -> AccountRestoreSummary
}

enum AccountInitialRestoreServiceSupport {

    static let permissionDeniedMessage =
        "Unable to restore your account data. Please sign in again or try later."
    static let emptyRestoreMessage =
        "Your account is ready. Start logging to build your history."
    static let offlineRestoreMessage =
        "Restore will continue when you're back online."
    static let skippedLocalDataMessage =
        "Your recent account data is already on this device."

    static func isOfflineError(_ error: Error) -> Bool {
        AccountRemoteDataInspectionSupport.classify(error) == .offline
    }

    static func restoreFailure(from remoteFailure: AccountRemoteDataInspectionFailure) -> AccountRemoteDataInspectionFailure {
        remoteFailure
    }
}

@MainActor
final class AccountInitialRestoreService: AccountInitialRestoring {

    private let profileBootstrapService: ProfileBootstrapService
    private let puller: AccountSyncPulling
    private let localInspector: AccountLocalDataInspecting
    private let remoteInspector: AccountRemoteDataInspecting
    private let stateStore: AccountRestoreStateStoring
    private let syncCoordinator: AccountSyncCoordinating?
    private let dailyLogService: DailyLogService
    private let networkChecker: any AccountSyncNetworkChecking
    private let currentUIDProvider: () -> String?
    private let dateProvider: DateProviding
    private let calendar: Calendar

    init(
        profileBootstrapService: ProfileBootstrapService,
        puller: AccountSyncPulling,
        localInspector: AccountLocalDataInspecting,
        remoteInspector: AccountRemoteDataInspecting,
        stateStore: AccountRestoreStateStoring,
        syncCoordinator: AccountSyncCoordinating? = nil,
        dailyLogService: DailyLogService,
        networkChecker: any AccountSyncNetworkChecking = AlwaysAvailableAccountSyncNetworkChecker(),
        currentUIDProvider: @escaping () -> String?,
        dateProvider: DateProviding? = nil,
        calendar: Calendar = AccountInitialRestoreService.defaultCalendar
    ) {
        self.profileBootstrapService = profileBootstrapService
        self.puller = puller
        self.localInspector = localInspector
        self.remoteInspector = remoteInspector
        self.stateStore = stateStore
        self.syncCoordinator = syncCoordinator
        self.dailyLogService = dailyLogService
        self.networkChecker = networkChecker
        self.currentUIDProvider = currentUIDProvider
        self.dateProvider = dateProvider ?? SystemDateProvider()
        self.calendar = calendar
    }

    func runBlockingInitialRestore(
        uid: String,
        reason: AccountRestoreReason
    ) async -> AccountRestoreSummary {
        await runRestore(
            uid: uid,
            reason: reason,
            mode: .blockingInitial
        )
    }

    func runBackgroundBackfill(
        uid: String,
        reason: AccountRestoreReason
    ) async -> AccountRestoreSummary {
        let now = dateProvider.now

        guard let normalizedUID = normalizedUID(uid) else {
            return failedSummary(
                uid: uid.trimmingCharacters(in: .whitespacesAndNewlines),
                reason: reason,
                mode: .backgroundBackfill,
                startedAt: now,
                endedAt: now,
                message: "Restore could not start for this account."
            )
        }

        guard isUIDStillCurrent(normalizedUID) else {
            return skippedSummary(
                uid: normalizedUID,
                reason: reason,
                mode: .backgroundBackfill,
                startedAt: now,
                endedAt: now,
                message: "Account changed before backfill could start."
            )
        }

        guard stateStore.shouldRunBackgroundBackfill(uid: normalizedUID, now: now) else {
            return skippedSummary(
                uid: normalizedUID,
                reason: reason,
                mode: .backgroundBackfill,
                startedAt: now,
                endedAt: now,
                message: "Background backfill is not needed right now."
            )
        }

        return await runRestore(
            uid: normalizedUID,
            reason: reason,
            mode: .backgroundBackfill
        )
    }

    // MARK: - Core restore

    private func runRestore(
        uid: String,
        reason: AccountRestoreReason,
        mode: AccountRestoreMode
    ) async -> AccountRestoreSummary {
        let startedAt = dateProvider.now

        guard let normalizedUID = normalizedUID(uid) else {
            return failedSummary(
                uid: uid.trimmingCharacters(in: .whitespacesAndNewlines),
                reason: reason,
                mode: mode,
                startedAt: startedAt,
                endedAt: startedAt,
                message: "Restore could not start for this account."
            )
        }

        AccountRestoreLogger.event(
            "restore_started",
            fields: [
                "uid": normalizedUID,
                "reason": reason.rawValue,
                "mode": mode.rawValue
            ]
        )

        stateStore.markStarted(
            uid: normalizedUID,
            reason: reason,
            mode: mode,
            now: startedAt
        )

        guard isUIDStillCurrent(normalizedUID) else {
            return finishSkipped(
                uid: normalizedUID,
                reason: reason,
                mode: mode,
                startedAt: startedAt,
                message: "Account changed during restore."
            )
        }

        let localStatus: AccountLocalDataStatus
        do {
            localStatus = try await localInspector.inspectLocalData(for: normalizedUID)
        } catch {
            AccountRestoreLogger.error("local_inspection_failed", fields: ["uid": normalizedUID], underlying: error)
            return finishFailed(
                uid: normalizedUID,
                reason: reason,
                mode: mode,
                startedAt: startedAt,
                message: "Restore could not inspect local account data."
            )
        }

        if mode == .blockingInitial,
           !stateStore.shouldRunBlockingRestore(
               uid: normalizedUID,
               localDataStatus: localStatus,
               now: startedAt
           ) {
            return finishSkipped(
                uid: normalizedUID,
                reason: reason,
                mode: mode,
                startedAt: startedAt,
                message: AccountInitialRestoreServiceSupport.skippedLocalDataMessage
            )
        }

        let today = dateProvider.now
        let remoteStatus = await remoteInspector.inspectRemoteData(for: normalizedUID, today: today)

        if let remoteFailure = remoteStatus.failure,
           !remoteStatus.hasAnyRestorableData {
            return finishRemoteFailure(
                uid: normalizedUID,
                reason: reason,
                mode: mode,
                startedAt: startedAt,
                localStatus: localStatus,
                remoteFailure: remoteFailure
            )
        }

        if !networkChecker.isNetworkAvailable,
           mode == .blockingInitial,
           localStatus.needsInitialRestore,
           !localStatus.hasProfile,
           !remoteStatus.hasCloudProfile {
            return finishOffline(
                uid: normalizedUID,
                reason: reason,
                mode: mode,
                startedAt: startedAt,
                profileRestored: false,
                pullSummary: nil
            )
        }

        if localStatus.pendingMutationCount > 0,
           let syncCoordinator,
           networkChecker.isNetworkAvailable,
           AccountPersistenceFeatureFlags.uploadPendingMutationsEnabled {
            AccountRestoreLogger.event(
                "restore_upload_pending_started",
                fields: [
                    "uid": normalizedUID,
                    "pendingCount": String(localStatus.pendingMutationCount)
                ]
            )
            _ = await syncCoordinator.uploadPendingOnly(for: normalizedUID, reason: .afterSignIn)
        }

        guard isUIDStillCurrent(normalizedUID) else {
            return finishSkipped(
                uid: normalizedUID,
                reason: reason,
                mode: mode,
                startedAt: startedAt,
                message: "Account changed during restore."
            )
        }

        let hadLocalProfile = localStatus.hasProfile
        var profileRestored = false

        if mode == .blockingInitial || !hadLocalProfile {
            stateStore.markProgress(uid: normalizedUID, status: .restoringProfile, now: dateProvider.now)
            do {
                switch try await profileBootstrapService.resolve(uid: normalizedUID) {
                case .main:
                    profileRestored = !hadLocalProfile && remoteStatus.hasCloudProfile
                case .missingCloudProfile:
                    if !remoteStatus.hasAnyRestorableData {
                        return finishCompletedEmpty(
                            uid: normalizedUID,
                            reason: reason,
                            mode: mode,
                            startedAt: startedAt,
                            profileRestored: false
                        )
                    }
                }
            } catch {
                AccountRestoreLogger.error(
                    "profile_restore_failed",
                    fields: ["uid": normalizedUID],
                    underlying: error
                )
                if AccountInitialRestoreServiceSupport.isOfflineError(error) {
                    return finishOffline(
                        uid: normalizedUID,
                        reason: reason,
                        mode: mode,
                        startedAt: startedAt,
                        profileRestored: localStatus.hasProfile,
                        pullSummary: nil
                    )
                }
                return finishFailed(
                    uid: normalizedUID,
                    reason: reason,
                    mode: mode,
                    startedAt: startedAt,
                    message: AccountInitialRestoreServiceSupport.permissionDeniedMessage
                )
            }
        }

        if !remoteStatus.hasAnyRestorableData, mode == .blockingInitial {
            return finishCompletedEmpty(
                uid: normalizedUID,
                reason: reason,
                mode: mode,
                startedAt: startedAt,
                profileRestored: profileRestored || localStatus.hasProfile
            )
        }

        guard networkChecker.isNetworkAvailable else {
            return finishOffline(
                uid: normalizedUID,
                reason: reason,
                mode: mode,
                startedAt: startedAt,
                profileRestored: profileRestored || localStatus.hasProfile,
                pullSummary: nil
            )
        }

        let dateRange = dateRange(for: mode, referenceDate: today)
        stateStore.markProgress(uid: normalizedUID, status: .restoringRecentData, now: dateProvider.now())
        let pullSummary = await puller.pullRecentAccountData(
            for: normalizedUID,
            from: dateRange.start,
            to: dateRange.end
        )

        if mode == .blockingInitial || mode == .manualRetry {
            stateStore.markProgress(uid: normalizedUID, status: .restoringWeightHistory, now: dateProvider.now())
        }

        stateStore.markProgress(uid: normalizedUID, status: .rebuildingLocalViews, now: dateProvider.now())
        refreshDailyTotals(from: dateRange.start, to: dateRange.end)

        return finishPullOutcome(
            uid: normalizedUID,
            reason: reason,
            mode: mode,
            startedAt: startedAt,
            profileRestored: profileRestored || localStatus.hasProfile,
            pullSummary: pullSummary,
            remoteFailure: remoteStatus.failure
        )
    }

    // MARK: - Terminal outcomes

    private func finishCompletedEmpty(
        uid: String,
        reason: AccountRestoreReason,
        mode: AccountRestoreMode,
        startedAt: Date,
        profileRestored: Bool
    ) -> AccountRestoreSummary {
        let endedAt = dateProvider.now
        let summary = AccountRestoreSummary(
            uid: uid,
            reason: reason,
            mode: mode,
            status: .completed,
            startedAt: startedAt,
            endedAt: endedAt,
            profileRestored: profileRestored,
            dailyLogsRestored: 0,
            foodEntriesRestored: 0,
            waterEntriesRestored: 0,
            weightEntriesRestored: 0,
            dailyReviewsRestored: 0,
            skippedLocalNewer: 0,
            conflicts: 0,
            failed: 0,
            isPartial: false,
            userFacingMessage: AccountInitialRestoreServiceSupport.emptyRestoreMessage
        )
        stateStore.markCompleted(uid: uid, summary: summary, now: endedAt)
        AccountRestoreLogger.event("restore_completed_empty", fields: ["uid": uid, "mode": mode.rawValue])
        return summary
    }

    private func finishSkipped(
        uid: String,
        reason: AccountRestoreReason,
        mode: AccountRestoreMode,
        startedAt: Date,
        message: String
    ) -> AccountRestoreSummary {
        let endedAt = dateProvider.now
        let summary = AccountRestoreSummary(
            uid: uid,
            reason: reason,
            mode: mode,
            status: .skipped,
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
            failed: 0,
            isPartial: false,
            userFacingMessage: message
        )
        stateStore.markSkipped(uid: uid, reason: reason, now: endedAt)
        AccountRestoreLogger.event("restore_skipped", fields: ["uid": uid, "mode": mode.rawValue])
        return summary
    }

    private func finishOffline(
        uid: String,
        reason: AccountRestoreReason,
        mode: AccountRestoreMode,
        startedAt: Date,
        profileRestored: Bool,
        pullSummary: AccountSyncPullSummary?
    ) -> AccountRestoreSummary {
        let endedAt = dateProvider.now
        let summary = AccountRestoreSummary(
            uid: uid,
            reason: reason,
            mode: mode,
            status: .offline,
            startedAt: startedAt,
            endedAt: endedAt,
            profileRestored: profileRestored,
            dailyLogsRestored: pullSummary?.dailyLogsFetched ?? 0,
            foodEntriesRestored: pullSummary?.foodEntriesFetched ?? 0,
            waterEntriesRestored: pullSummary?.waterEntriesFetched ?? 0,
            weightEntriesRestored: pullSummary?.weightEntriesFetched ?? 0,
            dailyReviewsRestored: pullSummary?.dailyReviewsFetched ?? 0,
            skippedLocalNewer: pullSummary?.skippedLocalNewer ?? 0,
            conflicts: pullSummary?.conflicts ?? 0,
            failed: pullSummary?.failed ?? 0,
            isPartial: pullSummary != nil,
            userFacingMessage: AccountInitialRestoreServiceSupport.offlineRestoreMessage
        )
        stateStore.markOffline(uid: uid, reason: reason, now: endedAt)
        AccountRestoreLogger.warn("restore_offline", fields: ["uid": uid, "mode": mode.rawValue])
        return summary
    }

    private func finishFailed(
        uid: String,
        reason: AccountRestoreReason,
        mode: AccountRestoreMode,
        startedAt: Date,
        message: String
    ) -> AccountRestoreSummary {
        let endedAt = dateProvider.now
        let summary = AccountRestoreSummary(
            uid: uid,
            reason: reason,
            mode: mode,
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
        AccountRestoreLogger.error("restore_failed", fields: ["uid": uid, "mode": mode.rawValue])
        return summary
    }

    private func finishRemoteFailure(
        uid: String,
        reason: AccountRestoreReason,
        mode: AccountRestoreMode,
        startedAt: Date,
        localStatus: AccountLocalDataStatus,
        remoteFailure: AccountRemoteDataInspectionFailure
    ) -> AccountRestoreSummary {
        switch remoteFailure {
        case .offline, .unavailable:
            return finishOffline(
                uid: uid,
                reason: reason,
                mode: mode,
                startedAt: startedAt,
                profileRestored: localStatus.hasProfile,
                pullSummary: nil
            )
        case .permissionDenied, .unauthenticated:
            return finishFailed(
                uid: uid,
                reason: reason,
                mode: mode,
                startedAt: startedAt,
                message: AccountInitialRestoreServiceSupport.permissionDeniedMessage
            )
        case .decodingFailed:
            return finishFailed(
                uid: uid,
                reason: reason,
                mode: mode,
                startedAt: startedAt,
                message: "Some account data could not be read. You can retry restore later."
            )
        case .unknown:
            return finishFailed(
                uid: uid,
                reason: reason,
                mode: mode,
                startedAt: startedAt,
                message: "Restore could not reach your account data."
            )
        }
    }

    private func finishPullOutcome(
        uid: String,
        reason: AccountRestoreReason,
        mode: AccountRestoreMode,
        startedAt: Date,
        profileRestored: Bool,
        pullSummary: AccountSyncPullSummary,
        remoteFailure: AccountRemoteDataInspectionFailure?
    ) -> AccountRestoreSummary {
        let endedAt = dateProvider.now
        let restoredAnything = pullSummary.inserted > 0
            || pullSummary.updated > 0
            || profileRestored
        let isPartial = pullSummary.failed > 0
            || pullSummary.conflicts > 0
            || remoteFailure == .decodingFailed
        let status: AccountRestoreStatus = isPartial ? .partial : .completed

        let summary = AccountRestoreSummary(
            uid: uid,
            reason: reason,
            mode: mode,
            status: status,
            startedAt: startedAt,
            endedAt: endedAt,
            profileRestored: profileRestored,
            dailyLogsRestored: pullSummary.dailyLogsFetched,
            foodEntriesRestored: pullSummary.foodEntriesFetched,
            waterEntriesRestored: pullSummary.waterEntriesFetched,
            weightEntriesRestored: pullSummary.weightEntriesFetched,
            dailyReviewsRestored: pullSummary.dailyReviewsFetched,
            skippedLocalNewer: pullSummary.skippedLocalNewer,
            conflicts: pullSummary.conflicts,
            failed: pullSummary.failed,
            isPartial: isPartial,
            userFacingMessage: restoredAnything ? nil : AccountInitialRestoreServiceSupport.emptyRestoreMessage
        )

        if isPartial {
            stateStore.markPartial(uid: uid, summary: summary, now: endedAt)
            AccountRestoreLogger.warn(
                "restore_partial",
                fields: [
                    "uid": uid,
                    "mode": mode.rawValue,
                    "failed": String(pullSummary.failed),
                    "conflicts": String(pullSummary.conflicts)
                ]
            )
        } else {
            stateStore.markCompleted(uid: uid, summary: summary, now: endedAt)
            AccountRestoreLogger.event(
                "restore_completed",
                fields: [
                    "uid": uid,
                    "mode": mode.rawValue,
                    "dailyLogs": String(pullSummary.dailyLogsFetched),
                    "foodEntries": String(pullSummary.foodEntriesFetched)
                ]
            )
        }

        return summary
    }

    // MARK: - Helpers

    private func normalizedUID(_ uid: String) -> String? {
        try? AccountSyncMutationValidation.normalizedOwnerUID(uid)
    }

    private func isUIDStillCurrent(_ uid: String) -> Bool {
        guard let currentUID = currentUIDProvider()?.trimmingCharacters(in: .whitespacesAndNewlines),
              !currentUID.isEmpty else {
            return false
        }
        return currentUID == uid
    }

    private func dateRange(for mode: AccountRestoreMode, referenceDate: Date) -> (start: String, end: String) {
        switch mode {
        case .blockingInitial, .manualRetry:
            // Puller uses one shared date range; weight lookback is the widest blocking window.
            return AccountRestorePolicy.weightDateRange(
                for: .blockingInitial,
                referenceDate: referenceDate,
                calendar: calendar
            )
        case .backgroundBackfill:
            return AccountRestorePolicy.weightDateRange(
                for: .backgroundBackfill,
                referenceDate: referenceDate,
                calendar: calendar
            )
        }
    }

    private func refreshDailyTotals(from startDate: String, to endDate: String) {
        let dates = AccountSyncPuller.localDates(from: startDate, to: endDate, calendar: calendar)
        for localDate in dates {
            guard let date = CloudAccountDataDateCodec.date(fromLocalDateString: localDate, calendar: calendar) else {
                continue
            }
            do {
                if try dailyLogService.dailyLogEntity(for: date) != nil {
                    _ = try dailyLogService.recalculateDailyTotals(for: date)
                }
            } catch {
                AccountRestoreLogger.warn(
                    "restore_recalculate_failed",
                    fields: ["localDate": localDate]
                )
            }
        }
    }

    private func skippedSummary(
        uid: String,
        reason: AccountRestoreReason,
        mode: AccountRestoreMode,
        startedAt: Date,
        endedAt: Date,
        message: String
    ) -> AccountRestoreSummary {
        AccountRestoreSummary(
            uid: uid,
            reason: reason,
            mode: mode,
            status: .skipped,
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
            failed: 0,
            isPartial: false,
            userFacingMessage: message
        )
    }

    private func failedSummary(
        uid: String,
        reason: AccountRestoreReason,
        mode: AccountRestoreMode,
        startedAt: Date,
        endedAt: Date,
        message: String
    ) -> AccountRestoreSummary {
        AccountRestoreSummary(
            uid: uid,
            reason: reason,
            mode: mode,
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
    }

    private static var defaultCalendar: Calendar {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(secondsFromGMT: 0)!
        return calendar
    }
}
