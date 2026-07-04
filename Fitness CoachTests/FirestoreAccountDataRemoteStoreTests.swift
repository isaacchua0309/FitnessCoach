//
//  FirestoreAccountDataRemoteStoreTests.swift
//  Fitness CoachTests
//
//  Forma — Account data remote store tests (Phase 2).
//
//  UserId mismatch checks run against FirestoreAccountDataRemoteStore (validation
//  happens before any Firestore write, so no emulator is required).
//  Save/fetch/scoping/delete contract tests use InMemoryAccountDataRemoteStore.
//

import XCTest
@testable import Fitness_Coach

final class FirestoreAccountDataRemoteStoreTests: XCTestCase {

    private let userA = "userA"
    private let userB = "userB"
    private let localDate = "2026-07-04"
    private let otherDate = "2026-07-05"
    private let referenceDate = Date(timeIntervalSince1970: 1_750_000_000)

    private var contractStore: InMemoryAccountDataRemoteStore!
    private var firestoreStore: FirestoreAccountDataRemoteStore!

    override func setUp() async throws {
        try await super.setUp()
        contractStore = InMemoryAccountDataRemoteStore()
        firestoreStore = FirestoreAccountDataRemoteStore()
    }

    // MARK: - UserId mismatch (FirestoreAccountDataRemoteStore)

    func testSaveDailyLogRejectsUserIdMismatch() async throws {
        let document = FirestoreAccountDataRemoteStoreTestFixtures.dailyLog(
            userId: userB,
            localDate: localDate,
            referenceDate: referenceDate
        )

        await XCTAssertThrowsErrorAsync(
            try await firestoreStore.saveDailyLog(document, uid: userA)
        ) { error in
            XCTAssertEqual(
                error as? AccountDataRemoteStoreError,
                .userIdMismatch(expected: userA, actual: userB)
            )
        }
    }

    func testSaveFoodEntryRejectsUserIdMismatch() async throws {
        let document = FirestoreAccountDataRemoteStoreTestFixtures.foodEntry(
            userId: userB,
            localDate: localDate,
            referenceDate: referenceDate
        )

        await XCTAssertThrowsErrorAsync(
            try await firestoreStore.saveFoodEntry(document, uid: userA)
        ) { error in
            XCTAssertEqual(
                error as? AccountDataRemoteStoreError,
                .userIdMismatch(expected: userA, actual: userB)
            )
        }
    }

    func testSaveWaterEntryRejectsUserIdMismatch() async throws {
        let document = FirestoreAccountDataRemoteStoreTestFixtures.waterEntry(
            userId: userB,
            localDate: localDate,
            referenceDate: referenceDate
        )

        await XCTAssertThrowsErrorAsync(
            try await firestoreStore.saveWaterEntry(document, uid: userA)
        ) { error in
            XCTAssertEqual(
                error as? AccountDataRemoteStoreError,
                .userIdMismatch(expected: userA, actual: userB)
            )
        }
    }

    func testSaveWeightEntryRejectsUserIdMismatch() async throws {
        let document = FirestoreAccountDataRemoteStoreTestFixtures.weightEntry(
            userId: userB,
            localDate: localDate,
            referenceDate: referenceDate,
            entryId: "weight1"
        )

        await XCTAssertThrowsErrorAsync(
            try await firestoreStore.saveWeightEntry(document, uid: userA)
        ) { error in
            XCTAssertEqual(
                error as? AccountDataRemoteStoreError,
                .userIdMismatch(expected: userA, actual: userB)
            )
        }
    }

    func testSaveDailyReviewRejectsUserIdMismatch() async throws {
        let document = FirestoreAccountDataRemoteStoreTestFixtures.dailyReview(
            userId: userB,
            localDate: localDate,
            referenceDate: referenceDate
        )

        await XCTAssertThrowsErrorAsync(
            try await firestoreStore.saveDailyReview(document, uid: userA)
        ) { error in
            XCTAssertEqual(
                error as? AccountDataRemoteStoreError,
                .userIdMismatch(expected: userA, actual: userB)
            )
        }
    }

    // MARK: - Protocol contract (InMemoryAccountDataRemoteStore)

