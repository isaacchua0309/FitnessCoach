//
//  CoachTimelineContextV2ComprehensiveTests.swift
//  Fitness CoachTests
//
//  Targeted coverage gaps for Coach Timeline Context v2 domain and store behavior.
//

import XCTest
@testable import Fitness_Coach

// MARK: - Domain

final class CoachTimelineContextV2DomainTests: XCTestCase {

    private var calendar: Calendar!

    override func setUp() {
        super.setUp()
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "America/Los_Angeles")!
        self.calendar = calendar
    }

    func testUnknownPayloadJSONFallsBackWithoutCrashing() {
        let result = CoachTimelineEventPayloadCodec.decode("{\"futureKind\":\"mystery\",\"value\":42}")

        switch result {
        case .unknownPayload(let rawJSON):
            XCTAssertTrue(rawJSON.contains("futureKind"))
        default:
            XCTFail("Expected unknownPayload fallback")
        }

        XCTAssertEqual(CoachTimelineEventPayloadCodec.decodePayloadOnly("not-json"), .empty)
    }

    func testEventCodableRoundTripPreservesUnknownTypeAsEmptyPayload() throws {
        let event = CoachTimelineEvent.make(
            type: .unknown,
            source: .system,
            sourceAttribution: .system,
            status: .confirmed,
            payload: .empty,
            occurredAt: Date(timeIntervalSince1970: 1_720_000_000),
            calendar: calendar
        )

        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601

        let data = try encoder.encode(event)
        let decoded = try decoder.decode(CoachTimelineEvent.self, from: data)

        XCTAssertEqual(decoded.type, .unknown)
        XCTAssertEqual(decoded.payload, .empty)
    }

    func testStatusQueryFiltersPendingRejectedAndFailed() {
        let confirmed = makeEvent(type: .foodLogged, status: .confirmed, offset: 3)
        let pending = makeEvent(type: .foodEstimateCreated, status: .pending, offset: 2)
        let rejected = makeEvent(type: .foodRejected, status: .rejected, offset: 1)
        let failed = makeEvent(type: .backendError, status: .failed, offset: 0)

        let confirmedOnly = CoachTimelineQuery(
            statuses: [.confirmed],
            includeSuperseded: false
        ).apply(to: [failed, rejected, pending, confirmed])

        XCTAssertEqual(confirmedOnly.map(\.status), [.confirmed])
        XCTAssertEqual(confirmedOnly.map(\.type), [.foodLogged])
    }

    func testSupersededCorrectionChainPreservesReplacementLink() async throws {
        let store = FakeCoachTimelineStore()
        let entryId = UUID()
        let original = CoachTimelineEvent.make(
            type: .foodLogged,
            source: .coachUI,
            sourceAttribution: .userConfirmation,
            status: .confirmed,
            payload: .foodLogged(
                FoodLoggedPayload(
                    entryId: entryId,
                    name: "Chicken",
                    calories: 250,
                    proteinGrams: 40,
                    carbsGrams: 0,
                    fatGrams: 8
                )
            ),
            occurredAt: Date(timeIntervalSince1970: 1_000),
            calendar: calendar,
            link: CoachTimelineEventLink(linkedEntryId: entryId)
        )
        try await store.append(original)

        let correction = CoachTimelineEvent.make(
            type: .foodEdited,
            source: .coachUI,
            sourceAttribution: .userConfirmation,
            status: .confirmed,
            payload: .foodLogged(
                FoodLoggedPayload(
                    entryId: entryId,
                    name: "Chicken (edited)",
                    calories: 280,
                    proteinGrams: 42,
                    carbsGrams: 0,
                    fatGrams: 9
                )
            ),
            occurredAt: Date(timeIntervalSince1970: 2_000),
            calendar: calendar,
            link: CoachTimelineEventLink(linkedEntryId: entryId)
        )
        try await store.supersedeEvent(id: original.id, by: correction)

        let superseded = try await store.event(id: original.id)
        let replacement = try await store.event(id: correction.id)

        XCTAssertEqual(superseded?.status, .superseded)
        XCTAssertEqual(replacement?.supersedesEventId, original.id)
        XCTAssertEqual(replacement?.type, .foodEdited)

        let visible = CoachTimelineQuery(includeSuperseded: false)
            .apply(to: store.events)
        XCTAssertEqual(visible.map(\.id), [correction.id])
    }

    func testPendingFoodEstimateExcludedFromConfirmedTimelineQuery() {
        let pendingEstimate = makeEvent(type: .foodEstimateCreated, status: .pending, offset: 1)
        let confirmedFood = makeEvent(type: .foodLogged, status: .confirmed, offset: 2)

        let query = CoachTimelineQuery(
            statuses: [.confirmed],
            includeSuperseded: false
        )
        let results = query.apply(to: [pendingEstimate, confirmedFood])

        XCTAssertEqual(results.count, 1)
        XCTAssertEqual(results.first?.type, .foodLogged)
    }

    // MARK: Helpers

    private func makeEvent(
        type: CoachTimelineEventType,
        status: CoachTimelineEventStatus,
        offset: TimeInterval
    ) -> CoachTimelineEvent {
        CoachTimelineEvent.make(
            type: type,
            source: .coachUI,
            sourceAttribution: .userConfirmation,
            status: status,
            payload: .empty,
            occurredAt: Date(timeIntervalSince1970: offset),
            calendar: calendar
        )
    }
}

