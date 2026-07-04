//
//  CoachTimelineStoreTests.swift
//  Fitness CoachTests
//
//  Forma — CoachTimelineStoring service API tests.
//

import XCTest
@testable import Fitness_Coach

@MainActor
final class CoachTimelineStoreTests: XCTestCase {

    private var store: SwiftDataCoachTimelineStore!
    private var calendar: Calendar!
    private var now: Date!

    override func setUp() async throws {
        let harness = try CoachTimelineStoreTestHarness.make()
        store = harness.store
        calendar = harness.calendar
        now = harness.now
    }

    override func tearDown() {
        store = nil
        calendar = nil
        now = nil
        super.tearDown()
    }

    // MARK: Append

    func testAppendEvent() async throws {
        let event = CoachTimelineStoreTestFixtures.messageEvent(
            text: "Hello Coach",
            occurredAt: now,
            calendar: calendar
        )

        try await store.append(event)

        let loaded = try await store.event(id: event.id)
        XCTAssertEqual(loaded, event)
    }

    func testAppendManyEventsInChronologicalOrder() async throws {
        let first = CoachTimelineStoreTestFixtures.messageEvent(
            text: "First",
            occurredAt: day(offset: -2),
            calendar: calendar
        )
        let second = CoachTimelineStoreTestFixtures.messageEvent(
            text: "Second",
            occurredAt: day(offset: -1),
            calendar: calendar
        )

        try await store.appendMany([second, first])

        let events = try await store.recentEvents(limit: 10, before: nil)
        XCTAssertEqual(events.map(\.id), [first.id, second.id])
    }

    // MARK: Queries

    func testEventsForLocalDate() async throws {
        let today = CoachTimelineStoreTestFixtures.messageEvent(
            text: "Today",
            occurredAt: now,
            calendar: calendar
        )
        let yesterday = CoachTimelineStoreTestFixtures.messageEvent(
            text: "Yesterday",
            occurredAt: day(offset: -1),
            calendar: calendar
        )
        try await store.appendMany([today, yesterday])

        let todayEvents = try await store.events(forLocalDate: today.localDate)
        XCTAssertEqual(todayEvents.map(\.id), [today.id])

        let yesterdayEvents = try await store.events(forLocalDate: yesterday.localDate)
        XCTAssertEqual(yesterdayEvents.map(\.id), [yesterday.id])
    }

    func testEventsInDateRange() async throws {
        let old = CoachTimelineStoreTestFixtures.messageEvent(
            text: "Old",
            occurredAt: day(offset: -5),
            calendar: calendar
        )
        let mid = CoachTimelineStoreTestFixtures.messageEvent(
            text: "Mid",
            occurredAt: day(offset: -2),
            calendar: calendar
        )
        let recent = CoachTimelineStoreTestFixtures.messageEvent(
            text: "Recent",
            occurredAt: now,
            calendar: calendar
        )
        try await store.appendMany([old, mid, recent])

        let start = day(offset: -3)
        let end = day(offset: -1)
        let ranged = try await store.events(from: start, to: end)
        XCTAssertEqual(ranged.map(\.id), [mid.id])
    }

    func testRecentEventsLimitAndBeforeDate() async throws {
        let first = CoachTimelineStoreTestFixtures.messageEvent(
            text: "A",
            occurredAt: day(offset: -3),
            calendar: calendar
        )
        let second = CoachTimelineStoreTestFixtures.messageEvent(
            text: "B",
            occurredAt: day(offset: -2),
            calendar: calendar
        )
        let third = CoachTimelineStoreTestFixtures.messageEvent(
            text: "C",
            occurredAt: day(offset: -1),
            calendar: calendar
        )
        try await store.appendMany([first, second, third])

        let before = day(offset: 0)
        let recent = try await store.recentEvents(limit: 2, before: before)
        XCTAssertEqual(recent.map(\.id), [second.id, third.id])
    }

    // MARK: Idempotency & status

    func testDuplicateIdAppendIsIdempotent() async throws {
        let event = CoachTimelineStoreTestFixtures.messageEvent(
            text: "Original",
            occurredAt: now,
            calendar: calendar
        )
        try await store.append(event)

        var duplicate = event
        duplicate = CoachTimelineEvent(
            id: event.id,
            type: .assistantMessage,
            source: .aiBackend,
            sourceAttribution: .classifier,
            status: .failed,
            payload: .message(MessagePayload(textPreview: "Changed")),
            utcTimestamp: event.utcTimestamp,
            localTimestamp: event.localTimestamp,
            timezoneIdentifier: event.timezoneIdentifier,
            localDate: event.localDate,
            link: event.link,
            supersedesEventId: event.supersedesEventId,
            recordedAt: event.recordedAt
        )

        try await store.append(duplicate)

        let loaded = try await store.event(id: event.id)
        XCTAssertEqual(loaded, event)
    }

    func testMarkEventStatus() async throws {
        let event = CoachTimelineStoreTestFixtures.foodEstimateEvent(occurredAt: now, calendar: calendar)
        try await store.append(event)

        try await store.markEventStatus(id: event.id, status: .confirmed)

        let loaded = try await store.event(id: event.id)
        XCTAssertEqual(loaded?.status, .confirmed)
    }

