//
//  AccountRestorePolicyTests.swift
//  Fitness CoachTests
//
//  Forma — Account restore policy tests (Phase 4).
//

import XCTest
@testable import Fitness_Coach

final class AccountRestorePolicyTests: XCTestCase {

    private let referenceDate = ProfileTestFixtures.referenceDate

    func testBlockingLookbackConstants() {
        XCTAssertEqual(AccountRestorePolicy.blockingDailyLogLookbackDays, 30)
        XCTAssertEqual(AccountRestorePolicy.blockingWeightLookbackDays, 180)
        XCTAssertEqual(AccountRestorePolicy.backgroundDailyLogLookbackDays, 365)
        XCTAssertEqual(AccountRestorePolicy.backgroundWeightLookbackDays, 730)
    }

    func testBlockingTimeoutRange() {
        let range = AccountRestorePolicy.blockingRestoreTimeoutRange()
        XCTAssertEqual(range.lowerBound, 8)
        XCTAssertEqual(range.upperBound, 20)
        XCTAssertTrue(range.contains(AccountRestorePolicy.preferredBlockingRestoreTimeoutSeconds))
    }

    func testScopeExclusions() {
        XCTAssertFalse(AccountRestorePolicy.includesRawMealImages)
        XCTAssertFalse(AccountRestorePolicy.includesRawHealthKitData)
        XCTAssertFalse(AccountRestorePolicy.includesCoachCloudData)
        XCTAssertTrue(AccountRestorePolicy.preservesLocalNewerUnsyncedEdits)
    }

    func testDailyLogLookbackDaysByMode() {
        XCTAssertEqual(
            AccountRestorePolicy.dailyLogLookbackDays(for: .blockingInitial),
            30
        )
        XCTAssertEqual(
            AccountRestorePolicy.dailyLogLookbackDays(for: .backgroundBackfill),
            365
        )
    }

    func testRestoreStatusTerminalStates() {
        XCTAssertFalse(AccountRestoreStatus.checking.isTerminal)
        XCTAssertTrue(AccountRestoreStatus.completed.isTerminal)
        XCTAssertTrue(AccountRestoreStatus.partial.isTerminal)
        XCTAssertTrue(AccountRestoreStatus.skipped.isTerminal)
        XCTAssertTrue(AccountRestoreStatus.restoringRecentData.isInProgress)
    }

    func testRestoreSummaryTotals() {
        let summary = AccountRestoreSummary(
            uid: "user-a",
            reason: .afterSignIn,
            mode: .blockingInitial,
            status: .completed,
            startedAt: referenceDate,
            endedAt: referenceDate.addingTimeInterval(5),
            profileRestored: true,
            dailyLogsRestored: 2,
            foodEntriesRestored: 10,
            waterEntriesRestored: 3,
            weightEntriesRestored: 4,
            dailyReviewsRestored: 1,
            skippedLocalNewer: 0,
            conflicts: 0,
            failed: 0,
            isPartial: false,
            userFacingMessage: nil
        )
        XCTAssertEqual(summary.totalEntitiesRestored, 20)
        XCTAssertEqual(summary.duration, 5)
    }
}
