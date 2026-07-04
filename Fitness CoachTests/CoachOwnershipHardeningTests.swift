//
//  CoachOwnershipHardeningTests.swift
//  Fitness CoachTests
//
//  Forma — Phase 1 coach transcript and timeline UID ownership hardening.
//

import XCTest
import SwiftData
@testable import Fitness_Coach

@MainActor
final class CoachOwnershipHardeningTests: XCTestCase {

    func testNilUserIdCoachRowsAreNotVisibleToAnySession() throws {
        let harness = try makeHarness()
        try seedLegacyTranscriptMessage(in: harness.store, text: "Legacy coach reply")

        XCTAssertTrue(try harness.repository.fetchAllSorted(userId: "signed-in-user").isEmpty)
        XCTAssertTrue(try harness.repository.fetchAllSorted(userId: "other-user").isEmpty)
        XCTAssertTrue(try harness.repository.fetchAllSorted(userId: nil).isEmpty)
    }

    func testNilUserIdTimelineRowsAreNotVisibleToAnySession() throws {
        let harness = try makeHarness()
        try seedLegacyTimelineEvent(in: harness.store)

        XCTAssertTrue(try harness.timelineRepository.fetch(userId: "signed-in-user").isEmpty)
        XCTAssertTrue(try harness.timelineRepository.fetch(userId: "other-user").isEmpty)
        XCTAssertTrue(try harness.timelineRepository.fetch(userId: nil).isEmpty)
    }

    func testUserBCannotSeeUserATranscriptMessages() throws {
        let harness = try makeHarness()
        let userAMessage = ChatMessage(
            id: UUID(),
            role: .user,
            text: "User A message",
            createdAt: ProfileTestFixtures.referenceDate
        )
        try harness.repository.replaceAll([userAMessage], userId: "user-a")

        let messagesForB = try harness.repository.fetchAllSorted(userId: "user-b")
        XCTAssertTrue(messagesForB.isEmpty)
    }

    func testUserBCannotSeeUserATimelineEvents() throws {
        let harness = try makeHarness()
        let event = CoachTimelineEvent.make(
            type: .userMessage,
            source: .coachUI,
            sourceAttribution: .userConfirmation,
            status: .confirmed,
            payload: .message(MessagePayload(textPreview: "User A event")),
            occurredAt: harness.now
        )
        try harness.timelineRepository.appendIdempotent(event, userId: "user-a")

        let eventsForB = try harness.timelineRepository.fetch(userId: "user-b")
        XCTAssertTrue(eventsForB.isEmpty)
    }

    func testRetentionPruningDoesNotDeleteAnotherUsersTranscript() throws {
        let harness = try makeHarness()
        var userAMessages: [ChatMessage] = []
        for index in 0..<305 {
            userAMessages.append(
                ChatMessage(
                    role: index.isMultiple(of: 2) ? .user : .assistant,
                    text: "user-a \(index)",
                    createdAt: harness.now.addingTimeInterval(TimeInterval(index))
                )
            )
        }
        try harness.repository.replaceAll(userAMessages, userId: "user-a")

        let userBMessage = ChatMessage(
            role: .user,
            text: "user-b only",
            createdAt: harness.now.addingTimeInterval(10_000)
        )
        try harness.repository.replaceAll([userBMessage], userId: "user-b")

        try harness.repository.pruneRetainedOnly(userId: "user-a")

        XCTAssertEqual(try harness.repository.fetchAllSorted(userId: "user-a").count, 300)
        XCTAssertEqual(try harness.repository.fetchAllSorted(userId: "user-b").count, 1)
        XCTAssertEqual(try harness.repository.fetchAllSorted(userId: "user-b").first?.text, "user-b only")
    }

    func testTimelineCompactionDoesNotDeleteAnotherUsersEvents() throws {
        let harness = try makeHarness()
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
            try harness.timelineRepository.appendIdempotent(event, userId: "user-a")
        }

        let userBEvent = CoachTimelineEvent.make(
            type: .userMessage,
            source: .coachUI,
            sourceAttribution: .userConfirmation,
            status: .confirmed,
            payload: .message(MessagePayload(textPreview: "User B keeps this")),
            occurredAt: oldDate,
            calendar: harness.calendar
        )
        try harness.timelineRepository.appendIdempotent(userBEvent, userId: "user-b")

