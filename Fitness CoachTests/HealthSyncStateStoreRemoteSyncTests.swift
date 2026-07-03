//
//  HealthSyncStateStoreRemoteSyncTests.swift
//  Fitness CoachTests
//
//  Forma — Verifies local → remote health summary sync wiring in HealthSyncStateStore.
//

import Foundation
import XCTest
@testable import Fitness_Coach

@MainActor
final class HealthSyncStateStoreRemoteSyncTests: XCTestCase {

    private var calendar: Calendar!
    private var cache: MemoryHealthCacheStore!
    private var repository: RemoteSyncHookMockRepository!
    private var syncService: HealthSyncService!
    private var remoteSyncService: MockHealthSummarySyncService!

    override func setUp() {
        super.setUp()
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(secondsFromGMT: 0)!
        self.calendar = calendar
        self.cache = MemoryHealthCacheStore()
        self.repository = RemoteSyncHookMockRepository()
        self.syncService = HealthSyncService(
            repository: repository,
            cacheStore: cache,
            calendar: calendar,
            foregroundMinimumInterval: 0
        )
        self.remoteSyncService = MockHealthSummarySyncService()
    }

    func testRemoteSummarySyncNotScheduledWhenFlagDisabled() async {
        let store = HealthSyncStateStore(
            syncService: syncService,
            remoteSummarySyncService: remoteSyncService,
            syncEnabled: true,
            remoteSummarySyncEnabled: { false }
        )

        store.syncToday()
        try? await Task.sleep(nanoseconds: 300_000_000)

        XCTAssertEqual(remoteSyncService.syncAfterLocalHealthRefreshCallCount, 0)
    }

    func testRemoteSummarySyncNotScheduledWhenRemoteServiceMissing() async {
        let store = HealthSyncStateStore(
            syncService: syncService,
            remoteSummarySyncService: nil,
            syncEnabled: true,
            remoteSummarySyncEnabled: { true }
        )

        store.syncToday()
        try? await Task.sleep(nanoseconds: 300_000_000)

        XCTAssertEqual(remoteSyncService.syncAfterLocalHealthRefreshCallCount, 0)
    }

    func testRemoteSummarySyncScheduledAfterSuccessfulLocalSync() async {
        let store = HealthSyncStateStore(
            syncService: syncService,
            remoteSummarySyncService: remoteSyncService,
            syncEnabled: true,
            remoteSummarySyncEnabled: { true }
        )

        store.syncToday()
        try? await Task.sleep(nanoseconds: 900_000_000)

        XCTAssertEqual(remoteSyncService.syncAfterLocalHealthRefreshCallCount, 1)
        XCTAssertEqual(remoteSyncService.lastSyncAfterLocalHealthRefreshDays, 1)
        XCTAssertEqual(store.state.phase, .succeeded)
    }

    func testRemoteSummarySyncNotScheduledAfterFailedLocalSync() async {
        repository.availability = HealthDataAvailability(
            isHealthDataAvailable: false,
            permissionStatus: .uniform(.available, isHealthDataAvailable: false),
            cachedDayCount: 0
        )

        let store = HealthSyncStateStore(
            syncService: syncService,
            remoteSummarySyncService: remoteSyncService,
            syncEnabled: true,
            remoteSummarySyncEnabled: { true }
        )

        store.syncToday()
        try? await Task.sleep(nanoseconds: 300_000_000)

    func testRemoteSummarySyncDebouncesRapidLocalSyncs() async {
        remoteSyncService.syncAfterLocalHealthRefreshDelayNanoseconds = 400_000_000
        let store = HealthSyncStateStore(
            syncService: syncService,
            remoteSummarySyncService: remoteSyncService,
            syncEnabled: true,
            remoteSummarySyncEnabled: { true }
        )

        store.syncToday()
        try? await Task.sleep(nanoseconds: 100_000_000)
        store.syncToday()
        try? await Task.sleep(nanoseconds: 1_200_000_000)

        XCTAssertEqual(remoteSyncService.syncAfterLocalHealthRefreshCallCount, 1)
    }

    func testRefreshOnAppForegroundSkippedBeforeBootstrapComplete() async {
        let store = HealthSyncStateStore(
            syncService: syncService,
            remoteSummarySyncService: remoteSyncService,
            syncEnabled: true,
            remoteSummarySyncEnabled: { true }
        )

        store.refreshOnAppForeground()
        try? await Task.sleep(nanoseconds: 300_000_000)

        XCTAssertEqual(store.state.phase, .idle)
    }

    func testRefreshOnAppForegroundRunsAfterBootstrapMarked() async {
        let store = HealthSyncStateStore(
            syncService: syncService,
            remoteSummarySyncService: remoteSyncService,
            syncEnabled: true,
            remoteSummarySyncEnabled: { true }
        )

        store.markForegroundBootstrapComplete()
        store.refreshOnAppForeground()
        try? await Task.sleep(nanoseconds: 500_000_000)

        XCTAssertEqual(store.state.phase, .succeeded)
    }
}

private final class RemoteSyncHookMockRepository: HealthDataRepositorying, @unchecked Sendable {
    var availability = HealthDataAvailability(
        isHealthDataAvailable: true,
        permissionStatus: .uniform(.available, isHealthDataAvailable: true),
        cachedDayCount: 1
    )

    func normalizedSamples(for date: Date, calendar: Calendar) async throws -> [HealthNormalizedSample] { [] }
    func getDailyMetrics(for date: Date, calendar: Calendar) async -> DailyHealthMetrics {
        .empty(for: date)
    }
    func getDailyMetrics(from startDate: Date, to endDate: Date, calendar: Calendar) async -> [DailyHealthMetrics] { [] }
    func getRecentWorkouts(days: Int, calendar: Calendar) async -> [NormalizedWorkout] { [] }
    func getWorkouts(from startDate: Date, to endDate: Date, calendar: Calendar) async -> [NormalizedWorkout] { [] }
    func getRecentSleep(days: Int, calendar: Calendar) async -> [NormalizedSleepRecord] { [] }
    func getSleepRecords(from startDate: Date, to endDate: Date, calendar: Calendar) async -> [NormalizedSleepRecord] { [] }
    func getRecentHeartMetrics(days: Int, calendar: Calendar) async -> [NormalizedHeartMetric] { [] }
    func getHeartMetrics(from startDate: Date, to endDate: Date, calendar: Calendar) async -> [NormalizedHeartMetric] { [] }
    func getBodyMassHistory(days: Int, calendar: Calendar) async -> [NormalizedBodyMass] { [] }
    func getHealthDataAvailability() async -> HealthDataAvailability { availability }
    func refreshHealthData(days: Int, endingOn date: Date, calendar: Calendar) async -> HealthRefreshResult {
        HealthRefreshResult(daysRefreshed: days, refreshedAt: Date())
    }
}
