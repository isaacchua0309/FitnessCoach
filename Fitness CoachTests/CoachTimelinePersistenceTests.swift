//
//  CoachTimelinePersistenceTests.swift
//  Fitness CoachTests
//
//  Forma — Coach Timeline SwiftData persistence tests.
//

import XCTest
@testable import Fitness_Coach

@MainActor
final class CoachTimelinePersistenceTests: XCTestCase {

    private var harness: Harness!

    override func setUp() async throws {
        harness = try Harness()
    }

    override func tearDown() {
        harness = nil
        super.tearDown()
    }

    // MARK: Codec

    func testPayloadCodecRoundTripPreservesExtendedLinks() throws {
        let event = CoachTimelineEvent.make(
            type: .photoAnalysisCompleted,
            source: .aiBackend,
            sourceAttribution: .mealImage,
            confidence: .medium,
            status: .pending,
            payload: .photo(
                PhotoPayload(sessionId: UUID(), mimeType: "image/jpeg", compressedByteSize: 88_000)
            ),
            link: CoachTimelineEventLink(
                linkedMessageId: UUID(),
                linkedPhotoSessionId: UUID(),
                linkedDailyLogId: UUID(),
                relatedEventIds: [UUID()]
            )
        )

        let json = CoachTimelineEventPayloadCodec.encode(event: event)
        let decoded = try XCTUnwrap({
            if case .success(let envelope) = CoachTimelineEventPayloadCodec.decode(json) {
                return envelope
            }
            return nil
        }())

        XCTAssertEqual(decoded.payload, event.payload)
        XCTAssertEqual(decoded.linkedPhotoSessionId, event.link.linkedPhotoSessionId)
        XCTAssertEqual(decoded.linkedDailyLogId, event.link.linkedDailyLogId)
        XCTAssertEqual(decoded.relatedEventIds, event.link.relatedEventIds)
    }

    func testUnknownPayloadJSONFallsBackToEmptyWithoutCrashing() {
        let result = CoachTimelineEventPayloadCodec.decode("{\"unexpected\":true,\"items\":[1,2,3]}")

        switch result {
        case .unknownPayload(let rawJSON):
            XCTAssertTrue(rawJSON.contains("unexpected"))
        default:
            XCTFail("Expected unknownPayload fallback")
        }

        XCTAssertEqual(CoachTimelineEventPayloadCodec.decodePayloadOnly("not-json"), .empty)
    }

    func testUnknownEventTypeMapsToUnknownDomainCase() {
        let entity = CoachTimelineEventEntity(
            id: UUID(),
            userId: nil,
            eventTypeRaw: "futureEventType_v99",
            sourceRaw: "system",
            statusRaw: "confirmed",
            confidenceRaw: nil,
            sourceAttributionRaw: "system",
            utcCreatedAt: Date(),
            localCreatedAt: "2026-07-03T10:00:00-07:00",
            localDate: "2026-07-03",
            timezoneIdentifier: "America/Los_Angeles",
            summary: "legacy row",
            payloadJSON: "{\"schemaVersion\":99,\"payload\":{\"kind\":\"empty\"},\"relatedEventIds\":[]}",
            linkedEntryId: nil,
            linkedMessageId: nil,
            supersedesEventId: nil,
            schemaVersion: 99,
            createdAt: Date(),
            updatedAt: Date()
        )

        let model = entity.toModel()
        XCTAssertEqual(model.type, .unknown)
        XCTAssertEqual(model.payload, .empty)
        XCTAssertEqual(model.source, .system)
    }

    // MARK: Entity mapping

    func testEntityRoundTripPreservesCoreFields() throws {
        let original = CoachTimelineEvent.make(
            type: .foodLogged,
            source: .coachUI,
            sourceAttribution: .userConfirmation,
            confidence: .high,
            status: .confirmed,
            payload: .foodLogged(
                FoodLoggedPayload(
                    entryId: UUID(),
                    dailyLogId: UUID(),
                    name: "Greek yogurt",
                    calories: 150,
                    proteinGrams: 15,
                    carbsGrams: 8,
                    fatGrams: 4
                )
            ),
            link: CoachTimelineEventLink(
                linkedEntryId: UUID(),
                linkedMessageId: UUID()
            ),
            supersedesEventId: UUID()
        )

        let entity = CoachTimelineEventEntity(model: original, userId: "user-123")
        let roundTripped = entity.toModel()

        XCTAssertEqual(roundTripped.id, original.id)
        XCTAssertEqual(roundTripped.type, original.type)
        XCTAssertEqual(roundTripped.status, original.status)
        XCTAssertEqual(roundTripped.confidence, original.confidence)
        XCTAssertEqual(roundTripped.payload, original.payload)
        XCTAssertEqual(roundTripped.linkedEntryId, original.linkedEntryId)
        XCTAssertEqual(roundTripped.linkedMessageId, original.linkedMessageId)
        XCTAssertEqual(roundTripped.supersedesEventId, original.supersedesEventId)
        XCTAssertEqual(entity.userId, "user-123")
        XCTAssertFalse(entity.summary.isEmpty)
        XCTAssertFalse(entity.payloadJSON.isEmpty)
    }

