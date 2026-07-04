//
//  AccountRestoreOutcomeSupportTests.swift
//  Fitness CoachTests
//
//  Forma — Restore timeout/offline/partial outcome tests (Phase 4).
//

import XCTest
@testable import Fitness_Coach

final class AccountRestoreOutcomeSupportTests: XCTestCase {

    private let ownerUID = "user-a"
    private let startedAt = Date(timeIntervalSince1970: 1_000)
    private let endedAt = Date(timeIntervalSince1970: 1_020)

    func testTimedOutSummaryMarksPartialWhenLocalDataExists() {
        let localStatus = AccountLocalDataStatus(
            uid: ownerUID,
            hasProfile: true,
            hasAnyDailyLogs: true,
            hasTodayDailyLog: true,
            foodEntryCount: 2,
            waterEntryCount: 0,
            weightEntryCount: 0,
            dailyReviewCount: 0,
            pendingMutationCount: 0,
            failedMutationCount: 0,
            newestLocalUpdatedAt: endedAt,
            oldestLocalDate: "2026-01-01",
            newestLocalDate: "2026-01-02",
            isEffectivelyEmpty: false,
            needsInitialRestore: false
        )

        let summary = AccountRestoreOutcomeSupport.timedOutSummary(
            uid: ownerUID,
            reason: .afterSignIn,
            startedAt: startedAt,
            endedAt: endedAt,
            localStatus: localStatus,
            remoteFailure: nil
        )

        XCTAssertEqual(summary.status, .partial)
        XCTAssertTrue(summary.isPartial)
        XCTAssertTrue(summary.allowsContinuedEntry)
        XCTAssertEqual(summary.userFacingMessage, FormaProductCopy.AccountRestore.TimedOut.body)
    }

    func testTimedOutSummaryWithoutDataAndOfflineRemoteFailureReturnsOffline() {
        let localStatus = emptyLocalStatus()

        let summary = AccountRestoreOutcomeSupport.timedOutSummary(
            uid: ownerUID,
            reason: .afterSignIn,
            startedAt: startedAt,
            endedAt: endedAt,
            localStatus: localStatus,
            remoteFailure: .offline
        )

        XCTAssertEqual(summary.status, .offline)
        XCTAssertTrue(summary.allowsContinuedEntry)
    }

    func testTimedOutSummaryWithoutDataAndNoRemoteFailureReturnsFailed() {
        let localStatus = emptyLocalStatus()

        let summary = AccountRestoreOutcomeSupport.timedOutSummary(
            uid: ownerUID,
            reason: .afterSignIn,
            startedAt: startedAt,
            endedAt: endedAt,
            localStatus: localStatus,
            remoteFailure: nil
        )

        XCTAssertEqual(summary.status, .failed)
        XCTAssertFalse(summary.allowsContinuedEntry)
        XCTAssertEqual(summary.userFacingMessage, FormaProductCopy.AccountRestore.Failed.body)
    }

    func testPartialPullOutcomeWhenProfileRestoredButPullFailed() {
        let pullSummary = AccountSyncPullSummary(
            uid: ownerUID,
            dailyLogsFetched: 0,
            foodEntriesFetched: 0,
            waterEntriesFetched: 0,
            weightEntriesFetched: 0,
            dailyReviewsFetched: 0,
            inserted: 0,
            updated: 0,
            skippedLocalNewer: 0,
            conflicts: 0,
            failed: 2
        )

        XCTAssertTrue(
            AccountRestoreOutcomeSupport.isPartialPullOutcome(
                profileRestored: true,
                pullSummary: pullSummary,
                remoteFailure: nil
            )
        )
    }

    func testSummaryShouldScheduleBackgroundBackfillForPartialAndOffline() {
        let partial = AccountRestoreSummary(
            uid: ownerUID,
            reason: .afterSignIn,
            mode: .blockingInitial,
            status: .partial,
            startedAt: startedAt,
            endedAt: endedAt,
            profileRestored: true,
            dailyLogsRestored: 0,
            foodEntriesRestored: 0,
            waterEntriesRestored: 0,
            weightEntriesRestored: 0,
            dailyReviewsRestored: 0,
            skippedLocalNewer: 0,
            conflicts: 0,
            failed: 1,
            isPartial: true,
            userFacingMessage: nil
        )

        XCTAssertTrue(partial.shouldScheduleBackgroundBackfill)
    }

    private func emptyLocalStatus() -> AccountLocalDataStatus {
        AccountLocalDataStatus(
            uid: ownerUID,
            hasProfile: false,
            hasAnyDailyLogs: false,
            hasTodayDailyLog: false,
            foodEntryCount: 0,
            waterEntryCount: 0,
            weightEntryCount: 0,
            dailyReviewCount: 0,
            pendingMutationCount: 0,
            failedMutationCount: 0,
            newestLocalUpdatedAt: nil,
            oldestLocalDate: nil,
            newestLocalDate: nil,
            isEffectivelyEmpty: true,
            needsInitialRestore: true
        )
    }
}