    func testSaveAndFetchDailyLog() async throws {
        let document = FirestoreAccountDataRemoteStoreTestFixtures.dailyLog(
            userId: userA,
            localDate: localDate,
            referenceDate: referenceDate
        )

        try await contractStore.saveDailyLog(document, uid: userA)
        let fetched = try await contractStore.fetchDailyLog(uid: userA, localDate: localDate)

        XCTAssertNotNil(fetched)
        XCTAssertEqual(fetched?.id, localDate)
        XCTAssertEqual(fetched?.userId, userA)
        XCTAssertEqual(fetched?.localDate, localDate)
        XCTAssertEqual(fetched?.caloriesConsumed, document.caloriesConsumed)
        XCTAssertEqual(fetched?.proteinConsumed, document.proteinConsumed)
        XCTAssertEqual(fetched?.carbsConsumed, document.carbsConsumed)
        XCTAssertEqual(fetched?.fatConsumed, document.fatConsumed)
    }

    func testSaveAndFetchFoodEntriesForDate() async throws {
        let food1 = FirestoreAccountDataRemoteStoreTestFixtures.foodEntry(
            userId: userA,
            localDate: localDate,
            referenceDate: referenceDate,
            entryId: "food1"
        )
        let food2 = FirestoreAccountDataRemoteStoreTestFixtures.foodEntry(
            userId: userA,
            localDate: localDate,
            referenceDate: referenceDate,
            entryId: "food2"
        )

        try await contractStore.saveFoodEntry(food1, uid: userA)
        try await contractStore.saveFoodEntry(food2, uid: userA)

        let fetched = try await contractStore.fetchFoodEntries(uid: userA, localDate: localDate)
        XCTAssertEqual(fetched.count, 2)
        XCTAssertEqual(Set(fetched.map(\.id)), Set(["food1", "food2"]))
    }

    func testFoodEntriesAreScopedByDate() async throws {
        let july4Food = FirestoreAccountDataRemoteStoreTestFixtures.foodEntry(
            userId: userA,
            localDate: localDate,
            referenceDate: referenceDate,
            entryId: "food-july4"
        )
        let july5Food = FirestoreAccountDataRemoteStoreTestFixtures.foodEntry(
            userId: userA,
            localDate: otherDate,
            referenceDate: referenceDate,
            entryId: "food-july5"
        )

        try await contractStore.saveFoodEntry(july4Food, uid: userA)
        try await contractStore.saveFoodEntry(july5Food, uid: userA)

        let fetched = try await contractStore.fetchFoodEntries(uid: userA, localDate: localDate)
        XCTAssertEqual(fetched.count, 1)
        XCTAssertEqual(fetched.first?.id, "food-july4")
        XCTAssertEqual(fetched.first?.localDate, localDate)
    }

    func testSaveAndFetchWaterEntriesForDate() async throws {
        let water1 = FirestoreAccountDataRemoteStoreTestFixtures.waterEntry(
            userId: userA,
            localDate: localDate,
            referenceDate: referenceDate,
            entryId: "water1"
        )
        let water2 = FirestoreAccountDataRemoteStoreTestFixtures.waterEntry(
            userId: userA,
            localDate: localDate,
            referenceDate: referenceDate,
            entryId: "water2"
        )

        try await contractStore.saveWaterEntry(water1, uid: userA)
        try await contractStore.saveWaterEntry(water2, uid: userA)

        let fetched = try await contractStore.fetchWaterEntries(uid: userA, localDate: localDate)
        XCTAssertEqual(fetched.count, 2)
        XCTAssertEqual(Set(fetched.map(\.id)), Set(["water1", "water2"]))
        XCTAssertTrue(fetched.allSatisfy { $0.userId == userA && $0.localDate == localDate })
    }

    func testSaveAndFetchWeightEntries() async throws {
        let weight = FirestoreAccountDataRemoteStoreTestFixtures.weightEntry(
            userId: userA,
            localDate: localDate,
            referenceDate: referenceDate,
            entryId: "weight1"
        )

        try await contractStore.saveWeightEntry(weight, uid: userA)

        let all = try await contractStore.fetchWeightEntries(uid: userA, from: nil, to: nil)
        let ranged = try await contractStore.fetchWeightEntries(
            uid: userA,
            from: localDate,
            to: localDate
        )

        XCTAssertEqual(all.count, 1)
        XCTAssertEqual(all.first?.id, "weight1")
        XCTAssertEqual(all.first?.userId, userA)
        XCTAssertEqual(all.first?.weightKg, 68.4)
        XCTAssertEqual(ranged, all)
    }

