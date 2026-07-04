//
//  FirestoreNutritionSyncClientTests.swift
//  Fitness CoachTests
//
//  Forma — Nutrition remote client abstraction tests (Phase 2).
//

import XCTest
@testable import Fitness_Coach

final class FirestoreNutritionSyncClientTests: XCTestCase {

    private let referenceDate = ProfileTestFixtures.referenceDate

    func testNoOpClientAcceptsCallsWithoutSideEffects() async throws {
        let client = NoOpNutritionRemoteSyncClient()
        let metadata = CloudNutritionDocumentMapping.makeSyncMetadataDocument(
            context: CloudNutritionSyncMappingContext(
                userId: "signed-in-user",
                now: referenceDate
            )
        )

        try await client.saveSyncMetadata(metadata, uid: "signed-in-user")
        XCTAssertNil(try await client.fetchSyncMetadata(uid: "signed-in-user"))
        XCTAssertTrue(try await client.listFoodEntries(uid: "signed-in-user", dayId: "2026-07-03").isEmpty)
    }

    func testMockClientRecordsSavedDocuments() async throws {
        let mock = MockNutritionRemoteSyncClient()
        let context = CloudNutritionSyncMappingContext(userId: "signed-in-user", now: referenceDate)
        let food = CloudNutritionDocumentMapping.makeCloudFoodEntryDocument(
            from: FoodEntry(
                id: UUID(),
                dailyLogId: UUID(),
                mealType: .lunch,
                name: "Salad",
                quantity: 1,
                unit: "bowl",
                calories: 400,
                protein: 20,
                carbs: 30,
                fat: 12,
                fiber: nil,
                sodium: nil,
                source: .manual,
                confidence: .high,
                imageUrl: nil,
                notes: nil,
                createdAt: referenceDate,
                updatedAt: referenceDate
            ),
            logDate: referenceDate,
            context: context
        )

        try await mock.saveFoodEntry(food, uid: "signed-in-user", dayId: "2026-07-03")

        XCTAssertEqual(mock.savedFoodEntries.count, 1)
        XCTAssertEqual(mock.savedFoodEntries.first?.name, "Salad")
        let fetched = try await mock.fetchFoodEntry(
            uid: "signed-in-user",
            dayId: "2026-07-03",
            entryId: food.id
        )
        XCTAssertEqual(fetched?.calories, 400)
    }

    func testFirestoreSupportRejectsMismatchedDocumentUID() {
        let document = CloudSyncMetadataDocument(
            userId: "other-user",
            schemaVersion: 1,
            lastFullPullAt: nil,
            lastSuccessfulPushAt: nil,
            lastSuccessfulPullAt: nil,
            lastKnownServerUpdatedAt: nil,
            lastMigrationAt: nil,
            lastDeviceId: "device",
            clientVersion: "1.0.0",
            updatedAt: referenceDate
        )

        XCTAssertThrowsError(
            try FirestoreNutritionSyncSupport.validate(document, sessionUID: "signed-in-user")
        ) { error in
            guard case NutritionSyncError.ownerMismatch = error else {
                return XCTFail("Expected ownerMismatch, got \(error)")
            }
        }
    }

    func testAccountDataCloudPathsMatchFirestoreLayout() {
        XCTAssertEqual(
            AccountDataCloudPaths.syncMetadataDocument(uid: "user-a"),
            "users/user-a/syncMetadata/current"
        )
        XCTAssertEqual(
            AccountDataCloudPaths.foodEntryDocument(
                uid: "user-a",
                localDate: "2026-07-03",
                entryId: "food-1"
            ),
            "users/user-a/dailyLogs/2026-07-03/foodEntries/food-1"
        )
        XCTAssertEqual(
            AccountDataCloudPaths.profileDocument(uid: "user-a"),
            "users/user-a/profile/current"
        )
    }
}

// MARK: - Mock client

final class MockNutritionRemoteSyncClient: NutritionRemoteSyncing, @unchecked Sendable {

    var savedSyncMetadata: [CloudSyncMetadataDocument] = []
    var savedDailyLogs: [CloudDailyLogDocument] = []
    var savedFoodEntries: [CloudFoodEntryDocument] = []
    var savedWaterEntries: [CloudWaterEntryDocument] = []
    var savedWeightEntries: [CloudWeightEntryDocument] = []
    var savedDailyReviews: [CloudDailyReviewDocument] = []

    func fetchSyncMetadata(uid: String) async throws -> CloudSyncMetadataDocument? {
        savedSyncMetadata.last { $0.userId == uid }
    }

    func saveSyncMetadata(_ document: CloudSyncMetadataDocument, uid: String) async throws {
        savedSyncMetadata.append(document)
    }

    func fetchDailyLog(uid: String, dayId: String) async throws -> CloudDailyLogDocument? {
        savedDailyLogs.last { $0.userId == uid && $0.id == dayId }
    }

    func saveDailyLog(_ document: CloudDailyLogDocument, uid: String) async throws {
        savedDailyLogs.append(document)
    }

    func listDailyLogsUpdatedSince(uid: String, after: Date) async throws -> [CloudDailyLogDocument] {
        savedDailyLogs.filter { $0.userId == uid && $0.updatedAt > after }
    }

    func fetchFoodEntry(uid: String, dayId: String, entryId: String) async throws -> CloudFoodEntryDocument? {
        savedFoodEntries.last { $0.userId == uid && $0.id == entryId && $0.localDate == dayId }
    }

    func saveFoodEntry(_ document: CloudFoodEntryDocument, uid: String, dayId: String) async throws {
        savedFoodEntries.append(document)
    }

    func listFoodEntries(uid: String, dayId: String) async throws -> [CloudFoodEntryDocument] {
        savedFoodEntries.filter { $0.userId == uid && $0.localDate == dayId }
    }

    func fetchWaterEntry(uid: String, dayId: String, entryId: String) async throws -> CloudWaterEntryDocument? {
        savedWaterEntries.last { $0.userId == uid && $0.id == entryId && $0.localDate == dayId }
    }

    func saveWaterEntry(_ document: CloudWaterEntryDocument, uid: String, dayId: String) async throws {
        savedWaterEntries.append(document)
    }

    func listWaterEntries(uid: String, dayId: String) async throws -> [CloudWaterEntryDocument] {
        savedWaterEntries.filter { $0.userId == uid && $0.localDate == dayId }
    }

    func fetchWeightEntry(uid: String, entryId: String) async throws -> CloudWeightEntryDocument? {
        savedWeightEntries.last { $0.userId == uid && $0.id == entryId }
    }

    func saveWeightEntry(_ document: CloudWeightEntryDocument, uid: String) async throws {
        savedWeightEntries.append(document)
    }

    func listWeightEntriesUpdatedSince(uid: String, after: Date) async throws -> [CloudWeightEntryDocument] {
        savedWeightEntries.filter { $0.userId == uid && $0.updatedAt > after }
    }

    func fetchDailyReview(uid: String, dayId: String) async throws -> CloudDailyReviewDocument? {
        savedDailyReviews.last { $0.userId == uid && $0.localDate == dayId }
    }

    func saveDailyReview(_ document: CloudDailyReviewDocument, uid: String, dayId: String) async throws {
        savedDailyReviews.append(document)
    }
}
