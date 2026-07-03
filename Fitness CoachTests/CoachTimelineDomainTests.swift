//
//  CoachTimelineDomainTests.swift
//  Fitness CoachTests
//
//  Forma — Coach timeline domain model tests.
//

import XCTest
@testable import Fitness_Coach

final class CoachTimelineDomainTests: XCTestCase {

    func testEventFactoryProducesLocalDateAndTimestamps() {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "America/Los_Angeles")!
        let instant = Date(timeIntervalSince1970: 1_720_000_000)

        let event = CoachTimelineEvent.make(
            type: .userMessage,
            source: .coachUI,
            sourceAttribution: .userConfirmation,
            status: .confirmed,
            payload: .message(MessagePayload(textPreview: "Hello", role: "user")),
            occurredAt: instant,
            calendar: calendar,
            link: CoachTimelineEventLink(linkedMessageId: UUID())
        )

        XCTAssertEqual(event.timezoneIdentifier, "America/Los_Angeles")
        XCTAssertFalse(event.localDate.isEmpty)
        XCTAssertFalse(event.localTimestamp.isEmpty)
        XCTAssertEqual(event.type.expectedPayloadKind, .message)
    }

    func testPayloadCodableRoundTrip() throws {
        let payloads: [CoachTimelineEventPayload] = [
            .message(MessagePayload(textPreview: "Hi", role: "assistant")),
            .foodEstimate(FoodEstimatePayload(mealName: "Oatmeal", calories: 300, requiresConfirmation: true)),
            .foodLogged(FoodLoggedPayload(
                entryId: UUID(),
                name: "Chicken",
                calories: 250,
                proteinGrams: 40,
                carbsGrams: 0,
                fatGrams: 8
            )),
            .waterLogged(WaterLoggedPayload(entryId: UUID(), amountMl: 500)),
            .weightLogged(WeightLoggedPayload(entryId: UUID(), weightKg: 72.5)),
            .workoutDetected(WorkoutDetectedPayload(workoutCount: 1, totalDurationMinutes: 45)),
            .steps(StepsPayload(steps: 8_500, previousSteps: 8_200)),
            .photo(PhotoPayload(sessionId: UUID(), mimeType: "image/jpeg", compressedByteSize: 120_000, hasCaption: true)),
            .confirmation(ConfirmationPayload(kind: "food", originalText: "Log chicken")),
            .error(ErrorPayload(category: "authentication", isRetryable: true, httpStatus: 401)),
            .healthAvailability(HealthAvailabilityPayload(isAvailable: false, missingSignals: ["sleep"])),
            .contextGeneration(ContextGenerationPayload(lookbackDays: 7, hasTodaySummary: true)),
            .undo(UndoPerformedPayload(entryType: "food", summary: "Undid chicken")),
            .systemRefresh(SystemRefreshPayload(reason: "dataChanged")),
            .empty
        ]

        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601

        for payload in payloads {
            let data = try encoder.encode(payload)
            let decoded = try decoder.decode(CoachTimelineEventPayload.self, from: data)
            XCTAssertEqual(decoded, payload)
        }
    }

    func testEventCodableRoundTrip() throws {
        let event = CoachTimelineEvent.make(
            type: .foodLogged,
            source: .localPipeline,
            sourceAttribution: .userConfirmation,
            confidence: .high,
            status: .confirmed,
            payload: .foodLogged(FoodLoggedPayload(
                entryId: UUID(),
                dailyLogId: UUID(),
                name: "Eggs",
                calories: 140,
                proteinGrams: 12,
                carbsGrams: 1,
                fatGrams: 10
            )),
            link: CoachTimelineEventLink(linkedEntryId: UUID(), linkedMessageId: UUID())
        )

        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601

        let data = try encoder.encode(event)
        let decoded = try decoder.decode(CoachTimelineEvent.self, from: data)

        XCTAssertEqual(decoded, event)
    }

    func testQueryFiltersSupersededAndLimits() {
        let older = CoachTimelineEvent.make(
            type: .systemRefresh,
            source: .system,
            sourceAttribution: .system,
            status: .superseded,
            payload: .systemRefresh(SystemRefreshPayload()),
            occurredAt: Date(timeIntervalSince1970: 1_000)
        )
        let newer = CoachTimelineEvent.make(
            type: .userMessage,
            source: .coachUI,
            sourceAttribution: .localParser,
            status: .confirmed,
            payload: .message(MessagePayload(textPreview: "New")),
            occurredAt: Date(timeIntervalSince1970: 2_000)
        )

        let query = CoachTimelineQuery(limit: 1, includeSuperseded: false)
        let results = query.apply(to: [older, newer])

        XCTAssertEqual(results.count, 1)
        XCTAssertEqual(results.first?.type, .userMessage)
    }

    func testDayGroupingSortsAscending() {
        let first = CoachTimelineEvent.make(
            type: .waterLogged,
            source: .coachUI,
            sourceAttribution: .userConfirmation,
            status: .confirmed,
            payload: .waterLogged(WaterLoggedPayload(entryId: UUID(), amountMl: 250)),
            occurredAt: Date(timeIntervalSince1970: 1_000)
        )
        let second = CoachTimelineEvent.make(
            type: .foodLogged,
            source: .coachUI,
            sourceAttribution: .userConfirmation,
            status: .confirmed,
            payload: .foodLogged(FoodLoggedPayload(
                entryId: UUID(),
                name: "Salad",
                calories: 400,
                proteinGrams: 20,
                carbsGrams: 30,
                fatGrams: 15
            )),
            occurredAt: Date(timeIntervalSince1970: 2_000)
        )

        let days = CoachTimelineDay.group([second, first])
        XCTAssertEqual(days.count, 1)
        XCTAssertEqual(days[0].events.map(\.type), [.waterLogged, .foodLogged])
    }

    func testCompactionPolicyPreservesConfirmedMutations() {
        let policy = CoachTimelineCompactionPolicy.default
        let foodLogged = CoachTimelineEvent.make(
            type: .foodLogged,
            source: .coachUI,
            sourceAttribution: .userConfirmation,
            status: .confirmed,
            payload: .foodLogged(FoodLoggedPayload(
                entryId: UUID(),
                name: "Banana",
                calories: 105,
                proteinGrams: 1,
                carbsGrams: 27,
                fatGrams: 0
            ))
        )

        XCTAssertTrue(policy.shouldPreserve(foodLogged))
        XCTAssertTrue(policy.isCollapsible(.stepsUpdated))
        XCTAssertFalse(policy.isCollapsible(.foodLogged))
    }
}
