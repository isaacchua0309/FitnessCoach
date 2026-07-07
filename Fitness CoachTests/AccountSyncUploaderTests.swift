//
//  AccountSyncUploaderTests.swift
//  Fitness CoachTests
//
//  Forma — Account sync uploader tests (Phase 3).
//

import XCTest
import SwiftData
@testable import Fitness_Coach

@MainActor
final class AccountSyncUploaderTests: XCTestCase {

    private var store: SwiftDataStore!
    private var outbox: SwiftDataAccountSyncOutboxStore!
    private var payloadBuilder: SwiftDataAccountSyncPayloadBuilder!
    private var remoteStore: InMemoryAccountDataRemoteStore!
    private var uploader: AccountSyncUploader!
    private var calendar: Calendar!
    private var localDate: String!

    private let ownerUID = "userA"
    private let otherUID = "userB"
    private let referenceDate = ProfileFixtures.referenceDate

    override func setUp() async throws {
        try await super.setUp()
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(secondsFromGMT: 0)!
        self.calendar = calendar
        localDate = CloudAccountDataDateCodec.localDateString(from: referenceDate, calendar: calendar)

        let container = try FormaModelContainer.makeContainer(inMemory: true)
        store = SwiftDataStore(container: container)
        outbox = SwiftDataAccountSyncOutboxStore(store: store)
        payloadBuilder = SwiftDataAccountSyncPayloadBuilder(store: store, calendar: calendar)
        remoteStore = InMemoryAccountDataRemoteStore()
        uploader = AccountSyncUploader(
            outbox: outbox,
            payloadBuilder: payloadBuilder,
            remoteStore: remoteStore,
            store: store,
            calendar: calendar,
            nowProvider: { self.referenceDate }
        )
    }

    func testUploaderUploadsDueFoodMutation() async throws {
        let foodID = UUID()
        let dailyLog = try seedDailyLog(ownerUID: ownerUID)
        _ = try seedFood(id: foodID, dailyLog: dailyLog, ownerUID: ownerUID)

        try outbox.enqueueLocalMutation(
            ownerUID: ownerUID,
            entityType: .foodEntry,
            entityId: foodID.uuidString,
            localDate: localDate,
            operation: .upsert,
            mutationGroupId: nil
        )

        let summary = await uploader.uploadDueMutations(for: ownerUID, limit: 10)

        XCTAssertEqual(summary.succeeded, 1)
        XCTAssertEqual(summary.failed, 0)
        let remoteEntries = try await remoteStore.fetchFoodEntries(uid: ownerUID, localDate: localDate)
        XCTAssertEqual(remoteEntries.count, 1)
        XCTAssertEqual(remoteEntries.first?.id, foodID.uuidString)
        XCTAssertEqual(remoteEntries.first?.userId, ownerUID)
    }

    func testUploaderMarksMutationSucceeded() async throws {
        let foodID = UUID()
        let dailyLog = try seedDailyLog(ownerUID: ownerUID)
        _ = try seedFood(id: foodID, dailyLog: dailyLog, ownerUID: ownerUID)

        try outbox.enqueueLocalMutation(
            ownerUID: ownerUID,
            entityType: .foodEntry,
            entityId: foodID.uuidString,
            localDate: localDate,
            operation: .upsert,
            mutationGroupId: nil
        )

        let dueMutations = try await outbox.fetchDueMutations(ownerUID: ownerUID, limit: 1, now: referenceDate)
        let mutationID = try XCTUnwrap(dueMutations.first?.id)

        _ = await uploader.uploadDueMutations(for: ownerUID, limit: 10)

        let entity = try XCTUnwrap(fetchMutationEntity(id: mutationID))
        XCTAssertEqual(entity.status, .succeeded)
        XCTAssertNil(entity.lastError)
        XCTAssertNil(entity.nextRetryAt)
    }

