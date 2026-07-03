//
//  HealthDataRepositoryTests.swift
//  Fitness CoachTests
//

import XCTest
@testable import Fitness_Coach

final class HealthDataRepositoryTests: XCTestCase {

    private var calendar: Calendar!
    private var cache: HealthCacheStore!
    private var mockManager: MockHealthKitManager!
    private var repository: HealthDataRepository!

    override func setUp() {
        super.setUp()
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(secondsFromGMT: 0) ?? .gmt
        self.calendar = calendar
        self.cache = HealthCacheStore()
        self.mockManager = MockHealthKitManager()
        self.repository = HealthDataRepository(
            healthKitManager: mockManager,
            normalizer: HealthSampleNormalizer(),
            cacheStore: cache
        )
    }

    // MARK: - Availability

    func testGetHealthDataAvailabilityWhenUnavailableReturnsZeroCache() async {
        mockManager.isAvailable = false

        let availability = await repository.getHealthDataAvailability()

        XCTAssertFalse(availability.isHealthDataAvailable)
        XCTAssertEqual(availability.cachedDayCount, 0)
        XCTAssertFalse(availability.hasAnyReadableSignal)
    }

    // MARK: - Daily metrics

    func testGetDailyMetricsReturnsEmptyWhenHealthKitUnavailable() async {
        mockManager.isAvailable = false
        let day = makeDate(2026, 7, 3)

        let metrics = await repository.getDailyMetrics(for: day, calendar: calendar)

        XCTAssertEqual(metrics.date, day)
        XCTAssertEqual(metrics.steps, 0)
        XCTAssertEqual(metrics.activeEnergyKcal, 0)
        XCTAssertEqual(metrics.exerciseMinutes, 0)
    }

    func testGetDailyMetricsNormalizesFetchedValues() async {
        let day = makeDate(2026, 7, 3)
        mockManager.dailyMetricsByDay[day] = HealthDailyMetrics(
            date: day,
            steps: 10_000,
            activeEnergyKcal: 500,
            exerciseMinutes: 45
        )

        let metrics = await repository.getDailyMetrics(for: day, calendar: calendar)

        XCTAssertEqual(metrics.steps, 10_000)
        XCTAssertEqual(metrics.activeEnergyKcal, 500)
        XCTAssertEqual(metrics.exerciseMinutes, 45)
        XCTAssertEqual(cache.cachedDayCount(calendar: calendar), 1)
    }

    func testGetDailyMetricsRangeUsesCacheForKnownDays() async {
        let day1 = makeDate(2026, 7, 1)
        let day2 = makeDate(2026, 7, 2)
        mockManager.dailyMetricsByDay[day1] = HealthDailyMetrics(
            date: day1, steps: 1_000, activeEnergyKcal: 100, exerciseMinutes: 10
        )
        mockManager.dailyMetricsByDay[day2] = HealthDailyMetrics(
            date: day2, steps: 2_000, activeEnergyKcal: 200, exerciseMinutes: 20
        )

        _ = await repository.getDailyMetrics(for: day1, calendar: calendar)
        mockManager.fetchDailyMetricsRangeCallCount = 0

        let range = await repository.getDailyMetrics(from: day1, to: day2, calendar: calendar)

        XCTAssertEqual(range.count, 2)
        XCTAssertEqual(range[0].steps, 1_000)
        XCTAssertEqual(range[1].steps, 2_000)
        XCTAssertEqual(mockManager.fetchDailyMetricsRangeCallCount, 1)
    }

    // MARK: - Workouts

    func testGetRecentWorkoutsUsesDefaultDaysWhenZeroPassed() async {
        let workout = makeWorkout(on: makeDate(2026, 7, 3, hour: 8))
        mockManager.workouts = [workout]

        let results = await repository.getRecentWorkouts(days: 0, calendar: calendar)

        XCTAssertEqual(results.count, 1)
        XCTAssertEqual(results.first?.category, .running)
    }

    func testGetWorkoutsReturnsEmptyOnAuthorizationDenied() async {
        mockManager.workoutsError = HealthKitManagerError.authorizationDenied

        let results = await repository.getWorkouts(
            from: makeDate(2026, 7, 1),
            to: makeDate(2026, 7, 3)
        )

        XCTAssertTrue(results.isEmpty)
    }

    // MARK: - Sleep / heart / body mass

    func testGetRecentSleepReturnsEmptyWhenUnavailable() async {
        mockManager.isAvailable = false

        let records = await repository.getRecentSleep(days: 7, calendar: calendar)

        XCTAssertTrue(records.isEmpty)
    }

    func testGetRecentHeartMetricsNormalizesValues() async {
        let day = makeDate(2026, 7, 3, hour: 7)
        mockManager.heartMetrics = [
            HealthHeartMetric(
                id: UUID(),
                kind: .restingHeartRate,
                date: day,
                value: 58,
                unitSymbol: HealthUnitSymbol.beatsPerMinute
            )
        ]

        let metrics = await repository.getRecentHeartMetrics(days: 7, calendar: calendar)

        XCTAssertEqual(metrics.count, 1)
        XCTAssertEqual(metrics.first?.value, 58)
        XCTAssertEqual(metrics.first?.kind, .restingHeartRate)
    }

    func testGetBodyMassHistoryReturnsEmptyOnFetchFailure() async {
        mockManager.bodyMassError = HealthKitManagerError.queryFailed

        let records = await repository.getBodyMassHistory(days: 30, calendar: calendar)

        XCTAssertTrue(records.isEmpty)
    }

    // MARK: - Refresh

