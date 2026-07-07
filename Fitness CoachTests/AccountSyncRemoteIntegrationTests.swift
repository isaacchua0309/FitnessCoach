//
//  AccountSyncRemoteIntegrationTests.swift
//  Fitness CoachTests
//
//  Forma — Phase 3 sync ↔ Phase 2 remote store integration tests.
//
//  Emulator limitation
//  -------------------
//  These tests exercise the full uploader/puller stack through the
//  `AccountDataRemoteStore` protocol using `InMemoryAccountDataRemoteStore`.
//  A Firestore emulator harness is not wired in this target (see
//  `FirestoreAccountDataRemoteStoreTests` and
//  `Docs/AccountPersistence/PHASE_2_CLOUD_SCHEMA_AND_RULES.md`). Production
//  `FirestoreAccountDataRemoteStore` pre-write validation is covered separately;
//  round-trip save/fetch/delete scoping is validated here via the protocol double
//  that implements the same contract.
//

import XCTest
import SwiftData
@testable import Fitness_Coach

@MainActor
final class AccountSyncRemoteIntegrationTests: XCTestCase {

    private var harness: RemoteSyncHarness!

    private let userA = "userA"
    private let userB = "userB"
    private let referenceDate = ProfileFixtures.referenceDate
    private var localDate: String!

    override func setUp() async throws {
        try await super.setUp()
        harness = try RemoteSyncHarness.make(referenceDate: referenceDate)
        localDate = harness.localDate
    }

    // MARK: - Upload round-trips

    func testUploadFoodThenFetchFromRemoteStore() async throws {
        let foodID = UUID()
        let dailyLog = try harness.seedDailyLog(ownerUID: userA, caloriesConsumed: 400)
        let food = try harness.seedFood(
            id: foodID,
            dailyLog: dailyLog,
            ownerUID: userA,
            name: "Grilled chicken",
            calories: 400
        )

        try await harness.upload(
            ownerUID: userA,
            entityType: .foodEntry,
            entityId: foodID.uuidString,
            localDate: localDate
        )

        let remoteEntries = try await harness.remoteStore.fetchFoodEntries(uid: userA, localDate: localDate)
        XCTAssertEqual(remoteEntries.count, 1)
        let remote = try XCTUnwrap(remoteEntries.first)
        XCTAssertEqual(remote.id, foodID.uuidString)
        XCTAssertEqual(remote.userId, userA)
        XCTAssertEqual(remote.name, "Grilled chicken")
        XCTAssertEqual(remote.calories, 400)
        XCTAssertNil(remote.imageUrl)
        XCTAssertNoRawImageFields(in: remote)
        XCTAssertEqual(food.syncStatus, .synced)
    }

    func testUploadWaterThenFetchFromRemoteStore() async throws {
        let waterID = UUID()
        let dailyLog = try harness.seedDailyLog(ownerUID: userA, waterConsumedMl: 475)
        let water = try harness.seedWater(
            id: waterID,
            dailyLog: dailyLog,
            ownerUID: userA,
            amountMl: 475
        )

        try await harness.upload(
            ownerUID: userA,
            entityType: .waterEntry,
            entityId: waterID.uuidString,
            localDate: localDate
        )

        let remoteEntries = try await harness.remoteStore.fetchWaterEntries(uid: userA, localDate: localDate)
        XCTAssertEqual(remoteEntries.count, 1)
        let remote = try XCTUnwrap(remoteEntries.first)
        XCTAssertEqual(remote.id, waterID.uuidString)
        XCTAssertEqual(remote.userId, userA)
        XCTAssertEqual(remote.amountMl, 475)
        XCTAssertEqual(water.syncStatus, .synced)
    }

