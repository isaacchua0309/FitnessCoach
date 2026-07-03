//
//  CoachTimelineBackfillServiceTests.swift
//  Fitness CoachTests
//
//  Forma — CoachTimelineBackfillService idempotent hydration tests.
//

import XCTest
@testable import Fitness_Coach

@MainActor
final class CoachTimelineBackfillServiceTests: XCTestCase {

    private var harness: DailyLogServiceTestSupport.Harness!
    private var weightLogService: WeightLogService!
    private var timelineStore: FakeCoachTimelineStore!
    private var healthQuery: FakeCoachTimelineHealthActivityQuery!
    private var service: CoachTimelineBackfillService!

    override func setUp() async throws {
        harness = try DailyLogServiceTestSupport.makeHarness()
        try harness.seedProfile()
        weightLogService = WeightLogService(
            store: harness.store,
            dailyLogService: harness.dailyLogService,
            dateProvider: harness.dateProvider
        )
        timelineStore = FakeCoachTimelineStore()
        healthQuery = FakeCoachTimelineHealthActivityQuery()
        service = makeService()
    }

    override func tearDown() {
        service = nil
        healthQuery = nil
        timelineStore = nil
        weightLogService = nil
        harness = nil
        super.tearDown()
    }

    // MARK: Food

    func testFoodBackfillCreatesFoodLoggedEvents() async throws {
        _ = try harness.foodLogService.addFoodEntry(
            DailyLogServiceTestSupport.foodDraft(name: "Salad", calories: 420, protein: 25),
            date: harness.today
        )

        await service.runBackfill()

        let events = timelineStore.events
        XCTAssertEqual(events.count, 1)
        XCTAssertEqual(events[0].type, .foodLogged)
        XCTAssertEqual(events[0].sourceAttribution, .systemBackfill)
        XCTAssertEqual(events[0].linkedEntryId, events[0].link.linkedEntryId)
        guard case .foodLogged(let payload) = events[0].payload else {
            return XCTFail("Expected foodLogged payload")
        }
        XCTAssertEqual(payload.name, "Salad")
    }

    // MARK: Water

    func testWaterBackfillCreatesWaterLoggedEvents() async throws {
        _ = try harness.waterLogService.addWater(amountMl: 500, date: harness.today)

        await service.runBackfill()

        let events = timelineStore.events
        XCTAssertEqual(events.count, 1)
        XCTAssertEqual(events[0].type, .waterLogged)
        XCTAssertEqual(events[0].sourceAttribution, .systemBackfill)
        guard case .waterLogged(let payload) = events[0].payload else {
            return XCTFail("Expected waterLogged payload")
        }
        XCTAssertEqual(payload.amountMl, 500)
    }

    // MARK: Weight

    func testWeightBackfillCreatesWeightLoggedEvents() async throws {
        _ = try weightLogService.logWeight(72.5, date: harness.today)

        await service.runBackfill()

        let events = timelineStore.events
        XCTAssertEqual(events.count, 1)
        XCTAssertEqual(events[0].type, .weightLogged)
        XCTAssertEqual(events[0].sourceAttribution, .systemBackfill)
        guard case .weightLogged(let payload) = events[0].payload else {
            return XCTFail("Expected weightLogged payload")
        }
        XCTAssertEqual(payload.weightKg, 72.5)
    }

    // MARK: Workouts

    func testWorkoutBackfillUsesHealthWorkoutsOnly() async throws {
        try harness.seedWorkoutCaloriesBurned(calories: 400)

        let workout = HealthWorkoutRecord(
            id: UUID(),
            activityName: "Run",
            startDate: harness.today,
            endDate: harness.today.addingTimeInterval(1_800),
            durationMinutes: 30,
            activeCalories: 280
        )
        healthQuery.workouts = [workout]
        healthQuery.stepsByDay[harness.dateProvider.startOfDay(for: harness.today)] = 6_000

        await service.runBackfill()

        let workoutEvents = timelineStore.events.filter { $0.type == .workoutDetected }
        XCTAssertEqual(workoutEvents.count, 1)
        guard case .workoutDetected(let payload) = workoutEvents[0].payload else {
            return XCTFail("Expected workoutDetected payload")
        }
        XCTAssertEqual(payload.workoutCount, 1)
        XCTAssertEqual(payload.totalActiveCalories, 280)
        XCTAssertNotEqual(payload.totalActiveCalories, 400)
    }

    func testLegacyWorkoutCaloriesDoNotCreateWorkoutEvents() async throws {
        try harness.seedWorkoutCaloriesBurned(calories: 400)
        healthQuery.workouts = []

        await service.runBackfill()

        XCTAssertTrue(timelineStore.events.filter { $0.type == .workoutDetected }.isEmpty)
    }

    // MARK: Steps

    func testStepsMissingWhenHealthUnavailable() async throws {
        healthQuery.stepsError = HealthKitManagerError.authorizationDenied

        await service.runBackfill()

        XCTAssertTrue(timelineStore.events.filter { $0.type == .stepsUpdated }.isEmpty)
    }

    func testStepsBackfillCreatesStepsUpdatedEvent() async throws {
        healthQuery.stepsByDay[harness.dateProvider.startOfDay(for: harness.today)] = 4_500

        await service.runBackfill()

        let stepsEvents = timelineStore.events.filter { $0.type == .stepsUpdated }
        XCTAssertEqual(stepsEvents.count, 1)
        XCTAssertEqual(stepsEvents[0].sourceAttribution, .systemBackfill)
        guard case .steps(let payload) = stepsEvents[0].payload else {
            return XCTFail("Expected steps payload")
        }
        XCTAssertEqual(payload.steps, 4_500)
    }

