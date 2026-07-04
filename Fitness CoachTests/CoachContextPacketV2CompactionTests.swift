//
//  CoachContextPacketV2CompactionTests.swift
//  Fitness CoachTests
//
//  Deterministic compaction policy tests for CoachContextPacketV2.
//

import XCTest
@testable import Fitness_Coach

@MainActor
final class CoachContextPacketV2CompactionTests: XCTestCase {

    private let today = "2026-07-04"
    private var calendar: Calendar!
    private var baseDate: Date!

    override func setUp() {
        super.setUp()
        var cal = Calendar(identifier: .gregorian)
        cal.timeZone = TimeZone(identifier: "Asia/Singapore") ?? .current
        calendar = cal
        baseDate = cal.date(from: DateComponents(year: 2026, month: 7, day: 4, hour: 12)) ?? Date()
    }

    func testTenEventsNoCompactionNeeded() {
        let events = (0..<10).map { index in
            makeFoodLogged(name: "Meal \(index)", calories: 400 + index, offset: TimeInterval(index * 60))
        }

        let result = CoachContextPacketV2TimelineCompactionPolicy.compact(
            events: events,
            todayLocalDate: today,
            limit: 20
        )

        XCTAssertEqual(result.events.count, 10)
        XCTAssertEqual(result.metadata.originalEventCount, 10)
        XCTAssertEqual(result.metadata.exportedEventCount, 10)
        XCTAssertEqual(result.metadata.compactedEventCount, 0)
        XCTAssertNil(result.metadata.compactionReason)
        assertSorted(result.events)
    }

    func testFiftyEventBusyDayCompactsLowerPriorityEvents() {
        var events: [CoachTimelineEvent] = (0..<12).map { index in
            makeFoodLogged(name: "Food \(index)", calories: 300 + index, offset: TimeInterval(index * 30))
        }
        events.append(contentsOf: (0..<25).map { index in
            makeAssistantMessage(text: String(repeating: "Detail ", count: 20) + "\(index)", offset: TimeInterval(400 + index))
        })
        events.append(makeStepsUpdated(steps: 8_000, offset: 900))
        events.append(makeWorkoutDetected(offset: 910))
        events.append(contentsOf: (0..<12).map { index in
            makeSystemRefresh(offset: TimeInterval(1_000 + index))
        })

        let result = CoachContextPacketV2TimelineCompactionPolicy.compact(
            events: events,
            todayLocalDate: today,
            limit: 20
        )

        XCTAssertLessThanOrEqual(result.events.count, 20)
        XCTAssertEqual(result.metadata.originalEventCount, events.count)
        XCTAssertGreaterThan(result.metadata.compactedEventCount, 0)
        XCTAssertTrue(result.events.contains(where: { $0.type == CoachTimelineEventType.workoutDetected.rawValue }))
        XCTAssertTrue(result.events.contains(where: { $0.type == CoachTimelineEventType.stepsUpdated.rawValue }))
        assertSorted(result.events)
    }

    func testHundredEventExtremeDaySummarizesOlderFoodLogs() {
        var events: [CoachTimelineEvent] = (0..<20).map { index in
            makeFoodLogged(name: "Food \(index)", calories: 250 + index, offset: TimeInterval(index * 20))
        }
        events.append(contentsOf: (0..<70).map { index in
            makeAssistantMessage(text: "Assistant \(index)", offset: TimeInterval(500 + index))
        })
        events.append(makeStepsUpdated(steps: 10_000, offset: 2_000))
        events.append(contentsOf: (0..<10).map { index in
            makeSystemRefresh(offset: TimeInterval(2_100 + index))
        })

        let result = CoachContextPacketV2TimelineCompactionPolicy.compact(
            events: events,
            todayLocalDate: today,
            limit: 20
        )

        XCTAssertLessThanOrEqual(result.events.count, 20)
        XCTAssertTrue(
            result.events.contains {
                $0.type == CoachContextPacketV2TimelineCompactionPolicy.dailyFoodSummaryType
            },
            "Older food logs should collapse into a dailyFoodSummary event"
        )
        assertSorted(result.events)
    }