    func testRefreshHealthDataPopulatesCache() async {
        let day = makeDate(2026, 7, 3)
        mockManager.dailyMetricsByDay[day] = HealthDailyMetrics(
            date: day, steps: 5_000, activeEnergyKcal: 300, exerciseMinutes: 30
        )

        let result = await repository.refreshHealthData(days: 1, endingOn: day, calendar: calendar)

        XCTAssertEqual(result.daysRefreshed, 1)
        XCTAssertEqual(cache.cachedDayCount(calendar: calendar), 1)
    }

    func testRefreshHealthDataReturnsZeroWhenUnavailable() async {
        mockManager.isAvailable = false

        let result = await repository.refreshHealthData(days: 7, endingOn: makeDate(2026, 7, 3), calendar: calendar)

        XCTAssertEqual(result.daysRefreshed, 0)
    }

    // MARK: - Legacy normalized samples

    func testNormalizedSamplesThrowsWhenUnavailable() async {
        mockManager.isAvailable = false
        let day = makeDate(2026, 7, 3)

        do {
            _ = try await repository.normalizedSamples(for: day, calendar: calendar)
            XCTFail("Expected unavailable error")
        } catch let error as HealthDataRepositoryError {
            XCTAssertEqual(error, .unavailable)
        } catch {
            XCTFail("Unexpected error: \(error)")
        }
    }

    func testNormalizedSamplesMapsBundleToLegacySamples() async throws {
        let day = makeDate(2026, 7, 3)
        mockManager.dailyMetricsByDay[day] = HealthDailyMetrics(
            date: day, steps: 8_000, activeEnergyKcal: 400, exerciseMinutes: 35
        )
        mockManager.workouts = [makeWorkout(on: makeDate(2026, 7, 3, hour: 9))]

        let samples = try await repository.normalizedSamples(for: day, calendar: calendar)

        XCTAssertTrue(samples.contains { $0.kind == .stepCount && $0.value == 8_000 })
        XCTAssertTrue(samples.contains { $0.kind == .activeEnergy && $0.value == 400 })
        XCTAssertTrue(samples.contains { $0.kind == .exerciseTime && $0.value == 35 })
        XCTAssertTrue(samples.contains { $0.kind == .workout })
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

    private func makeWorkout(on start: Date) -> HealthFetchedWorkout {
        HealthFetchedWorkout(
            id: UUID(),
            activityTypeName: "Running",
            startDate: start,
            endDate: calendar.date(byAdding: .hour, value: 1, to: start) ?? start,
            durationMinutes: 60,
            activeCaloriesKcal: 400,
            sourceName: "Apple Watch"
        )
    }
}

// MARK: - Mock

private final class MockHealthKitManager: HealthKitManaging, @unchecked Sendable {

    var isAvailable = true
    var dailyMetricsByDay: [Date: HealthDailyMetrics] = [:]
    var workouts: [HealthFetchedWorkout] = []
    var workoutsError: HealthKitManagerError?
    var sleepRecords: [HealthSleepRecord] = []
    var sleepError: HealthKitManagerError?
    var heartMetrics: [HealthHeartMetric] = []
    var heartError: HealthKitManagerError?
    var bodyMassRecords: [HealthBodyMassRecord] = []
    var bodyMassError: HealthKitManagerError?
    var permissionStatus = HealthPermissionStatus.uniform(.available, isHealthDataAvailable: true)
    var fetchDailyMetricsRangeCallCount = 0

    var isHealthDataAvailable: Bool { isAvailable }

    func requestAuthorization(includingFutureTypes: Bool) async throws -> HealthPermissionStatus {
        _ = includingFutureTypes
        guard isAvailable else { throw HealthKitManagerError.unavailable }
        return permissionStatus
    }

    func getAuthorizationStatus(includingFutureTypes: Bool) async -> HealthPermissionStatus {
        _ = includingFutureTypes
        return isAvailable ? permissionStatus : .unavailable()
    }

    func fetchDailyMetrics(for date: Date, calendar: Calendar) async throws -> HealthDailyMetrics {
        _ = calendar
        try throwIfNeeded()
        let day = calendar.startOfDay(for: date)
        return dailyMetricsByDay[day] ?? .empty(for: day)
    }

    func fetchDailyMetrics(
        from startDate: Date,
        to endDate: Date,
        calendar: Calendar
    ) async throws -> [HealthDailyMetrics] {
        fetchDailyMetricsRangeCallCount += 1
        try throwIfNeeded()

        let rangeStart = calendar.startOfDay(for: startDate)
        let rangeEnd = calendar.startOfDay(for: endDate)
        var metrics: [HealthDailyMetrics] = []
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

    func fetchWorkouts(from startDate: Date, to endDate: Date) async throws -> [HealthFetchedWorkout] {
        if let workoutsError { throw workoutsError }
        try throwIfNeeded()
        return workouts.filter { $0.startDate >= startDate && $0.startDate < endDate }
    }

    func fetchSleepRecords(from startDate: Date, to endDate: Date) async throws -> [HealthSleepRecord] {
        if let sleepError { throw sleepError }
        try throwIfNeeded()
        return sleepRecords.filter { $0.startDate >= startDate && $0.startDate < endDate }
    }

    func fetchHeartMetrics(from startDate: Date, to endDate: Date) async throws -> [HealthHeartMetric] {
        if let heartError { throw heartError }
        try throwIfNeeded()
        return heartMetrics.filter { $0.date >= startDate && $0.date < endDate }
    }

    func fetchBodyMassRecords(from startDate: Date, to endDate: Date) async throws -> [HealthBodyMassRecord] {
        if let bodyMassError { throw bodyMassError }
        try throwIfNeeded()
        return bodyMassRecords.filter { $0.date >= startDate && $0.date < endDate }
    }

    private func throwIfNeeded() throws {
        guard isAvailable else { throw HealthKitManagerError.unavailable }
    }
}