    func testUploadWeightThenFetchFromRemoteStore() async throws {
        let weightID = UUID()
        let weight = try harness.seedWeight(
            id: weightID,
            ownerUID: userA,
            weightKg: 67.8,
            note: "Morning"
        )

        try await harness.upload(
            ownerUID: userA,
            entityType: .weightEntry,
            entityId: weightID.uuidString,
            localDate: localDate
        )

        let remoteEntries = try await harness.remoteStore.fetchWeightEntries(
            uid: userA,
            from: localDate,
            to: localDate
        )
        XCTAssertEqual(remoteEntries.count, 1)
        let remote = try XCTUnwrap(remoteEntries.first)
        XCTAssertEqual(remote.id, weightID.uuidString)
        XCTAssertEqual(remote.userId, userA)
        XCTAssertEqual(remote.weightKg, 67.8)
        XCTAssertEqual(remote.localDate, localDate)
        XCTAssertEqual(weight.syncStatus, .synced)
    }

    func testUploadDailyLogThenFetchFromRemoteStore() async throws {
        _ = try harness.seedDailyLog(
            ownerUID: userA,
            caloriesConsumed: 610,
            proteinConsumed: 45,
            carbsConsumed: 52,
            fatConsumed: 18
        )

        try await harness.upload(
            ownerUID: userA,
            entityType: .dailyLog,
            entityId: localDate,
            localDate: localDate
        )

        let remote = try await harness.remoteStore.fetchDailyLog(uid: userA, localDate: localDate)
        let document = try XCTUnwrap(remote)
        XCTAssertEqual(document.userId, userA)
        XCTAssertEqual(document.localDate, localDate)
        XCTAssertEqual(document.caloriesConsumed, 610)
        XCTAssertEqual(document.proteinConsumed, 45)
        XCTAssertEqual(document.carbsConsumed, 52)
        XCTAssertEqual(document.fatConsumed, 18)
    }

    func testUploadDailyReviewThenFetchFromRemoteStore() async throws {
        let dailyLog = try harness.seedDailyLog(ownerUID: userA)
        _ = try harness.seedDailyReview(
            dailyLog: dailyLog,
            ownerUID: userA,
            summaryText: "Strong protein day"
        )

        try await harness.upload(
            ownerUID: userA,
            entityType: .dailyReview,
            entityId: localDate,
            localDate: localDate
        )

        let remote = try await harness.remoteStore.fetchDailyReview(uid: userA, localDate: localDate)
        let document = try XCTUnwrap(remote)
        XCTAssertEqual(document.userId, userA)
        XCTAssertEqual(document.localDate, localDate)
        XCTAssertEqual(document.summaryText, "Strong protein day")
    }

    func testDeleteFoodPropagatesToRemoteStore() async throws {
        let foodID = UUID()
        let dailyLog = try harness.seedDailyLog(ownerUID: userA)
        let food = try harness.seedFood(id: foodID, dailyLog: dailyLog, ownerUID: userA)

        try await harness.upload(
            ownerUID: userA,
            entityType: .foodEntry,
            entityId: foodID.uuidString,
            localDate: localDate
        )
        let remoteFoodEntriesBeforeDelete = try await harness.remoteStore.fetchFoodEntries(uid: userA, localDate: localDate)
        XCTAssertEqual(remoteFoodEntriesBeforeDelete.count, 1)

        food.deletedAt = referenceDate
        food.syncStatus = .pendingDelete
        try harness.store.save()

        try await harness.upload(
            ownerUID: userA,
            entityType: .foodEntry,
            entityId: foodID.uuidString,
            localDate: localDate,
            operation: .delete
        )

        let remoteFoodEntriesAfterDelete = try await harness.remoteStore.fetchFoodEntries(uid: userA, localDate: localDate)
        XCTAssertEqual(remoteFoodEntriesAfterDelete.count, 0)
        XCTAssertNil(try harness.fetchFoodEntity(id: foodID))
    }

    // MARK: - Pull round-trips

