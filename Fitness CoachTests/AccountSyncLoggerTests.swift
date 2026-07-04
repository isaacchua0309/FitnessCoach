//
//  AccountSyncLoggerTests.swift
//  Fitness CoachTests
//
//  Forma — Privacy-safe account sync logger tests (Phase 3).
//

import XCTest
@testable import Fitness_Coach

final class AccountSyncLoggerTests: XCTestCase {

    private let sampleUID = "firebase-user-abc123xyz789"

    func testHashedUIDDoesNotContainFullUID() {
        let hash = AccountSyncLogger.hashedUID(sampleUID)
        XCTAssertEqual(hash.count, 8)
        XCTAssertFalse(hash.contains(sampleUID))
        XCTAssertFalse(hash.contains("firebase"))
    }

    func testHashedUIDIsStable() {
        XCTAssertEqual(
            AccountSyncLogger.hashedUID(sampleUID),
            AccountSyncLogger.hashedUID(sampleUID)
        )
    }

    func testErrorCategoryMapsKnownErrors() {
        XCTAssertEqual(
            AccountSyncLogger.errorCategory(
                from: AccountDataRemoteStoreError.userIdMismatch(expected: "a", actual: "b")
            ),
            "remote_store"
        )
        XCTAssertEqual(
            AccountSyncLogger.errorCategory(
                from: CloudAccountDataMappingError.ownerMismatch(entity: "FoodEntryEntity", id: "1")
            ),
            "mapping"
        )
        XCTAssertEqual(
            AccountSyncLogger.errorCategory(
                from: AccountSyncUploaderError.deferredDailyLogDelete
            ),
            "uploader"
        )
    }

    func testDiagnosticsSnapshotUsesHashedUIDOnly() {
        let summary = AccountSyncRunSummary(
            uid: sampleUID,
            reason: .manual,
            startedAt: Date(timeIntervalSince1970: 1_000),
            endedAt: Date(timeIntervalSince1970: 1_001),
            uploadSummary: AccountSyncUploadSummary(
                uid: sampleUID,
                attempted: 2,
                succeeded: 1,
                failed: 1,
                cancelled: 0
            ),
            pullSummary: nil,
            didSkip: false,
            skipReason: nil
        )

        let snapshot = AccountSyncDiagnosticsSnapshot.make(
            traceId: "trace-1",
            summary: summary,
            durationMs: 1_000
        )

        XCTAssertEqual(snapshot.uidHash, AccountSyncLogger.hashedUID(sampleUID))
        XCTAssertNotEqual(snapshot.uidHash, sampleUID)
        XCTAssertEqual(snapshot.upload?.attempted, 2)
        XCTAssertEqual(snapshot.upload?.succeeded, 1)
        XCTAssertEqual(snapshot.upload?.failed, 1)
    }
}
