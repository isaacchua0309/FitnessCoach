//
//  CrossDeviceSyncLoggerTests.swift
//  Fitness CoachTests
//
//  Forma — Privacy-safe cross-device sync logger tests (Phase 5).
//

import XCTest
@testable import Fitness_Coach

final class CrossDeviceSyncLoggerTests: XCTestCase {

    private let sampleUID = "firebase-user-abc123xyz789"
    private let referenceDate = ProfileTestFixtures.referenceDate

    func testCompletionFieldsUseHashedUIDOnly() {
        let summary = CrossDeviceSyncSummary(
            uid: sampleUID,
            mode: .manualRefresh,
            reason: .manualPullToRefresh,
            status: .completed,
            startedAt: referenceDate,
            endedAt: referenceDate.addingTimeInterval(1.5),
            uploadedMutations: 2,
            pulledDailyLogs: 1,
            pulledFoodEntries: 3,
            pulledWaterEntries: 1,
            pulledWeightEntries: 0,
            pulledDailyReviews: 1,
            pulledProfile: true,
            inserted: 2,
            updated: 1,
            deleted: 0,
            skippedLocalNewer: 0,
            conflicts: 0,
            failed: 0,
            didRefreshUI: true,
            userFacingMessage: nil
        )

        let fields = CrossDeviceSyncLogger.completionFields(
            traceId: "trace-abc",
            summary: summary
        )

        XCTAssertEqual(fields["traceId"], "trace-abc")
        XCTAssertEqual(fields["uidHash"], AccountSyncLogger.hashedUID(sampleUID))
        XCTAssertNotEqual(fields["uidHash"], sampleUID)
        XCTAssertEqual(fields["mode"], CrossDeviceSyncMode.manualRefresh.rawValue)
        XCTAssertEqual(fields["reason"], CrossDeviceSyncReason.manualPullToRefresh.rawValue)
        XCTAssertEqual(fields["status"], CrossDeviceSyncStatus.completed.rawValue)
        XCTAssertEqual(fields["durationMs"], "1500")
        XCTAssertEqual(fields["uploadedMutations"], "2")
        XCTAssertEqual(fields["pulledDailyLogs"], "1")
        XCTAssertEqual(fields["pulledFoodEntries"], "3")
        XCTAssertEqual(fields["pulledWaterEntries"], "1")
        XCTAssertEqual(fields["pulledWeightEntries"], "0")
        XCTAssertEqual(fields["pulledDailyReviews"], "1")
        XCTAssertEqual(fields["pulledProfile"], "true")
        XCTAssertEqual(fields["inserted"], "2")
        XCTAssertEqual(fields["updated"], "1")
        XCTAssertEqual(fields["deleted"], "0")
        XCTAssertEqual(fields["conflicts"], "0")
        XCTAssertEqual(fields["failed"], "0")
        XCTAssertEqual(fields["offline"], "false")
        XCTAssertNil(fields["uid"])
        XCTAssertNil(fields["userFacingMessage"])
    }

    func testCompletionFieldsMarkOfflineRuns() {
        let summary = CrossDeviceSyncSummary(
            uid: sampleUID,
            mode: .foregroundRefresh,
            reason: .appForeground,
            status: .offline,
            startedAt: referenceDate,
            endedAt: referenceDate,
            uploadedMutations: 0,
            pulledDailyLogs: 0,
            pulledFoodEntries: 0,
            pulledWaterEntries: 0,
            pulledWeightEntries: 0,
            pulledDailyReviews: 0,
            pulledProfile: false,
            inserted: 0,
            updated: 0,
            deleted: 0,
            skippedLocalNewer: 0,
            conflicts: 0,
            failed: 0,
            didRefreshUI: false,
            userFacingMessage: "You're offline. Your data is saved on this device."
        )

        let fields = CrossDeviceSyncLogger.completionFields(
            traceId: "trace-offline",
            summary: summary
        )

        XCTAssertEqual(fields["offline"], "true")
        XCTAssertEqual(fields["status"], CrossDeviceSyncStatus.offline.rawValue)
        XCTAssertNil(fields["message"])
    }

    func testCompletionFieldsIncludeErrorCategoryWhenProvided() {
        let summary = CrossDeviceSyncSummary(
            uid: sampleUID,
            mode: .manualRefresh,
            reason: .manualPullToRefresh,
            status: .failed,
            startedAt: referenceDate,
            endedAt: referenceDate,
            uploadedMutations: 0,
            pulledDailyLogs: 0,
            pulledFoodEntries: 0,
            pulledWaterEntries: 0,
            pulledWeightEntries: 0,
            pulledDailyReviews: 0,
            pulledProfile: false,
            inserted: 0,
            updated: 0,
            deleted: 0,
            skippedLocalNewer: 0,
            conflicts: 0,
            failed: 1,
            didRefreshUI: false,
            userFacingMessage: nil
        )

        let fields = CrossDeviceSyncLogger.completionFields(
            traceId: "trace-failed",
            summary: summary,
            errorCategory: "cross_device_sync_failed"
        )

        XCTAssertEqual(fields["errorCategory"], "cross_device_sync_failed")
        XCTAssertEqual(fields["failed"], "1")
    }
}
