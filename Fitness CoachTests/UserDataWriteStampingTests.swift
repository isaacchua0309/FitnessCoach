//
//  UserDataWriteStampingTests.swift
//  Fitness CoachTests
//
//  Forma — Phase 1 UID stamping on local user-data writes.
//

import XCTest
import SwiftData
@testable import Fitness_Coach

@MainActor
final class UserDataWriteStampingTests: XCTestCase {

    private var harness: DailyLogServiceTestSupport.Harness!

    override func setUp() async throws {
        harness = try DailyLogServiceTestSupport.makeHarness()
        _ = try harness.seedProfile()
        _ = try harness.profileService.assignOwnerUID("signed-in-user")
    }

    override func tearDown() {
        harness = nil
        super.tearDown()
    }

    func testFoodWriteStampsOwnerAndBookkeepingFields() throws {
        _ = try harness.foodLogService.addFoodEntry(
            DailyLogServiceTestSupport.foodDraft(name: "Stamped Meal", calories: 500),
            date: harness.today
        )

        let entity = try XCTUnwrap(try harness.store.fetch(FetchDescriptor<FoodEntryEntity>()).first)
        XCTAssertEqual(entity.ownerUID, "signed-in-user")
        XCTAssertEqual(entity.entitySchemaVersion, UserDataEntitySchema.currentEntitySchemaVersion)
        XCTAssertNotNil(entity.localUpdatedAt)
    }

    func testWaterWriteStampsOwnerUID() throws {
        _ = try harness.waterLogService.addWater(amountMl: 250, date: harness.today)

        let entity = try XCTUnwrap(try harness.store.fetch(FetchDescriptor<WaterEntryEntity>()).first)
        XCTAssertEqual(entity.ownerUID, "signed-in-user")
    }

    func testWeightWriteStampsOwnerUID() throws {
        _ = try harness.weightLogService.logWeight(70.5, date: harness.today)

        let entity = try XCTUnwrap(try harness.store.fetch(FetchDescriptor<WeightEntryEntity>()).first)
        XCTAssertEqual(entity.ownerUID, "signed-in-user")
    }

    func testDailyLogCreationStampsOwnerUID() throws {
        _ = try harness.dailyLogService.getOrCreateLog(for: harness.today)

        let entity = try XCTUnwrap(try harness.store.fetch(FetchDescriptor<DailyLogEntity>()).first)
        XCTAssertEqual(entity.ownerUID, "signed-in-user")
    }

    func testCoachTranscriptWriteStampsUserId() throws {
        let repository = CoachChatTranscriptPersistenceRepository(store: harness.store)
        let message = ChatMessage(
            id: UUID(),
            role: .user,
            text: "Hello coach",
            createdAt: harness.today
        )

        try repository.replaceAll([message], userId: "signed-in-user")

        let entity = try XCTUnwrap(
            try harness.store.fetch(FetchDescriptor<CoachChatTranscriptMessageEntity>()).first
        )
        XCTAssertEqual(entity.userId, "signed-in-user")
        XCTAssertEqual(entity.entitySchemaVersion, UserDataEntitySchema.currentEntitySchemaVersion)
        XCTAssertNotNil(entity.localUpdatedAt)
    }

    func testCoachTimelineWriteStampsUserId() throws {
        let repository = CoachTimelinePersistenceRepository(
            store: harness.store,
            dateProvider: harness.dateProvider
        )
        let event = CoachTimelineEvent.make(
            type: .userMessage,
            source: .coachUI,
            sourceAttribution: .userConfirmation,
            status: .confirmed,
            payload: .message(MessagePayload(textPreview: "Hi")),
            occurredAt: harness.today
        )

        try repository.appendIdempotent(event, userId: "signed-in-user")

        let entity = try XCTUnwrap(
            try harness.store.fetch(FetchDescriptor<CoachTimelineEventEntity>()).first
        )
        XCTAssertEqual(entity.userId, "signed-in-user")
        XCTAssertEqual(entity.entitySchemaVersion, UserDataEntitySchema.currentEntitySchemaVersion)
        XCTAssertNotNil(entity.localUpdatedAt)
    }

    func testFoodEditPreservesOwnerUID() throws {
        let entry = try harness.foodLogService.addFoodEntry(
            DailyLogServiceTestSupport.foodDraft(name: "Editable Meal", calories: 400),
            date: harness.today
        )

        _ = try harness.foodLogService.editFoodEntry(
            id: entry.id,
            update: FoodEntryUpdate(name: "Renamed Meal")
        )

        let entity = try XCTUnwrap(try harness.store.fetch(FetchDescriptor<FoodEntryEntity>()).first)
        XCTAssertEqual(entity.ownerUID, "signed-in-user")
        XCTAssertEqual(entity.name, "Renamed Meal")
        XCTAssertNotNil(entity.localUpdatedAt)
    }
}