    func testUploaderMarksEntitySynced() async throws {
        let foodID = UUID()
        let dailyLog = try seedDailyLog(ownerUID: ownerUID)
        let food = try seedFood(id: foodID, dailyLog: dailyLog, ownerUID: ownerUID)

        try outbox.enqueueLocalMutation(
            ownerUID: ownerUID,
            entityType: .foodEntry,
            entityId: foodID.uuidString,
            localDate: localDate,
            operation: .upsert,
            mutationGroupId: nil
        )

        _ = await uploader.uploadDueMutations(for: ownerUID, limit: 10)

        XCTAssertEqual(food.syncStatus, .synced)
        XCTAssertNotNil(food.lastSyncedAt)
        XCTAssertNotNil(food.cloudUpdatedAt)
        XCTAssertEqual(food.cloudId, foodID.uuidString)
        XCTAssertNil(food.lastSyncError)
        XCTAssertEqual(food.syncAttemptCount, 0)
    }

    func testUploaderLeavesFailedMutationRetryable() async throws {
        let foodID = UUID()
        let dailyLog = try seedDailyLog(ownerUID: ownerUID)
        _ = try seedFood(id: foodID, dailyLog: dailyLog, ownerUID: otherUID)

        try outbox.enqueueLocalMutation(
            ownerUID: ownerUID,
            entityType: .foodEntry,
            entityId: foodID.uuidString,
            localDate: localDate,
            operation: .upsert,
            mutationGroupId: nil
        )

        let dueMutations = try await outbox.fetchDueMutations(ownerUID: ownerUID, limit: 1, now: referenceDate)
        let mutationID = try XCTUnwrap(dueMutations.first?.id)

        let summary = await uploader.uploadDueMutations(for: ownerUID, limit: 10)

        XCTAssertEqual(summary.failed, 1)
        let mutationEntity = try XCTUnwrap(fetchMutationEntity(id: mutationID))
        XCTAssertEqual(mutationEntity.status, .failed)
        XCTAssertEqual(mutationEntity.attemptCount, 1)
        XCTAssertNotNil(mutationEntity.nextRetryAt)
        XCTAssertNotNil(mutationEntity.lastError)

        let beforeRetry = try await outbox.fetchDueMutations(
            ownerUID: ownerUID,
            limit: 10,
            now: referenceDate.addingTimeInterval(10)
        )
        XCTAssertTrue(beforeRetry.isEmpty)
    }

    func testUploaderNeverUploadsOtherUserMutation() async throws {
        let foodA = UUID()
        let foodB = UUID()
        let logA = try seedDailyLog(ownerUID: ownerUID)
        let logB = try seedDailyLog(ownerUID: otherUID, date: referenceDate.addingTimeInterval(86_400))
        _ = try seedFood(id: foodA, dailyLog: logA, ownerUID: ownerUID)
        _ = try seedFood(id: foodB, dailyLog: logB, ownerUID: otherUID)

        try outbox.enqueueLocalMutation(
            ownerUID: ownerUID,
            entityType: .foodEntry,
            entityId: foodA.uuidString,
            localDate: localDate,
            operation: .upsert,
            mutationGroupId: nil
        )
        let otherLocalDate = CloudAccountDataDateCodec.localDateString(
            from: referenceDate.addingTimeInterval(86_400),
            calendar: calendar
        )
        try outbox.enqueueLocalMutation(
            ownerUID: otherUID,
            entityType: .foodEntry,
            entityId: foodB.uuidString,
            localDate: otherLocalDate,
            operation: .upsert,
            mutationGroupId: nil
        )

        let summary = await uploader.uploadDueMutations(for: ownerUID, limit: 10)

        XCTAssertEqual(summary.succeeded, 1)
        let ownerFoodEntries = try await remoteStore.fetchFoodEntries(uid: ownerUID, localDate: localDate)
        let otherFoodEntries = try await remoteStore.fetchFoodEntries(uid: otherUID, localDate: otherLocalDate)
        XCTAssertEqual(ownerFoodEntries.count, 1)
        XCTAssertEqual(otherFoodEntries.count, 0)
    }

