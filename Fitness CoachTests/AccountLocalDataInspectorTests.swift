//
//  AccountLocalDataInspectorTests.swift
//  Fitness CoachTests
//
//  Forma — Account local data inspector tests (Phase 4).
//

import XCTest
import SwiftData
@testable import Fitness_Coach

@MainActor
final class AccountLocalDataInspectorTests: XCTestCase {

    private let ownerUID = "user-a"
    private let otherUID = "user-b"
    private let referenceDate = ProfileTestFixtures.referenceDate
    private let calendar = Calendar(identifier: .gregorian)

    private var store: SwiftDataStore!
    private var profileService: UserProfileService!
    private var outbox: SwiftDataAccountSyncOutboxStore!
    private var inspector: AccountLocalDataInspector!
    private var dateProvider: FixedDailyLogTestDateProvider!

    override func setUp() async throws {
        try await super.setUp()
        dateProvider = FixedDailyLogTestDateProvider(now: referenceDate, calendar: calendar)
        let container = try FormaModelContainer.makeContainer(inMemory: true)
        store = SwiftDataStore(container: container)
        profileService = UserProfileService(store: store, dateProvider: dateProvider)
        outbox = SwiftDataAccountSyncOutboxStore(store: store)
        inspector = AccountLocalDataInspector(
            store: store,
            userProfileService: profileService,
            outboxStore: outbox,
            dateProvider: dateProvider,
            calendar: calendar
        )
    }

    override func tearDown() async throws {
        inspector = nil
        outbox = nil
        profileService = nil
        store = nil
        dateProvider = nil
        try await super.tearDown()
    }

    func testEmptyFreshInstallReportsNeedsInitialRestore() async throws {
        let status = try await inspector.inspectLocalData(for: ownerUID)

        XCTAssertEqual(status.uid, ownerUID)
        XCTAssertFalse(status.hasProfile)
        XCTAssertFalse(status.hasAnyDailyLogs)
        XCTAssertFalse(status.hasTodayDailyLog)
        XCTAssertEqual(status.foodEntryCount, 0)
        XCTAssertEqual(status.waterEntryCount, 0)
        XCTAssertEqual(status.weightEntryCount, 0)
        XCTAssertEqual(status.dailyReviewCount, 0)
        XCTAssertEqual(status.pendingMutationCount, 0)
        XCTAssertEqual(status.failedMutationCount, 0)
        XCTAssertNil(status.newestLocalUpdatedAt)
        XCTAssertNil(status.oldestLocalDate)
        XCTAssertNil(status.newestLocalDate)
        XCTAssertTrue(status.isEffectivelyEmpty)
        XCTAssertTrue(status.needsInitialRestore)
    }

    func testPopulatedAccountDoesNotNeedInitialRestore() async throws {
        _ = try seedProfile(ownerUID: ownerUID)
        let dailyLog = try seedDailyLog(ownerUID: ownerUID, date: referenceDate)
        _ = try seedFood(dailyLog: dailyLog, ownerUID: ownerUID, name: "Oats")
        _ = try seedWater(dailyLog: dailyLog, ownerUID: ownerUID)
        _ = try seedWeight(ownerUID: ownerUID, date: referenceDate)
        _ = try seedReview(dailyLog: dailyLog, ownerUID: ownerUID)

        let status = try await inspector.inspectLocalData(for: ownerUID)

        XCTAssertTrue(status.hasProfile)
        XCTAssertTrue(status.hasAnyDailyLogs)
        XCTAssertTrue(status.hasTodayDailyLog)
        XCTAssertEqual(status.foodEntryCount, 1)
        XCTAssertEqual(status.waterEntryCount, 1)
        XCTAssertEqual(status.weightEntryCount, 1)
        XCTAssertEqual(status.dailyReviewCount, 1)
        XCTAssertFalse(status.isEffectivelyEmpty)
        XCTAssertFalse(status.needsInitialRestore)
        XCTAssertNotNil(status.newestLocalUpdatedAt)
        XCTAssertEqual(
            status.oldestLocalDate,
            CloudAccountDataDateCodec.localDateString(from: referenceDate, calendar: calendar)
        )
        XCTAssertEqual(status.newestLocalDate, status.oldestLocalDate)
    }