    func testManyAssistantMessagesCompactFirstUnderByteLimit() {
        var packet = makeBasePacket()
        packet.timeline.recentEvents = (0..<15).map { index in
            CoachTimelineContextEvent(
                id: UUID(),
                timestamp: baseDate.addingTimeInterval(TimeInterval(index)),
                type: CoachTimelineEventType.assistantMessage.rawValue,
                source: CoachTimelineEventSourceAttribution.aiBackend.rawValue,
                status: CoachTimelineEventStatus.confirmed.rawValue,
                summary: String(repeating: "Long assistant summary ", count: 30) + "\(index)",
                compactPayload: ["detail": String(repeating: "x", count: 200)],
                confidence: nil,
                linkedEntryId: nil,
                linkedMessageId: nil
            )
        }
        packet.recentChatMessages = (0..<8).map { index in
            CoachChatMessageContext(
                id: UUID(),
                role: ChatMessageRole.assistant.rawValue,
                text: String(repeating: "Assistant chat ", count: 40) + "\(index)",
                timestamp: baseDate,
                hasPhotoAttachment: false
            )
        }
        packet.timeline.recentEvents.append(
            CoachTimelineContextEvent(
                id: UUID(),
                timestamp: baseDate,
                type: CoachTimelineEventType.foodLogged.rawValue,
                source: CoachTimelineEventSourceAttribution.userConfirmation.rawValue,
                status: CoachTimelineEventStatus.confirmed.rawValue,
                summary: "Logged lunch",
                compactPayload: ["kcal": "520"],
                confidence: nil,
                linkedEntryId: UUID(),
                linkedMessageId: nil
            )
        )

        var metadata: CoachContextCompactionMetadata? = CoachContextCompactionMetadata(
            originalEventCount: packet.timeline.recentEvents.count,
            exportedEventCount: packet.timeline.recentEvents.count
        )
        let compacted = CoachContextPacketV2SizeCompactor.compact(
            packet,
            byteLimit: 4_096,
            compaction: &metadata
        )

        XCTAssertTrue(compacted.fitsWithinByteLimit(4_096))
        XCTAssertTrue(compacted.timeline.recentEvents.contains { $0.type == CoachTimelineEventType.foodLogged.rawValue })
        XCTAssertTrue(compacted.recentChatMessages.allSatisfy { $0.text.count <= 80 || $0.role != ChatMessageRole.assistant.rawValue })
        XCTAssertNotNil(metadata?.compactionReason)
    }

    func testEditDeleteEventsPreserved() {
        let food = makeFoodLogged(name: "Salad", calories: 400, offset: 0)
        let edited = CoachTimelineEvent.make(
            type: .foodEdited,
            source: .coachUI,
            sourceAttribution: .userConfirmation,
            status: .confirmed,
            payload: .foodLogged(
                FoodLoggedPayload(
                    entryId: UUID(),
                    name: "Salad edited",
                    calories: 430,
                    proteinGrams: 20,
                    carbsGrams: 30,
                    fatGrams: 12
                )
            ),
            occurredAt: baseDate.addingTimeInterval(60),
            calendar: calendar,
            link: CoachTimelineEventLink(linkedEntryId: UUID())
        )
        let deleted = CoachTimelineEvent.make(
            type: .foodDeleted,
            source: .coachUI,
            sourceAttribution: .userConfirmation,
            status: .confirmed,
            payload: .foodLogged(
                FoodLoggedPayload(
                    entryId: UUID(),
                    name: "Snack",
                    calories: 180,
                    proteinGrams: 5,
                    carbsGrams: 20,
                    fatGrams: 8
                )
            ),
            occurredAt: baseDate.addingTimeInterval(120),
            calendar: calendar,
            link: CoachTimelineEventLink(linkedEntryId: UUID())
        )

        let result = CoachContextPacketV2TimelineCompactionPolicy.compact(
            events: [food, edited, deleted] + (0..<30).map { makeAssistantMessage(text: "noise \($0)", offset: TimeInterval(200 + $0)) },
            todayLocalDate: today,
            limit: 20
        )

        XCTAssertTrue(result.events.contains { $0.type == CoachTimelineEventType.foodEdited.rawValue })
        XCTAssertTrue(result.events.contains { $0.type == CoachTimelineEventType.foodDeleted.rawValue })
        XCTAssertNotNil(result.events.first { $0.type == CoachTimelineEventType.foodEdited.rawValue }?.linkedEntryId)
    }

