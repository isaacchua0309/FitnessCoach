//
//  HealthIntelligenceEngineTests.swift
//  Fitness CoachTests
//

import XCTest
@testable import Fitness_Coach

final class HealthIntelligenceEngineTests: XCTestCase {

    private var calendar: Calendar!
    private var repository: MockIntelligenceRepository!
    private var engine: HealthIntelligenceEngine!

    override func setUp() {
        super.setUp()
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(secondsFromGMT: 0) ?? .gmt
        self.calendar = calendar
        self.repository = MockIntelligenceRepository(calendar: calendar)
        self.engine = HealthIntelligenceEngine(repository: repository)
    }

    func testComposeSnapshotStepsOnlyWhenOtherSignalsDenied() async {
        let day = makeDate(2026, 7, 3)
        repository.availability = HealthDataAvailability(
            isHealthDataAvailable: true,
            permissionStatus: HealthPermissionStatus(
                isHealthDataAvailable: true,
                signalAccess: [
                    .stepCount: .available,
                    .activeEnergyBurned: .denied,
                    .appleExerciseTime: .denied,
                    .workout: .denied,
                    .restingHeartRate: .denied,
                    .heartRateVariabilitySDNN: .denied,
                    .sleepAnalysis: .denied,
                    .bodyMass: .denied
                ],
                resolvedAt: Date()
            ),
            cachedDayCount: 1
        )
        repository.dailyMetricsByDay[day] = DailyHealthMetrics(
            date: day,
            steps: 12_345,
            activeEnergyKcal: 500,
            exerciseMinutes: 40
        )

        let snapshot = await engine.composeSnapshot(for: day, calendar: calendar)

        XCTAssertEqual(snapshot.activity.steps, 12_345)
        XCTAssertNil(snapshot.activity.activeEnergyKcal)
        XCTAssertNil(snapshot.activity.exerciseMinutes)
        XCTAssertNil(snapshot.workout)
    }

    func testComposeSnapshotMissingSleepHRVFallsBackToUnknownRecovery() async {
        let day = makeDate(2026, 7, 3)
        repository.availability = HealthDataAvailability(
            isHealthDataAvailable: true,
            permissionStatus: HealthPermissionStatus(
                isHealthDataAvailable: true,
                signalAccess: [
                    .stepCount: .available,
                    .activeEnergyBurned: .available,
                    .appleExerciseTime: .available,
                    .workout: .available,
                    .restingHeartRate: .denied,
                    .heartRateVariabilitySDNN: .denied,
                    .sleepAnalysis: .denied,
                    .bodyMass: .available
                ],
                resolvedAt: Date()
            ),
            cachedDayCount: 1
        )
        repository.dailyMetricsByDay[day] = DailyHealthMetrics(
            date: day,
            steps: 8_000,
            activeEnergyKcal: 400,
            exerciseMinutes: 35
        )

        let snapshot = await engine.composeSnapshot(for: day, calendar: calendar)

        XCTAssertEqual(snapshot.recovery.status, .unknown)
        XCTAssertNil(snapshot.recovery.score)
    }

    func testComposeSnapshotWithReadableSleepSignalsUsesInsufficientDataRecovery() async {
        let day = makeDate(2026, 7, 3)
        repository.availability = .connectedSnapshot
        repository.dailyMetricsByDay[day] = DailyHealthMetrics(
            date: day,
            steps: 8_000,
            activeEnergyKcal: 400,
            exerciseMinutes: 35
        )

        let snapshot = await engine.composeSnapshot(for: day, calendar: calendar)

        XCTAssertEqual(snapshot.recovery.status, .unknown)
        XCTAssertNil(snapshot.recovery.score)
    }

    func testComposeSnapshotWhenHealthUnavailableReturnsUnknownRecovery() async {
        repository.availability = .unavailableSnapshot

        let day = makeDate(2026, 7, 3)
        let snapshot = await engine.composeSnapshot(for: day, calendar: calendar)

        XCTAssertEqual(snapshot.date, day)
        XCTAssertEqual(snapshot.recovery.status, .unknown)
        XCTAssertNil(snapshot.recovery.score)
        XCTAssertNil(snapshot.workout)
        XCTAssertEqual(snapshot.activity, .empty)
        XCTAssertNil(snapshot.weeklyReview)
        XCTAssertEqual(snapshot.planConfidence.label, "Unknown")
        XCTAssertEqual(snapshot.planConfidence.score, 0)
        XCTAssertEqual(snapshot.nutritionAdjustment, .none)
    }

