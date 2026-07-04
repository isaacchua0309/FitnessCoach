//
//  AccountSyncMutationIntegrationTests.swift
//  Fitness CoachTests
//
//  Forma — Local mutation → outbox integration tests (Phase 3).
//

import XCTest
import SwiftData
@testable import Fitness_Coach

@MainActor
final class AccountSyncMutationIntegrationTests: XCTestCase {

    private let ownerUID = "test-user-1"
    private let referenceDate = DailyLogServiceTestSupport.referenceNow

    func testFoodCreateMarksPendingUploadAndEnqueuesMutation() async throws {
        let harness = try FitnessActionCenterTestSupport.makeHarness(
            referenceNow: referenceDate,
            cloudUID: ownerUID
        )
        _ = try harness.seedProfile(ownerUID: ownerUID)

        let entry = try harness.actionCenter.logFood(
            DailyLogServiceTestSupport.foodDraft(name: "Oats", calories: 320),
            date: harness.today
        )

        let outbox = try XCTUnwrap(harness.base.accountSyncOutboxStore)
        let due = try await outbox.fetchDueMutations(
            ownerUID: ownerUID,
            limit: 10,
            now: referenceDate
        )
        XCTAssertTrue(
            due.contains(where: {
                $0.entityType == .foodEntry
                    && $0.entityId == entry.id.uuidString
                    && $0.operation == .upsert
            })
        )

        let foodEntity = try XCTUnwrap(fetchFoodEntity(id: entry.id, in: harness.base.store))
        XCTAssertEqual(foodEntity.syncStatus, .pendingUpload)
        XCTAssertEqual(foodEntity.ownerUID, ownerUID)
        XCTAssertNotNil(foodEntity.localUpdatedAt)
        XCTAssertNotNil(foodEntity.lastMutationId)
        XCTAssertNil(foodEntity.lastSyncError)
    }

    func testFoodEditMarksPendingUploadAndEnqueuesMutation() async throws {
        let harness = try FitnessActionCenterTestSupport.makeHarness(
            referenceNow: referenceDate,
            cloudUID: ownerUID
        )
        _ = try harness.seedProfile(ownerUID: ownerUID)

        let entry = try harness.actionCenter.logFood(
            DailyLogServiceTestSupport.foodDraft(name: "Rice", calories: 200),
            date: harness.today
        )

        _ = try harness.actionCenter.editFoodEntry(
            id: entry.id,
            update: FoodEntryUpdate(calories: 240, name: "Brown rice")
        )

        let foodEntity = try XCTUnwrap(fetchFoodEntity(id: entry.id, in: harness.base.store))
        XCTAssertEqual(foodEntity.syncStatus, .pendingUpload)
        XCTAssertEqual(foodEntity.calories, 240)

        let outbox = try XCTUnwrap(harness.base.accountSyncOutboxStore)
        let due = try await outbox.fetchDueMutations(
            ownerUID: ownerUID,
            limit: 10,
            now: referenceDate
        )
        XCTAssertTrue(due.contains(where: { $0.entityType == .foodEntry && $0.operation == .upsert }))
    }

    func testFoodDeleteCreatesPendingDeleteForSyncedEntity() async throws {
        let harness = try FitnessActionCenterTestSupport.makeHarness(
            referenceNow: referenceDate,
            cloudUID: ownerUID
        )
        _ = try harness.seedProfile(ownerUID: ownerUID)

        let entry = try harness.actionCenter.logFood(
            DailyLogServiceTestSupport.foodDraft(name: "Salmon", calories: 420),
            date: harness.today
        )

        let foodEntity = try XCTUnwrap(fetchFoodEntity(id: entry.id, in: harness.base.store))
        foodEntity.syncStatus = .synced
        foodEntity.lastSyncedAt = referenceDate
        try harness.base.store.save()

        try harness.actionCenter.deleteFoodEntry(id: entry.id)

        XCTAssertTrue(try harness.actionCenter.getFoodEntries(for: harness.today).isEmpty)
        let tombstone = try XCTUnwrap(fetchFoodEntity(id: entry.id, in: harness.base.store))
        XCTAssertEqual(tombstone.syncStatus, .pendingDelete)
        XCTAssertNotNil(tombstone.deletedAt)

        let outbox = try XCTUnwrap(harness.base.accountSyncOutboxStore)
        let due = try await outbox.fetchDueMutations(
            ownerUID: ownerUID,
            limit: 10,
            now: referenceDate
        )
        XCTAssertTrue(
            due.contains(where: {
                $0.entityType == .foodEntry
                    && $0.entityId == entry.id.uuidString
                    && $0.operation == .delete
            })
        )
    }

    func testWaterCreateEnqueuesMutation() async throws {
        let harness = try FitnessActionCenterTestSupport.makeHarness(
            referenceNow: referenceDate,
            cloudUID: ownerUID
        )
        _ = try harness.seedProfile(ownerUID: ownerUID)

        let entry = try harness.actionCenter.logWater(amountMl: 350, date: harness.today)

        let outbox = try XCTUnwrap(harness.base.accountSyncOutboxStore)
        let due = try await outbox.fetchDueMutations(
            ownerUID: ownerUID,
            limit: 10,
            now: referenceDate
        )
        XCTAssertTrue(
            due.contains(where: {
                $0.entityType == .waterEntry && $0.entityId == entry.id.uuidString && $0.operation == .upsert
            })
        )
    }