    func testPendingConfirmationPreservedWithManyEvents() {
        let pending = CoachTimelineEvent.make(
            type: .pendingConfirmationCreated,
            source: .coachUI,
            sourceAttribution: .estimateFood,
            status: .pending,
            payload: .confirmation(
                ConfirmationPayload(kind: "food", originalText: "Pending lunch")
            ),
            occurredAt: baseDate,
            calendar: calendar
        )
        let events = [pending] + (0..<40).map { makeAssistantMessage(text: "msg \($0)", offset: TimeInterval($0)) }

        let result = CoachContextPacketV2TimelineCompactionPolicy.compact(
            events: events,
            todayLocalDate: today,
            limit: 20
        )

        XCTAssertTrue(result.events.contains { $0.type == CoachTimelineEventType.pendingConfirmationCreated.rawValue })
    }

    func testRejectedAndPendingEstimatesExcluded() {
        let rejected = CoachTimelineEvent.make(
            type: .foodRejected,
            source: .aiBackend,
            sourceAttribution: .estimateFood,
            status: .rejected,
            payload: .foodEstimate(
                FoodEstimatePayload(mealName: "Chicken", calories: 500, requiresConfirmation: true)
            ),
            occurredAt: baseDate,
            calendar: calendar
        )
        let estimate = CoachTimelineEvent.make(
            type: .foodEstimateCreated,
            source: .aiBackend,
            sourceAttribution: .estimateFood,
            status: .pending,
            payload: .foodEstimate(
                FoodEstimatePayload(mealName: "Rice", calories: 300, requiresConfirmation: true)
            ),
            occurredAt: baseDate.addingTimeInterval(10),
            calendar: calendar
        )
        let confirmed = makeFoodLogged(name: "Eggs", calories: 140, offset: 20)

        let result = CoachContextPacketV2TimelineCompactionPolicy.compact(
            events: [rejected, estimate, confirmed],
            todayLocalDate: today,
            limit: 20
        )

        XCTAssertEqual(result.events.count, 1)
        XCTAssertEqual(result.events.first?.type, CoachTimelineEventType.foodLogged.rawValue)
    }

    func testSameInputProducesSameOutput() {
        let events = (0..<35).map { index in
            makeFoodLogged(name: "Meal \(index)", calories: 300 + index, offset: TimeInterval(index * 15))
        } + (0..<20).map { index in
            makeAssistantMessage(text: "Assistant \(index)", offset: TimeInterval(600 + index))
        }

        let first = CoachContextPacketV2TimelineCompactionPolicy.compact(
            events: events,
            todayLocalDate: today,
            limit: 20
        )
        let second = CoachContextPacketV2TimelineCompactionPolicy.compact(
            events: events.shuffled().sorted(by: {
                if $0.utcTimestamp != $1.utcTimestamp { return $0.utcTimestamp < $1.utcTimestamp }
                return $0.id.uuidString < $1.id.uuidString
            }),
            todayLocalDate: today,
            limit: 20
        )

        XCTAssertEqual(first.events.map(\.id), second.events.map(\.id))
        XCTAssertEqual(first.events.map(\.type), second.events.map(\.type))
        XCTAssertEqual(first.metadata, second.metadata)
    }