    func testComposeSnapshotIncludesAccurateActivityWhenStepsAvailable() async {
        let day = makeDate(2026, 7, 3)
        repository.availability = .connectedSnapshot
        repository.dailyMetricsByDay[day] = DailyHealthMetrics(
            date: day,
            steps: 9_500,
            activeEnergyKcal: 520,
            exerciseMinutes: 44
        )

        let snapshot = await engine.composeSnapshot(for: day, calendar: calendar)

        XCTAssertEqual(snapshot.activity.steps, 9_500)
        XCTAssertEqual(snapshot.activity.activeEnergyKcal, 520)
        XCTAssertEqual(snapshot.activity.exerciseMinutes, 44)
    }

    func testComposeSnapshotIncludesWorkoutSummaryForToday() async {
        let day = makeDate(2026, 7, 3)
        repository.availability = .connectedSnapshot
        repository.workouts = [
            NormalizedWorkout(
                id: UUID(uuidString: "00000000-0000-0000-0000-000000000001")!,
                category: .running,
                activityLabel: "Running",
                startDate: makeDate(2026, 7, 3, hour: 7),
                endDate: makeDate(2026, 7, 3, hour: 8),
                durationMinutes: 55,
                activeEnergyKcal: 410,
                sourceName: "Apple Watch"
            ),
            NormalizedWorkout(
                id: UUID(uuidString: "00000000-0000-0000-0000-000000000002")!,
                category: .walking,
                activityLabel: "Walking",
                startDate: makeDate(2026, 7, 3, hour: 18),
                endDate: makeDate(2026, 7, 3, hour: 18, minute: 30),
                durationMinutes: 30,
                activeEnergyKcal: 120,
                sourceName: "Apple Watch"
            )
        ]

        let snapshot = await engine.composeSnapshot(for: day, calendar: calendar)

        XCTAssertEqual(snapshot.workout?.workoutCount, 2)
        XCTAssertEqual(snapshot.workout?.title, "Running + 1 more")
        XCTAssertEqual(snapshot.workout?.totalDurationMinutes, 85)
        XCTAssertEqual(snapshot.workout?.totalActiveCalories, 530)
        XCTAssertEqual(snapshot.workout?.primaryWorkoutType, .running)
        XCTAssertTrue(snapshot.workout?.hasWorkout == true)
    }

    func testComposeSnapshotOmitsWorkoutWhenNoneToday() async {
        let day = makeDate(2026, 7, 3)
        repository.availability = .connectedSnapshot
        repository.workouts = [
            NormalizedWorkout(
                id: UUID(),
                category: .cycling,
                activityLabel: "Cycling",
                startDate: makeDate(2026, 7, 1, hour: 9),
                endDate: makeDate(2026, 7, 1, hour: 10),
                durationMinutes: 60,
                activeEnergyKcal: 300,
                sourceName: nil
            )
        ]

        let snapshot = await engine.composeSnapshot(for: day, calendar: calendar)

        XCTAssertNil(snapshot.workout)
    }

    func testComposeSnapshotWeeklyReviewNilWhenLessThanSevenDaysOfData() async {
        let day = makeDate(2026, 7, 7)
        repository.availability = .connectedSnapshot
        repository.weekMetrics = (0..<5).map { offset in
            let date = calendar.date(byAdding: .day, value: -offset, to: day)!
            return DailyHealthMetrics(date: date, steps: 5_000, activeEnergyKcal: 300, exerciseMinutes: 30)
        }

        let snapshot = await engine.composeSnapshot(for: day, calendar: calendar)

        XCTAssertNil(snapshot.weeklyReview)
        XCTAssertEqual(snapshot.planConfidence.label, "Limited")
    }

    func testComposeSnapshotImprovesPlanConfidenceWithSevenDaysOfData() async {
        let day = makeDate(2026, 7, 7)
        repository.availability = .connectedSnapshot
        repository.weekMetrics = (0..<7).map { offset in
            let date = calendar.date(byAdding: .day, value: -offset, to: day)!
            return DailyHealthMetrics(date: date, steps: 6_000, activeEnergyKcal: 350, exerciseMinutes: 35)
        }

        let snapshot = await engine.composeSnapshot(for: day, calendar: calendar)

        XCTAssertNotNil(snapshot.weeklyReview)
        XCTAssertEqual(snapshot.planConfidence.label, "Moderate")
        XCTAssertEqual(snapshot.planConfidence.score, 0.75)
    }

