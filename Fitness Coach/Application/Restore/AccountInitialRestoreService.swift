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
        reason: AccountRestoreReason,
        prefetchedRemoteStatus: AccountRemoteDataStatus?
    ) async -> AccountRestoreSummary

    func runBackgroundBackfill(
        uid: String,
        reason: AccountRestoreReason
    ) async -> AccountRestoreSummary
}

extension AccountInitialRestoring {
    func runBlockingInitialRestore(
        uid: String,
        reason: AccountRestoreReason
    ) async -> AccountRestoreSummary {
        await runBlockingInitialRestore(
            uid: uid,
            reason: reason,
            prefetchedRemoteStatus: nil
        )
    }
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
        reason: AccountRestoreReason,
        prefetchedRemoteStatus: AccountRemoteDataStatus?
    ) async -> AccountRestoreSummary {
        let mode: AccountRestoreMode = reason == .manualRetry ? .manualRetry : .blockingInitial
        return await runRestore(
            uid: uid,
            reason: reason,
            mode: mode,
            prefetchedRemoteStatus: prefetchedRemoteStatus
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

        return await runBackgroundBackfillRestore(
            uid: normalizedUID,
            reason: reason,
            startedAt: now
        )
    }

    // MARK: - Background backfill

    private func runBackgroundBackfillRestore(
        uid: String,
        reason: AccountRestoreReason,
        startedAt: Date
    ) async -> AccountRestoreSummary {
        AccountRestoreLogger.event(
            "background_backfill_started",
            fields: [
                "uid": uid,
                "reason": reason.rawValue
            ]
        )
        stateStore.markBackgroundBackfillStarted(uid: uid, now: startedAt)

        guard isUIDStillCurrent(uid) else {
            return finishBackgroundSkipped(
                uid: uid,
                reason: reason,
                startedAt: startedAt,
                message: "Account changed before backfill could start."
            )
        }

        guard networkChecker.isNetworkAvailable else {
            AccountRestoreLogger.warn("background_backfill_offline", fields: ["uid": uid])
            return finishBackgroundSkipped(
                uid: uid,
                reason: reason,
                startedAt: startedAt,
                message: "Background backfill deferred until network is available."
            )
        }

        let localStatus: AccountLocalDataStatus
        do {
            localStatus = try await localInspector.inspectLocalData(for: uid)
        } catch {
            AccountRestoreLogger.error(
                "background_backfill_local_inspection_failed",
                fields: ["uid": uid],
                underlying: error
            )
            return finishBackgroundFailed(
                uid: uid,
                reason: reason,
                startedAt: startedAt,
                message: "Background backfill could not inspect local account data."
            )
        }

        guard localStatus.hasProfile else {
            return finishBackgroundSkipped(
                uid: uid,
                reason: reason,
                startedAt: startedAt,
                message: "Background backfill requires a local profile."
            )
        }

        let today = dateProvider.now
        let dailyRange = AccountRestorePolicy.dailyLogDateRange(
            for: .backgroundBackfill,
            referenceDate: today,
            calendar: calendar
        )
        let weightRange = AccountRestorePolicy.weightDateRange(
            for: .backgroundBackfill,
            referenceDate: today,
            calendar: calendar
        )

        let recentPullSummary = await AccountRestoreBootstrapTracer.measure(
            "background_hydration_daily",
            fields: ["mode": AccountRestoreMode.backgroundBackfill.rawValue]
        ) {
            await puller.pullRecentAccountData(
                for: uid,
                from: dailyRange.start,
                to: dailyRange.end
            )
        }

        if Task.isCancelled || !isUIDStillCurrent(uid) {
            return finishBackgroundSkipped(
                uid: uid,
                reason: reason,
                startedAt: startedAt,
                message: "Background backfill was cancelled."
            )
        }

        var pullSummary = recentPullSummary
        if weightRange.start != dailyRange.start || weightRange.end != dailyRange.end {
            let weightPullSummary = await AccountRestoreBootstrapTracer.measure("background_hydration_weight") {
                await puller.pullWeightEntries(
                    for: uid,
                    from: weightRange.start,
                    to: weightRange.end
                )
            }
            pullSummary = AccountRestoreOutcomeSupport.mergePullSummaries(
                recentPullSummary,
                weightPullSummary
            )
        }

        if Task.isCancelled || !isUIDStillCurrent(uid) {
            return finishBackgroundSkipped(
                uid: uid,
                reason: reason,
                startedAt: startedAt,
                message: "Background backfill was cancelled."
            )
        }

        refreshDailyTotals(from: weightRange.start, to: weightRange.end)

        return finishBackgroundPullOutcome(
            uid: uid,
            reason: reason,
            startedAt: startedAt,
            profileRestored: localStatus.hasProfile,
            pullSummary: pullSummary
        )
    }

    private func finishBackgroundSkipped(
        uid: String,
        reason: AccountRestoreReason,
        startedAt: Date,
        message: String
    ) -> AccountRestoreSummary {
        let endedAt = dateProvider.now
        let summary = AccountRestoreSummary(
            uid: uid,
            reason: reason,
            mode: .backgroundBackfill,
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
        AccountRestoreLogger.event("background_backfill_skipped", fields: ["uid": uid])
        return summary
    }

    private func finishBackgroundFailed(
        uid: String,
        reason: AccountRestoreReason,
        startedAt: Date,
        message: String
    ) -> AccountRestoreSummary {
        let endedAt = dateProvider.now
        let summary = AccountRestoreSummary(
            uid: uid,
            reason: reason,
            mode: .backgroundBackfill,
            status: .partial,
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
            isPartial: true,
            userFacingMessage: message
        )
        stateStore.markPartial(uid: uid, summary: summary, now: endedAt)
        AccountRestoreLogger.warn("background_backfill_failed", fields: ["uid": uid])
        return summary
    }

    private func finishBackgroundPullOutcome(
        uid: String,
        reason: AccountRestoreReason,
        startedAt: Date,
        profileRestored: Bool,
        pullSummary: AccountSyncPullSummary
    ) -> AccountRestoreSummary {
        let endedAt = dateProvider.now
        let isPartial = AccountRestoreOutcomeSupport.isPartialPullOutcome(
            profileRestored: profileRestored,
            pullSummary: pullSummary,
            remoteFailure: nil
        )
        let status: AccountRestoreStatus = isPartial ? .partial : .completed
        let summary = AccountRestoreSummary(
            uid: uid,
            reason: reason,
            mode: .backgroundBackfill,
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
            userFacingMessage: isPartial ? FormaProductCopy.AccountRestore.Partial.body : nil
        )

        if isPartial {
            stateStore.markPartial(uid: uid, summary: summary, now: endedAt)
            AccountRestoreLogger.warn(
                "background_backfill_partial",
                fields: [
                    "uid": uid,
                    "failed": String(pullSummary.failed),
                    "conflicts": String(pullSummary.conflicts)
                ]
            )
        } else {
            stateStore.markCompleted(uid: uid, summary: summary, now: endedAt)
            AccountRestoreLogger.event(
                "background_backfill_completed",
                fields: [
                    "uid": uid,
                    "dailyLogs": String(pullSummary.dailyLogsFetched),
                    "foodEntries": String(pullSummary.foodEntriesFetched),
                    "weightEntries": String(pullSummary.weightEntriesFetched)
                ]
            )
        }

        return summary
    }

    // MARK: - Core restore

    private func runRestore(
        uid: String,
        reason: AccountRestoreReason,
        mode: AccountRestoreMode,
        prefetchedRemoteStatus: AccountRemoteDataStatus? = nil
    ) async -> AccountRestoreSummary {
        let startedAt = dateProvider.now
        AccountRestoreBootstrapTracer.event(
            "restore_task_started",
            fields: [
                "reason": reason.rawValue,
                "mode": mode.rawValue,
                "trigger": "blocking_or_retry",
                "cachehit": prefetchedRemoteStatus == nil ? "false" : "true"
            ]
        )

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
            localStatus = try await AccountRestoreBootstrapTracer.measure("local_profile_lookup") {
                try await localInspector.inspectLocalData(for: normalizedUID)
            }
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

        if mode == .blockingInitial || mode == .manualRetry,
           !stateStore.shouldRunBlockingRestore(
               uid: normalizedUID,
               localDataStatus: localStatus,
               now: startedAt
           ) {
            AccountRestoreBootstrapTracer.event(
                "blocking_restore_skipped_local_ready",
                fields: ["cachehit": "true"]
            )
            return finishSkipped(
                uid: normalizedUID,
                reason: reason,
                mode: mode,
                startedAt: startedAt,
                message: AccountInitialRestoreServiceSupport.skippedLocalDataMessage
            )
        }

        let today = dateProvider.now
        let remoteStatus: AccountRemoteDataStatus
        if let prefetchedRemoteStatus,
           prefetchedRemoteStatus.uid == normalizedUID {
            AccountRestoreBootstrapTracer.event(
                "cloud_metadata_lookup",
                fields: ["cachehit": "true", "durationMs": "0"]
            )
            remoteStatus = prefetchedRemoteStatus
        } else {
            remoteStatus = await AccountRestoreBootstrapTracer.measure(
                "cloud_metadata_lookup",
                fields: ["cachehit": "false"]
            ) {
                await remoteInspector.inspectRemoteData(for: normalizedUID, today: today)
            }
        }

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

        if Task.isCancelled {
            return finishCancelled(
                uid: normalizedUID,
                reason: reason,
                mode: mode,
                startedAt: startedAt,
                localStatus: localStatus
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
                pullSummary: nil,
                localStatus: localStatus
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

        if mode == .blockingInitial || mode == .manualRetry || !hadLocalProfile {
            stateStore.markProgress(uid: normalizedUID, status: .restoringProfile, now: dateProvider.now)
            do {
                let resolveOutcome = try await AccountRestoreBootstrapTracer.measure("critical_profile_resolve") {
                    try await profileBootstrapService.resolve(uid: normalizedUID)
                }
                switch resolveOutcome {
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
                        pullSummary: nil,
                        localStatus: localStatus
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

        if !remoteStatus.hasAnyRestorableData,
           mode == .blockingInitial || mode == .manualRetry {
            return finishCompletedEmpty(
                uid: normalizedUID,
                reason: reason,
                mode: mode,
                startedAt: startedAt,
                profileRestored: profileRestored || localStatus.hasProfile
            )
        }

        guard networkChecker.isNetworkAvailable else {
            let refreshedLocalStatus = try? await localInspector.inspectLocalData(for: normalizedUID)
            return finishOffline(
                uid: normalizedUID,
                reason: reason,
                mode: mode,
                startedAt: startedAt,
                profileRestored: profileRestored || localStatus.hasProfile,
                pullSummary: nil,
                localStatus: refreshedLocalStatus ?? localStatus
            )
        }

        let dailyRange = AccountRestorePolicy.dailyLogDateRange(
            for: mode,
            referenceDate: today,
            calendar: calendar
        )
        let weightRange = AccountRestorePolicy.weightDateRange(
            for: mode,
            referenceDate: today,
            calendar: calendar
        )

        // Phase 1 critical bootstrap: recent logs + weight in the daily window.
        stateStore.markProgress(uid: normalizedUID, status: .restoringRecentData, now: dateProvider.now)
        let recentPullSummary = await AccountRestoreBootstrapTracer.measure(
            "critical_cloud_profile_download",
            fields: ["mode": mode.rawValue]
        ) {
            await puller.pullRecentAccountData(
                for: normalizedUID,
                from: dailyRange.start,
                to: dailyRange.end
            )
        }

        var pullSummary = recentPullSummary
        // Extended weight history only — never re-fan-out food/water/review for the wider window.
        if weightRange.start != dailyRange.start || weightRange.end != dailyRange.end {
            stateStore.markProgress(uid: normalizedUID, status: .restoringWeightHistory, now: dateProvider.now)
            let weightPullSummary = await AccountRestoreBootstrapTracer.measure("critical_weight_download") {
                await puller.pullWeightEntries(
                    for: normalizedUID,
                    from: weightRange.start,
                    to: weightRange.end
                )
            }
            pullSummary = AccountRestoreOutcomeSupport.mergePullSummaries(
                recentPullSummary,
                weightPullSummary
            )
        }

        if Task.isCancelled {
            return finishCancelled(
                uid: normalizedUID,
                reason: reason,
                mode: mode,
                startedAt: startedAt,
                localStatus: try? await localInspector.inspectLocalData(for: normalizedUID)
            )
        }

        stateStore.markProgress(uid: normalizedUID, status: .rebuildingLocalViews, now: dateProvider.now)
        await AccountRestoreBootstrapTracer.measure("local_persistence_rebuild") {
            refreshDailyTotals(from: dailyRange.start, to: dailyRange.end)
        }

        let summary = finishPullOutcome(
            uid: normalizedUID,
            reason: reason,
            mode: mode,
            startedAt: startedAt,
            profileRestored: profileRestored || localStatus.hasProfile,
            pullSummary: pullSummary,
            remoteFailure: remoteStatus.failure
        )
        AccountRestoreBootstrapTracer.event(
            "time_to_first_usable_screen_ready",
            fields: [
                "durationMs": String(max(0, Int((summary.duration ?? 0) * 1_000))),
                "status": summary.status.rawValue
            ]
        )
        return summary
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
        pullSummary: AccountSyncPullSummary?,
        localStatus: AccountLocalDataStatus? = nil
    ) -> AccountRestoreSummary {
        if let localStatus,
           !AccountRestoreOutcomeSupport.hasMeaningfulLocalRestoreProgress(localStatus),
           !profileRestored,
           mode == .blockingInitial || mode == .manualRetry {
            return finishFailed(
                uid: uid,
                reason: reason,
                mode: mode,
                startedAt: startedAt,
                message: FormaProductCopy.AccountRestore.Failed.body
            )
        }

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
                pullSummary: nil,
                localStatus: localStatus
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
                message: AccountRestoreOutcomeSupport.safeFailureMessage(for: remoteFailure)
            )
        case .unknown:
            return finishFailed(
                uid: uid,
                reason: reason,
                mode: mode,
                startedAt: startedAt,
                message: AccountRestoreOutcomeSupport.safeFailureMessage(for: remoteFailure)
            )
        }
    }

    private func finishCancelled(
        uid: String,
        reason: AccountRestoreReason,
        mode: AccountRestoreMode,
        startedAt: Date,
        localStatus: AccountLocalDataStatus?
    ) -> AccountRestoreSummary {
        let endedAt = dateProvider.now
        if let localStatus,
           AccountRestoreOutcomeSupport.hasMeaningfulLocalRestoreProgress(localStatus) {
            let summary = AccountRestoreOutcomeSupport.timedOutSummary(
                uid: uid,
                reason: reason,
                startedAt: startedAt,
                endedAt: endedAt,
                localStatus: localStatus,
                remoteFailure: nil
            )
            stateStore.markPartial(uid: uid, summary: summary, now: endedAt)
            return summary
        }

        return finishFailed(
            uid: uid,
            reason: reason,
            mode: mode,
            startedAt: startedAt,
            message: FormaProductCopy.AccountRestore.Failed.body
        )
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
        let isPartial = AccountRestoreOutcomeSupport.isPartialPullOutcome(
            profileRestored: profileRestored,
            pullSummary: pullSummary,
            remoteFailure: remoteFailure
        )
        let status: AccountRestoreStatus = isPartial ? .partial : .completed

        let userFacingMessage: String?
        if isPartial {
            if profileRestored,
               pullSummary.inserted == 0,
               pullSummary.updated == 0 {
                userFacingMessage = FormaProductCopy.AccountRestore.Partial.body
            } else if pullSummary.weightEntriesFetched == 0,
                      pullSummary.failed > 0,
                      restoredAnything {
                userFacingMessage = FormaProductCopy.AccountRestore.Partial.body
            } else {
                userFacingMessage = FormaProductCopy.AccountRestore.Partial.body
            }
        } else {
            userFacingMessage = restoredAnything ? nil : AccountInitialRestoreServiceSupport.emptyRestoreMessage
        }

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
            userFacingMessage: userFacingMessage
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

    nonisolated private static var defaultCalendar: Calendar {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(secondsFromGMT: 0)!
        return calendar
    }
}
