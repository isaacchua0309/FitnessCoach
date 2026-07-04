//
//  AccountDataRemoteStoreTests.swift
//  Fitness CoachTests
//
//  Forma — Account data remote store tests (Phase 2).
//

import XCTest
@testable import Fitness_Coach

final class AccountDataRemoteStoreTests: XCTestCase {

    private let uid = "signed-in-user"
    private let otherUID = "other-user"
    private let localDate = "2026-07-03"
    private let referenceDate = Date(timeIntervalSince1970: 1_750_000_000)

    private var store: InMemoryAccountDataRemoteStore!

    override func setUp() async throws {
        try await super.setUp()
        store = InMemoryAccountDataRemoteStore()
    }

    func testInMemoryStoreRoundTripsDailyLog() async throws {
        let document = AccountDataRemoteStoreTestFixtures.dailyLog(
            userId: uid,
            localDate: localDate,
            referenceDate: referenceDate
        )

        try await store.saveDailyLog(document, uid: uid)
        let fetched = try await store.fetchDailyLog(uid: uid, localDate: localDate)

        XCTAssertEqual(fetched, document)
    }

    func testInMemoryStoreFetchesDailyLogsInDateRange() async throws {
        let early = AccountDataRemoteStoreTestFixtures.dailyLog(
            userId: uid,
            localDate: "2026-07-01",
            referenceDate: referenceDate
        )
        let middle = AccountDataRemoteStoreTestFixtures.dailyLog(
            userId: uid,
            localDate: "2026-07-03",
            referenceDate: referenceDate
        )
        let late = AccountDataRemoteStoreTestFixtures.dailyLog(
            userId: uid,
            localDate: "2026-07-05",
            referenceDate: referenceDate
        )

        try await store.saveDailyLog(early, uid: uid)
        try await store.saveDailyLog(middle, uid: uid)
        try await store.saveDailyLog(late, uid: uid)

        let results = try await store.fetchDailyLogs(uid: uid, from: "2026-07-02", to: "2026-07-04")
        XCTAssertEqual(results.map(\.localDate), ["2026-07-03"])
    }

    func testInMemoryStoreRoundTripsFoodAndWaterEntries() async throws {
        let food = AccountDataRemoteStoreTestFixtures.foodEntry(
            userId: uid,
            localDate: localDate,
            referenceDate: referenceDate
        )
        let water = AccountDataRemoteStoreTestFixtures.waterEntry(
            userId: uid,
            localDate: localDate,
            referenceDate: referenceDate
        )

        try await store.saveFoodEntry(food, uid: uid)
        try await store.saveWaterEntry(water, uid: uid)

        let fetchedFood = try await store.fetchFoodEntries(uid: uid, localDate: localDate)
        let fetchedWater = try await store.fetchWaterEntries(uid: uid, localDate: localDate)

        XCTAssertEqual(fetchedFood, [food])
        XCTAssertEqual(fetchedWater, [water])
    }

    func testInMemoryStoreDeletesFoodEntry() async throws {
        let food = AccountDataRemoteStoreTestFixtures.foodEntry(
            userId: uid,
            localDate: localDate,
            referenceDate: referenceDate,
            entryId: "food-1"
        )
        try await store.saveFoodEntry(food, uid: uid)
        try await store.deleteFoodEntry(uid: uid, localDate: localDate, entryId: "food-1")

        XCTAssertTrue(try await store.fetchFoodEntries(uid: uid, localDate: localDate).isEmpty)
    }

    func testInMemoryStoreRoundTripsWeightEntriesWithOptionalRange() async throws {
        let weight = AccountDataRemoteStoreTestFixtures.weightEntry(
            userId: uid,
            localDate: localDate,
            referenceDate: referenceDate,
            entryId: "weight-1"
        )

        try await store.saveWeightEntry(weight, uid: uid)

        let all = try await store.fetchWeightEntries(uid: uid, from: nil, to: nil)
        let ranged = try await store.fetchWeightEntries(uid: uid, from: localDate, to: localDate)

        XCTAssertEqual(all, [weight])
        XCTAssertEqual(ranged, [weight])
    }