    func testUploaderContinuesAfterOneFailure() async throws {
        let successID = UUID()
        let failureID = UUID()
        let dailyLog = try seedDailyLog(ownerUID: ownerUID)
        _ = try seedFood(id: successID, dailyLog: dailyLog, ownerUID: ownerUID, name: "Good")
        _ = try seedFood(id: failureID, dailyLog: dailyLog, ownerUID: otherUID, name: "Bad")

        try outbox.enqueueLocalMutation(
            ownerUID: ownerUID,
            entityType: .foodEntry,
            entityId: failureID.uuidString,
            localDate: localDate,
            operation: .upsert,
            mutationGroupId: nil
        )
        try outbox.enqueueLocalMutation(
            ownerUID: ownerUID,
            entityType: .foodEntry,
            entityId: successID.uuidString,
            localDate: localDate,
            operation: .upsert,
            mutationGroupId: nil
        )

        let summary = await uploader.uploadDueMutations(for: ownerUID, limit: 10)

        XCTAssertEqual(summary.attempted, 2)
        XCTAssertEqual(summary.succeeded, 1)
        XCTAssertEqual(summary.failed, 1)
        let uploadedFoodEntries = try await remoteStore.fetchFoodEntries(uid: ownerUID, localDate: localDate)
        XCTAssertEqual(uploadedFoodEntries.count, 1)
        XCTAssertEqual(uploadedFoodEntries.first?.name, "Good")
    }

    func testUploaderDeletesRemoteFoodEntryForPendingDelete() async throws {
        let foodID = UUID()
        let dailyLog = try seedDailyLog(ownerUID: ownerUID)
        let food = try seedFood(id: foodID, dailyLog: dailyLog, ownerUID: ownerUID)
        food.deletedAt = referenceDate
        food.syncStatus = .pendingDelete
        try store.save()

        let document = try CloudAccountDataMappers.cloudDocument(
            from: food,
            logDate: referenceDate,
            context: CloudAccountDataMappingContext(userId: ownerUID, calendar: calendar)
        )
        try await remoteStore.saveFoodEntry(document, uid: ownerUID)

        try outbox.enqueueLocalMutation(
            ownerUID: ownerUID,
            entityType: .foodEntry,
            entityId: foodID.uuidString,
            localDate: localDate,
            operation: .delete,
            mutationGroupId: nil
        )

        let summary = await uploader.uploadDueMutations(for: ownerUID, limit: 10)

        XCTAssertEqual(summary.succeeded, 1)
        XCTAssertNil(try fetchFoodEntity(id: foodID))
        let remoteFoodEntries = try await remoteStore.fetchFoodEntries(uid: ownerUID, localDate: localDate)
        XCTAssertEqual(remoteFoodEntries.count, 0)
    }

    func testMissingUpsertEntityCancelsMutation() async throws {
        try outbox.enqueueLocalMutation(
            ownerUID: ownerUID,
            entityType: .foodEntry,
            entityId: UUID().uuidString,
            localDate: localDate,
            operation: .upsert,
            mutationGroupId: nil
        )

        let summary = await uploader.uploadDueMutations(for: ownerUID, limit: 10)

        XCTAssertEqual(summary.cancelled, 1)
        XCTAssertEqual(summary.succeeded, 0)
        XCTAssertEqual(summary.failed, 0)
    }

    func testDailyLogDeleteMutationIsCancelled() async throws {
        try outbox.enqueueLocalMutation(
            ownerUID: ownerUID,
            entityType: .dailyLog,
            entityId: localDate,
            localDate: localDate,
            operation: .delete,
            mutationGroupId: nil
        )

        let summary = await uploader.uploadDueMutations(for: ownerUID, limit: 10)

        XCTAssertEqual(summary.cancelled, 1)
        XCTAssertEqual(summary.succeeded, 0)
    }

    func testSecondUploadIsIdempotentWhenOutboxIsDrained() async throws {
        let foodID = UUID()
        let dailyLog = try seedDailyLog(ownerUID: ownerUID)
        _ = try seedFood(id: foodID, dailyLog: dailyLog, ownerUID: ownerUID)

        try outbox.enqueueLocalMutation(
            ownerUID: ownerUID,
            entityType: .foodEntry,
            entityId: foodID.uuidString,
            localDate: localDate,
            operation: .upsert,
            mutationGroupId: nil
        )

        let first = await uploader.uploadDueMutations(for: ownerUID, limit: 10)
        let second = await uploader.uploadDueMutations(for: ownerUID, limit: 10)

        XCTAssertEqual(first.succeeded, 1)
        XCTAssertEqual(second.attempted, 0)
        let remoteFoodEntries = try await remoteStore.fetchFoodEntries(uid: ownerUID, localDate: localDate)
        XCTAssertEqual(remoteFoodEntries.count, 1)
    }