    func testOutputBelowSizeLimitAfterCompaction() {
        var packet = makeBasePacket()
        packet.today = CoachContextTodayPacket(
            nutrition: CoachTodayNutritionContext(
                caloriesConsumed: 3_500,
                proteinConsumed: 180,
                carbsConsumed: 320,
                fatConsumed: 90,
                caloriesRemaining: 0,
                proteinRemaining: 0
            ),
            targets: CoachTodayTargetsContext(calorieTarget: 2_200, proteinTarget: 160)
        )
        packet.recentMealsStructured = (0..<10).map { index in
            CoachRecentMealContext(
                name: "Meal \(index)",
                calories: 350 + index,
                proteinGrams: 25,
                localDate: today
            )
        }
        packet.timeline.recentEvents = (0..<20).map { index in
            CoachTimelineContextEvent(
                id: UUID(),
                timestamp: baseDate.addingTimeInterval(TimeInterval(index)),
                type: CoachTimelineEventType.foodLogged.rawValue,
                source: CoachTimelineEventSourceAttribution.userConfirmation.rawValue,
                status: CoachTimelineEventStatus.confirmed.rawValue,
                summary: "Logged meal \(index) with extra detail",
                compactPayload: ["kcal": String(350 + index), "name": "Meal \(index)"],
                confidence: nil,
                linkedEntryId: UUID(),
                linkedMessageId: nil
            )
        }
        packet.recentChatMessages = (0..<12).map { index in
            CoachChatMessageContext(
                id: UUID(),
                role: ChatMessageRole.assistant.rawValue,
                text: String(repeating: "Chat ", count: 50) + "\(index)",
                timestamp: baseDate,
                hasPhotoAttachment: false
            )
        }

        var metadata: CoachContextCompactionMetadata?
        let compacted = CoachContextPacketV2SizeCompactor.compact(packet, compaction: &metadata)
        XCTAssertTrue(compacted.fitsWithinByteLimit())
    }

    func testTotalsStillMatchConfirmedFoodAfterCompaction() {
        let meals = (0..<6).map { index in
            CoachRecentMealContext(
                name: "Meal \(index)",
                calories: 400 + index,
                proteinGrams: 30,
                localDate: today,
                linkedEntryId: UUID()
            )
        }
        var packet = makeBasePacket()
        packet.recentMealsStructured = meals
        packet.today = CoachContextTodayPacket(
            nutrition: CoachTodayNutritionContext(
                caloriesConsumed: meals.compactMap(\.calories).reduce(0, +),
                proteinConsumed: meals.compactMap(\.proteinGrams).reduce(0, +),
                caloriesRemaining: 0,
                proteinRemaining: 0
            ),
            targets: CoachTodayTargetsContext(calorieTarget: 2_500, proteinTarget: 160)
        )

        let validated = CoachContextCorrectnessValidator.validateAndCorrect(packet, calendar: calendar)
        XCTAssertTrue(validated.isValid)
        XCTAssertEqual(validated.correctedPacket.today?.nutrition?.caloriesConsumed, 2_415)
    }

    func testPhotoSessionEventsRetained() {
        let sessionID = UUID()
        let photo = CoachTimelineEvent.make(
            type: .photoAttached,
            source: .coachUI,
            sourceAttribution: .localParser,
            status: .confirmed,
            payload: .photo(PhotoPayload(sessionId: sessionID, mimeType: "image/jpeg", hasCaption: false)),
            occurredAt: baseDate,
            calendar: calendar,
            link: CoachTimelineEventLink(linkedPhotoSessionId: sessionID)
        )
        let clarification = CoachTimelineEvent.make(
            type: .clarificationAsked,
            source: .aiBackend,
            sourceAttribution: .analyzeMealImage,
            status: .confirmed,
            payload: .message(MessagePayload(textPreview: "What portion?", role: "assistant")),
            occurredAt: baseDate.addingTimeInterval(30),
            calendar: calendar,
            link: CoachTimelineEventLink(linkedPhotoSessionId: sessionID)
        )

        let result = CoachContextPacketV2TimelineCompactionPolicy.compact(
            events: [photo, clarification] + (0..<30).map { makeAssistantMessage(text: "noise", offset: TimeInterval(100 + $0)) },
            todayLocalDate: today,
            limit: 20
        )

        XCTAssertTrue(result.events.contains { $0.type == CoachTimelineEventType.photoAttached.rawValue })
        XCTAssertTrue(result.events.contains { $0.type == CoachTimelineEventType.clarificationAsked.rawValue })
    }