    func testInMemoryStoreRoundTripsDailyReviewAndSyncMetadata() async throws {
        let review = AccountDataRemoteStoreTestFixtures.dailyReview(
            userId: uid,
            localDate: localDate,
            referenceDate: referenceDate
        )
        let metadata = AccountDataRemoteStoreTestFixtures.syncMetadata(
            userId: uid,
            referenceDate: referenceDate
        )

        try await store.saveDailyReview(review, uid: uid)
        try await store.saveSyncMetadata(metadata, uid: uid)

        XCTAssertEqual(try await store.fetchDailyReview(uid: uid, localDate: localDate), review)
        XCTAssertEqual(try await store.fetchSyncMetadata(uid: uid), metadata)

        try await store.deleteDailyReview(uid: uid, localDate: localDate)
        XCTAssertNil(try await store.fetchDailyReview(uid: uid, localDate: localDate))
    }

    func testSaveRejectsUserIdMismatch() async throws {
        let document = AccountDataRemoteStoreTestFixtures.dailyLog(
            userId: otherUID,
            localDate: localDate,
            referenceDate: referenceDate
        )

        do {
            try await store.saveDailyLog(document, uid: uid)
            XCTFail("Expected userIdMismatch")
        } catch let error as AccountDataRemoteStoreError {
            XCTAssertEqual(error, .userIdMismatch(expected: uid, actual: otherUID))
        }
    }

    func testSaveRejectsInvalidLocalDatePath() async throws {
        let document = AccountDataRemoteStoreTestFixtures.foodEntry(
            userId: uid,
            localDate: "not-a-date",
            referenceDate: referenceDate
        )

        await XCTAssertThrowsErrorAsync(
            try await store.saveFoodEntry(document, uid: uid)
        ) { error in
            XCTAssertEqual(error as? AccountDataRemoteStoreError, .invalidDocumentPath)
        }
    }

    func testFirestoreStoreRejectsUserIdMismatchBeforeWrite() async throws {
        let firestoreStore = FirestoreAccountDataRemoteStore()
        let document = AccountDataRemoteStoreTestFixtures.dailyLog(
            userId: otherUID,
            localDate: localDate,
            referenceDate: referenceDate
        )

        do {
            try await firestoreStore.saveDailyLog(document, uid: uid)
            XCTFail("Expected userIdMismatch")
        } catch let error as AccountDataRemoteStoreError {
            XCTAssertEqual(error, .userIdMismatch(expected: uid, actual: otherUID))
        }
    }
}

// MARK: - Fixtures

enum AccountDataRemoteStoreTestFixtures {

    static func dailyLog(userId: String, localDate: String, referenceDate: Date) -> CloudDailyLogDocument {
        CloudDailyLogDocument(
            id: localDate,
            userId: userId,
            localDate: localDate,
            timezone: "UTC",
            calorieTarget: 2000,
            proteinTarget: 140,
            carbTarget: 180,
            fatTarget: 65,
            waterTargetMl: 2500,
            expectedWeeklyWeightLossKg: nil,
            aggressiveness: CalorieAggressiveness.moderate.rawValue,
            caloriesConsumed: 520,
            proteinConsumed: 35,
            carbsConsumed: 48,
            fatConsumed: 18,
            fiberConsumed: nil,
            sodiumConsumed: nil,
            waterConsumedMl: 750,
            steps: nil,
            workoutCaloriesBurned: 0,
            weightKg: nil,
            dailyReviewId: nil,
            schemaVersion: AccountDataCloudSchema.currentSchemaVersion,
            createdAt: referenceDate,
            updatedAt: referenceDate,
            deletedAt: nil,
            deviceId: "test-device",
            source: AccountDataCloudSchema.clientSource,
            mutationId: nil
        )
    }

