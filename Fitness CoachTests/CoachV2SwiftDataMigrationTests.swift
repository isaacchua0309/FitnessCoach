//
//  CoachV2SwiftDataMigrationTests.swift
//  Fitness CoachTests
//
//  Coach Timeline Context v2 SwiftData migration hardening tests.
//

import XCTest
import SwiftData
@testable import Fitness_Coach

@MainActor
final class CoachV2SwiftDataMigrationTests: XCTestCase {

    private var storeURL: URL!

    override func setUp() {
        super.setUp()
        FormaSwiftDataMigrationGate.resetForTesting()
        storeURL = FormaSwiftDataMigrationTestSupport.makeTemporaryStoreURL()
    }

    override func tearDown() {
        FormaSwiftDataMigrationTestSupport.removeStore(at: storeURL)
        FormaSwiftDataMigrationGate.resetForTesting()
        storeURL = nil
        super.tearDown()
    }

    // MARK: Schema registration

    func testCoachV2EntitiesRegisteredInActiveSchema() {
        XCTAssertTrue(FormaSchemaCoachV2Verification.coachV2EntitiesAreRegisteredInActiveSchema())
        XCTAssertTrue(FormaSchemaCoachV2Verification.coachTimelineEntityRegisteredAtV5())
        XCTAssertTrue(FormaSchemaCoachV2Verification.legacyChatMessageEntityIsV1Only())
    }

    func testFreshInstallCurrentSchemaInitializesEmptyCoachTables() throws {
        let container = try FormaModelContainer.makeContainer(inMemory: true)
        XCTAssertEqual(try FormaSwiftDataMigrationTestSupport.fetchCount(CoachTimelineEventEntity.self, in: container), 0)
        XCTAssertEqual(try FormaSwiftDataMigrationTestSupport.fetchCount(CoachChatTranscriptMessageEntity.self, in: container), 0)
        XCTAssertTrue(FormaSwiftDataMigrationGate.isCoachV2MigrationComplete)
    }

    // MARK: On-disk migration

    func testPreV4StoreMigratesToCurrentSchemaAndPreservesNutritionLogs() throws {
        let legacyContainer = try FormaModelContainer.makeLegacyContainer(FormaSchemaV4.self, storeURL: storeURL)
        let legacyContext = ModelContext(legacyContainer)
        let seeded = try FormaSwiftDataMigrationTestSupport.seedNutritionLogs(in: legacyContext)
        XCTAssertFalse(FormaSwiftDataMigrationGate.isCoachV2MigrationComplete)

        _ = legacyContainer
        let migratedContainer = try FormaModelContainer.migrateContainer(at: storeURL)

        XCTAssertTrue(FormaSwiftDataMigrationGate.isCoachV2MigrationComplete)
        XCTAssertEqual(try FormaSwiftDataMigrationTestSupport.fetchCount(DailyLogEntity.self, in: migratedContainer), 1)
        XCTAssertEqual(try FormaSwiftDataMigrationTestSupport.fetchCount(FoodEntryEntity.self, in: migratedContainer), 1)
        XCTAssertEqual(try FormaSwiftDataMigrationTestSupport.fetchCount(WaterEntryEntity.self, in: migratedContainer), 1)
        XCTAssertEqual(try FormaSwiftDataMigrationTestSupport.fetchCount(WeightEntryEntity.self, in: migratedContainer), 1)
        XCTAssertEqual(try FormaSwiftDataMigrationTestSupport.fetchCount(CoachTimelineEventEntity.self, in: migratedContainer), 0)
        XCTAssertEqual(try FormaSwiftDataMigrationTestSupport.fetchCount(CoachChatTranscriptMessageEntity.self, in: migratedContainer), 0)

        let context = ModelContext(migratedContainer)
        let food = try XCTUnwrap(try context.fetch(FetchDescriptor<FoodEntryEntity>()).first)
        XCTAssertEqual(food.id, seeded.foodID)
        XCTAssertEqual(food.name, "Chicken rice")
        XCTAssertEqual(food.calories, 520)
    }

    func testPreV1StoreWithLegacyChatMigratesWithoutConflict() throws {
        let legacyContainer = try FormaModelContainer.makeLegacyContainer(FormaSchemaV1.self, storeURL: storeURL)
        let legacyContext = ModelContext(legacyContainer)
        let seeded = try FormaSwiftDataMigrationTestSupport.seedNutritionLogs(in: legacyContext)
        _ = try FormaSwiftDataMigrationTestSupport.seedLegacyChatMessage(in: legacyContext)

        _ = legacyContainer
        let migratedContainer = try FormaModelContainer.migrateContainer(at: storeURL)

        XCTAssertEqual(try FormaSwiftDataMigrationTestSupport.fetchCount(FoodEntryEntity.self, in: migratedContainer), 1)
        XCTAssertEqual(try FormaSwiftDataMigrationTestSupport.fetchCount(CoachChatTranscriptMessageEntity.self, in: migratedContainer), 0)
        let food = try XCTUnwrap(
            try ModelContext(migratedContainer).fetch(FetchDescriptor<FoodEntryEntity>()).first
        )
        XCTAssertEqual(food.id, seeded.foodID)
    }

