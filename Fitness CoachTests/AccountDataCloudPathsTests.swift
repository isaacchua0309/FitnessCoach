//
//  AccountDataCloudPathsTests.swift
//  Fitness CoachTests
//
//  Forma — Canonical Firestore path helper tests (Phase 2).
//

import XCTest
@testable import Fitness_Coach

final class AccountDataCloudPathsTests: XCTestCase {

    private let uid = "userA"
    private let localDate = "2026-07-04"

    func testDailyLogPath() {
        XCTAssertEqual(
            AccountDataCloudPaths.dailyLogDocument(uid: uid, localDate: localDate),
            "users/userA/dailyLogs/2026-07-04"
        )
    }

    func testFoodEntryPath() {
        XCTAssertEqual(
            AccountDataCloudPaths.foodEntryDocument(
                uid: uid,
                localDate: localDate,
                entryId: "food1"
            ),
            "users/userA/dailyLogs/2026-07-04/foodEntries/food1"
        )
    }

    func testWaterEntryPath() {
        XCTAssertEqual(
            AccountDataCloudPaths.waterEntryDocument(
                uid: uid,
                localDate: localDate,
                entryId: "water1"
            ),
            "users/userA/dailyLogs/2026-07-04/waterEntries/water1"
        )
    }

    func testWeightEntryPath() {
        XCTAssertEqual(
            AccountDataCloudPaths.weightEntryDocument(uid: uid, entryId: "weight1"),
            "users/userA/weightEntries/weight1"
        )
    }

    func testDailyReviewPath() {
        XCTAssertEqual(
            AccountDataCloudPaths.dailyReviewDocument(uid: uid, localDate: localDate),
            "users/userA/dailyReviews/2026-07-04"
        )
    }

    func testSyncMetadataPath() {
        XCTAssertEqual(
            AccountDataCloudPaths.syncMetadataDocument(uid: uid),
            "users/userA/syncMetadata/current"
        )
    }
}