    // MARK: HealthKit denied

    func testHealthKitDeniedDoesNotCrashAndSkipsHealthEvents() async throws {
        healthQuery.workouts = []
        healthQuery.stepsError = HealthKitManagerError.authorizationDenied

        await service.runBackfill()

        XCTAssertTrue(timelineStore.events.isEmpty)
    }

    // MARK: Duplicate prevention

    func testDuplicatePreventionSkipsExistingEntryLinkedEvents() async throws {
        let entry = try harness.foodLogService.addFoodEntry(
            DailyLogServiceTestSupport.foodDraft(name: "Eggs", calories: 140, protein: 12),
            date: harness.today
        )

        let existing = CoachTimelineEvent.make(
            type: .foodLogged,
            source: .coachUI,
            sourceAttribution: .userConfirmation,
            status: .confirmed,
            payload: .foodLogged(
                FoodLoggedPayload(
                    entryId: entry.id,
                    dailyLogId: entry.dailyLogId,
                    name: entry.name,
                    calories: entry.calories,
                    proteinGrams: entry.protein,
                    carbsGrams: entry.carbs,
                    fatGrams: entry.fat
                )
            ),
            occurredAt: entry.createdAt,
            calendar: harness.dateProvider.calendar,
            link: CoachTimelineEventLink(
                linkedEntryId: entry.id,
                linkedDailyLogId: entry.dailyLogId
            )
        )
        try await timelineStore.append(existing)

        await service.runBackfill()

        XCTAssertEqual(timelineStore.events.count, 1)
        XCTAssertEqual(timelineStore.events[0].sourceAttribution, .userConfirmation)
    }

    // MARK: Idempotency

    func testRepeatedRunIsIdempotent() async throws {
        _ = try harness.foodLogService.addFoodEntry(
            DailyLogServiceTestSupport.foodDraft(name: "Toast", calories: 180),
            date: harness.today
        )
        _ = try harness.waterLogService.addWater(amountMl: 250, date: harness.today)
        healthQuery.stepsByDay[harness.dateProvider.startOfDay(for: harness.today)] = 4_500

        await service.runBackfill()
        let firstCount = timelineStore.events.count
        XCTAssertGreaterThan(firstCount, 0)

        await service.runBackfill()
        XCTAssertEqual(timelineStore.events.count, firstCount)
    }

    func testNilTimelineStoreIsSafeNoOp() async {
        let nilStoreService = CoachTimelineBackfillService(
            timelineStore: nil,
            foodLogService: harness.foodLogService,
            waterLogService: harness.waterLogService,
            weightLogService: weightLogService,
            healthActivityQuery: healthQuery,
            dateProvider: harness.dateProvider,
            calendar: harness.dateProvider.calendar
        )

        await nilStoreService.runBackfill()
        XCTAssertTrue(timelineStore.events.isEmpty)
    }

    func testDeduplicatorTreatsSameDayWorkoutAsDuplicate() {
        let calendar = harness.dateProvider.calendar
        let day = harness.today
        let first = CoachTimelineEvent.make(
            type: .workoutDetected,
            source: .system,
            sourceAttribution: .systemBackfill,
            status: .confirmed,
            payload: .workoutDetected(WorkoutDetectedPayload(workoutCount: 1)),
            occurredAt: day,
            calendar: calendar
        )
        let second = CoachTimelineEvent.make(
            type: .workoutDetected,
            source: .system,
            sourceAttribution: .systemBackfill,
            status: .confirmed,
            payload: .workoutDetected(WorkoutDetectedPayload(workoutCount: 2)),
            occurredAt: day.addingTimeInterval(30),
            calendar: calendar
        )

        XCTAssertTrue(
            CoachTimelineBackfillDeduplicator.isDuplicate(
                existing: first,
                candidate: second,
                tolerance: CoachTimelineBackfillService.timestampTolerance
            )
        )
    }

    // MARK: Helpers

    private func makeService() -> CoachTimelineBackfillService {
        CoachTimelineBackfillService(
            timelineStore: timelineStore,
            foodLogService: harness.foodLogService,
            waterLogService: harness.waterLogService,
            weightLogService: weightLogService,
            healthActivityQuery: healthQuery,
            dateProvider: harness.dateProvider,
            calendar: harness.dateProvider.calendar
        )
    }
}

// MARK: - Fake health query

struct FakeCoachTimelineHealthActivityQuery: CoachTimelineHealthActivityQuerying {

    var workouts: [HealthWorkoutRecord] = []
    var workoutsError: Error?
    var stepsByDay: [Date: Int] = [:]
    var stepsError: Error?

    func workouts(from startDate: Date, to endDate: Date) async -> [HealthWorkoutRecord] {
        workouts.filter { workout in
            workout.startDate >= startDate && workout.startDate < endDate
        }
    }

    func stepsToday(on date: Date, calendar: Calendar) async throws -> Int {
        if let stepsError {
            throw stepsError
        }
        let dayStart = calendar.startOfDay(for: date)
        guard let steps = stepsByDay[dayStart] else {
            throw HealthKitManagerError.authorizationDenied
        }
        return steps
    }
}
