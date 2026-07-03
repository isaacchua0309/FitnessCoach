//
//  HealthActivityQueryServiceRepositoryRoutingTests.swift
//  Fitness CoachTests
//

import XCTest
@testable import Fitness_Coach

final class HealthActivityQueryServiceRepositoryRoutingTests: XCTestCase {

    private let calendar = Calendar(identifier: .gregorian)
    private lazy var day = calendar.date(from: DateComponents(year: 2026, month: 7, day: 3))!

    func testStepsTodayRoutesThroughRepositoryWhenEnabled() async throws {
        let repository = MockRoutingRepository(
            dailyMetrics: DailyHealthMetrics(
                date: day,
                steps: 4_321,
                activeEnergyKcal: 0,
                exerciseMinutes: 0
            )
        )
        let query = HealthActivityQueryService(
            workoutReader: FailingWorkoutReader(),
            stepReader: FailingStepReader(),
            healthDataRepository: repository,
            repositoryReadRoutingEnabled: true
        )

        let steps = try await query.stepsToday(on: day, calendar: calendar)

        XCTAssertEqual(steps, 4_321)
        XCTAssertEqual(repository.dailyMetricsCallCount, 1)
    }

    func testStepsTodayUsesLegacyReaderWhenRepositoryRoutingDisabled() async throws {
        let repository = MockRoutingRepository(
            dailyMetrics: DailyHealthMetrics(
                date: day,
                steps: 4_321,
                activeEnergyKcal: 0,
                exerciseMinutes: 0
            )
        )
        let query = HealthActivityQueryService(
            workoutReader: FailingWorkoutReader(),
            stepReader: MockHealthKitStepReader(stepCount: 9_876),
            healthDataRepository: repository,
            repositoryReadRoutingEnabled: false
        )

        let steps = try await query.stepsToday(on: day, calendar: calendar)

        XCTAssertEqual(steps, 9_876)
        XCTAssertEqual(repository.dailyMetricsCallCount, 0)
    }

    func testWorkoutsRoutesThroughRepositoryWhenEnabled() async {
        let workout = NormalizedWorkout(
            id: UUID(uuidString: "00000000-0000-0000-0000-000000000001")!,
            category: .running,
            activityLabel: "Running",
            startDate: day,
            endDate: day.addingTimeInterval(1_800),
            durationMinutes: 30,
            activeEnergyKcal: 250,
            sourceName: "Apple Watch"
        )
        let repository = MockRoutingRepository(workouts: [workout])
        let query = HealthActivityQueryService(
            workoutReader: FailingWorkoutReader(),
            stepReader: MockHealthKitStepReader(stepCount: 0),
            healthDataRepository: repository,
            repositoryReadRoutingEnabled: true
        )

        let records = await query.workouts(from: day, to: day.addingTimeInterval(86_400))

        XCTAssertEqual(records.count, 1)
        XCTAssertEqual(records[0].activityName, "Running")
        XCTAssertEqual(records[0].durationMinutes, 30)
        XCTAssertEqual(records[0].activeCalories, 250)
        XCTAssertEqual(repository.workoutsCallCount, 1)
    }

    func testWorkoutsUsesLegacyReaderWhenRepositoryRoutingDisabled() async {
        let legacyWorkout = HealthWorkoutRecord(
            id: UUID(uuidString: "00000000-0000-0000-0000-000000000002")!,
            activityName: "Cycling",
            startDate: day,
            endDate: day.addingTimeInterval(3_600),
            durationMinutes: 60,
            activeCalories: 400
        )
        let repository = MockRoutingRepository(workouts: [])
        let query = HealthActivityQueryService(
            workoutReader: MockHealthKitWorkoutReader(workouts: [legacyWorkout]),
            stepReader: MockHealthKitStepReader(stepCount: 0),
            healthDataRepository: repository,
            repositoryReadRoutingEnabled: false
        )

        let records = await query.workouts(from: day, to: day.addingTimeInterval(86_400))

        XCTAssertEqual(records, [legacyWorkout])
        XCTAssertEqual(repository.workoutsCallCount, 0)
    }
}

// MARK: - Mocks

private final class MockRoutingRepository: HealthDataRepositorying, @unchecked Sendable {
    let dailyMetrics: DailyHealthMetrics
    let workouts: [NormalizedWorkout]
    private(set) var dailyMetricsCallCount = 0
    private(set) var workoutsCallCount = 0

    init(
        dailyMetrics: DailyHealthMetrics = .zero,
        workouts: [NormalizedWorkout] = []
    ) {
        self.dailyMetrics = dailyMetrics
        self.workouts = workouts
    }

    func normalizedSamples(for date: Date, calendar: Calendar) async throws -> [HealthNormalizedSample] {
        []
    }

    func getDailyMetrics(for date: Date, calendar: Calendar) async -> DailyHealthMetrics {
        dailyMetricsCallCount += 1
        return dailyMetrics
    }

    func getDailyMetrics(
        from startDate: Date,
        to endDate: Date,
        calendar: Calendar
    ) async -> [DailyHealthMetrics] {
        [dailyMetrics]
    }

    func getRecentWorkouts(days: Int, calendar: Calendar) async -> [NormalizedWorkout] {
        workouts
    }

    func getWorkouts(from startDate: Date, to endDate: Date) async -> [NormalizedWorkout] {
        workoutsCallCount += 1
        return workouts
    }

    func getRecentSleep(days: Int, calendar: Calendar) async -> [NormalizedSleepRecord] {
        []
    }

    func getSleepRecords(from startDate: Date, to endDate: Date, calendar: Calendar) async -> [NormalizedSleepRecord] {
        []
    }

    func getRecentHeartMetrics(days: Int, calendar: Calendar) async -> [NormalizedHeartMetric] {
        []
    }

    func getHeartMetrics(from startDate: Date, to endDate: Date, calendar: Calendar) async -> [NormalizedHeartMetric] {
        []
    }

    func getBodyMassHistory(days: Int, calendar: Calendar) async -> [NormalizedBodyMass] {
        []
    }

    func getHealthDataAvailability() async -> HealthDataAvailability {
        HealthDataAvailability(
            isHealthDataAvailable: false,
            permissionStatus: .unavailable(),
            cachedDayCount: 0
        )
    }

    func refreshHealthData(
        days: Int,
        endingOn date: Date,
        calendar: Calendar
    ) async -> HealthRefreshResult {
        HealthRefreshResult(daysRefreshed: 0, refreshedAt: Date())
    }
}

private struct FailingWorkoutReader: HealthKitWorkoutReading {
    func fetchWorkouts(from startDate: Date, to endDate: Date) async throws -> [HealthWorkoutRecord] {
        XCTFail("Legacy workout reader should not be called")
        return []
    }
}

private struct FailingStepReader: HealthKitStepReading {
    func fetchStepCount(from startDate: Date, to endDate: Date) async throws -> Int {
        XCTFail("Legacy step reader should not be called")
        return 0
    }
}