    func testStoreWithMalformedTimelinePayloadDecodesSafelyAfterMigration() throws {
        let legacyContainer = try FormaModelContainer.makeLegacyContainer(FormaSchemaV5.self, storeURL: storeURL)
        let legacyContext = ModelContext(legacyContainer)
        let eventID = try FormaSwiftDataMigrationTestSupport.seedMalformedTimelineEvent(in: legacyContext)

        _ = legacyContainer
        let migratedContainer = try FormaModelContainer.migrateContainer(at: storeURL)
        let context = ModelContext(migratedContainer)
        let entity = try XCTUnwrap(try context.fetch(FetchDescriptor<CoachTimelineEventEntity>()).first { $0.id == eventID })

        let model = entity.toModelSafe()
        XCTAssertEqual(model.type, .foodLogged)
        XCTAssertEqual(model.payload, .empty)
    }

    // MARK: Backfill + maintenance gating

    func testBackfillDoesNotRunBeforeMigrationComplete() async throws {
        let harness = try DailyLogServiceTestSupport.makeHarness()
        _ = try harness.foodLogService.addFoodEntry(
            DailyLogServiceTestSupport.foodDraft(name: "Eggs", calories: 140, protein: 12),
            date: harness.today
        )

        let timelineStore = FakeCoachTimelineStore()
        let service = CoachTimelineBackfillService(
            timelineStore: timelineStore,
            foodLogService: harness.foodLogService
        )

        await service.runBackfill()
        XCTAssertTrue(timelineStore.events.isEmpty)

        FormaSwiftDataMigrationGate.markCoachV2MigrationComplete()
        await service.runBackfill()
        XCTAssertEqual(timelineStore.events.count, 1)
    }

    func testRepeatedBackfillAfterMigrationDoesNotDuplicateEvents() async throws {
        FormaSwiftDataMigrationGate.markCoachV2MigrationComplete()
        let harness = try DailyLogServiceTestSupport.makeHarness()
        try harness.seedProfile()
        _ = try harness.foodLogService.addFoodEntry(
            DailyLogServiceTestSupport.foodDraft(name: "Salad", calories: 420, protein: 25),
            date: harness.today
        )

        let timelineStore = SwiftDataCoachTimelineStore(store: harness.store)
        let localDate = CoachTimelineEvent.makeTimestamps(
            from: harness.today,
            calendar: harness.dateProvider.calendar
        ).localDate

        let firstService = CoachTimelineBackfillService(
            timelineStore: timelineStore,
            foodLogService: harness.foodLogService,
            dateProvider: harness.dateProvider,
            calendar: harness.dateProvider.calendar
        )
        await firstService.runBackfill()

        let secondService = CoachTimelineBackfillService(
            timelineStore: timelineStore,
            foodLogService: harness.foodLogService,
            dateProvider: harness.dateProvider,
            calendar: harness.dateProvider.calendar
        )
        await secondService.runBackfill()

        let events = try await timelineStore.events(forLocalDate: localDate)
        XCTAssertEqual(events.filter { $0.type == .foodLogged }.count, 1)
    }

    func testTranscriptStoreHandlesEmptyStoreWithoutCrashing() throws {
        let container = try FormaModelContainer.makeContainer(inMemory: true)
        let store = SwiftDataCoachChatTranscriptStore(store: SwiftDataStore(container: container))
        XCTAssertTrue(store.loadMessages().isEmpty)
        store.saveMessages([])
        XCTAssertTrue(store.loadMessages().isEmpty)
    }

    func testTranscriptPruningSkippedUntilMigrationComplete() throws {
        let container = try FormaModelContainer.makeContainer(
            inMemory: true,
            storeURL: nil,
            markMigrationComplete: false
        )
        let swiftDataStore = SwiftDataStore(container: container)
        let context = swiftDataStore.modelContext
        let now = FormaSwiftDataMigrationTestSupport.referenceDate
        for index in 0..<305 {
            context.insert(
                CoachChatTranscriptMessageEntity(
                    model: ChatMessage(
                        role: .user,
                        text: "message \(index)",
                        createdAt: now.addingTimeInterval(TimeInterval(index))
                    ),
                    userId: nil
                )
            )
        }
        try context.save()

        let transcriptStore = SwiftDataCoachChatTranscriptStore(store: swiftDataStore)
        FormaSwiftDataMigrationGate.resetForTesting()
        XCTAssertEqual(transcriptStore.loadMessages().count, 305)

        FormaSwiftDataMigrationGate.markCoachV2MigrationComplete()
        XCTAssertEqual(transcriptStore.loadMessages().count, 300)
    }

    func testTimelineCompactionSkippedUntilMigrationComplete() async throws {
        FormaSwiftDataMigrationGate.resetForTesting()
        let container = try FormaModelContainer.makeContainer(
            inMemory: true,
            storeURL: nil,
            markMigrationComplete: false
        )
        let timelineStore = SwiftDataCoachTimelineStore(store: SwiftDataStore(container: container))
        let oldDate = Calendar.current.date(byAdding: .day, value: -40, to: Date())!
        let event = CoachTimelineEvent.make(
            type: .systemRefresh,
            source: .system,
            sourceAttribution: .system,
            status: .confirmed,
            payload: .systemRefresh(SystemRefreshPayload(reason: "old refresh")),
            occurredAt: oldDate
        )
        try await timelineStore.append(event)

        try await timelineStore.deleteEventsOlderThan(policy: .default)
        let remainingBeforeMigration = try await timelineStore.recentEvents(limit: 10, before: nil)
        XCTAssertEqual(remainingBeforeMigration.count, 1)

        FormaSwiftDataMigrationGate.markCoachV2MigrationComplete()
        try await timelineStore.deleteEventsOlderThan(policy: .default)
        let pruned = try await timelineStore.recentEvents(limit: 10, before: nil)
        XCTAssertTrue(pruned.isEmpty)
    }
}