// MARK: - Store

@MainActor
final class CoachTimelineContextV2StoreTests: XCTestCase {

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

    func testMarkEventStatusThrowsWhenEventMissing() async {
        let missingId = UUID()

        do {
            try await store.markEventStatus(id: missingId, status: .confirmed)
            XCTFail("Expected eventNotFound error")
        } catch let error as CoachTimelineStoreError {
            if case .eventNotFound(let id) = error {
                XCTAssertEqual(id, missingId)
            } else {
                XCTFail("Expected eventNotFound, got \(error)")
            }
        } catch {
            XCTFail("Unexpected error: \(error)")
        }
    }
}

// MARK: - Context packet pending/rejected totals

@MainActor
final class CoachTimelineContextV2PacketTests: XCTestCase {

    private var harness: DailyLogServiceTestSupport.Harness!
    private var timelineStore: FakeCoachTimelineStore!

    override func setUp() async throws {
        harness = try DailyLogServiceTestSupport.makeHarness()
        try harness.seedProfile()
        timelineStore = FakeCoachTimelineStore()
    }

    override func tearDown() {
        timelineStore = nil
        harness = nil
        super.tearDown()
    }

    func testPendingEstimateExcludedFromNutritionTotals() async {
        let pending = CoachTimelineEvent.make(
            type: .pendingConfirmationCreated,
            source: .aiBackend,
            sourceAttribution: .estimateFood,
            status: .pending,
            payload: .confirmation(
                ConfirmationPayload(
                    kind: "food",
                    originalText: "log chicken",
                    assistantMessagePreview: "Confirm chicken bowl?"
                )
            ),
            occurredAt: harness.today,
            calendar: harness.dateProvider.calendar
        )
        try? await timelineStore.append(pending)

        let packet = await makeBuilder(includeBackfill: false).makeContext(
            recentMessages: [
                ChatMessage(role: .assistant, text: "Logging 620 kcal chicken bowl.", createdAt: harness.today)
            ],
            mode: .live
        )

        XCTAssertEqual(packet.today?.nutrition?.caloriesConsumed ?? 0, 0)
        XCTAssertTrue(packet.recentMealsStructured.isEmpty)
        XCTAssertTrue(
            packet.timeline.recentEvents.contains {
                $0.type == CoachTimelineEventType.pendingConfirmationCreated.rawValue
                    && $0.status == CoachTimelineEventStatus.pending.rawValue
            }
        )
    }

    private func makeBuilder(includeBackfill: Bool) -> CoachContextPacketV2Builder {
        CoachContextPacketV2Builder(
            dailyLogService: harness.dailyLogService,
            foodLogService: harness.foodLogService,
            waterLogService: harness.waterLogService,
            weightLogService: WeightLogService(
                store: harness.store,
                dailyLogService: harness.dailyLogService,
                dateProvider: harness.dateProvider
            ),
            userProfileService: harness.profileService,
            healthActivityQuery: HealthActivityQueryService(
                workoutReader: StubHealthKitWorkoutReader(workouts: []),
                stepReader: StubHealthKitStepReader(stepsByDay: [:]),
                repositoryReadRoutingEnabled: false
            ),
            timelineStore: timelineStore,
            dateProvider: harness.dateProvider,
            calendar: harness.dateProvider.calendar
        )
    }
}

// MARK: - Shared harness (store tests)

@MainActor
private enum CoachTimelineStoreTestHarness {

    static func make(userId: String? = nil) throws -> (store: SwiftDataCoachTimelineStore, calendar: Calendar, now: Date) {
        let calendar = CoachTimelineContextV2StoreFixtures.calendar
        let now = CoachTimelineContextV2StoreFixtures.referenceNow
        let dateProvider = FixedDailyLogTestDateProvider(now: now, calendar: calendar)
        let container = try FormaModelContainer.makeContainer(inMemory: true)
        let store = SwiftDataCoachTimelineStore(
            store: SwiftDataStore(container: container),
            dateProvider: dateProvider,
            userIdProvider: { userId },
            calendar: calendar
        )
        return (store, calendar, now)
    }
}

private enum CoachTimelineContextV2StoreFixtures {
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

private struct StubHealthKitWorkoutReader: HealthKitWorkoutReading {
    let workouts: [HealthWorkoutRecord]
    let error: Error?

    init(workouts: [HealthWorkoutRecord], error: Error? = nil) {
        self.workouts = workouts
        self.error = error
    }

    func fetchWorkouts(from startDate: Date, to endDate: Date) async throws -> [HealthWorkoutRecord] {
        if let error { throw error }
        return workouts
    }
}

private struct StubHealthKitStepReader: HealthKitStepReading {
    let stepsByDay: [Date: Int]
    let error: Error?

    func fetchStepCount(from startDate: Date, to endDate: Date) async throws -> Int {
        if let error { throw error }
        guard let steps = stepsByDay[startDate] else {
            throw HealthKitManagerError.authorizationDenied
        }
        return steps
    }
}