    func testPullRemoteFoodIntoEmptyLocalStore() async throws {
        let foodID = UUID().uuidString
        let remoteDailyLog = FirestoreAccountDataRemoteStoreTestFixtures.dailyLog(
            userId: userA,
            localDate: localDate,
            referenceDate: referenceDate
        )
        let remoteFood = FirestoreAccountDataRemoteStoreTestFixtures.foodEntry(
            userId: userA,
            localDate: localDate,
            referenceDate: referenceDate,
            entryId: foodID
        )
        try await harness.remoteStore.saveDailyLog(remoteDailyLog, uid: userA)
        try await harness.remoteStore.saveFoodEntry(remoteFood, uid: userA)

        let pullHarness = try RemoteSyncHarness.make(
            referenceDate: referenceDate,
            remoteStore: harness.remoteStore
        )
        let summary = await pullHarness.puller.pullRecentAccountData(
            for: userA,
            from: localDate,
            to: localDate
        )

        XCTAssertEqual(summary.foodEntriesFetched, 1)
        XCTAssertGreaterThanOrEqual(summary.inserted, 1)

        let localFood = try XCTUnwrap(pullHarness.fetchFoodEntity(id: foodID))
        XCTAssertEqual(localFood.name, "Salad")
        XCTAssertEqual(localFood.ownerUID, userA)
        XCTAssertEqual(localFood.syncStatus, .synced)
        XCTAssertNil(localFood.imageUrl)
    }

    func testPullRemoteWeightIntoEmptyLocalStore() async throws {
        let weightID = UUID().uuidString
        let remoteWeight = FirestoreAccountDataRemoteStoreTestFixtures.weightEntry(
            userId: userA,
            localDate: localDate,
            referenceDate: referenceDate,
            entryId: weightID
        )
        try await harness.remoteStore.saveWeightEntry(remoteWeight, uid: userA)

        let pullHarness = try RemoteSyncHarness.make(
            referenceDate: referenceDate,
            remoteStore: harness.remoteStore
        )
        let summary = await pullHarness.puller.pullRecentAccountData(
            for: userA,
            from: localDate,
            to: localDate
        )

        XCTAssertEqual(summary.weightEntriesFetched, 1)
        XCTAssertEqual(summary.inserted, 1)

        let localWeight = try XCTUnwrap(pullHarness.fetchWeightEntity(id: weightID))
        XCTAssertEqual(localWeight.weightKg, 68.4)
        XCTAssertEqual(localWeight.ownerUID, userA)
        XCTAssertEqual(localWeight.syncStatus, .synced)
    }

    func testUserBDoesNotPullUserARemoteData() async throws {
        let foodID = UUID().uuidString
        let remoteDailyLog = FirestoreAccountDataRemoteStoreTestFixtures.dailyLog(
            userId: userA,
            localDate: localDate,
            referenceDate: referenceDate
        )
        let remoteFood = FirestoreAccountDataRemoteStoreTestFixtures.foodEntry(
            userId: userA,
            localDate: localDate,
            referenceDate: referenceDate,
            entryId: foodID
        )
        try await harness.remoteStore.saveDailyLog(remoteDailyLog, uid: userA)
        try await harness.remoteStore.saveFoodEntry(remoteFood, uid: userA)

        let pullHarness = try RemoteSyncHarness.make(
            referenceDate: referenceDate,
            remoteStore: harness.remoteStore
        )
        let summary = await pullHarness.puller.pullRecentAccountData(
            for: userB,
            from: localDate,
            to: localDate
        )

        XCTAssertEqual(summary.foodEntriesFetched, 0)
        XCTAssertEqual(summary.inserted, 0)
        XCTAssertNil(pullHarness.fetchFoodEntity(id: foodID))
        XCTAssertTrue(try pullHarness.store.fetch(FetchDescriptor<FoodEntryEntity>()).isEmpty)

        let userBFood = try await harness.remoteStore.fetchFoodEntries(uid: userB, localDate: localDate)
        XCTAssertTrue(userBFood.isEmpty)
    }
}

// MARK: - Harness

@MainActor
private struct RemoteSyncHarness {

