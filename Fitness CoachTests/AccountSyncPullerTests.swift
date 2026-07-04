//
//  AccountSyncPullerTests.swift
//  Fitness CoachTests
//
//  Forma — Account sync puller tests (Phase 3).
//

import XCTest
import SwiftData
@testable import Fitness_Coach

@MainActor
final class AccountSyncPullerTests: XCTestCase {

    private var store: SwiftDataStore!
    private var remoteStore: InMemoryAccountDataRemoteStore!
    private var puller: AccountSyncPuller!
    private var calendar: Calendar!
    private var localDate: String!

    private let ownerUID = "userA"
    private let otherUID = "userB"
    private let referenceDate = ProfileTestFixtures.referenceDate

    override func setUp() async throws {
        try await super.setUp()
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(secondsFromGMT: 0)!
        self.calendar = calendar
        localDate = CloudAccountDataDateCodec.localDateString(from: referenceDate, calendar: calendar)

        let container = try FormaModelContainer.makeContainer(inMemory: true)
        store = SwiftDataStore(container: container)
        remoteStore = InMemoryAccountDataRemoteStore()
        puller = AccountSyncPuller(
            remoteStore: remoteStore,
            store: store,
            calendar: calendar,
            nowProvider: { self.referenceDate }
        )
    }

    func testPullerInsertsRemoteDailyLog() async throws {
        let dailyLogDocument = makeDailyLogDocument(caloriesConsumed: 640, proteinConsumed: 48)
        try await remoteStore.saveDailyLog(dailyLogDocument, uid: ownerUID)

        let summary = await puller.pullRecentAccountData(
            for: ownerUID,
            from: localDate,
            to: localDate
        )

        XCTAssertEqual(summary.dailyLogsFetched, 1)
        XCTAssertEqual(summary.inserted, 1)
        XCTAssertEqual(summary.failed, 0)

        let dailyLog = try XCTUnwrap(try store.fetch(FetchDescriptor<DailyLogEntity>()).first)
        XCTAssertEqual(dailyLog.ownerUID, ownerUID)
        XCTAssertEqual(dailyLog.caloriesConsumed, 640)
        XCTAssertEqual(dailyLog.proteinConsumed, 48)
        XCTAssertEqual(dailyLog.syncStatus, .synced)
    }

    func testPullerInsertsRemoteFoodEntries() async throws {
        let foodID = UUID().uuidString
        let dailyLogDocument = makeDailyLogDocument(caloriesConsumed: 100)
        let foodDocument = makeFoodDocument(entryId: foodID, name: "Cloud Meal", updatedAt: referenceDate)

        try await remoteStore.saveDailyLog(dailyLogDocument, uid: ownerUID)
        try await remoteStore.saveFoodEntry(foodDocument, uid: ownerUID)

        let summary = await puller.pullRecentAccountData(
            for: ownerUID,
            from: localDate,
            to: localDate
        )

        XCTAssertEqual(summary.foodEntriesFetched, 1)
        XCTAssertEqual(summary.inserted, 2)
        XCTAssertEqual(summary.failed, 0)

        let food = try XCTUnwrap(fetchFoodEntity(id: foodID))
        XCTAssertEqual(food.name, "Cloud Meal")
        XCTAssertEqual(food.ownerUID, ownerUID)
        XCTAssertEqual(food.syncStatus, .synced)
        XCTAssertEqual(food.cloudId, foodID)
    }

    func testPullerDoesNotOverwritePendingLocalEdit() async throws {
        let foodID = UUID()
        let dailyLog = try seedDailyLog(ownerUID: ownerUID)
        let food = try seedFood(
            id: foodID,
            dailyLog: dailyLog,
            ownerUID: ownerUID,
            name: "Local Draft",
            updatedAt: referenceDate.addingTimeInterval(300)
        )
        food.syncStatus = .pendingUpload
        food.localUpdatedAt = referenceDate.addingTimeInterval(300)
        try store.save()

        let remoteDailyLog = makeDailyLogDocument(caloriesConsumed: 100)
        let remoteFood = makeFoodDocument(
            entryId: foodID.uuidString,
            name: "Cloud Meal",
            updatedAt: referenceDate
        )
        try await remoteStore.saveDailyLog(remoteDailyLog, uid: ownerUID)
        try await remoteStore.saveFoodEntry(remoteFood, uid: ownerUID)

        let summary = await puller.pullRecentAccountData(
            for: ownerUID,
            from: localDate,
            to: localDate
        )

        XCTAssertEqual(summary.skippedLocalNewer, 1)
        XCTAssertEqual(summary.conflicts, 0)
        XCTAssertEqual(food.name, "Local Draft")
        XCTAssertEqual(food.syncStatus, .pendingUpload)
    }