    // MARK: - Helpers

    private func makeBasePacket() -> CoachContextPacketV2 {
        CoachContextPacketV2(
            meta: CoachContextMeta(
                generatedAt: baseDate,
                timezoneIdentifier: calendar.timeZone.identifier,
                localDate: today,
                localTime: "12:00",
                schemaVersion: CoachContextPacketV2.schemaVersion
            ),
            missingData: CoachMissingDataContext()
        )
    }

    private func makeFoodLogged(name: String, calories: Int, offset: TimeInterval) -> CoachTimelineEvent {
        CoachTimelineEvent.make(
            type: .foodLogged,
            source: .coachUI,
            sourceAttribution: .userConfirmation,
            status: .confirmed,
            payload: .foodLogged(
                FoodLoggedPayload(
                    entryId: UUID(),
                    name: name,
                    calories: calories,
                    proteinGrams: 20,
                    carbsGrams: 30,
                    fatGrams: 10
                )
            ),
            occurredAt: baseDate.addingTimeInterval(offset),
            calendar: calendar,
            link: CoachTimelineEventLink(linkedEntryId: UUID())
        )
    }

    private func makeAssistantMessage(text: String, offset: TimeInterval) -> CoachTimelineEvent {
        CoachTimelineEvent.make(
            type: .assistantMessage,
            source: .aiBackend,
            sourceAttribution: .aiBackend,
            status: .confirmed,
            payload: .message(MessagePayload(textPreview: text, role: "assistant")),
            occurredAt: baseDate.addingTimeInterval(offset),
            calendar: calendar
        )
    }

    private func makeSystemRefresh(offset: TimeInterval) -> CoachTimelineEvent {
        CoachTimelineEvent.make(
            type: .systemRefresh,
            source: .system,
            sourceAttribution: .system,
            status: .confirmed,
            payload: .systemRefresh(SystemRefreshPayload(reason: "refresh")),
            occurredAt: baseDate.addingTimeInterval(offset),
            calendar: calendar
        )
    }

    private func makeStepsUpdated(steps: Int, offset: TimeInterval) -> CoachTimelineEvent {
        CoachTimelineEvent.make(
            type: .stepsUpdated,
            source: .system,
            sourceAttribution: .healthKit,
            status: .confirmed,
            payload: .steps(StepsUpdatedPayload(steps: steps)),
            occurredAt: baseDate.addingTimeInterval(offset),
            calendar: calendar
        )
    }

    private func makeWorkoutDetected(offset: TimeInterval) -> CoachTimelineEvent {
        CoachTimelineEvent.make(
            type: .workoutDetected,
            source: .system,
            sourceAttribution: .healthKit,
            status: .confirmed,
            payload: .workoutDetected(
                WorkoutDetectedPayload(
                    workoutCount: 1,
                    totalDurationMinutes: 30,
                    totalActiveCalories: 200,
                    primaryWorkoutTitle: "Run"
                )
            ),
            occurredAt: baseDate.addingTimeInterval(offset),
            calendar: calendar
        )
    }

    private func assertSorted(_ events: [CoachTimelineContextEvent], file: StaticString = #filePath, line: UInt = #line) {
        let timestamps = events.map(\.timestamp)
        XCTAssertEqual(timestamps, timestamps.sorted(), file: file, line: line)
    }
}