    func testSupersedeEvent() async throws {
        let original = CoachTimelineStoreTestFixtures.foodEstimateEvent(occurredAt: now, calendar: calendar)
        try await store.append(original)

        let replacement = CoachTimelineEvent.make(
            type: .foodLogged,
            source: .coachUI,
            sourceAttribution: .userConfirmation,
            status: .confirmed,
            payload: .foodLogged(
                FoodLoggedPayload(
                    entryId: UUID(),
                    name: "Logged meal",
                    calories: 500,
                    proteinGrams: 30,
                    carbsGrams: 40,
                    fatGrams: 15
                )
            ),
            occurredAt: now,
            calendar: calendar
        )

        try await store.supersedeEvent(id: original.id, by: replacement)

        let old = try await store.event(id: original.id)
        XCTAssertEqual(old?.status, .superseded)

        let fresh = try await store.event(id: replacement.id)
        XCTAssertEqual(fresh?.supersedesEventId, original.id)
    }

    // MARK: Safe decode

    func testCorruptedPayloadReturnsUnknownEventWithoutCrashing() async throws {
        let container = try FormaModelContainer.makeContainer(inMemory: true)
        let swiftDataStore = SwiftDataStore(container: container)
        let repository = CoachTimelinePersistenceRepository(
            store: swiftDataStore,
            dateProvider: FixedDailyLogTestDateProvider(
                now: CoachTimelineStoreTestFixtures.referenceNow,
                calendar: CoachTimelineStoreTestFixtures.calendar
            )
        )

        let entity = CoachTimelineEventEntity(
            id: UUID(),
            userId: nil,
            eventTypeRaw: "not_a_real_type",
            sourceRaw: "system",
            statusRaw: "confirmed",
            confidenceRaw: nil,
            sourceAttributionRaw: "system",
            utcCreatedAt: Date(),
            localCreatedAt: "broken",
            localDate: "2026-07-03",
            timezoneIdentifier: "UTC",
            summary: "broken row",
            payloadJSON: "{ this is not valid json",
            linkedEntryId: nil,
            linkedMessageId: nil,
            supersedesEventId: nil,
            schemaVersion: 1,
            createdAt: Date(),
            updatedAt: Date()
        )
        try swiftDataStore.insert(entity)

        let service = SwiftDataCoachTimelineStore(
            repository: repository,
            calendar: CoachTimelineStoreTestFixtures.calendar
        )

        let loaded = try await service.event(id: entity.id)
        XCTAssertEqual(loaded?.type, .unknown)
        XCTAssertEqual(loaded?.payload, .empty)
    }

    // MARK: Pruning

    func testDeleteEventsOlderThanCompactionPolicy() async throws {
        let oldSteps = CoachTimelineEvent.make(
            type: .stepsUpdated,
            source: .healthSync,
            sourceAttribution: .healthKit,
            status: .confirmed,
            payload: .steps(StepsPayload(steps: 3_000)),
            occurredAt: day(offset: -40),
            calendar: calendar
        )
        let todaySteps = CoachTimelineEvent.make(
            type: .stepsUpdated,
            source: .healthSync,
            sourceAttribution: .healthKit,
            status: .confirmed,
            payload: .steps(StepsPayload(steps: 4_000)),
            occurredAt: now,
            calendar: calendar
        )
        try await store.appendMany([oldSteps, todaySteps])

        try await store.deleteEventsOlderThan(
            policy: CoachTimelineCompactionPolicy(retainDays: 30)
        )

        let remaining = try await store.recentEvents(limit: 20, before: nil)
        XCTAssertEqual(remaining.map(\.id), [todaySteps.id])
    }

    // MARK: Helpers

    private func day(offset: Int) -> Date {
        calendar.date(byAdding: .day, value: offset, to: now)!
    }
}

// MARK: - Harness

@MainActor
private enum CoachTimelineStoreTestHarness {

    static func make(userId: String? = nil) throws -> (store: SwiftDataCoachTimelineStore, calendar: Calendar, now: Date) {
        let calendar = CoachTimelineStoreTestFixtures.calendar
        let now = CoachTimelineStoreTestFixtures.referenceNow
        let dateProvider = FixedDailyLogTestDateProvider(now: now, calendar: calendar)
        let container = try FormaModelContainer.makeContainer(inMemory: true)
        let store = SwiftDataCoachTimelineStore(
            store: SwiftDataStore(container: container),
            dateProvider: dateProvider,
            userIdProvider: { userId },
            calendar: calendar
        )
        return (store, calendar, dateProvider.now)
    }
}

private enum CoachTimelineStoreTestFixtures {

    static let calendar: Calendar = {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "America/Los_Angeles")!
        return calendar
    }()

    static let referenceNow: Date = {
        var components = DateComponents()
        components.calendar = calendar
        components.timeZone = calendar.timeZone
        components.year = 2026
        components.month = 7
        components.day = 3
        components.hour = 12
        return calendar.date(from: components)!
    }()

    static func messageEvent(
        text: String,
        occurredAt: Date,
        calendar: Calendar
    ) -> CoachTimelineEvent {
        CoachTimelineEvent.make(
            type: .userMessage,
            source: .coachUI,
            sourceAttribution: .localParser,
            status: .confirmed,
            payload: .message(MessagePayload(textPreview: text)),
            occurredAt: occurredAt,
            calendar: calendar
        )
    }

    static func foodEstimateEvent(
        occurredAt: Date,
        calendar: Calendar
    ) -> CoachTimelineEvent {
        CoachTimelineEvent.make(
            type: .foodEstimateCreated,
            source: .aiBackend,
            sourceAttribution: .estimateFood,
            confidence: .medium,
            status: .pending,
            payload: .foodEstimate(
                FoodEstimatePayload(mealName: "Salad", calories: 420, requiresConfirmation: true)
            ),
            occurredAt: occurredAt,
            calendar: calendar
        )
    }
}
