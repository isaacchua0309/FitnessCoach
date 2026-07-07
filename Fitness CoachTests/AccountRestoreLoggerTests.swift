//
//  AccountRestoreLoggerTests.swift
//  Fitness CoachTests
//
//  Forma — Privacy-safe account restore logger tests (Phase 4).
//

import XCTest
@testable import Fitness_Coach

final class AccountRestoreLoggerTests: XCTestCase {

    private let sampleUID = "firebase-user-abc123xyz789"
    private let referenceDate = ProfileFixtures.referenceDate

    func testDiagnosticsSnapshotUsesHashedUIDOnly() {
        let summary = makeSummary(uid: sampleUID, status: .completed)

        let snapshot = AccountRestoreDiagnosticsSnapshot.make(
            traceId: "trace-restore-1",
            summary: summary
        )

        XCTAssertEqual(snapshot.uidHash, AccountSyncLogger.hashedUID(sampleUID))
        XCTAssertNotEqual(snapshot.uidHash, sampleUID)
        XCTAssertFalse(snapshot.uidHash.contains("firebase"))
    }

    func testDiagnosticsSnapshotIncludesSafeAggregateFields() {
        let summary = AccountRestoreSummary(
            uid: sampleUID,
            reason: .afterSignIn,
            mode: .blockingInitial,
            status: .partial,
            startedAt: referenceDate,
            endedAt: referenceDate.addingTimeInterval(2),
            profileRestored: true,
            dailyLogsRestored: 3,
            foodEntriesRestored: 12,
            waterEntriesRestored: 4,
            weightEntriesRestored: 2,
            dailyReviewsRestored: 1,
            skippedLocalNewer: 5,
            conflicts: 1,
            failed: 2,
            isPartial: true,
            userFacingMessage: "Restored chicken salad and 72.4 kg weigh-in"
        )

        let snapshot = AccountRestoreDiagnosticsSnapshot.make(
            traceId: "trace-restore-2",
            summary: summary,
            errorCategory: "puller"
        )

        XCTAssertEqual(snapshot.traceId, "trace-restore-2")
        XCTAssertEqual(snapshot.reason, AccountRestoreReason.afterSignIn.rawValue)
        XCTAssertEqual(snapshot.mode, AccountRestoreMode.blockingInitial.rawValue)
        XCTAssertEqual(snapshot.status, AccountRestoreStatus.partial.rawValue)
        XCTAssertEqual(snapshot.durationMs, 2_000)
        XCTAssertTrue(snapshot.profileRestored)
        XCTAssertEqual(snapshot.dailyLogsRestored, 3)
        XCTAssertEqual(snapshot.foodEntriesRestored, 12)
        XCTAssertEqual(snapshot.waterEntriesRestored, 4)
        XCTAssertEqual(snapshot.weightEntriesRestored, 2)
        XCTAssertEqual(snapshot.dailyReviewsRestored, 1)
        XCTAssertEqual(snapshot.skippedLocalNewer, 5)
        XCTAssertEqual(snapshot.conflicts, 1)
        XCTAssertEqual(snapshot.failed, 2)
        XCTAssertEqual(snapshot.errorCategory, "puller")
        XCTAssertFalse(snapshot.wasOffline)
        XCTAssertTrue(snapshot.wasPartial)

        let fields = snapshot.safeFieldDictionary
        let joined = fields.values.joined(separator: "|")
        XCTAssertFalse(joined.contains("chicken"))
        XCTAssertFalse(joined.contains("72.4"))
        XCTAssertFalse(joined.contains(sampleUID))
    }

    func testRemoteFailureAnalyticsCategoryIsStable() {
        XCTAssertEqual(AccountRemoteDataInspectionFailure.offline.analyticsCategory, "offline")
        XCTAssertEqual(AccountRemoteDataInspectionFailure.permissionDenied.analyticsCategory, "permission_denied")
        XCTAssertEqual(AccountRemoteDataInspectionFailure.decodingFailed.analyticsCategory, "decoding_failed")
    }

    func testRedactedRestoreStateDescriptionDoesNotExposeFailureMessage() {
        let state = AccountRestoreStoredState(
            uid: sampleUID,
            status: .failed,
            lastStartedAt: referenceDate,
            lastCompletedAt: referenceDate,
            lastSuccessfulBlockingRestoreAt: nil,
            lastSuccessfulBackgroundBackfillAt: nil,
            lastFailureMessage: "Network unavailable while restoring chicken salad",
            restoredSchemaVersion: 42,
            lastRestoreAppVersion: "1.0.0"
        )

        let description = AccountRestoreLoggerDebugSupport.redactedRestoreStateDescription(state)
        XCTAssertTrue(description.contains("hasFailureMessage=true"))
        XCTAssertFalse(description.contains("chicken"))
        XCTAssertFalse(description.contains(sampleUID))
    }

    private func makeSummary(
        uid: String,
        status: AccountRestoreStatus
    ) -> AccountRestoreSummary {
        AccountRestoreSummary(
            uid: uid,
            reason: .afterSignIn,
            mode: .blockingInitial,
            status: status,
            startedAt: referenceDate,
            endedAt: referenceDate,
            profileRestored: true,
            dailyLogsRestored: 1,
            foodEntriesRestored: 2,
            waterEntriesRestored: 1,
            weightEntriesRestored: 1,
            dailyReviewsRestored: 0,
            skippedLocalNewer: 0,
            conflicts: 0,
            failed: 0,
            isPartial: status == .partial,
            userFacingMessage: nil
        )
    }
}