    func testPullMarksConflictWhenRemoteIsNewerThanPendingUpload() async throws {
        let foodID = UUID()
        let dailyLog = try seedDailyLog(ownerUID: ownerUID)
        let food = try seedFood(
            id: foodID,
            dailyLog: dailyLog,
            ownerUID: ownerUID,
            name: "Local Draft",
            updatedAt: referenceDate
        )
        food.syncStatus = .pendingUpload
        food.localUpdatedAt = referenceDate
        try store.save()

        let remoteDailyLog = makeDailyLogDocument(caloriesConsumed: 100)
        let remoteFood = makeFoodDocument(
            entryId: foodID.uuidString,
            name: "Cloud Meal",
            updatedAt: referenceDate.addingTimeInterval(300)
        )
        try await remoteStore.saveDailyLog(remoteDailyLog, uid: ownerUID)
        try await remoteStore.saveFoodEntry(remoteFood, uid: ownerUID)

        let summary = await puller.pullRecentAccountData(
            for: ownerUID,
            from: localDate,
            to: localDate
        )

        XCTAssertEqual(summary.conflicts, 1)
        XCTAssertEqual(food.name, "Local Draft")
        XCTAssertEqual(food.syncStatus, .conflict)
    }

    func testPullerUpdatesSyncedLocalEntityWhenRemoteNewer() async throws {
        let foodID = UUID()
        let dailyLog = try seedDailyLog(ownerUID: ownerUID)
        let food = try seedFood(
            id: foodID,
            dailyLog: dailyLog,
            ownerUID: ownerUID,
            name: "Old Name",
            updatedAt: referenceDate
        )
        food.syncStatus = .synced
        food.cloudId = foodID.uuidString
        try store.save()

        let remoteDailyLog = makeDailyLogDocument(caloriesConsumed: 100)
        let remoteFood = makeFoodDocument(
            entryId: foodID.uuidString,
            name: "New Name",
            updatedAt: referenceDate.addingTimeInterval(300)
        )
        try await remoteStore.saveDailyLog(remoteDailyLog, uid: ownerUID)
        try await remoteStore.saveFoodEntry(remoteFood, uid: ownerUID)

        let summary = await puller.pullRecentAccountData(
            for: ownerUID,
            from: localDate,
            to: localDate
        )

        XCTAssertEqual(summary.updated, 1)
        XCTAssertEqual(food.name, "New Name")
        XCTAssertEqual(food.syncStatus, .synced)
    }

    func testPullerSkipsOwnerMismatch() async throws {
        let foodID = UUID()
        let dailyLog = try seedDailyLog(ownerUID: otherUID)
        _ = try seedFood(
            id: foodID,
            dailyLog: dailyLog,
            ownerUID: otherUID,
            name: "Other User Meal",
            updatedAt: referenceDate
        )

        let remoteDailyLog = makeDailyLogDocument(userId: ownerUID, caloriesConsumed: 100)
        let remoteFood = makeFoodDocument(
            entryId: foodID.uuidString,
            name: "Cloud Meal",
            updatedAt: referenceDate.addingTimeInterval(300)
        )
        try await remoteStore.saveDailyLog(remoteDailyLog, uid: ownerUID)
        try await remoteStore.saveFoodEntry(remoteFood, uid: ownerUID)

        let summary = await puller.pullRecentAccountData(
            for: ownerUID,
            from: localDate,
            to: localDate
        )

        XCTAssertEqual(summary.failed, 1)
        XCTAssertEqual(try fetchFoodEntity(id: foodID.uuidString)?.name, "Other User Meal")
        XCTAssertEqual(try fetchFoodEntity(id: foodID.uuidString)?.ownerUID, otherUID)
    }

    func testPullerAppliesRemoteDeletedAtWhenSafe() async throws {
        let foodID = UUID()
        let dailyLog = try seedDailyLog(ownerUID: ownerUID)
        let food = try seedFood(
            id: foodID,
            dailyLog: dailyLog,
            ownerUID: ownerUID,
            name: "Synced Meal",
            updatedAt: referenceDate
        )
        food.syncStatus = .synced
        food.cloudId = foodID.uuidString
        try store.save()

        let deletedAt = referenceDate.addingTimeInterval(120)
        let remoteDailyLog = makeDailyLogDocument(caloriesConsumed: 100)
        var remoteFood = makeFoodDocument(
            entryId: foodID.uuidString,
            name: "Synced Meal",
            updatedAt: deletedAt
        )
        remoteFood.deletedAt = deletedAt
        try await remoteStore.saveDailyLog(remoteDailyLog, uid: ownerUID)
        try await remoteStore.saveFoodEntry(remoteFood, uid: ownerUID)

        let summary = await puller.pullRecentAccountData(
            for: ownerUID,
            from: localDate,
            to: localDate
        )

        XCTAssertEqual(summary.updated, 1)
        XCTAssertEqual(food.deletedAt, deletedAt)
        XCTAssertEqual(food.syncStatus, .synced)
        XCTAssertNotNil(food.cloudUpdatedAt)
    }

