//
//  HealthSyncServiceTests.swift
//  Fitness CoachTests
//

import XCTest
@testable import Fitness_Coach

final class HealthSyncServiceTests: XCTestCase {

    private var calendar: Calendar!
    private var mockRepository: MockSyncRepository!
    private var mockPermission: MockSyncPermissionService!
    private var cache: MemoryHealthCacheStore!
    private var service: HealthSyncService!

    override func setUp() {
        super.setUp()
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(secondsFromGMT: 0) ?? .gmt
        self.calendar = calendar
        self.mockRepository = MockSyncRepository()
        self.mockPermission = MockSyncPermissionService()
        self.cache = MemoryHealthCacheStore()
        self.service = HealthSyncService(
            repository: mockRepository,
            permissionService: mockPermission,
            cacheStore: cache,
            calendar: calendar,
            foregroundMinimumInterval: 0
        )
    }

    func testGetCurrentSyncStateStartsIdle() async {
        let state = await service.getCurrentSyncState()
        XCTAssertEqual(state.phase, .idle)
        XCTAssertFalse(state.isSyncing)
    }

    func testSyncTodayFailsWhenPermissionDenied() async {
        mockPermission.status = .uniform(.denied, isHealthDataAvailable: true)

        let state = await service.syncToday()

        XCTAssertEqual(state.phase, .failed)
        XCTAssertEqual(state.lastError, .permissionDenied)
        XCTAssertEqual(mockRepository.refreshCallCount, 0)
    }

    func testSyncTodaySucceedsAndReportsProgress() async {
        mockPermission.status = .uniform(.available, isHealthDataAvailable: true)

        let state = await service.syncToday()

        XCTAssertEqual(state.phase, .succeeded)
        XCTAssertEqual(state.progress.daysRequested, 1)
        XCTAssertEqual(state.progress.daysCompleted, 1)
        XCTAssertEqual(mockRepository.refreshCallCount, 1)
        XCTAssertNotNil(state.lastSuccessfulSyncAt)
    }

    func testConcurrentSyncPreventsOverlappingRuns() async {
        mockPermission.status = .uniform(.available, isHealthDataAvailable: true)
        mockRepository.refreshDelayNanoseconds = 300_000_000

        let service = self.service
        async let first = Task { await service.syncLastNDays(2) }
        async let second = Task { await service.syncToday() }
        _ = await (first.value, second.value)

        XCTAssertLessThanOrEqual(mockRepository.refreshCallCount, 2)
    }

    func testSyncStateTransitionsFromIdleToSucceeded() async {
        mockPermission.status = .uniform(.available, isHealthDataAvailable: true)

        let initial = await service.getCurrentSyncState()
        XCTAssertEqual(initial.phase, .idle)

        let finished = await service.syncToday()

        XCTAssertEqual(finished.phase, .succeeded)
        XCTAssertEqual(finished.trigger, .today)
        XCTAssertEqual(finished.progress.daysCompleted, 1)
        XCTAssertFalse(finished.isSyncing)
    }

    func testPartialSyncFailureDoesNotWipeExistingCacheEntry() async {
        let day = makeDate(2026, 7, 3)
        let bundle = HealthNormalizedDayBundle(
            dailyMetrics: DailyHealthMetrics(date: day, steps: 5_500, activeEnergyKcal: 320, exerciseMinutes: 28),
            workouts: [],
            sleepRecords: [],
            heartMetrics: [],
            bodyMassRecords: []
        )
        cache.store(HealthCacheEntry(date: day, bundle: bundle, cachedAt: Date()), calendar: calendar)

        let deniedSleepStatus = HealthPermissionStatus(
            isHealthDataAvailable: true,
            signalAccess: [
                .stepCount: .available,
                .activeEnergyBurned: .available,
                .appleExerciseTime: .available,
                .workout: .available,
                .restingHeartRate: .available,
                .heartRateVariabilitySDNN: .available,
                .sleepAnalysis: .denied,
                .bodyMass: .available
            ],
            resolvedAt: Date()
        )
        mockPermission.status = deniedSleepStatus
        mockRepository.availability = HealthDataAvailability(
            isHealthDataAvailable: true,
            permissionStatus: deniedSleepStatus,
            cachedDayCount: 1
        )

        let state = await service.syncToday()

        XCTAssertEqual(state.phase, .partialSuccess)
        XCTAssertEqual(cache.dailyMetrics(for: day, calendar: calendar)?.steps, 5_500)
    }

    func testConcurrentSyncIsIgnored() async {
        mockPermission.status = .uniform(.available, isHealthDataAvailable: true)
        mockRepository.refreshDelayNanoseconds = 200_000_000

        async let first = service.syncLastNDays(3)
        async let second = service.syncToday()
        let results = await [first, second]

        let syncingStates = results.filter { $0.phase == .syncing }
        XCTAssertTrue(syncingStates.count <= 1 || results.contains { $0.phase == .succeeded })
        XCTAssertLessThanOrEqual(mockRepository.refreshCallCount, 3)
    }

