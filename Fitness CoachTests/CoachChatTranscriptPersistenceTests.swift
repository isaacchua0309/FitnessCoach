//
//  CoachChatTranscriptPersistenceTests.swift
//  Fitness CoachTests
//
//  Forma — SwiftData Coach chat transcript persistence tests.
//

import XCTest
import SwiftData
@testable import Fitness_Coach

@MainActor
final class CoachChatTranscriptPersistenceTests: XCTestCase {

    private var harness: Harness!

    override func setUp() async throws {
        harness = try Harness()
    }

    override func tearDown() {
        harness = nil
        super.tearDown()
    }

    func testPersistsMessages() throws {
        let messages = [
            ChatMessage(role: .user, text: "log 200g chicken", createdAt: harness.now),
            ChatMessage(role: .assistant, text: "I can help with that.", createdAt: harness.now.addingTimeInterval(1))
        ]

        harness.transcriptStore.saveMessages(messages)

        let entities = try harness.repository.persistedEntities(userId: nil)
        XCTAssertEqual(entities.count, 2)
        XCTAssertEqual(Set(entities.map(\.id)), Set(messages.map(\.id)))
    }

    func testReloadsMessagesAfterNewStoreInstance() throws {
        let message = ChatMessage(
            id: UUID(),
            role: .user,
            text: "status",
            createdAt: harness.now
        )
        harness.transcriptStore.saveMessages([message])

        let reloadedStore = SwiftDataCoachChatTranscriptStore(store: harness.swiftDataStore)
        let loaded = reloadedStore.loadMessages()

        XCTAssertEqual(loaded.count, 1)
        XCTAssertEqual(loaded.first?.id, message.id)
        XCTAssertEqual(loaded.first?.text, "status")
    }

    func testPreservesChronologicalOrder() throws {
        let first = ChatMessage(role: .user, text: "first", createdAt: harness.now.addingTimeInterval(-20))
        let second = ChatMessage(role: .assistant, text: "second", createdAt: harness.now.addingTimeInterval(-10))
        let third = ChatMessage(role: .user, text: "third", createdAt: harness.now)

        harness.transcriptStore.saveMessages([third, first, second])

        let loaded = harness.transcriptStore.loadMessages()
        XCTAssertEqual(loaded.map(\.text), ["first", "second", "third"])
    }

    func testRetentionPruningKeepsNewestThreeHundredWithinThirtyDays() throws {
        var messages: [ChatMessage] = []
        for index in 0..<305 {
            messages.append(
                ChatMessage(
                    role: index.isMultiple(of: 2) ? .user : .assistant,
                    text: "message \(index)",
                    createdAt: harness.now.addingTimeInterval(TimeInterval(index))
                )
            )
        }

        harness.transcriptStore.saveMessages(messages)

        let loaded = harness.transcriptStore.loadMessages()
        XCTAssertEqual(loaded.count, 300)
        XCTAssertEqual(loaded.first?.text, "message 5")
        XCTAssertEqual(loaded.last?.text, "message 304")
    }

    func testRetentionPruningDropsMessagesOlderThanThirtyDays() throws {
        let old = ChatMessage(
            role: .user,
            text: "old",
            createdAt: harness.day(offset: -31)
        )
        let recent = ChatMessage(
            role: .assistant,
            text: "recent",
            createdAt: harness.now
        )

        harness.transcriptStore.saveMessages([old, recent])

        let loaded = harness.transcriptStore.loadMessages()
        XCTAssertEqual(loaded.map(\.text), ["recent"])
    }

    func testLargeImageMetadataPersistsThumbnailOnly() throws {
        let largeJPEG = Data(repeating: 0xFF, count: CoachChatTranscriptRetentionPolicy.maxPersistedFullImageBytes + 1)
        let thumbnail = Data([0x01, 0x02, 0x03])
        let attachment = ChatMessageImageAttachment(
            imageJPEG: largeJPEG,
            thumbnailJPEG: thumbnail,
            source: .library
        )
        let message = ChatMessage.userMealPhoto(caption: "Lunch", attachment: attachment, createdAt: harness.now)

        harness.transcriptStore.saveMessages([message])

        let entity = try XCTUnwrap(try harness.repository.persistedEntities(userId: nil).first)
        XCTAssertTrue(entity.hasImageAttachment)
        XCTAssertEqual(entity.originalImageByteSize, largeJPEG.count)
        XCTAssertEqual(entity.thumbnailJPEG, thumbnail)
        XCTAssertNil(entity.fullImageJPEG)

        let reloaded = try XCTUnwrap(harness.transcriptStore.loadMessages().first)
        XCTAssertEqual(reloaded.imageAttachment?.thumbnailJPEG, thumbnail)
        XCTAssertEqual(reloaded.imageAttachment?.imageJPEG, thumbnail)
    }

    func testPhotoAnalysisLinkRoundTrip() throws {
        let userMessageID = UUID()
        let sessionID = UUID()
        let message = ChatMessage.assistantPhotoAnalysisResult(
            text: "Estimated 420 kcal.",
            sessionID: sessionID,
            relatedUserMessageID: userMessageID,
            createdAt: harness.now
        )

        harness.transcriptStore.saveMessages([message])

        let loaded = try XCTUnwrap(harness.transcriptStore.loadMessages().first)
        XCTAssertEqual(loaded.photoAnalysisLink?.sessionID, sessionID)
        XCTAssertEqual(loaded.photoAnalysisLink?.relatedUserMessageID, userMessageID)
        XCTAssertEqual(loaded.photoAnalysisLink?.kind, .result)
    }