    func testPullerReturnsSummaryCounts() async throws {
        let foodID = UUID().uuidString
        let dailyLogDocument = makeDailyLogDocument(caloriesConsumed: 520)
        let foodDocument = makeFoodDocument(entryId: foodID, name: "Remote Meal", updatedAt: referenceDate)

        try await remoteStore.saveDailyLog(dailyLogDocument, uid: ownerUID)
        try await remoteStore.saveFoodEntry(foodDocument, uid: ownerUID)

        let summary = await puller.pullRecentAccountData(
            for: ownerUID,
            from: localDate,
            to: localDate
        )

        XCTAssertEqual(summary.uid, ownerUID)
        XCTAssertEqual(summary.dailyLogsFetched, 1)
        XCTAssertEqual(summary.foodEntriesFetched, 1)
        XCTAssertEqual(summary.inserted, 2)
        XCTAssertEqual(summary.updated, 0)
        XCTAssertEqual(summary.skippedLocalNewer, 0)
        XCTAssertEqual(summary.conflicts, 0)
        XCTAssertEqual(summary.failed, 0)
    }

    func testPullDoesNotFetchAnotherUsersRemoteData() async throws {
        let foodID = UUID().uuidString
        let remoteDailyLog = makeDailyLogDocument(userId: otherUID, caloriesConsumed: 100)
        let remoteFood = makeFoodDocument(
            entryId: foodID,
            userId: otherUID,
            name: "Other User Meal",
            updatedAt: referenceDate
        )
        try await remoteStore.saveDailyLog(remoteDailyLog, uid: otherUID)
        try await remoteStore.saveFoodEntry(remoteFood, uid: otherUID)

        let summary = await puller.pullRecentAccountData(
            for: ownerUID,
            from: localDate,
            to: localDate
        )

        XCTAssertEqual(summary.foodEntriesFetched, 0)
        XCTAssertEqual(summary.inserted, 0)
        XCTAssertNil(try fetchFoodEntity(id: foodID))
    }

    func testDefaultRecentDateRangeSpansConfiguredDayCount() {
        let range = AccountSyncPuller.defaultRecentDateRange(
            referenceDate: referenceDate,
            dayCount: 30,
            calendar: calendar
        )

        let dates = AccountSyncPuller.localDates(from: range.start, to: range.end, calendar: calendar)
        XCTAssertEqual(dates.count, 30)
        XCTAssertEqual(range.end, localDate)
    }

    // MARK: - Helpers

    private func makeDailyLogDocument(
        userId: String = "userA",
        caloriesConsumed: Int = 520,
        proteinConsumed: Int = 35
    ) -> CloudDailyLogDocument {
        FirestoreAccountDataRemoteStoreTestFixtures.dailyLog(
            userId: userId,
            localDate: localDate,
            referenceDate: referenceDate
        ).with {
            $0.caloriesConsumed = caloriesConsumed
            $0.proteinConsumed = proteinConsumed
        }
    }

    private func makeFoodDocument(
        entryId: String,
        userId: String = "userA",
        name: String,
        updatedAt: Date
    ) -> CloudFoodEntryDocument {
        var document = FirestoreAccountDataRemoteStoreTestFixtures.foodEntry(
            userId: userId,
            localDate: localDate,
            referenceDate: referenceDate,
            entryId: entryId
        )
        document.name = name
        document.updatedAt = updatedAt
        return document
    }

    @discardableResult
    private func seedDailyLog(ownerUID: String) throws -> DailyLogEntity {
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
        name: String,
        updatedAt: Date
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
            updatedAt: updatedAt
        )
        food.dailyLog = dailyLog
        try store.insert(food)
        return food
    }

    private func fetchFoodEntity(id: String) throws -> FoodEntryEntity? {
        guard let uuid = UUID(uuidString: id) else { return nil }
        var descriptor = FetchDescriptor<FoodEntryEntity>(predicate: #Predicate { $0.id == uuid })
        descriptor.fetchLimit = 1
        return try store.fetchOne(descriptor)
    }
}

private extension CloudDailyLogDocument {
    func with(_ mutate: (inout CloudDailyLogDocument) -> Void) -> CloudDailyLogDocument {
        var copy = self
        mutate(&copy)
        return copy
    }
}