    func testPendingMutationsBlockInitialRestore() async throws {
        try await outbox.enqueue(
            ownerUID: ownerUID,
            entityType: .foodEntry,
            entityId: UUID().uuidString,
            localDate: CloudAccountDataDateCodec.localDateString(from: referenceDate, calendar: calendar),
            operation: .upsert,
            mutationGroupId: nil
        )

        let status = try await inspector.inspectLocalData(for: ownerUID)

        XCTAssertTrue(status.isEffectivelyEmpty)
        XCTAssertEqual(status.pendingMutationCount, 1)
        XCTAssertEqual(status.failedMutationCount, 0)
        XCTAssertFalse(status.needsInitialRestore)
    }

    func testFailedMutationsBlockInitialRestore() async throws {
        try await outbox.enqueue(
            ownerUID: ownerUID,
            entityType: .waterEntry,
            entityId: UUID().uuidString,
            localDate: CloudAccountDataDateCodec.localDateString(from: referenceDate, calendar: calendar),
            operation: .upsert,
            mutationGroupId: nil
        )
        let mutationID = try await outbox.fetchDueMutations(
            ownerUID: ownerUID,
            limit: 1,
            now: referenceDate
        ).first!.id
        try await outbox.markFailed(
            mutationID,
            ownerUID: ownerUID,
            error: AccountSyncOutboxError.mutationNotFound,
            now: referenceDate
        )

        let status = try await inspector.inspectLocalData(for: ownerUID)

        XCTAssertTrue(status.isEffectivelyEmpty)
        XCTAssertEqual(status.pendingMutationCount, 0)
        XCTAssertEqual(status.failedMutationCount, 1)
        XCTAssertFalse(status.needsInitialRestore)
    }

    func testAnotherUserDataIsIgnored() async throws {
        _ = try seedProfile(ownerUID: otherUID)
        let otherLog = try seedDailyLog(ownerUID: otherUID, date: referenceDate)
        _ = try seedFood(dailyLog: otherLog, ownerUID: otherUID, name: "Other Meal")
        _ = try seedLegacyFoodWithoutOwner(dailyLog: otherLog, name: "Legacy Meal")

        let status = try await inspector.inspectLocalData(for: ownerUID)

        XCTAssertFalse(status.hasProfile)
        XCTAssertFalse(status.hasAnyDailyLogs)
        XCTAssertEqual(status.foodEntryCount, 0)
        XCTAssertTrue(status.isEffectivelyEmpty)
        XCTAssertTrue(status.needsInitialRestore)
    }

    func testTombstonedRowsDoNotPopulateAccount() async throws {
        let dailyLog = try seedDailyLog(ownerUID: ownerUID, date: referenceDate)
        let food = try seedFood(dailyLog: dailyLog, ownerUID: ownerUID, name: "Deleted Meal")
        food.deletedAt = referenceDate
        food.syncStatus = .pendingDelete
        try store.save()

        try await outbox.enqueue(
            ownerUID: ownerUID,
            entityType: .foodEntry,
            entityId: food.id.uuidString,
            localDate: CloudAccountDataDateCodec.localDateString(from: referenceDate, calendar: calendar),
            operation: .delete,
            mutationGroupId: nil
        )

        let status = try await inspector.inspectLocalData(for: ownerUID)

        XCTAssertEqual(status.foodEntryCount, 0)
        XCTAssertTrue(status.hasAnyDailyLogs)
        XCTAssertTrue(status.isEffectivelyEmpty)
        XCTAssertEqual(status.pendingMutationCount, 1)
        XCTAssertFalse(status.needsInitialRestore)
    }