    func testPartialSuccessWhenOneSignalUnavailable() async {
        let deniedSleepStatus = HealthPermissionStatus(
            isHealthDataAvailable: true,
            signalAccess: [
                .stepCount: .available,
                .activeEnergyBurned: .available,
                .appleExerciseTime: .available,
                .workout: .available,
                .restingHeartRate: .available,
                .heartRateVariabilitySDNN: .available,
                .sleepAnalysis: .denied,
                .bodyMass: .available
            ],
            resolvedAt: Date()
        )
        mockPermission.status = deniedSleepStatus
        mockRepository.availability = HealthDataAvailability(
            isHealthDataAvailable: true,
            permissionStatus: deniedSleepStatus,
            cachedDayCount: 0
        )

        let state = await service.syncToday()

        XCTAssertEqual(state.phase, .partialSuccess)
        XCTAssertTrue(state.signalResults.contains { $0.signal == .sleepAnalysis && !$0.succeeded })
    }

    func testRefreshOnForegroundIsThrottled() async {
        mockPermission.status = .uniform(.available, isHealthDataAvailable: true)
        let throttledService = HealthSyncService(
            repository: mockRepository,
            permissionService: mockPermission,
            cacheStore: cache,
            calendar: calendar,
            foregroundMinimumInterval: 60 * 15
        )

        _ = await throttledService.refreshOnAppForeground()
        let before = mockRepository.refreshCallCount
        _ = await throttledService.refreshOnAppForeground()

        XCTAssertEqual(mockRepository.refreshCallCount, before)
    }

    func testSyncInitialUsesNinetyDayWindow() async {
        mockPermission.status = .uniform(.available, isHealthDataAvailable: true)

        let state = await service.syncInitialHealthData()

        XCTAssertEqual(state.trigger, .initial)
        XCTAssertEqual(state.progress.daysRequested, HealthCachePolicy.retentionDays)
        XCTAssertEqual(mockRepository.refreshCallCount, HealthCachePolicy.retentionDays)
        XCTAssertEqual(state.phase, .succeeded)
    }

    // MARK: - Helpers

    private func makeDate(_ year: Int, _ month: Int, _ day: Int) -> Date {
        calendar.date(from: DateComponents(year: year, month: month, day: day))!
    }
}

// MARK: - Mocks

private final class MockSyncRepository: HealthDataRepositorying, @unchecked Sendable {

    var refreshCallCount = 0
    var refreshDelayNanoseconds: UInt64 = 0
    var availability = HealthDataAvailability(
        isHealthDataAvailable: true,
        permissionStatus: .uniform(.available, isHealthDataAvailable: true),
        cachedDayCount: 0
    )

    func normalizedSamples(for date: Date, calendar: Calendar) async throws -> [HealthNormalizedSample] {
        []
    }

    func getDailyMetrics(for date: Date, calendar: Calendar) async -> DailyHealthMetrics {
        .empty(for: date)
    }

    func getDailyMetrics(from startDate: Date, to endDate: Date, calendar: Calendar) async -> [DailyHealthMetrics] {
        []
    }

    func getRecentWorkouts(days: Int, calendar: Calendar) async -> [NormalizedWorkout] {
        []
    }

    func getWorkouts(from startDate: Date, to endDate: Date) async -> [NormalizedWorkout] {
        []
    }

    func getRecentSleep(days: Int, calendar: Calendar) async -> [NormalizedSleepRecord] {
        []
    }

    func getRecentHeartMetrics(days: Int, calendar: Calendar) async -> [NormalizedHeartMetric] {
        []
    }

    func getBodyMassHistory(days: Int, calendar: Calendar) async -> [NormalizedBodyMass] {
        []
    }

    func getHealthDataAvailability() async -> HealthDataAvailability {
        availability
    }

    func refreshHealthData(
        days: Int,
        endingOn date: Date,
        calendar: Calendar
    ) async -> HealthRefreshResult {
        if refreshDelayNanoseconds > 0 {
            try? await Task.sleep(nanoseconds: refreshDelayNanoseconds)
        }
        refreshCallCount += 1
        return HealthRefreshResult(daysRefreshed: 1, refreshedAt: Date())
    }
}

private struct MockSyncPermissionService: HealthPermissionServing {

    var status: HealthPermissionStatus = .uniform(.available, isHealthDataAvailable: true)

    var isHealthDataAvailable: Bool {
        status.isHealthDataAvailable
    }

    func currentStatus(includingFutureTypes: Bool) async -> HealthPermissionStatus {
        status
    }

    func requestPermissions(includingFutureTypes: Bool) async throws -> HealthPermissionStatus {
        status
    }
}
