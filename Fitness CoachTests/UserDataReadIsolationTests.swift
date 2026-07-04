//
//  UserDataReadIsolationTests.swift
//  Fitness CoachTests
//
//  Forma — Phase 1 per-user read isolation for local user data.
//

import XCTest
import SwiftData
@testable import Fitness_Coach

@MainActor
final class UserDataReadIsolationTests: XCTestCase {

    func testFilterVisibleCoachEntitiesExcludesNilUserIdForSignedInSession() throws {
        let harness = try makeHarness(sessionUID: "signed-in-user")
        let entity = CoachChatTranscriptMessageEntity(
            id: UUID(),
            userId: nil,
            roleRawValue: "assistant",
            text: "legacy",
            createdAt: harness.today,
            relatedDailyLogId: nil,
            relatedEntryId: nil,
            hasImageAttachment: false,
            imageKindRaw: nil,
            imageSourceRaw: nil,
            thumbnailJPEG: nil,
            fullImageJPEG: nil,
            originalImageByteSize: nil,
            photoSessionID: nil,
            relatedUserMessageID: nil,
            photoAnalysisLinkKindRaw: nil,
            structuredContentJSON: nil,
            updatedAt: harness.today
        )

        let visible = UserDataOwnerScope.filterVisibleCoachEntities(
            [entity],
            sessionUID: "signed-in-user"
        )
        XCTAssertTrue(visible.isEmpty)
    }

    func testSignedInUserDoesNotSeeLegacyUnownedFoodRows() throws {
        let harness = try makeHarness(sessionUID: "signed-in-user")
        _ = try harness.profileService.createProfile(
            ProfileTestFixtures.sampleDraft,
            ownerUID: "signed-in-user"
        )
        try seedLegacyUnownedFood(in: harness.store)

        let entries = try harness.foodLogService.getFoodEntries(for: harness.today)
        XCTAssertTrue(entries.isEmpty)
    }

    func testSignedInUserDoesNotSeeForeignOwnedFoodRows() throws {
        let harness = try makeHarness(sessionUID: "user-b")
        _ = try harness.profileService.createProfile(
            ProfileTestFixtures.sampleDraft,
            ownerUID: "user-b"
        )
        try seedOwnedFood(in: harness.store, ownerUID: "user-a", name: "Foreign meal")

        let entries = try harness.foodLogService.getFoodEntries(for: harness.today)
        XCTAssertTrue(entries.isEmpty)
    }

    func testSignedInUserOnlySeesOwnWeightEntries() throws {
        let harness = try makeHarness(sessionUID: "user-b")
        _ = try harness.profileService.createProfile(
            ProfileTestFixtures.sampleDraft,
            ownerUID: "user-b"
        )
        try seedOwnedWeight(in: harness.store, ownerUID: "user-a", weightKg: 80)
        harness.sessionUID.uid = "user-b"
        _ = try harness.weightLogService.logWeight(72.0, date: harness.today)

        let entries = try harness.weightLogService.getWeightEntries(
            from: harness.today,
            to: harness.today
        )
        XCTAssertEqual(entries.count, 1)
        XCTAssertEqual(entries.first?.weightKg, 72.0)
    }

    func testSignedInUserFoodRangeQueryIsScopedToCurrentUID() throws {
        let harness = try makeHarness(sessionUID: "user-b")
        _ = try harness.profileService.createProfile(
            ProfileTestFixtures.sampleDraft,
            ownerUID: "user-b"
        )
        try seedOwnedFood(in: harness.store, ownerUID: "user-a", name: "Foreign meal")

        harness.sessionUID.uid = "user-b"
        _ = try harness.foodLogService.addFoodEntry(
            DailyLogServiceTestSupport.foodDraft(name: "Owned meal", calories: 300),
            date: harness.today
        )

        let entries = try harness.foodLogService.getFoodEntries(
            from: harness.today,
            to: harness.today
        )
        XCTAssertEqual(entries.count, 1)
        XCTAssertEqual(entries.first?.name, "Owned meal")
    }

    func testSignedInCoachTranscriptExcludesNilUserIdRows() throws {
        let harness = try makeHarness(sessionUID: "signed-in-user")
        let repository = CoachChatTranscriptPersistenceRepository(store: harness.store)

        let legacyMessage = ChatMessage(
            id: UUID(),
            role: .assistant,
            text: "Legacy coach reply",
            createdAt: ProfileTestFixtures.referenceDate
        )
        harness.store.modelContext.insert(
            CoachChatTranscriptMessageEntity(
                model: legacyMessage,
                userId: nil,
                updatedAt: ProfileTestFixtures.referenceDate
            )
        )
        try harness.store.save()

        let ownedMessage = ChatMessage(
            id: UUID(),
            role: .user,
            text: "Owned message",
            createdAt: ProfileTestFixtures.referenceDate
        )
        try repository.replaceAll([ownedMessage], userId: "signed-in-user")

        let messages = try repository.fetchAllSorted(userId: "signed-in-user")
        XCTAssertEqual(messages.count, 1)
        XCTAssertEqual(messages.first?.text, "Owned message")
    }