    func testRejectsUnownedDocumentDuringUpload() async throws {
        let foodID = UUID()
        let dailyLog = try seedDailyLog(ownerUID: ownerUID)
        let food = try seedFood(id: foodID, dailyLog: dailyLog, ownerUID: ownerUID)

        try outbox.enqueueLocalMutation(
            ownerUID: ownerUID,
            entityType: .foodEntry,
            entityId: foodID.uuidString,
            localDate: localDate,
            operation: .upsert,
            mutationGroupId: nil
        )

        let tamperedUploader = AccountSyncUploader(
            outbox: outbox,
            payloadBuilder: TamperedPayloadBuilder(
                base: payloadBuilder,
                tamperUserId: otherUID
            ),
            remoteStore: remoteStore,
            store: store,
            calendar: calendar,
            nowProvider: { self.referenceDate }
        )

        let summary = await tamperedUploader.uploadDueMutations(for: ownerUID, limit: 10)

        XCTAssertEqual(summary.failed, 1)
        XCTAssertEqual(food.syncStatus, .failed)
        let remoteFoodEntries = try await remoteStore.fetchFoodEntries(uid: ownerUID, localDate: localDate)
        XCTAssertEqual(remoteFoodEntries.count, 0)
    }

    // MARK: - Helpers

    @discardableResult
    private func seedDailyLog(
        ownerUID: String,
        date: Date? = nil
    ) throws -> DailyLogEntity {
        let logDate = date ?? referenceDate
        let entity = DailyLogEntity(
            id: UUID(),
            ownerUID: ownerUID,
            date: logDate,
            weightKg: nil,
            calorieTarget: 2_000,
            proteinTarget: 140,
            carbTarget: 180,
            fatTarget: 65,
            waterTargetMl: 2_500,
            expectedWeeklyWeightLossKg: 0.5,
            aggressivenessRawValue: CalorieAggressiveness.moderate.rawValue,
            caloriesConsumed: 0,
            proteinConsumed: 0,
            carbsConsumed: 0,
            fatConsumed: 0,
            fiberConsumed: nil,
            sodiumConsumed: nil,
            waterConsumedMl: 0,
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
    private func seedFood(
        id: UUID,
        dailyLog: DailyLogEntity,
        ownerUID: String,
        name: String = "Meal"
    ) throws -> FoodEntryEntity {
        let food = FoodEntryEntity(
            id: id,
            ownerUID: ownerUID,
            dailyLogId: dailyLog.id,
            mealTypeRawValue: MealType.lunch.rawValue,
            name: name,
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
            createdAt: referenceDate,
            updatedAt: referenceDate
        )
        food.dailyLog = dailyLog
        try store.insert(food)
        return food
    }

    private func fetchFoodEntity(id: UUID) throws -> FoodEntryEntity? {
        var descriptor = FetchDescriptor<FoodEntryEntity>(predicate: #Predicate { $0.id == id })
        descriptor.fetchLimit = 1
        return try store.fetchOne(descriptor)
    }

    private func fetchMutationEntity(id: String) -> AccountSyncMutationEntity? {
        var descriptor = FetchDescriptor<AccountSyncMutationEntity>(
            predicate: #Predicate { $0.id == id }
        )
        descriptor.fetchLimit = 1
        return try? store.fetchOne(descriptor)
    }
}

@MainActor
private final class TamperedPayloadBuilder: AccountSyncPayloadBuilding {

    private let base: AccountSyncPayloadBuilding

    init(base: AccountSyncPayloadBuilding, tamperUserId: String) {
        self.base = base
        self.tamperUserId = tamperUserId
    }

    private let tamperUserId: String

    func buildPayload(for mutation: AccountSyncMutation) async throws -> AccountSyncPayload {
        let payload = try await base.buildPayload(for: mutation)
        guard var food = payload.foodEntry else { return payload }
        food.userId = tamperUserId
        return AccountSyncPayload(
            mutation: payload.mutation,
            entityType: payload.entityType,
            operation: payload.operation,
            dailyLog: payload.dailyLog,
            foodEntry: food,
            waterEntry: payload.waterEntry,
            weightEntry: payload.weightEntry,
            dailyReview: payload.dailyReview
        )
    }
}
