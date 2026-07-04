//
//  AccountSyncPayloadBuilderTests.swift
//  Fitness CoachTests
//
//  Forma — Account sync payload builder tests (Phase 3).
//

import XCTest
import SwiftData
@testable import Fitness_Coach

@MainActor
final class AccountSyncPayloadBuilderTests: XCTestCase {

    private var store: SwiftDataStore!
    private var builder: SwiftDataAccountSyncPayloadBuilder!
    private var calendar: Calendar!
    private let ownerUID = "userA"
    private let otherOwnerUID = "userB"
    private let referenceDate = ProfileTestFixtures.referenceDate
    private var localDate: String!

    override func setUp() async throws {
        try await super.setUp()
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(secondsFromGMT: 0)!
        self.calendar = calendar

        let container = try FormaModelContainer.makeContainer(inMemory: true)
        store = SwiftDataStore(container: container)
        builder = SwiftDataAccountSyncPayloadBuilder(store: store, calendar: calendar)
        localDate = CloudAccountDataDateCodec.localDateString(from: referenceDate, calendar: calendar)
    }

    func testBuildFoodUpsertPayload() async throws {
        let foodID = UUID()
        let dailyLog = try seedDailyLog()
        let food = FoodEntryEntity(
            id: foodID,
            ownerUID: ownerUID,
            dailyLogId: dailyLog.id,
            mealTypeRawValue: MealType.lunch.rawValue,
            name: "Chicken bowl",
            quantity: 1,
            unit: "bowl",
            calories: 520,
            protein: 42,
            carbs: 38,
            fat: 16,
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

        let mutation = makeMutation(
            entityType: .foodEntry,
            entityId: foodID.uuidString,
            localDate: localDate,
            operation: .upsert
        )

        let payload = try await builder.buildPayload(for: mutation)
        XCTAssertEqual(payload.entityType, .foodEntry)
        XCTAssertEqual(payload.operation, .upsert)
        let document = try XCTUnwrap(payload.foodEntry)
        XCTAssertEqual(document.id, foodID.uuidString)
        XCTAssertEqual(document.userId, ownerUID)
        XCTAssertEqual(document.name, "Chicken bowl")
        XCTAssertEqual(document.calories, 520)
        XCTAssertNil(payload.dailyLog)
        XCTAssertNil(payload.waterEntry)
        XCTAssertNil(payload.weightEntry)
        XCTAssertNil(payload.dailyReview)
    }

    func testBuildDailyLogUpsertPayload() async throws {
        let dailyLog = try seedDailyLog()
        dailyLog.caloriesConsumed = 610
        dailyLog.proteinConsumed = 45
        try store.save()

        let mutation = makeMutation(
            entityType: .dailyLog,
            entityId: localDate,
            localDate: localDate,
            operation: .upsert
        )

        let payload = try await builder.buildPayload(for: mutation)
        let document = try XCTUnwrap(payload.dailyLog)
        XCTAssertEqual(document.localDate, localDate)
        XCTAssertEqual(document.userId, ownerUID)
        XCTAssertEqual(document.caloriesConsumed, 610)
        XCTAssertEqual(document.proteinConsumed, 45)
    }

    func testBuildWaterUpsertPayload() async throws {
        let waterID = UUID()
        let dailyLog = try seedDailyLog()
        let water = WaterEntryEntity(
            id: waterID,
            ownerUID: ownerUID,
            dailyLogId: dailyLog.id,
            amountMl: 475,
            createdAt: referenceDate
        )
        water.dailyLog = dailyLog
        try store.insert(water)

        let mutation = makeMutation(
            entityType: .waterEntry,
            entityId: waterID.uuidString,
            localDate: localDate,
            operation: .upsert
        )

        let payload = try await builder.buildPayload(for: mutation)
        let document = try XCTUnwrap(payload.waterEntry)
        XCTAssertEqual(document.amountMl, 475)
        XCTAssertEqual(document.userId, ownerUID)
    }

    func testBuildWeightUpsertPayload() async throws {
        let weightID = UUID()
        let weight = WeightEntryEntity(
            id: weightID,
            ownerUID: ownerUID,
            date: referenceDate,
            weightKg: 67.8,
            note: "Morning",
            createdAt: referenceDate
        )
        try store.insert(weight)

        let mutation = makeMutation(
            entityType: .weightEntry,
            entityId: weightID.uuidString,
            localDate: localDate,
            operation: .upsert
        )

        let payload = try await builder.buildPayload(for: mutation)
        let document = try XCTUnwrap(payload.weightEntry)
        XCTAssertEqual(document.weightKg, 67.8)
        XCTAssertEqual(document.userId, ownerUID)
        XCTAssertEqual(document.localDate, localDate)
    }

    func testBuildDailyReviewUpsertPayload() async throws {
        let dailyLog = try seedDailyLog()
        let review = DailyReviewEntity(
            id: UUID(),
            ownerUID: ownerUID,
            dailyLogId: dailyLog.id,
            summaryText: "Strong protein day",
            caloriesSummary: "On target",
            proteinSummary: "High",
            hydrationSummary: "Good",
            workoutSummary: "Lifted",
            weightSummary: "Stable",
            tomorrowRecommendation: "Keep protein high",
            createdAt: referenceDate
        )
        review.dailyLog = dailyLog
        dailyLog.dailyReview = review
        try store.insert(review)
        try store.save()

        let mutation = makeMutation(
            entityType: .dailyReview,
            entityId: localDate,
            localDate: localDate,
            operation: .upsert
        )

        let payload = try await builder.buildPayload(for: mutation)
        let document = try XCTUnwrap(payload.dailyReview)
        XCTAssertEqual(document.summaryText, "Strong protein day")
        XCTAssertEqual(document.userId, ownerUID)
        XCTAssertEqual(document.localDate, localDate)
    }

    func testDeletePayloadDoesNotRequireEntity() async throws {
        let mutation = makeMutation(
            entityType: .foodEntry,
            entityId: UUID().uuidString,
            localDate: localDate,
            operation: .delete
        )

        let payload = try await builder.buildPayload(for: mutation)
        XCTAssertEqual(payload.operation, .delete)
        XCTAssertNil(payload.foodEntry)
        XCTAssertNil(payload.dailyLog)
        XCTAssertEqual(payload.deleteIdentity.ownerUID, ownerUID)
        XCTAssertEqual(payload.deleteIdentity.localDate, localDate)
    }

    func testDeletePayloadBuildsWhenEntityIsTombstoned() async throws {
        let foodID = UUID()
        let dailyLog = try seedDailyLog()
        let food = FoodEntryEntity(
            id: foodID,
            ownerUID: ownerUID,
            dailyLogId: dailyLog.id,
            mealTypeRawValue: MealType.lunch.rawValue,
            name: "Removed meal",
            quantity: 1,
            unit: "bowl",
            calories: 100,
            protein: 5,
            carbs: 10,
            fat: 2,
            fiber: nil,
            sodium: nil,
            sourceRawValue: FoodEntrySource.manual.rawValue,
            confidenceRawValue: ConfidenceLevel.high.rawValue,
            imageUrl: nil,
            notes: nil,
            createdAt: referenceDate,
            updatedAt: referenceDate
        )
        food.deletedAt = referenceDate
        food.syncStatusRawValue = AccountDataSyncStatus.pendingDelete.rawValue
        food.dailyLog = dailyLog
        try store.insert(food)

        let mutation = makeMutation(
            entityType: .foodEntry,
            entityId: foodID.uuidString,
            localDate: localDate,
            operation: .delete
        )

        let payload = try await builder.buildPayload(for: mutation)
        XCTAssertEqual(payload.operation, .delete)
        XCTAssertNil(payload.foodEntry)
    }

    func testRejectsOwnerMismatch() async throws {
        let foodID = UUID()
        let dailyLog = try seedDailyLog()
        let food = FoodEntryEntity(
            id: foodID,
            ownerUID: otherOwnerUID,
            dailyLogId: dailyLog.id,
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
            createdAt: referenceDate,
            updatedAt: referenceDate
        )
        food.dailyLog = dailyLog
        try store.insert(food)

        let mutation = makeMutation(
            entityType: .foodEntry,
            entityId: foodID.uuidString,
            localDate: localDate,
            operation: .upsert
        )

        await XCTAssertThrowsErrorAsync {
            _ = try await self.builder.buildPayload(for: mutation)
        }
    }

    func testRejectsMissingOwnerUIDOnMutation() async throws {
        let mutation = AccountSyncMutation(
            id: UUID().uuidString,
            ownerUID: "   ",
            entityType: .foodEntry,
            entityId: UUID().uuidString,
            localDate: localDate,
            operation: .upsert,
            createdAt: referenceDate,
            attemptCount: 0
        )

        await XCTAssertThrowsErrorAsync {
            _ = try await self.builder.buildPayload(for: mutation)
        }
    }

    func testUpsertMissingEntityThrows() async throws {
        let mutation = makeMutation(
            entityType: .foodEntry,
            entityId: UUID().uuidString,
            localDate: localDate,
            operation: .upsert
        )

        do {
            _ = try await builder.buildPayload(for: mutation)
            XCTFail("Expected missing local entity error.")
        } catch let error as AccountSyncPayloadBuilderError {
            XCTAssertEqual(
                error,
                .missingLocalEntity(entityType: .foodEntry, entityId: mutation.entityId)
            )
        }
    }

    func testFoodPayloadDoesNotIncludeRawImageData() async throws {
        let foodID = UUID()
        let dailyLog = try seedDailyLog()
        let food = FoodEntryEntity(
            id: foodID,
            ownerUID: ownerUID,
            dailyLogId: dailyLog.id,
            mealTypeRawValue: MealType.lunch.rawValue,
            name: "Photo meal",
            quantity: 1,
            unit: "plate",
            calories: 300,
            protein: 20,
            carbs: 25,
            fat: 10,
            fiber: nil,
            sodium: nil,
            sourceRawValue: FoodEntrySource.manual.rawValue,
            confidenceRawValue: ConfidenceLevel.high.rawValue,
            imageUrl: "https://example.com/meal.jpg",
            notes: nil,
            createdAt: referenceDate,
            updatedAt: referenceDate
        )
        food.dailyLog = dailyLog
        try store.insert(food)

        let mutation = makeMutation(
            entityType: .foodEntry,
            entityId: foodID.uuidString,
            localDate: localDate,
            operation: .upsert
        )

        let payload = try await builder.buildPayload(for: mutation)
        let document = try XCTUnwrap(payload.foodEntry)
        XCTAssertEqual(document.imageUrl, "https://example.com/meal.jpg")
        XCTAssertFalse(Mirror(reflecting: document).children.contains { $0.label == "imageBytes" })
        XCTAssertFalse(Mirror(reflecting: document).children.contains { $0.label == "imageData" })
    }

    // MARK: - Helpers

    @discardableResult
    private func seedDailyLog() throws -> DailyLogEntity {
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

    private func makeMutation(
        entityType: AccountSyncEntityType,
        entityId: String,
        localDate: String?,
        operation: AccountSyncOperation
    ) -> AccountSyncMutation {
        AccountSyncMutation(
            id: UUID().uuidString,
            ownerUID: ownerUID,
            entityType: entityType,
            entityId: entityId,
            localDate: localDate,
            operation: operation,
            createdAt: referenceDate,
            attemptCount: 0
        )
    }
}

private func XCTAssertThrowsErrorAsync(
    _ expression: @escaping () async throws -> Void,
    file: StaticString = #filePath,
    line: UInt = #line
) async {
    do {
        try await expression()
        XCTFail("Expected error to be thrown.", file: file, line: line)
    } catch {
        // expected
    }
}
