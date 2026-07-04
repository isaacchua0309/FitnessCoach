//
//  AccountDataCloudPathsTests.swift
//  Fitness CoachTests
//
//  Forma — Canonical Firestore path helper tests (Phase 2).
//

import XCTest
@testable import Fitness_Coach

final class AccountDataCloudPathsTests: XCTestCase {

    private let uid = "user-a"
    private let localDate = "2026-07-03"
    private let entryId = "food-entry-1"

    func testUserRootAndProfileDocument() {
        XCTAssertEqual(AccountDataCloudPaths.userRoot(uid: uid), "users/user-a")
        XCTAssertEqual(
            AccountDataCloudPaths.profileDocument(uid: uid),
            "users/user-a/profile/current"
        )
    }

    func testDailyLogPaths() {
        XCTAssertEqual(
            AccountDataCloudPaths.dailyLogsCollection(uid: uid),
            "users/user-a/dailyLogs"
        )
        XCTAssertEqual(
            AccountDataCloudPaths.dailyLogDocument(uid: uid, localDate: localDate),
            "users/user-a/dailyLogs/2026-07-03"
        )
    }

    func testFoodAndWaterEntryPaths() {
        XCTAssertEqual(
            AccountDataCloudPaths.foodEntriesCollection(uid: uid, localDate: localDate),
            "users/user-a/dailyLogs/2026-07-03/foodEntries"
        )
        XCTAssertEqual(
            AccountDataCloudPaths.foodEntryDocument(uid: uid, localDate: localDate, entryId: entryId),
            "users/user-a/dailyLogs/2026-07-03/foodEntries/food-entry-1"
        )
        XCTAssertEqual(
            AccountDataCloudPaths.waterEntriesCollection(uid: uid, localDate: localDate),
            "users/user-a/dailyLogs/2026-07-03/waterEntries"
        )
        XCTAssertEqual(
            AccountDataCloudPaths.waterEntryDocument(uid: uid, localDate: localDate, entryId: "water-1"),
            "users/user-a/dailyLogs/2026-07-03/waterEntries/water-1"
        )
    }

    func testWeightAndReviewPaths() {
        XCTAssertEqual(
            AccountDataCloudPaths.weightEntriesCollection(uid: uid),
            "users/user-a/weightEntries"
        )
        XCTAssertEqual(
            AccountDataCloudPaths.weightEntryDocument(uid: uid, entryId: "weight-1"),
            "users/user-a/weightEntries/weight-1"
        )
        XCTAssertEqual(
            AccountDataCloudPaths.dailyReviewsCollection(uid: uid),
            "users/user-a/dailyReviews"
        )
        XCTAssertEqual(
            AccountDataCloudPaths.dailyReviewDocument(uid: uid, localDate: localDate),
            "users/user-a/dailyReviews/2026-07-03"
        )
    }

    func testSyncMetadataDocumentPath() {
        XCTAssertEqual(
            AccountDataCloudPaths.syncMetadataDocument(uid: uid),
            "users/user-a/syncMetadata/current"
        )
    }

    func testSchemaFieldConstants() {
        XCTAssertEqual(AccountDataCloudSchema.currentSchemaVersion, 1)
        XCTAssertEqual(AccountDataCloudSchema.userId, "userId")
        XCTAssertEqual(AccountDataCloudSchema.schemaVersion, "schemaVersion")
        XCTAssertEqual(AccountDataCloudSchema.createdAt, "createdAt")
        XCTAssertEqual(AccountDataCloudSchema.updatedAt, "updatedAt")
        XCTAssertEqual(AccountDataCloudSchema.deletedAt, "deletedAt")
        XCTAssertEqual(AccountDataCloudSchema.deviceId, "deviceId")
        XCTAssertEqual(AccountDataCloudSchema.source, "source")
        XCTAssertEqual(AccountDataCloudSchema.clientSource, "ios_forma")
    }
}