    let store: SwiftDataStore
    let outbox: SwiftDataAccountSyncOutboxStore
    let payloadBuilder: SwiftDataAccountSyncPayloadBuilder
    let remoteStore: InMemoryAccountDataRemoteStore
    let uploader: AccountSyncUploader
    let puller: AccountSyncPuller
    let calendar: Calendar
    let referenceDate: Date
    let localDate: String

    static func make(
        referenceDate: Date = ProfileFixtures.referenceDate,
        remoteStore: InMemoryAccountDataRemoteStore? = nil
    ) throws -> RemoteSyncHarness {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(secondsFromGMT: 0)!
        let localDate = CloudAccountDataDateCodec.localDateString(from: referenceDate, calendar: calendar)

        let container = try FormaModelContainer.makeContainer(inMemory: true)
        let store = SwiftDataStore(container: container)
        let outbox = SwiftDataAccountSyncOutboxStore(store: store)
        let payloadBuilder = SwiftDataAccountSyncPayloadBuilder(store: store, calendar: calendar)
        let resolvedRemoteStore = remoteStore ?? InMemoryAccountDataRemoteStore()

        let uploader = AccountSyncUploader(
            outbox: outbox,
            payloadBuilder: payloadBuilder,
            remoteStore: resolvedRemoteStore,
            store: store,
            calendar: calendar,
            nowProvider: { referenceDate }
        )
        let puller = AccountSyncPuller(
            remoteStore: resolvedRemoteStore,
            store: store,
            calendar: calendar,
            nowProvider: { referenceDate }
        )

        return RemoteSyncHarness(
            store: store,
            outbox: outbox,
            payloadBuilder: payloadBuilder,
            remoteStore: resolvedRemoteStore,
            uploader: uploader,
            puller: puller,
            calendar: calendar,
            referenceDate: referenceDate,
            localDate: localDate
        )
    }

    func upload(
        ownerUID: String,
        entityType: AccountSyncEntityType,
        entityId: String,
        localDate: String,
        operation: AccountSyncOperation = .upsert
    ) async throws {
        try outbox.enqueueLocalMutation(
            ownerUID: ownerUID,
            entityType: entityType,
            entityId: entityId,
            localDate: localDate,
            operation: operation,
            mutationGroupId: nil
        )
        let summary = await uploader.uploadDueMutations(for: ownerUID, limit: 10)
        XCTAssertEqual(summary.succeeded, 1, "Expected upload to succeed for \(entityType.rawValue)")
        XCTAssertEqual(summary.failed, 0)
    }

    @discardableResult
    func seedDailyLog(
        ownerUID: String,
        caloriesConsumed: Int = 0,
        proteinConsumed: Int = 0,
        carbsConsumed: Int = 0,
        fatConsumed: Int = 0,
        waterConsumedMl: Int = 0
    ) throws -> DailyLogEntity {
        let entity = DailyLogEntity(
            id: UUID(),
            ownerUID: ownerUID,
            date: referenceDate,
            weightKg: nil,
            calorieTarget: 2_000,
            proteinTarget: 140,
            carbTarget: 180,
            fatTarget: 65,
            waterTargetMl: 2_500,
            expectedWeeklyWeightLossKg: 0.5,
            aggressivenessRawValue: CalorieAggressiveness.moderate.rawValue,
            caloriesConsumed: caloriesConsumed,
            proteinConsumed: proteinConsumed,
            carbsConsumed: carbsConsumed,
            fatConsumed: fatConsumed,
            fiberConsumed: nil,
            sodiumConsumed: nil,
            waterConsumedMl: waterConsumedMl,
            steps: nil,
            workoutCaloriesBurned: 0,
            dailyReviewId: nil,
            createdAt: referenceDate,
            updatedAt: referenceDate
        )
        try store.insert(entity)
        return entity
    }