    func testTimelineLinkedMessageIdMatchesPersistedChatMessage() async throws {
        let messageID = UUID()
        let message = ChatMessage(
            id: messageID,
            role: .user,
            text: "delete lunch",
            createdAt: harness.now
        )
        harness.transcriptStore.saveMessages([message])

        let recorder = DefaultCoachTimelineRecorder(store: harness.timelineStore)
        recorder.recordUserMessage(
            text: message.text,
            messageId: messageID,
            hasPhotoAttachment: false,
            occurredAt: message.createdAt
        )

        let events = try await harness.timelineStore.recentEvents(limit: 10, before: nil)
        let userEvent = try XCTUnwrap(events.first { $0.type == .userMessage })
        XCTAssertEqual(userEvent.linkedMessageId, messageID)
    }

    func testCoachModelLoadsPersistedTranscriptOnInit() throws {
        let message = ChatMessage(role: .user, text: "hello again", createdAt: harness.now)
        harness.transcriptStore.saveMessages([message])

        let model = try harness.makeCoachModel(transcriptStore: harness.transcriptStore)

        XCTAssertEqual(model.messageCount, 1)
        XCTAssertEqual(model.messages.first?.text, "hello again")
        XCTAssertEqual(model.messages.first?.createdAt, message.createdAt)
    }

    func testSchemaV6ContainerInitializesWithTranscriptEntity() throws {
        let container = try FormaModelContainer.makeContainer(inMemory: true)
        let context = ModelContext(container)
        let entity = CoachChatTranscriptMessageEntity(
            model: ChatMessage(role: .user, text: "migration check"),
            userId: nil
        )
        context.insert(entity)
        try context.save()

        let fetched = try context.fetch(FetchDescriptor<CoachChatTranscriptMessageEntity>())
        XCTAssertEqual(fetched.count, 1)
        XCTAssertEqual(fetched.first?.text, "migration check")
    }
}

// MARK: - Retention policy unit tests

final class CoachChatTranscriptRetentionPolicyTests: XCTestCase {

    func testRetainedMessagesAppliesCountCap() {
        let now = Date()
        let messages = (0..<305).map { index in
            ChatMessage(
                role: .user,
                text: "\(index)",
                createdAt: now.addingTimeInterval(TimeInterval(index))
            )
        }

        let retained = CoachChatTranscriptRetentionPolicy.retainedMessages(from: messages, now: now)
        XCTAssertEqual(retained.count, 300)
        XCTAssertEqual(retained.first?.text, "5")
        XCTAssertEqual(retained.last?.text, "304")
    }

    func testRetainedMessagesAppliesAgeCap() {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(secondsFromGMT: 0)!
        let now = calendar.date(from: DateComponents(year: 2026, month: 7, day: 3))!

        let old = ChatMessage(
            role: .user,
            text: "old",
            createdAt: calendar.date(byAdding: .day, value: -31, to: now)!
        )
        let recent = ChatMessage(
            role: .assistant,
            text: "recent",
            createdAt: now
        )

        let retained = CoachChatTranscriptRetentionPolicy.retainedMessages(
            from: [old, recent],
            now: now,
            calendar: calendar
        )

        XCTAssertEqual(retained.map(\.text), ["recent"])
    }
}

// MARK: - Harness

@MainActor
private final class Harness {

    let swiftDataStore: SwiftDataStore
    let repository: CoachChatTranscriptPersistenceRepository
    let timelineStore: SwiftDataCoachTimelineStore
    let transcriptStore: SwiftDataCoachChatTranscriptStore
    let calendar: Calendar
    let now: Date

    init() throws {
        let container = try FormaModelContainer.makeContainer(inMemory: true)
        swiftDataStore = SwiftDataStore(container: container)
        let dateProvider = FixedDailyLogTestDateProvider(
            now: CoachChatTranscriptPersistenceTestFixtures.referenceNow,
            calendar: CoachChatTranscriptPersistenceTestFixtures.calendar
        )
        repository = CoachChatTranscriptPersistenceRepository(
            store: swiftDataStore,
            dateProvider: dateProvider,
            calendar: dateProvider.calendar
        )
        transcriptStore = SwiftDataCoachChatTranscriptStore(
            store: swiftDataStore,
            dateProvider: dateProvider,
            calendar: dateProvider.calendar
        )
        timelineStore = SwiftDataCoachTimelineStore(store: swiftDataStore)
        calendar = dateProvider.calendar
        now = dateProvider.now
    }

    func day(offset: Int) -> Date {
        calendar.date(byAdding: .day, value: offset, to: now)!
    }

    func makeCoachModel(transcriptStore: CoachChatTranscriptStore) throws -> CoachModel {
        let actionHarness = try FitnessActionCenterTestSupport.makeHarness(referenceNow: now)
        return CoachModel(
            actionCenter: actionHarness.actionCenter,
            dailyLogReader: actionHarness.dailyLogService,
            healthActivityQuery: actionHarness.healthActivityQuery,
            transcriptStore: transcriptStore
        )
    }
}

private enum CoachChatTranscriptPersistenceTestFixtures {
    static let calendar: Calendar = {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(secondsFromGMT: 0)!
        return calendar
    }()

    static let referenceNow = calendar.date(from: DateComponents(year: 2026, month: 7, day: 3, hour: 12))!
}