    // MARK: Store

    func testStoreAppendAndFetchOrderedHistory() throws {
        let first = CoachTimelineEvent.make(
            type: .userMessage,
            source: .coachUI,
            sourceAttribution: .localParser,
            status: .confirmed,
            payload: .message(MessagePayload(textPreview: "First")),
            occurredAt: harness.day(offset: -1)
        )
        let second = CoachTimelineEvent.make(
            type: .assistantMessage,
            source: .aiBackend,
            sourceAttribution: .classifier,
            status: .confirmed,
            payload: .message(MessagePayload(textPreview: "Second")),
            occurredAt: harness.now
        )

        try harness.store.append(first, userId: "uid-a")
        try harness.store.append(second, userId: "uid-a")

        let history = try harness.store.fetchOrderedHistory(userId: "uid-a")
        XCTAssertEqual(history.map(\.type), [.userMessage, .assistantMessage])
    }

    func testPruneDoesNotDeleteSameDayEvents() throws {
        let todayEvent = CoachTimelineEvent.make(
            type: .stepsUpdated,
            source: .healthSync,
            sourceAttribution: .healthKit,
            status: .confirmed,
            payload: .steps(StepsPayload(steps: 4_000)),
            occurredAt: harness.now
        )
        try harness.store.append(todayEvent, userId: nil)

        let deleted = try harness.store.prune(
            policy: CoachTimelinePruningPolicy(detailedRetentionDays: 0, writeCompactSummaries: false),
            calendar: harness.calendar
        )

        XCTAssertEqual(deleted, 0)
        XCTAssertEqual(try harness.store.fetchOrderedHistory().count, 1)
    }

    func testPruneRemovesOldCollapsibleEventsAndWritesSummary() throws {
        let oldDate = harness.day(offset: -40)
        for stepCount in [1000, 1100, 1200] {
            let event = CoachTimelineEvent.make(
                type: .stepsUpdated,
                source: .healthSync,
                sourceAttribution: .healthKit,
                status: .confirmed,
                payload: .steps(StepsPayload(steps: stepCount)),
                occurredAt: oldDate,
                calendar: harness.calendar
            )
            try harness.store.append(event, userId: nil)
        }

        let deleted = try harness.store.prune(
            policy: CoachTimelinePruningPolicy(
                detailedRetentionDays: 30,
                writeCompactSummaries: true
            ),
            calendar: harness.calendar
        )

        XCTAssertEqual(deleted, 3)
        let remaining = try harness.store.fetchOrderedHistory()
        XCTAssertEqual(remaining.count, 1)
        XCTAssertEqual(remaining.first?.type, .systemRefresh)
        if case .systemRefresh(let payload) = remaining.first?.payload {
            XCTAssertTrue(payload.reason?.contains("Compact summary") == true)
        } else {
            XCTFail("Expected compact summary event")
        }
    }

    func testPrunePreservesConfirmedMutationsBeyondRetention() throws {
        let oldDate = harness.day(offset: -45)
        let food = CoachTimelineEvent.make(
            type: .foodLogged,
            source: .coachUI,
            sourceAttribution: .userConfirmation,
            status: .confirmed,
            payload: .foodLogged(
                FoodLoggedPayload(
                    entryId: UUID(),
                    name: "Chicken",
                    calories: 250,
                    proteinGrams: 40,
                    carbsGrams: 0,
                    fatGrams: 8
                )
            ),
            occurredAt: oldDate,
            calendar: harness.calendar
        )
        try harness.store.append(food, userId: nil)

        _ = try harness.store.prune(calendar: harness.calendar)

        let remaining = try harness.store.fetchOrderedHistory()
        XCTAssertEqual(remaining.count, 1)
        XCTAssertEqual(remaining.first?.type, .foodLogged)
    }
}

// MARK: - Harness

@MainActor
private final class Harness {

    let store: CoachTimelineStore
    let calendar: Calendar
    let now: Date

    init() throws {
        let container = try FormaModelContainer.makeContainer(inMemory: true)
        let swiftDataStore = SwiftDataStore(container: container)
        let dateProvider = FixedDailyLogTestDateProvider(
            now: CoachTimelinePersistenceTestFixtures.referenceNow,
            calendar: CoachTimelinePersistenceTestFixtures.calendar
        )
        store = CoachTimelineStore(store: swiftDataStore, dateProvider: dateProvider)
        calendar = dateProvider.calendar
        now = dateProvider.now
    }

    func day(offset: Int) -> Date {
        calendar.date(byAdding: .day, value: offset, to: now)!
    }
}

private enum CoachTimelinePersistenceTestFixtures {
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
}
