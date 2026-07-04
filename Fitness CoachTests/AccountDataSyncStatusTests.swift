//
//  AccountDataSyncStatusTests.swift
//  Fitness CoachTests
//
//  Forma — Account data sync status enum tests (Phase 3).
//

import XCTest
@testable import Fitness_Coach

final class AccountDataSyncStatusTests: XCTestCase {

    func testAllCasesHaveStableRawValues() {
        XCTAssertEqual(AccountDataSyncStatus.allCases.map(\.rawValue), [
            "localOnly",
            "pendingUpload",
            "synced",
            "pendingDelete",
            "failed",
            "conflict"
        ])
    }

    func testCodableRoundTrip() throws {
        for status in AccountDataSyncStatus.allCases {
            let data = try JSONEncoder().encode(status)
            let decoded = try JSONDecoder().decode(AccountDataSyncStatus.self, from: data)
            XCTAssertEqual(decoded, status)
        }
    }

    func testNeedsSyncWorkFlags() {
        XCTAssertFalse(AccountDataSyncStatus.localOnly.needsSyncWork)
        XCTAssertFalse(AccountDataSyncStatus.synced.needsSyncWork)
        XCTAssertTrue(AccountDataSyncStatus.pendingUpload.needsSyncWork)
        XCTAssertTrue(AccountDataSyncStatus.pendingDelete.needsSyncWork)
        XCTAssertTrue(AccountDataSyncStatus.failed.needsSyncWork)
        XCTAssertTrue(AccountDataSyncStatus.conflict.needsSyncWork)
    }

    func testInvalidRawValueFallsBackToLocalOnlyOnEntity() {
        let entity = FoodEntryEntity(
            id: UUID(),
            dailyLogId: UUID(),
            mealTypeRawValue: MealType.lunch.rawValue,
            name: "Salad",
            quantity: 1,
            unit: "bowl",
            calories: 400,
            protein: 20,
            carbs: 30,
            fat: 12,
            fiber: nil,
            sodium: nil,
            sourceRawValue: FoodEntrySource.manual.rawValue,
            confidenceRawValue: ConfidenceLevel.high.rawValue,
            imageUrl: nil,
            notes: nil,
            createdAt: Date(),
            updatedAt: Date()
        )
        entity.syncStatusRawValue = "not-a-real-status"
        XCTAssertEqual(entity.syncStatus, .localOnly)
    }
}