        let deletedForA = try harness.timelineRepository.deleteEventsOlderThan(
            policy: CoachTimelineCompactionPolicy(retainDays: 30),
            userId: "user-a",
            calendar: harness.calendar
        )
        XCTAssertEqual(deletedForA, 3)
        XCTAssertTrue(try harness.timelineRepository.fetch(userId: "user-a").isEmpty)
        XCTAssertEqual(try harness.timelineRepository.fetch(userId: "user-b").count, 1)
    }

    func testSignedOutTranscriptStoreReturnsEmptyWithoutLeakingLegacyRows() throws {
        let harness = try makeHarness()
        try seedLegacyTranscriptMessage(in: harness.store, text: "Legacy coach reply")

        let signedOutStore = SwiftDataCoachChatTranscriptStore(
            repository: harness.repository,
            userIdProvider: { nil }
        )
        XCTAssertTrue(signedOutStore.loadMessages().isEmpty)
    }

    func testSignedOutTimelineStoreReturnsEmptyWithoutLeakingLegacyRows() async throws {
        let harness = try makeHarness()
        try seedLegacyTimelineEvent(in: harness.store)

        let signedOutStore = SwiftDataCoachTimelineStore(
            repository: harness.timelineRepository,
            userIdProvider: { nil }
        )
        let events = try await signedOutStore.events(forLocalDate: "2026-07-03")
        XCTAssertTrue(events.isEmpty)
    }

    func testSaveRequiresUserIdAndStampsOwnership() throws {
        let harness = try makeHarness()
        let store = SwiftDataCoachChatTranscriptStore(
            repository: harness.repository,
            userIdProvider: { "signed-in-user" }
        )

        let message = ChatMessage(
            role: .user,
            text: "Stamped message",
            createdAt: harness.now
        )
        store.saveMessages([message])

        let entity = try XCTUnwrap(try harness.repository.persistedEntities(userId: "signed-in-user").first)
        XCTAssertEqual(entity.userId, "signed-in-user")
        XCTAssertEqual(entity.entitySchemaVersion, UserDataEntitySchema.currentEntitySchemaVersion)
        XCTAssertNotNil(entity.localUpdatedAt)
    }

    // MARK: - Harness

    private struct Harness {
        let store: SwiftDataStore
        let repository: CoachChatTranscriptPersistenceRepository
        let timelineRepository: CoachTimelinePersistenceRepository
        let calendar: Calendar
        let now: Date

        func day(offset: Int) -> Date {
            calendar.date(byAdding: .day, value: offset, to: now)!
        }
    }

    private func makeHarness() throws -> Harness {
        let container = try FormaModelContainer.makeContainer(inMemory: true)
        let store = SwiftDataStore(container: container)
        let dateProvider = FixedDailyLogTestDateProvider(now: ProfileTestFixtures.referenceDate)
        return Harness(
            store: store,
            repository: CoachChatTranscriptPersistenceRepository(
                store: store,
                dateProvider: dateProvider,
                calendar: dateProvider.calendar
            ),
            timelineRepository: CoachTimelinePersistenceRepository(
                store: store,
                dateProvider: dateProvider
            ),
            calendar: dateProvider.calendar,
            now: dateProvider.now
        )
    }

    private func seedLegacyTranscriptMessage(in store: SwiftDataStore, text: String) throws {
        let message = ChatMessage(
            id: UUID(),
            role: .assistant,
            text: text,
            createdAt: ProfileTestFixtures.referenceDate
        )
        store.modelContext.insert(
            CoachChatTranscriptMessageEntity(
                model: message,
                userId: nil,
                updatedAt: ProfileTestFixtures.referenceDate
            )
        )
        try store.save()
    }

    private func seedLegacyTimelineEvent(in store: SwiftDataStore) throws {
        let entity = CoachTimelineEventEntity(
            id: UUID(),
            userId: nil,
            eventTypeRaw: CoachTimelineEventType.userMessage.rawValue,
            sourceRaw: CoachTimelineEventSource.coachUI.rawValue,
            statusRaw: CoachTimelineEventStatus.confirmed.rawValue,
            confidenceRaw: nil,
            sourceAttributionRaw: CoachTimelineEventSourceAttribution.userConfirmation.rawValue,
            utcCreatedAt: ProfileTestFixtures.referenceDate,
            localCreatedAt: "2026-07-03T12:00:00+00:00",
            localDate: "2026-07-03",
            timezoneIdentifier: "UTC",
            summary: "Legacy timeline row",
            payloadJSON: "{\"schemaVersion\":1,\"payload\":{\"kind\":\"empty\"},\"relatedEventIds\":[]}",
            linkedEntryId: nil,
            linkedMessageId: nil,
            supersedesEventId: nil,
            schemaVersion: 1,
            createdAt: ProfileTestFixtures.referenceDate,
            updatedAt: ProfileTestFixtures.referenceDate
        )
        store.modelContext.insert(entity)
        try store.save()
    }
}
