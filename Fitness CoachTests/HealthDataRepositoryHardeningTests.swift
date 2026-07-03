//
//  HealthDataRepositoryHardeningTests.swift
//  Fitness CoachTests
//

import XCTest
@testable import Fitness_Coach

final class HealthDataRepositoryHardeningTests: XCTestCase {

    private var calendar: Calendar!
    private var cache: MemoryHealthCacheStore!
    private var mockManager: MockHealthKitManager!
    private var repository: HealthDataRepository!

    override func setUp() {
        super.setUp()
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(secondsFromGMT: 0) ?? .gmt
        self.calendar = calendar
        self.cache = MemoryHealthCacheStore()
        self.mockManager = MockHealthKitManager()
        self.repository = HealthDataRepository(
            healthKitManager: mockManager,
            normalizer: HealthSampleNormalizer(),
            cacheStore: cache
        )
    }

    func testBulkRefreshUsesRangeFetchNotPerDayLoop() async {
        let endingOn = makeDate(2026, 7, 3)
        mockManager.dailyMetricsByDay[makeDate(2026, 7, 1)] = HealthDailyMetrics(
            date: makeDate(2026, 7, 1), steps: 1_000, activeEnergyKcal: 100, exerciseMinutes: 10
        )
        mockManager.dailyMetricsByDay[makeDate(2026, 7, 2)] = HealthDailyMetrics(
            date: makeDate(2026, 7, 2), steps: 2_000, activeEnergyKcal: 200, exerciseMinutes: 20
        )
        mockManager.dailyMetricsByDay[makeDate(2026, 7, 3)] = HealthDailyMetrics(
            date: makeDate(2026, 7, 3), steps: 3_000, activeEnergyKcal: 300, exerciseMinutes: 30
        )

        let result = await repository.refreshHealthData(days: 3, endingOn: endingOn, calendar: calendar)

        XCTAssertEqual(result.daysRefreshed, 3)
        XCTAssertEqual(mockManager.fetchDailyMetricsRangeCallCount, 1)
        XCTAssertEqual(mockManager.fetchDailyMetricsCallCount, 0)
    }

    func testPartialDayBundlePreservesStepsWhenWorkoutsDenied() async {
        let day = makeDate(2026, 7, 3)
        mockManager.dailyMetricsByDay[day] = HealthDailyMetrics(
            date: day, steps: 6_000, activeEnergyKcal: 300, exerciseMinutes: 30
        )
        mockManager.workoutsError = .authorizationDenied

        let metrics = await repository.getDailyMetrics(for: day, calendar: calendar)

        XCTAssertEqual(metrics.steps, 6_000)
    }

    func testRefreshCountsZeroWhenHealthKitUnavailable() async {
        mockManager.isAvailable = false

        let result = await repository.refreshHealthData(days: 7, endingOn: makeDate(2026, 7, 3), calendar: calendar)

        XCTAssertEqual(result.daysRefreshed, 0)
    }

    // MARK: - Helpers

    private func makeDate(_ year: Int, _ month: Int, _ day: Int) -> Date {
        calendar.date(from: DateComponents(year: year, month: month, day: day))!
    }
}

// MARK: - Mock

private final class MockHealthKitManager: HealthKitManaging, @unchecked Sendable {

    var isAvailable = true
    var dailyMetricsByDay: [Date: HealthDailyMetrics] = [:]
    var workoutsError: HealthKitManagerError?
    var fetchDailyMetricsCallCount = 0
    var fetchDailyMetricsRangeCallCount = 0
    var fetchWorkoutsCallCount = 0

    var isHealthDataAvailable: Bool { isAvailable }

    func requestAuthorization(includingFutureTypes: Bool) async throws -> HealthPermissionStatus {
        .uniform(.available, isHealthDataAvailable: isAvailable)
    }

    func getAuthorizationStatus(includingFutureTypes: Bool) async -> HealthPermissionStatus {
        isAvailable ? .uniform(.available, isHealthDataAvailable: true) : .unavailable()
    }

    func fetchDailyMetrics(for date: Date, calendar: Calendar) async throws -> HealthDailyMetrics {
        fetchDailyMetricsCallCount += 1
        let day = calendar.startOfDay(for: date)
        return dailyMetricsByDay[day] ?? .empty(for: day)
    }

    func fetchDailyMetrics(
        from startDate: Date,
        to endDate: Date,
        calendar: Calendar
    ) async throws -> [HealthDailyMetrics] {
        fetchDailyMetricsRangeCallCount += 1
        let rangeStart = calendar.startOfDay(for: startDate)
        let rangeEnd = calendar.startOfDay(for: endDate)
        var metrics: [HealthDailyMetrics] = []
        var cursor = rangeStart
        while cursor <= rangeEnd {
            let day = calendar.startOfDay(for: cursor)
            metrics.append(dailyMetricsByDay[day] ?? .empty(for: day))
            guard let next = calendar.date(byAdding: .day, value: 1, to: cursor) else { break }
            cursor = next
        }
        return metrics
    }

    func fetchWorkouts(from startDate: Date, to endDate: Date) async throws -> [HealthFetchedWorkout] {
        fetchWorkoutsCallCount += 1
        if let workoutsError { throw workoutsError }
        return []
    }

    func fetchSleepRecords(from startDate: Date, to endDate: Date) async throws -> [HealthSleepRecord] {
        []
    }

    func fetchHeartMetrics(from startDate: Date, to endDate: Date) async throws -> [HealthHeartMetric] {
        []
    }

    func fetchBodyMassRecords(from startDate: Date, to endDate: Date) async throws -> [HealthBodyMassRecord] {
        []
    }
}
