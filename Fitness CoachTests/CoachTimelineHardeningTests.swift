//
//  CoachTimelineHardeningTests.swift
//  Fitness CoachTests
//
//  Production hardening checks for Coach Timeline Context v2.
//

import XCTest
@testable import Fitness_Coach

// MARK: - Timeline context eligibility

final class CoachTimelineContextEligibilityTests: XCTestCase {

    private var calendar: Calendar!

    override func setUp() {
        super.setUp()
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "America/Los_Angeles")!
        self.calendar = calendar
    }

    func testRejectedAndFailedEventsExcludedFromContext() {
        let rejected = makeEvent(type: .foodRejected, status: .rejected)
        let failed = makeEvent(type: .backendError, status: .failed)
        let confirmed = makeEvent(type: .foodLogged, status: .confirmed)

        XCTAssertFalse(CoachContextPacketV2TimelineSelector.isContextEligible(rejected))
        XCTAssertFalse(CoachContextPacketV2TimelineSelector.isContextEligible(failed))
        XCTAssertTrue(CoachContextPacketV2TimelineSelector.isContextEligible(confirmed))
    }

    func testPendingEstimateExcludedUnlessPendingConfirmationCreated() {
        let estimate = makeEvent(type: .foodEstimateCreated, status: .pending)
        let pendingBar = makeEvent(type: .pendingConfirmationCreated, status: .pending)

        XCTAssertFalse(CoachContextPacketV2TimelineSelector.isContextEligible(estimate))
        XCTAssertTrue(CoachContextPacketV2TimelineSelector.isContextEligible(pendingBar))
    }

    func testSelectorOmitsRejectedEventsFromContextPacket() {
        let today = "2026-07-03"
        let events = [
            makeEvent(type: .foodRejected, status: .rejected, offset: 1),
            makeEvent(type: .foodLogged, status: .confirmed, offset: 2)
        ]

        let selected = CoachContextPacketV2TimelineSelector.selectEvents(
            from: events,
            todayLocalDate: today,
            limit: 10
        )

        XCTAssertEqual(selected.map(\.type), [.foodLogged])
    }

    func testMidnightBoundaryUsesLocalDateNotUTC() {
        var components = DateComponents()
        components.calendar = calendar
        components.timeZone = calendar.timeZone
        components.year = 2026
        components.month = 7
        components.day = 3
        components.hour = 23
        components.minute = 30
        let lateNight = calendar.date(from: components)!

        let event = CoachTimelineEvent.make(
            type: .foodLogged,
            source: .coachUI,
            sourceAttribution: .userConfirmation,
            status: .confirmed,
            payload: .empty,
            occurredAt: lateNight,
            calendar: calendar
        )

        XCTAssertEqual(event.localDate, "2026-07-03")
        XCTAssertTrue(event.timezoneIdentifier.contains("Los_Angeles") || event.timezoneIdentifier.contains("America"))
    }

    private func makeEvent(
        type: CoachTimelineEventType,
        status: CoachTimelineEventStatus,
        offset: TimeInterval = 0
    ) -> CoachTimelineEvent {
        CoachTimelineEvent.make(
            type: type,
            source: .coachUI,
            sourceAttribution: .userConfirmation,
            status: status,
            payload: .empty,
            occurredAt: Date(timeIntervalSince1970: 1_720_000_000 + offset),
            calendar: calendar
        )
    }
}

// MARK: - Recorder supersede

@MainActor
final class CoachTimelineRecorderSupersedeTests: XCTestCase {

    func testFoodEditSupersedesPriorEventInStore() async throws {
        let store = FakeCoachTimelineStore()
        let recorder = DefaultCoachTimelineRecorder(store: store)
        let calendar = CoachTimelineStoreTestFixtures.calendar
        let now = CoachTimelineStoreTestFixtures.referenceNow
        let entryId = UUID()

        let original = CoachTimelineEvent.make(
            type: .foodLogged,
            source: .coachUI,
            sourceAttribution: .userConfirmation,
            status: .confirmed,
            payload: .foodLogged(
                FoodLoggedPayload(
                    entryId: entryId,
                    name: "Salad",
                    calories: 400,
                    proteinGrams: 25,
                    carbsGrams: 30,
                    fatGrams: 12
                )
            ),
            occurredAt: now,
            calendar: calendar,
            link: CoachTimelineEventLink(linkedEntryId: entryId)
        )
        try await store.append(original)

        let entry = CoachTimelineRecorderTestFixtures.foodEntry(occurredAt: now)
        recorder.recordFoodEdited(
            entry: entry,
            supersedesEventId: original.id,
            occurredAt: now
        )

        try await waitForStoreCount(store, atLeast: 2)

        let superseded = try await store.event(id: original.id)
        XCTAssertEqual(superseded?.status, .superseded)

        let replacement = store.events.first { $0.type == .foodEdited }
        XCTAssertEqual(replacement?.supersedesEventId, original.id)
    }