    func testComposeSnapshotIsDeterministicForSameInputs() async {
        let day = makeDate(2026, 7, 3)
        repository.availability = .connectedSnapshot
        repository.dailyMetricsByDay[day] = DailyHealthMetrics(
            date: day,
            steps: 7_000,
            activeEnergyKcal: 400,
            exerciseMinutes: 40
        )
        repository.workouts = [
            NormalizedWorkout(
                id: UUID(uuidString: "00000000-0000-0000-0000-0000000000AA")!,
                category: .strength,
                activityLabel: "Strength training",
                startDate: makeDate(2026, 7, 3, hour: 12),
                endDate: makeDate(2026, 7, 3, hour: 13),
                durationMinutes: 45,
                activeEnergyKcal: 250,
                sourceName: nil
            )
        ]

        let first = await engine.composeSnapshot(for: day, calendar: calendar)
        let second = await engine.composeSnapshot(for: day, calendar: calendar)

        XCTAssertEqual(first, second)
    }

    // MARK: - Helpers

    private func makeDate(
        _ year: Int,
        _ month: Int,
        _ day: Int,
        hour: Int = 0,
        minute: Int = 0
    ) -> Date {
        calendar.date(
            from: DateComponents(year: year, month: month, day: day, hour: hour, minute: minute)
        )!
    }
}

// MARK: - Mock

private final class MockIntelligenceRepository: HealthDataRepositorying, @unchecked Sendable {

    let calendar: Calendar
    var availability: HealthDataAvailability = .connectedSnapshot
    var dailyMetricsByDay: [Date: DailyHealthMetrics] = [:]
    var workouts: [NormalizedWorkout] = []
    var weekMetrics: [DailyHealthMetrics] = []

    init(calendar: Calendar) {
        self.calendar = calendar
    }

    func normalizedSamples(for date: Date, calendar: Calendar) async throws -> [HealthNormalizedSample] {
        []
    }

    func getDailyMetrics(for date: Date, calendar: Calendar) async -> DailyHealthMetrics {
        let day = calendar.startOfDay(for: date)
        return dailyMetricsByDay[day] ?? .empty(for: day)
    }

    func getDailyMetrics(
        from startDate: Date,
        to endDate: Date,
        calendar: Calendar
    ) async -> [DailyHealthMetrics] {
        if !weekMetrics.isEmpty {
            return weekMetrics.sorted { $0.date < $1.date }
        }

        let rangeStart = calendar.startOfDay(for: startDate)
        let rangeEnd = calendar.startOfDay(for: endDate)
        var metrics: [DailyHealthMetrics] = []
        var cursor = rangeStart
        while cursor <= rangeEnd {
            let day = calendar.startOfDay(for: cursor)
            metrics.append(dailyMetricsByDay[day] ?? .empty(for: day))
            guard let next = calendar.date(byAdding: .day, value: 1, to: cursor) else {
                break
            }
            cursor = next
        }
        return metrics
    }

    func getRecentWorkouts(days: Int, calendar: Calendar) async -> [NormalizedWorkout] {
        workouts
    }

    func getWorkouts(from startDate: Date, to endDate: Date) async -> [NormalizedWorkout] {
        workouts
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
        availability
    }

    func refreshHealthData(days: Int, endingOn date: Date, calendar: Calendar) async -> HealthRefreshResult {
        HealthRefreshResult(daysRefreshed: days, refreshedAt: Date())
    }
}

private extension HealthDataAvailability {
    static var unavailableSnapshot: HealthDataAvailability {
        HealthDataAvailability(
            isHealthDataAvailable: false,
            permissionStatus: .unavailable(),
            cachedDayCount: 0
        )
    }

    static var connectedSnapshot: HealthDataAvailability {
        HealthDataAvailability(
            isHealthDataAvailable: true,
            permissionStatus: .uniform(.available, isHealthDataAvailable: true),
            cachedDayCount: 7
        )
    }
}
