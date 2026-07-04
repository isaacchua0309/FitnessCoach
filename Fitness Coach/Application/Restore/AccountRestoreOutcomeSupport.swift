//
//  AccountRestoreOutcomeSupport.swift
//  Fitness Coach
//
//  Forma — Shared restore outcome resolution (Phase 4).
//

import Foundation

enum AccountRestoreOutcomeSupport {

    static func allowsContinuedEntry(
        summary: AccountRestoreSummary,
        localStatus: AccountLocalDataStatus?
    ) -> Bool {
        switch summary.status {
        case .completed, .skipped, .partial, .offline:
            return true
        case .failed:
            if summary.profileRestored || summary.totalEntitiesRestored > 0 {
                return true
            }
            return localStatus?.hasProfile == true
        case .notStarted, .checking, .restoringProfile, .restoringRecentData,
             .restoringWeightHistory, .rebuildingLocalViews:
            return false
        }
    }

    static func hasMeaningfulLocalRestoreProgress(_ status: AccountLocalDataStatus) -> Bool {
        status.hasProfile || !status.isEffectivelyEmpty
    }

    static func timedOutSummary(
        uid: String,
        reason: AccountRestoreReason,
        startedAt: Date,
        endedAt: Date,
        localStatus: AccountLocalDataStatus,
        remoteFailure: AccountRemoteDataInspectionFailure?
    ) -> AccountRestoreSummary {
        if hasMeaningfulLocalRestoreProgress(localStatus) {
            return AccountRestoreSummary(
                uid: uid,
                reason: reason,
                mode: .blockingInitial,
                status: .partial,
                startedAt: startedAt,
                endedAt: endedAt,
                profileRestored: localStatus.hasProfile,
                dailyLogsRestored: localStatus.hasAnyDailyLogs ? 1 : 0,
                foodEntriesRestored: localStatus.foodEntryCount,
                waterEntriesRestored: localStatus.waterEntryCount,
                weightEntriesRestored: localStatus.weightEntryCount,
                dailyReviewsRestored: localStatus.dailyReviewCount,
                skippedLocalNewer: 0,
                conflicts: 0,
                failed: 0,
                isPartial: true,
                userFacingMessage: FormaProductCopy.AccountRestore.TimedOut.body
            )
        }

        switch remoteFailure {
        case .offline, .unavailable:
            return AccountRestoreSummary(
                uid: uid,
                reason: reason,
                mode: .blockingInitial,
                status: .offline,
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
                userFacingMessage: AccountInitialRestoreServiceSupport.offlineRestoreMessage
            )
        case .permissionDenied, .unauthenticated, .decodingFailed, .unknown, .none:
            return AccountRestoreSummary(
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
                userFacingMessage: FormaProductCopy.AccountRestore.Failed.body
            )
        }
    }

    static func mergePullSummaries(
        _ first: AccountSyncPullSummary,
        _ second: AccountSyncPullSummary?
    ) -> AccountSyncPullSummary {
        guard let second else { return first }
        return AccountSyncPullSummary(
            uid: first.uid,
            dailyLogsFetched: max(first.dailyLogsFetched, second.dailyLogsFetched),
            foodEntriesFetched: max(first.foodEntriesFetched, second.foodEntriesFetched),
            waterEntriesFetched: max(first.waterEntriesFetched, second.waterEntriesFetched),
            weightEntriesFetched: max(first.weightEntriesFetched, second.weightEntriesFetched),
            dailyReviewsFetched: max(first.dailyReviewsFetched, second.dailyReviewsFetched),
            inserted: first.inserted + second.inserted,
            updated: first.updated + second.updated,
            skippedLocalNewer: first.skippedLocalNewer + second.skippedLocalNewer,
            conflicts: first.conflicts + second.conflicts,
            failed: first.failed + second.failed
        )
    }

    static func isPartialPullOutcome(
        profileRestored: Bool,
        pullSummary: AccountSyncPullSummary,
        remoteFailure: AccountRemoteDataInspectionFailure?
    ) -> Bool {
        if pullSummary.failed > 0 || pullSummary.conflicts > 0 {
            return true
        }
        if remoteFailure == .decodingFailed {
            return true
        }
        if profileRestored,
           pullSummary.inserted == 0,
           pullSummary.updated == 0,
           pullSummary.failed > 0 {
            return true
        }
        if pullSummary.foodEntriesFetched > 0 || pullSummary.dailyLogsFetched > 0,
           pullSummary.weightEntriesFetched == 0,
           pullSummary.failed > 0 {
            return true
        }
        return false
    }

    static func safeFailureMessage(for failure: AccountRemoteDataInspectionFailure) -> String {
        switch failure {
        case .permissionDenied, .unauthenticated:
            return AccountInitialRestoreServiceSupport.permissionDeniedMessage
        case .decodingFailed:
            return "Some account data could not be read. You can retry restore later."
        case .offline, .unavailable:
            return AccountInitialRestoreServiceSupport.offlineRestoreMessage
        case .unknown:
            return FormaProductCopy.AccountRestore.Failed.body
        }
    }
}