    static func foodEntry(
        userId: String,
        localDate: String,
        referenceDate: Date,
        entryId: String = "food-1"
    ) -> CloudFoodEntryDocument {
        CloudFoodEntryDocument(
            id: entryId,
            userId: userId,
            dailyLogId: UUID().uuidString,
            localDate: localDate,
            mealType: MealType.lunch.rawValue,
            name: "Salad",
            quantity: 1,
            unit: "bowl",
            calories: 400,
            protein: 20,
            carbs: 30,
            fat: 12,
            fiber: nil,
            sodium: nil,
            source: FoodEntrySource.manual.rawValue,
            confidence: ConfidenceLevel.high.rawValue,
            imageUrl: nil,
            notes: nil,
            componentsJSON: nil,
            schemaVersion: AccountDataCloudSchema.currentSchemaVersion,
            createdAt: referenceDate,
            updatedAt: referenceDate,
            deletedAt: nil,
            deviceId: "test-device",
            mutationId: nil
        )
    }

    static func waterEntry(
        userId: String,
        localDate: String,
        referenceDate: Date,
        entryId: String = "water-1"
    ) -> CloudWaterEntryDocument {
        CloudWaterEntryDocument(
            id: entryId,
            userId: userId,
            dailyLogId: UUID().uuidString,
            localDate: localDate,
            amountMl: 350,
            schemaVersion: AccountDataCloudSchema.currentSchemaVersion,
            createdAt: referenceDate,
            updatedAt: referenceDate,
            deletedAt: nil,
            deviceId: "test-device",
            source: AccountDataCloudSchema.clientSource,
            mutationId: nil
        )
    }

    static func weightEntry(
        userId: String,
        localDate: String,
        referenceDate: Date,
        entryId: String
    ) -> CloudWeightEntryDocument {
        CloudWeightEntryDocument(
            id: entryId,
            userId: userId,
            localDate: localDate,
            weightKg: 68.4,
            note: nil,
            schemaVersion: AccountDataCloudSchema.currentSchemaVersion,
            createdAt: referenceDate,
            updatedAt: referenceDate,
            deletedAt: nil,
            deviceId: "test-device",
            source: AccountDataCloudSchema.clientSource,
            mutationId: nil
        )
    }

    static func dailyReview(userId: String, localDate: String, referenceDate: Date) -> CloudDailyReviewDocument {
        CloudDailyReviewDocument(
            id: UUID().uuidString,
            userId: userId,
            dailyLogId: UUID().uuidString,
            localDate: localDate,
            summaryText: "Solid day",
            caloriesSummary: "On target",
            proteinSummary: "High",
            hydrationSummary: "Good",
            workoutSummary: nil,
            weightSummary: nil,
            tomorrowRecommendation: "Repeat",
            schemaVersion: AccountDataCloudSchema.currentSchemaVersion,
            createdAt: referenceDate,
            updatedAt: referenceDate,
            deletedAt: nil,
            deviceId: "test-device",
            source: AccountDataCloudSchema.clientSource,
            mutationId: nil
        )
    }

    static func syncMetadata(userId: String, referenceDate: Date) -> CloudSyncMetadataDocument {
        CloudSyncMetadataDocument(
            userId: userId,
            schemaVersion: AccountDataCloudSchema.currentSchemaVersion,
            lastFullPullAt: nil,
            lastSuccessfulPushAt: referenceDate,
            lastSuccessfulPullAt: nil,
            lastKnownServerUpdatedAt: nil,
            lastMigrationAt: nil,
            lastDeviceId: "test-device",
            clientVersion: "1.0.0",
            updatedAt: referenceDate
        )
    }
}

// MARK: - Async assertion helper

private func XCTAssertThrowsErrorAsync<T>(
    _ expression: @autoclosure () async throws -> T,
    file: StaticString = #filePath,
    line: UInt = #line,
    _ validate: (Error) -> Void = { _ in }
) async {
    do {
        _ = try await expression()
        XCTFail("Expected error to be thrown", file: file, line: line)
    } catch {
        validate(error)
    }
}
