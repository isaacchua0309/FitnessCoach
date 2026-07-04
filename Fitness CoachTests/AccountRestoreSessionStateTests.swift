//
//  AccountRestoreSessionStateTests.swift
//  Fitness CoachTests
//
//  Forma — Restore session state for main-tab reload (Phase 4).
//

import XCTest
@testable import Fitness_Coach

@MainActor
final class AccountRestoreSessionStateTests: XCTestCase {

    func testRecordRestoreCompletionClearsBlockingAndPostsNotification() {
        let session = AccountRestoreSessionState()
        let expectation = expectation(forNotification: .accountRestoreDidComplete, object: nil)

        session.beginBlockingRestore()
        XCTAssertTrue(session.isBlockingRestoreActive)

        let summary = makeSummary(status: .completed)
        session.recordRestoreCompletion(summary)

        wait(for: [expectation], timeout: 1)
        XCTAssertFalse(session.isBlockingRestoreActive)
        XCTAssertEqual(session.lastCompletedSummary, summary)
        XCTAssertEqual(session.completionToken, 1)
    }

    func testPendingRestoreUIOnlyForPartialOrOfflineWithEmptyLocalData() async {
        let session = AccountRestoreSessionState()
        let inspector = StubAccountLocalDataInspector(isEffectivelyEmpty: true)

        session.recordRestoreCompletion(makeSummary(status: .completed))
        XCTAssertFalse(
            await session.shouldShowPendingRestoreUI(
                ownerUID: "user-1",
                localDataInspector: inspector
            )
        )

        session.recordRestoreCompletion(makeSummary(status: .offline))
        XCTAssertTrue(
            await session.shouldShowPendingRestoreUI(
                ownerUID: "user-1",
                localDataInspector: inspector
            )
        )

        session.recordRestoreCompletion(makeSummary(status: .partial))
        XCTAssertTrue(
            await session.shouldShowPendingRestoreUI(
                ownerUID: "user-1",
                localDataInspector: inspector
            )
        )
    }

    func testPendingRestoreUISuppressedWhenLocalDataExists() async {
        let session = AccountRestoreSessionState()
        session.recordRestoreCompletion(makeSummary(status: .offline))

        let inspector = StubAccountLocalDataInspector(isEffectivelyEmpty: false)
        XCTAssertFalse(
            await session.shouldShowPendingRestoreUI(
                ownerUID: "user-1",
                localDataInspector: inspector
            )
        )
    }

    func testClearForSignOutResetsSession() {
        let session = AccountRestoreSessionState()
        session.beginBlockingRestore()
        session.recordRestoreCompletion(makeSummary(status: .offline))

        session.clearForSignOut()

        XCTAssertFalse(session.isBlockingRestoreActive)
        XCTAssertNil(session.lastCompletedSummary)
    }

    private func makeSummary(status: AccountRestoreStatus) -> AccountRestoreSummary {
        AccountRestoreSummary(
            uid: "user-1",
            reason: .afterSignIn,
            mode: .blockingInitial,
            status: status,
            startedAt: Date(timeIntervalSince1970: 1_000),
            endedAt: Date(timeIntervalSince1970: 1_100),
            profileRestored: true,
            dailyLogsRestored: 0,
            foodEntriesRestored: 0,
            waterEntriesRestored: 0,
            weightEntriesRestored: 0,
            dailyReviewsRestored: 0,
            skippedLocalNewer: 0,
            conflicts: 0,
            failed: 0,
            isPartial: status == .partial,
            userFacingMessage: nil
        )
    }
}
