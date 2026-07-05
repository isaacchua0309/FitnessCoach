//
//  WeeklyProgressFreshnessBuilderTests.swift
//  Fitness CoachTests
//

import XCTest
@testable import Fitness_Coach

final class WeeklyProgressFreshnessBuilderTests: XCTestCase {

    private let now = Date(timeIntervalSince1970: 1_700_000_000)

    func testReturnsNilWhenInputUnavailable() {
        XCTAssertNil(WeeklyProgressFreshnessBuilder.build(nil))
    }

    func testRestoringAccountTakesPriority() {
        let state = WeeklyProgressFreshnessBuilder.build(
            WeeklyProgressFreshnessInput(
                isRestoringAccount: true,
                isCrossDeviceRefreshing: true,
                pendingUploadCount: 3,
                lastRefreshAt: now,
                recentlyRestoredAt: now,
                now: now
            )
        )

        XCTAssertEqual(
            state?.cardMessage,
            FormaProductCopy.WeeklyReviewPresentation.Freshness.restoringAccount
        )
    }

    func testCrossDeviceRefreshingShowsSyncingCopy() {
        let state = WeeklyProgressFreshnessBuilder.build(
            WeeklyProgressFreshnessInput(
                isRestoringAccount: false,
                isCrossDeviceRefreshing: true,
                pendingUploadCount: nil,
                lastRefreshAt: nil,
                recentlyRestoredAt: nil,
                now: now
            )
        )

        XCTAssertEqual(
            state?.cardMessage,
            FormaProductCopy.WeeklyReviewPresentation.Freshness.syncingChanges
        )
    }

    func testPendingUploadsShowGentleCardAndDetailCopy() {
        let state = WeeklyProgressFreshnessBuilder.build(
            WeeklyProgressFreshnessInput(
                isRestoringAccount: false,
                isCrossDeviceRefreshing: false,
                pendingUploadCount: 2,
                lastRefreshAt: nil,
                recentlyRestoredAt: nil,
                now: now
            )
        )

        XCTAssertEqual(
            state?.cardMessage,
            FormaProductCopy.WeeklyReviewPresentation.Freshness.syncingChanges
        )
        XCTAssertEqual(
            state?.detailMessage,
            FormaProductCopy.WeeklyReviewPresentation.Freshness.reviewMayUpdate
        )
    }

    func testRecentlyRestoredShowsSavedCopy() {
        let state = WeeklyProgressFreshnessBuilder.build(
            WeeklyProgressFreshnessInput(
                isRestoringAccount: false,
                isCrossDeviceRefreshing: false,
                pendingUploadCount: 0,
                lastRefreshAt: nil,
                recentlyRestoredAt: now.addingTimeInterval(-60),
                now: now
            )
        )

        XCTAssertEqual(
            state?.cardMessage,
            FormaProductCopy.WeeklyReviewPresentation.Freshness.savedToAccount
        )
        XCTAssertNil(state?.detailMessage)
    }

    func testRecentRefreshShowsUpdatedJustNow() {
        let state = WeeklyProgressFreshnessBuilder.build(
            WeeklyProgressFreshnessInput(
                isRestoringAccount: false,
                isCrossDeviceRefreshing: false,
                pendingUploadCount: 0,
                lastRefreshAt: now.addingTimeInterval(-30),
                recentlyRestoredAt: nil,
                now: now
            )
        )

        XCTAssertEqual(
            state?.cardMessage,
            FormaProductCopy.WeeklyReviewPresentation.Freshness.updatedJustNow
        )
    }

    func testStaleSignalsOmitFreshnessCopy() {
        let state = WeeklyProgressFreshnessBuilder.build(
            WeeklyProgressFreshnessInput(
                isRestoringAccount: false,
                isCrossDeviceRefreshing: false,
                pendingUploadCount: 0,
                lastRefreshAt: now.addingTimeInterval(-600),
                recentlyRestoredAt: now.addingTimeInterval(-900),
                now: now
            )
        )

        XCTAssertNil(state)
    }
}