    func testSaveAndFetchDailyReview() async throws {
        let review = FirestoreAccountDataRemoteStoreTestFixtures.dailyReview(
            userId: userA,
            localDate: localDate,
            referenceDate: referenceDate
        )

        try await contractStore.saveDailyReview(review, uid: userA)
        let fetched = try await contractStore.fetchDailyReview(uid: userA, localDate: localDate)

        XCTAssertEqual(fetched, review)
        XCTAssertEqual(fetched?.userId, userA)
        XCTAssertEqual(fetched?.localDate, localDate)
        XCTAssertEqual(fetched?.summaryText, "Solid day")
    }

    func testSaveAndFetchSyncMetadata() async throws {
        let metadata = FirestoreAccountDataRemoteStoreTestFixtures.syncMetadata(
            userId: userA,
            referenceDate: referenceDate
        )

        try await contractStore.saveSyncMetadata(metadata, uid: userA)
        let fetched = try await contractStore.fetchSyncMetadata(uid: userA)

        XCTAssertEqual(fetched, metadata)
        XCTAssertEqual(fetched?.userId, userA)
        XCTAssertEqual(fetched?.lastSuccessfulPushAt, referenceDate)
    }

    func testDeleteFoodEntryRemovesOnlyThatEntry() async throws {
        let food1 = FirestoreAccountDataRemoteStoreTestFixtures.foodEntry(
            userId: userA,
            localDate: localDate,
            referenceDate: referenceDate,
            entryId: "food1"
        )
        let food2 = FirestoreAccountDataRemoteStoreTestFixtures.foodEntry(
            userId: userA,
            localDate: localDate,
            referenceDate: referenceDate,
            entryId: "food2"
        )

        try await contractStore.saveFoodEntry(food1, uid: userA)
        try await contractStore.saveFoodEntry(food2, uid: userA)
        try await contractStore.deleteFoodEntry(uid: userA, localDate: localDate, entryId: "food1")

        let remaining = try await contractStore.fetchFoodEntries(uid: userA, localDate: localDate)
        XCTAssertEqual(remaining.count, 1)
        XCTAssertEqual(remaining.first?.id, "food2")
    }

    func testDeleteWaterEntryRemovesOnlyThatEntry() async throws {
        let water1 = FirestoreAccountDataRemoteStoreTestFixtures.waterEntry(
            userId: userA,
            localDate: localDate,
            referenceDate: referenceDate,
            entryId: "water1"
        )
        let water2 = FirestoreAccountDataRemoteStoreTestFixtures.waterEntry(
            userId: userA,
            localDate: localDate,
            referenceDate: referenceDate,
            entryId: "water2"
        )

        try await contractStore.saveWaterEntry(water1, uid: userA)
        try await contractStore.saveWaterEntry(water2, uid: userA)
        try await contractStore.deleteWaterEntry(uid: userA, localDate: localDate, entryId: "water1")

        let remaining = try await contractStore.fetchWaterEntries(uid: userA, localDate: localDate)
        XCTAssertEqual(remaining.count, 1)
        XCTAssertEqual(remaining.first?.id, "water2")
    }

    func testDeleteWeightEntryRemovesOnlyThatEntry() async throws {
        let weight1 = FirestoreAccountDataRemoteStoreTestFixtures.weightEntry(
            userId: userA,
            localDate: localDate,
            referenceDate: referenceDate,
            entryId: "weight1"
        )
        let weight2 = FirestoreAccountDataRemoteStoreTestFixtures.weightEntry(
            userId: userA,
            localDate: "2026-07-03",
            referenceDate: referenceDate,
            entryId: "weight2"
        )

        try await contractStore.saveWeightEntry(weight1, uid: userA)
        try await contractStore.saveWeightEntry(weight2, uid: userA)
        try await contractStore.deleteWeightEntry(uid: userA, entryId: "weight1")

        let remaining = try await contractStore.fetchWeightEntries(uid: userA, from: nil, to: nil)
        XCTAssertEqual(remaining.count, 1)
        XCTAssertEqual(remaining.first?.id, "weight2")
    }
}

// MARK: - Fixtures

enum FirestoreAccountDataRemoteStoreTestFixtures {

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
        entryId: String = "food1"
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
        entryId: String = "water1"
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