    func testSignedInCoachTimelineExcludesForeignUserRows() throws {
        let harness = try makeHarness(sessionUID: "user-b")
        let repository = CoachTimelinePersistenceRepository(
            store: harness.store,
            dateProvider: harness.dateProvider
        )

        let foreignEvent = CoachTimelineEvent.make(
            type: .userMessage,
            source: .coachUI,
            sourceAttribution: .userConfirmation,
            status: .confirmed,
            payload: .message(MessagePayload(textPreview: "Foreign")),
            occurredAt: harness.today
        )
        try repository.appendIdempotent(foreignEvent, userId: "user-a")

        let ownedEvent = CoachTimelineEvent.make(
            type: .assistantMessage,
            source: .aiBackend,
            sourceAttribution: .classifier,
            status: .confirmed,
            payload: .message(MessagePayload(textPreview: "Owned")),
            occurredAt: harness.today
        )
        try repository.appendIdempotent(ownedEvent, userId: "user-b")

        let events = try repository.fetch(userId: "user-b")
        XCTAssertEqual(events.count, 1)
        XCTAssertEqual(events.first?.type, .assistantMessage)
    }

    func testSignedInDailyLogsExcludeForeignAndUnownedRows() throws {
        let harness = try makeHarness(sessionUID: "user-b")
        _ = try harness.profileService.createProfile(
            ProfileTestFixtures.sampleDraft,
            ownerUID: "user-b"
        )
        try seedLegacyUnownedFood(in: harness.store)
        try seedOwnedFood(in: harness.store, ownerUID: "user-a", name: "Foreign meal")

        harness.sessionUID.uid = "user-b"
        _ = try harness.dailyLogService.getOrCreateLog(for: harness.today)

        let logs = try harness.dailyLogService.getLogs(from: harness.today, to: harness.today)
        XCTAssertEqual(logs.count, 1)
        XCTAssertEqual(try harness.foodLogService.getFoodEntries(for: harness.today).count, 0)
    }

    // MARK: - Harness

    private struct Harness {
        let store: SwiftDataStore
        let profileService: UserProfileService
        let dailyLogService: DailyLogService
        let foodLogService: FoodLogService
        let waterLogService: WaterLogService
        let weightLogService: WeightLogService
        let dateProvider: FixedDailyLogTestDateProvider
        let sessionUID: DailyLogTestSessionUID

        var today: Date { dateProvider.now }
    }

    private func makeHarness(sessionUID: String) throws -> Harness {
        let base = try DailyLogServiceTestSupport.makeHarness(sessionUID: sessionUID)
        return Harness(
            store: base.store,
            profileService: base.profileService,
            dailyLogService: base.dailyLogService,
            foodLogService: base.foodLogService,
            waterLogService: base.waterLogService,
            weightLogService: base.weightLogService,
            dateProvider: base.dateProvider,
            sessionUID: base.sessionUID
        )
    }

    private func seedLegacyUnownedFood(in store: SwiftDataStore) throws {
        let context = store.modelContext
        _ = try FormaSwiftDataMigrationTestSupport.seedNutritionLogs(in: context)
    }

    private func seedOwnedFood(
        in store: SwiftDataStore,
        ownerUID: String,
        name: String
    ) throws {
        let context = store.modelContext
        let dailyLogID = UUID()
        let dailyLog = DailyLogEntity(
            id: dailyLogID,
            ownerUID: ownerUID,
            date: ProfileTestFixtures.referenceDate,
            weightKg: nil,
            calorieTarget: 2_000,
            proteinTarget: 140,
            carbTarget: 180,
            fatTarget: 65,
            waterTargetMl: 2_500,
            expectedWeeklyWeightLossKg: nil,
            aggressivenessRawValue: "moderate",
            caloriesConsumed: 0,
            proteinConsumed: 0,
            carbsConsumed: 0,
            fatConsumed: 0,
            fiberConsumed: nil,
            sodiumConsumed: nil,
            waterConsumedMl: 0,
            steps: 0,
            workoutCaloriesBurned: 0,
            dailyReviewId: nil,
            createdAt: ProfileTestFixtures.referenceDate,
            updatedAt: ProfileTestFixtures.referenceDate
        )
        let food = FoodEntryEntity(
            id: UUID(),
            ownerUID: ownerUID,
            dailyLogId: dailyLogID,
            mealTypeRawValue: MealType.lunch.rawValue,
            name: name,
            quantity: 1,
            unit: "serving",
            calories: 300,
            protein: 20,
            carbs: 30,
            fat: 10,
            fiber: nil,
            sodium: nil,
            sourceRawValue: FoodEntrySource.manual.rawValue,
            confidenceRawValue: ConfidenceLevel.high.rawValue,
            imageUrl: nil,
            notes: nil,
            createdAt: ProfileTestFixtures.referenceDate,
            updatedAt: ProfileTestFixtures.referenceDate
        )
        food.dailyLog = dailyLog
        context.insert(dailyLog)
        context.insert(food)
        try context.save()
    }

    private func seedOwnedWeight(
        in store: SwiftDataStore,
        ownerUID: String,
        weightKg: Double
    ) throws {
        let context = store.modelContext
        let entity = WeightEntryEntity(
            id: UUID(),
            ownerUID: ownerUID,
            date: ProfileTestFixtures.referenceDate,
            weightKg: weightKg,
            note: nil,
            createdAt: ProfileTestFixtures.referenceDate
        )
        context.insert(entity)
        try context.save()
    }
}
