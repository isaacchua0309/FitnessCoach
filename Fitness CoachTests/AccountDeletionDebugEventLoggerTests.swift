//
//  AccountDeletionDebugEventLoggerTests.swift
//  Fitness CoachTests
//
//  Privacy-safe account deletion debug logging contract regressions.
//

import XCTest
@testable import Fitness_Coach

final class AccountDeletionDebugEventLoggerTests: XCTestCase {

    func testSafeEndpointRedactsHostAndPathOnly() {
        let url = URL(
            string: "https://us-central1-fitness-coach-732fd.cloudfunctions.net/accountDataDeletion/v1/account/delete-data"
        )!
        let endpoint = AccountDeletionDebugEventLogger.safeEndpoint(from: url)

        XCTAssertEqual(endpoint.host, "us-central1-fitness-coach-732fd.cloudfunctions.net")
        XCTAssertEqual(endpoint.path, "/accountDataDeletion/v1/account/delete-data")
    }

    func testRemoteErrorCategoryLabels() {
        XCTAssertEqual(
            AccountDeletionDebugEventLogger.remoteErrorCategoryLabel(.offline),
            "offline"
        )
        XCTAssertEqual(
            AccountDeletionDebugEventLogger.remoteErrorCategoryLabel(.permissionDenied),
            "forbidden"
        )
        XCTAssertEqual(
            AccountDeletionDebugEventLogger.remoteErrorCategoryLabel(.unauthenticated),
            "unauthorized"
        )
        XCTAssertEqual(
            AccountDeletionDebugEventLogger.remoteErrorCategoryLabel(.reauthenticationRequired),
            "requiresRecentLogin"
        )
        XCTAssertEqual(
            AccountDeletionDebugEventLogger.remoteErrorCategoryLabel(.serverUnavailable),
            "serverUnavailable"
        )
    }

    func testHttpStatus404MapsToNotFound() {
        let category = AccountDeletionDebugEventLogger.httpStatusMappedCategory(
            statusCode: 404,
            mapped: .unknown(nil)
        )
        XCTAssertEqual(category, "notFound")
    }

    func testTerminalPhaseForReauthenticationRequired() {
        let summary = AccountDeletionSummary(
            uid: "user-a",
            scope: .fullAccount,
            status: .reauthenticationRequired,
            startedAt: Date(),
            endedAt: Date(),
            remoteProfileDeleted: true,
            remoteDailyLogsDeleted: 1,
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
            failureCategory: .reauthenticationRequired,
            userFacingMessage: nil
        )

        XCTAssertEqual(
            AccountDeletionDebugEventLogger.terminalPhase(for: summary),
            .partial
        )
    }
}