    @discardableResult
    func seedFood(
        id: UUID,
        dailyLog: DailyLogEntity,
        ownerUID: String,
        name: String = "Meal",
        calories: Int = 400
    ) throws -> FoodEntryEntity {
        let food = FoodEntryEntity(
            id: id,
            ownerUID: ownerUID,
            dailyLogId: dailyLog.id,
            mealTypeRawValue: MealType.lunch.rawValue,
            name: name,
            quantity: 1,
            unit: "bowl",
            calories: calories,
            protein: 20,
            carbs: 30,
            fat: 12,
            fiber: nil,
            sodium: nil,
            sourceRawValue: FoodEntrySource.manual.rawValue,
            confidenceRawValue: ConfidenceLevel.high.rawValue,
            imageUrl: nil,
            notes: nil,
            createdAt: referenceDate,
            updatedAt: referenceDate
        )
        food.dailyLog = dailyLog
        try store.insert(food)
        return food
    }

    @discardableResult
    func seedWater(
        id: UUID,
        dailyLog: DailyLogEntity,
        ownerUID: String,
        amountMl: Int
    ) throws -> WaterEntryEntity {
        let water = WaterEntryEntity(
            id: id,
            ownerUID: ownerUID,
            dailyLogId: dailyLog.id,
            amountMl: amountMl,
            createdAt: referenceDate
        )
        water.dailyLog = dailyLog
        try store.insert(water)
        return water
    }

    @discardableResult
    func seedWeight(
        id: UUID,
        ownerUID: String,
        weightKg: Double,
        note: String?
    ) throws -> WeightEntryEntity {
        let weight = WeightEntryEntity(
            id: id,
            ownerUID: ownerUID,
            date: referenceDate,
            weightKg: weightKg,
            note: note,
            createdAt: referenceDate
        )
        try store.insert(weight)
        return weight
    }

    @discardableResult
    func seedDailyReview(
        dailyLog: DailyLogEntity,
        ownerUID: String,
        summaryText: String
    ) throws -> DailyReviewEntity {
        let review = DailyReviewEntity(
            id: UUID(),
            ownerUID: ownerUID,
            dailyLogId: dailyLog.id,
            summaryText: summaryText,
            caloriesSummary: "On target",
            proteinSummary: "High",
            hydrationSummary: "Good",
            workoutSummary: nil,
            weightSummary: nil,
            tomorrowRecommendation: "Repeat",
            createdAt: referenceDate
        )
        review.dailyLog = dailyLog
        dailyLog.dailyReview = review
        dailyLog.dailyReviewId = review.id
        try store.insert(review)
        return review
    }

    func fetchFoodEntity(id: String) -> FoodEntryEntity? {
        guard let uuid = UUID(uuidString: id) else { return nil }
        var descriptor = FetchDescriptor<FoodEntryEntity>(predicate: #Predicate { $0.id == uuid })
        descriptor.fetchLimit = 1
        return try? store.fetchOne(descriptor)
    }

    func fetchFoodEntity(id: UUID) throws -> FoodEntryEntity? {
        var descriptor = FetchDescriptor<FoodEntryEntity>(predicate: #Predicate { $0.id == id })
        descriptor.fetchLimit = 1
        return try store.fetchOne(descriptor)
    }

    func fetchWeightEntity(id: String) -> WeightEntryEntity? {
        guard let uuid = UUID(uuidString: id) else { return nil }
        var descriptor = FetchDescriptor<WeightEntryEntity>(predicate: #Predicate { $0.id == uuid })
        descriptor.fetchLimit = 1
        return try? store.fetchOne(descriptor)
    }
}

// MARK: - Assertions

private func XCTAssertNoRawImageFields(
    in document: CloudFoodEntryDocument,
    file: StaticString = #filePath,
    line: UInt = #line
) {
    XCTAssertNil(document.imageUrl, file: file, line: line)
    XCTAssertFalse(
        Mirror(reflecting: document).children.contains { $0.label == "imageBytes" },
        file: file,
        line: line
    )
    XCTAssertFalse(
        Mirror(reflecting: document).children.contains { $0.label == "imageData" },
        file: file,
        line: line
    )
}