    private func waitForStoreCount(
        _ store: FakeCoachTimelineStore,
        atLeast count: Int,
        timeout: TimeInterval = 1.0
    ) async throws {
        let satisfied = await AsyncTestSupport.waitUntil(maxYields: Int(timeout * 100)) {
            store.events.count >= count
        }
        XCTAssertTrue(satisfied)
    }
}

// MARK: - Backfill throttle

@MainActor
final class CoachTimelineBackfillThrottleTests: XCTestCase {

    func testRepeatedBackfillWithinIntervalIsNoOp() async throws {
        let harness = try DailyLogServiceTestSupport.makeHarness()
        try harness.seedProfile()
        _ = try harness.foodLogService.addFoodEntry(
            DailyLogServiceTestSupport.foodDraft(name: "Toast", calories: 180),
            date: harness.today
        )

        let timelineStore = FakeCoachTimelineStore()
        let service = CoachTimelineBackfillService(
            timelineStore: timelineStore,
            foodLogService: harness.foodLogService,
            waterLogService: harness.waterLogService,
            weightLogService: WeightLogService(
                store: harness.store,
                dailyLogService: harness.dailyLogService,
                dateProvider: harness.dateProvider
            ),
            healthActivityQuery: FakeCoachTimelineHealthActivityQuery(),
            dateProvider: harness.dateProvider,
            calendar: harness.dateProvider.calendar
        )

        await service.runBackfill()
        let firstCount = timelineStore.events.count
        XCTAssertGreaterThan(firstCount, 0)

        await service.runBackfill()
        XCTAssertEqual(timelineStore.events.count, firstCount)
    }
}

// MARK: - Degraded mode

@MainActor
final class CoachContextDegradedModeTests: XCTestCase {

    func testHealthKitDeniedSetsDegradedGenerationMode() async {
        let harness = try? DailyLogServiceTestSupport.makeHarness()
        guard let harness else { return XCTFail("Harness failed") }
        try? harness.seedProfile()

        let healthQuery = FakeCoachTimelineHealthActivityQuery()
        healthQuery.stepsError = HealthKitManagerError.authorizationDenied
        healthQuery.workoutsError = HealthKitManagerError.authorizationDenied

        let builder = CoachContextPacketV2Builder(
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
                workoutReader: StubHealthKitWorkoutReader(workouts: [], error: healthQuery.workoutsError),
                stepReader: StubHealthKitStepReader(stepsByDay: [:], error: healthQuery.stepsError),
                repositoryReadRoutingEnabled: false
            ),
            dateProvider: harness.dateProvider,
            calendar: harness.dateProvider.calendar
        )

        let packet = await builder.makeContext(recentMessages: [], mode: .live)

        XCTAssertEqual(packet.generationMode, .degraded)
        XCTAssertTrue(packet.missingData.healthKitDenied)
    }
}

// MARK: - Fixtures

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
}

private enum CoachTimelineRecorderTestFixtures {
    static func foodEntry(occurredAt: Date) -> FoodEntry {
        FoodEntry(
            id: UUID(),
            dailyLogId: UUID(),
            mealType: .lunch,
            name: "Salad",
            quantity: 1,
            unit: "bowl",
            calories: 420,
            protein: 25,
            carbs: 30,
            fat: 12,
            source: .aiTextEstimate,
            confidence: .medium,
            createdAt: occurredAt,
            updatedAt: occurredAt
        )
    }
}

private struct StubHealthKitWorkoutReader: HealthKitWorkoutReading {
    let workouts: [HealthWorkoutRecord]
    let error: Error?

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