    func testProfileOnlyWithoutLogsStillNeedsRestore() async throws {
        _ = try seedProfile(ownerUID: ownerUID)

        let status = try await inspector.inspectLocalData(for: ownerUID)

        XCTAssertTrue(status.hasProfile)
        XCTAssertTrue(status.isEffectivelyEmpty)
        XCTAssertTrue(status.needsInitialRestore)
    }

    func testInvalidUIDThrows() async {
        do {
            _ = try await inspector.inspectLocalData(for: "   ")
            XCTFail("Expected invalid UID error")
        } catch let error as AccountLocalDataInspectorError {
            XCTAssertEqual(error, .invalidUID)
        } catch {
            XCTFail("Unexpected error: \(error)")
        }
    }

    // MARK: - Fixtures

    @discardableResult
    private func seedProfile(ownerUID: String) throws -> UserProfile {
        var draft = ProfileTestFixtures.sampleDraft
        draft.targets = ProfileTestFixtures.sampleTargets
        return try profileService.createProfile(draft, ownerUID: ownerUID)
    }

    @discardableResult
    private func seedDailyLog(ownerUID: String, date: Date) throws -> DailyLogEntity {
        let entity = DailyLogEntity(
            id: UUID(),
            ownerUID: ownerUID,
            date: dateProvider.startOfDay(for: date),
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
        entity.localUpdatedAt = referenceDate
        try store.insert(entity)
        return entity
    }

    @discardableResult
    private func seedFood(
        dailyLog: DailyLogEntity,
        ownerUID: String,
        name: String
    ) throws -> FoodEntryEntity {
        let food = FoodEntryEntity(
            id: UUID(),
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
        food.localUpdatedAt = referenceDate
        try store.insert(food)
        return food
    }

    @discardableResult
    private func seedLegacyFoodWithoutOwner(
        dailyLog: DailyLogEntity,
        name: String
    ) throws -> FoodEntryEntity {
        let food = FoodEntryEntity(
            id: UUID(),
            ownerUID: nil,
            dailyLogId: dailyLog.id,
            mealTypeRawValue: MealType.lunch.rawValue,
            name: name,
            quantity: 1,
            unit: "bowl",
            calories: 200,
            protein: 10,
            carbs: 20,
            fat: 8,
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
    private func seedWater(dailyLog: DailyLogEntity, ownerUID: String) throws -> WaterEntryEntity {
        let water = WaterEntryEntity(
            id: UUID(),
            ownerUID: ownerUID,
            dailyLogId: dailyLog.id,
            amountMl: 250,
            createdAt: referenceDate
        )
        water.dailyLog = dailyLog
        water.localUpdatedAt = referenceDate
        try store.insert(water)
        return water
    }

    @discardableResult
    private func seedWeight(ownerUID: String, date: Date) throws -> WeightEntryEntity {
        let weight = WeightEntryEntity(
            id: UUID(),
            ownerUID: ownerUID,
            date: dateProvider.startOfDay(for: date),
            weightKg: 70,
            note: nil,
            createdAt: referenceDate
        )
        weight.localUpdatedAt = referenceDate
        try store.insert(weight)
        return weight
    }

    @discardableResult
    private func seedReview(dailyLog: DailyLogEntity, ownerUID: String) throws -> DailyReviewEntity {
        let review = DailyReviewEntity(
            id: UUID(),
            ownerUID: ownerUID,
            dailyLogId: dailyLog.id,
            summaryText: "Solid day",
            caloriesSummary: "On target",
            proteinSummary: "Good",
            hydrationSummary: "OK",
            workoutSummary: nil,
            weightSummary: nil,
            tomorrowRecommendation: "Keep going",
            createdAt: referenceDate
        )
        review.dailyLog = dailyLog
        review.localUpdatedAt = referenceDate
        try store.insert(review)
        return review
    }
}