    func testWeightCreateEnqueuesMutation() async throws {
        let harness = try FitnessActionCenterTestSupport.makeHarness(
            referenceNow: referenceDate,
            cloudUID: ownerUID
        )
        _ = try harness.seedProfile(ownerUID: ownerUID)
        _ = try harness.actionCenter.logFood(
            DailyLogServiceTestSupport.foodDraft(name: "Egg", calories: 80),
            date: harness.today
        )

        let entry = try harness.actionCenter.logDailyWeight(72.5, date: harness.today)

        let outbox = try XCTUnwrap(harness.base.accountSyncOutboxStore)
        let due = try await outbox.fetchDueMutations(
            ownerUID: ownerUID,
            limit: 20,
            now: referenceDate
        )
        XCTAssertTrue(
            due.contains(where: {
                $0.entityType == .weightEntry && $0.entityId == entry.id.uuidString && $0.operation == .upsert
            })
        )
    }

    func testDailyLogRecalculationEnqueuesDailyLogUpsert() async throws {
        let harness = try FitnessActionCenterTestSupport.makeHarness(
            referenceNow: referenceDate,
            cloudUID: ownerUID
        )
        _ = try harness.seedProfile(ownerUID: ownerUID)

        let entry = try harness.actionCenter.logFood(
            DailyLogServiceTestSupport.foodDraft(name: "Toast", calories: 180),
            date: harness.today
        )

        _ = try harness.actionCenter.editFoodEntry(
            id: entry.id,
            update: FoodEntryUpdate(calories: 220)
        )

        let outbox = try XCTUnwrap(harness.base.accountSyncOutboxStore)
        let due = try await outbox.fetchDueMutations(
            ownerUID: ownerUID,
            limit: 10,
            now: referenceDate
        )
        XCTAssertTrue(
            due.contains(where: { $0.entityType == .dailyLog && $0.operation == .upsert })
        )

        let dailyLog = try XCTUnwrap(try harness.dailyLogService.dailyLogEntity(for: harness.today))
        XCTAssertEqual(dailyLog.caloriesConsumed, 220)
        XCTAssertEqual(dailyLog.syncStatus, .pendingUpload)
    }

    func testDailyReviewCreateEnqueuesMutation() async throws {
        let harness = try FitnessActionCenterTestSupport.makeHarness(
            referenceNow: referenceDate,
            cloudUID: ownerUID
        )
        _ = try harness.seedProfile(ownerUID: ownerUID)
        _ = try harness.actionCenter.logFood(
            DailyLogServiceTestSupport.foodDraft(name: "Chicken", calories: 450),
            date: harness.today
        )

        _ = try await harness.actionCenter.generateDailyReview(for: harness.today)

        let outbox = try XCTUnwrap(harness.base.accountSyncOutboxStore)
        let due = try await outbox.fetchDueMutations(
            ownerUID: ownerUID,
            limit: 20,
            now: referenceDate
        )
        XCTAssertTrue(
            due.contains(where: { $0.entityType == .dailyReview && $0.operation == .upsert })
        )

        let dailyLog = try XCTUnwrap(try harness.dailyLogService.dailyLogEntity(for: harness.today))
        XCTAssertNotNil(dailyLog.dailyReview)
        XCTAssertEqual(dailyLog.dailyReview?.syncStatus, .pendingUpload)
    }

    func testOfflineMutationRemainsPendingAfterStoreReopen() async throws {
        let storeURL = FormaSwiftDataMigrationTestSupport.makeTemporaryStoreURL()
        defer { FormaSwiftDataMigrationTestSupport.removeStore(at: storeURL) }

        let container = try FormaModelContainer.makeContainer(inMemory: false, storeURL: storeURL)
        let store = SwiftDataStore(container: container)
        let outbox = SwiftDataAccountSyncOutboxStore(store: store)
        let tracker = AccountLocalMutationTracker(outbox: outbox, ownerUIDProvider: { ownerUID })
        let profileService = UserProfileService(store: store)
        let dailyLogService = DailyLogService(
            store: store,
            userProfileService: profileService,
            mutationTracker: tracker
        )
        let foodLogService = FoodLogService(
            store: store,
            dailyLogService: dailyLogService,
            mutationTracker: tracker
        )
        _ = try profileService.createProfile(ProfileTestFixtures.sampleDraft)
        _ = try profileService.assignOwnerUID(ownerUID)

        let entry = try foodLogService.addFoodEntry(
            DailyLogServiceTestSupport.foodDraft(name: "Yogurt", calories: 150),
            date: referenceDate
        )

        let foodBeforeReopen = try XCTUnwrap(fetchFoodEntity(id: entry.id, in: store))
        XCTAssertEqual(foodBeforeReopen.syncStatus, .pendingUpload)

        let reopenedContainer = try FormaModelContainer.makeContainer(inMemory: false, storeURL: storeURL)
        let reopenedStore = SwiftDataStore(container: reopenedContainer)
        let reopenedOutbox = SwiftDataAccountSyncOutboxStore(store: reopenedStore)

        let due = try await reopenedOutbox.fetchDueMutations(
            ownerUID: ownerUID,
            limit: 10,
            now: referenceDate
        )
        XCTAssertFalse(due.isEmpty)
        XCTAssertTrue(due.contains(where: { $0.entityType == .foodEntry && $0.operation == .upsert }))

        let foodAfterReopen = try XCTUnwrap(fetchFoodEntity(id: entry.id, in: reopenedStore))
        XCTAssertEqual(foodAfterReopen.syncStatus, .pendingUpload)
        XCTAssertNotNil(foodAfterReopen.localUpdatedAt)
    }

    // MARK: - Helpers

    private func fetchFoodEntity(id: UUID, in store: SwiftDataStore) -> FoodEntryEntity? {
        var descriptor = FetchDescriptor<FoodEntryEntity>(
            predicate: #Predicate { $0.id == id }
        )
        descriptor.fetchLimit = 1
        return try? store.fetchOne(descriptor)
    }
}
