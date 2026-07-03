//
//  HealthSummarySyncServiceTests.swift
//  Fitness CoachTests
//
//  Forma — Unit tests for remote Health Summary Sync orchestration.
//

import Foundation
import XCTest
@testable import Fitness_Coach

final class HealthSummarySyncServiceTests: XCTestCase {

    private var calendar: Calendar!
    private var cache: MemoryHealthCacheStore!
    private var remoteClient: MockHealthSummaryRemoteSyncClient!
    private var stateStore: LockedHealthSummaryRemoteSyncStateStore!
    private var repository: SummarySyncMockRepository!
    private var service: HealthSummarySyncService!

    override func setUp() {
        super.setUp()
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(secondsFromGMT: 0)!
        self.calendar = calendar
        self.cache = MemoryHealthCacheStore()
        self.remoteClient = MockHealthSummaryRemoteSyncClient()
        self.stateStore = LockedHealthSummaryRemoteSyncStateStore()
        self.repository = SummarySyncMockRepository()
        self.service = HealthSummarySyncService(
            remoteSyncClient: remoteClient,
            cacheStore: cache,
            repository: repository,
            userProvider: StaticHealthCacheUserProvider(userID: "user-123"),
            stateStore: stateStore,
            calendar: calendar,
            foregroundMinimumInterval: 60 * 15,
            remoteSyncEnabled: { true }
        )
    }

    override func tearDown() {
        remoteClient.reset()
        super.tearDown()
    }

    func testDisabledFeatureFlagReturnsDisabledState() async {
        let disabledService = HealthSummarySyncService(
            remoteSyncClient: remoteClient,
            cacheStore: cache,
            repository: repository,
            userProvider: StaticHealthCacheUserProvider(userID: "user-123"),
            stateStore: stateStore,
            calendar: calendar,
            remoteSyncEnabled: { false }
        )

        let state = await disabledService.getRemoteSyncState()
        XCTAssertEqual(state.phase, .disabled)

        await disabledService.syncRecentHealthSummaries(days: 7)
        XCTAssertTrue(remoteClient.uploadedDailySummaries.isEmpty)
    }

    func testUnauthenticatedUserDoesNotUpload() async {
        let unauthenticatedService = HealthSummarySyncService(
            remoteSyncClient: remoteClient,
            cacheStore: cache,
            repository: repository,
            userProvider: StaticHealthCacheUserProvider(userID: nil),
            stateStore: stateStore,
            calendar: calendar,
            remoteSyncEnabled: { true }
        )
        seedDay(makeDate(2026, 7, 3))

        await unauthenticatedService.syncRecentHealthSummaries(days: 1)

        XCTAssertTrue(remoteClient.uploadedDailySummaries.isEmpty)
        let state = await unauthenticatedService.getRemoteSyncState()
        XCTAssertEqual(state.lastError, .notAuthenticated)
    }

    func testSyncUploadsComposedSummaries() async {
        let day = makeDate(2026, 7, 3)
        seedDay(day, steps: 9000, workouts: [makeWorkout(on: day)])
        cache.storeRecoverySummary(
            RecoverySummary(
                score: 80,
                status: .ready,
                title: "Ready",
                explanation: "Good sleep",
                recommendedTraining: "Train",
                recommendedNutrition: "Eat",
                confidence: .high,
                contributingFactors: [],
                missingSignals: []
            ),
            for: day,
            calendar: calendar
        )

        await service.syncRecentHealthSummaries(days: 1)

        XCTAssertEqual(remoteClient.uploadedDailySummaries.count, 1)
        XCTAssertEqual(remoteClient.uploadedWorkoutSummaries.count, 1)
        XCTAssertEqual(remoteClient.uploadedRecoverySummaries.count, 1)
        XCTAssertEqual(remoteClient.uploadedMetadata.count, 1)

        let state = await service.getRemoteSyncState()
        XCTAssertEqual(state.phase, .succeeded)
        XCTAssertNotNil(state.lastSuccessfulRemoteSyncAt)
        XCTAssertNotNil(stateStore.load(for: "user-123").lastSuccessfulRemoteSyncAt)
    }

    func testPartialFailureDoesNotBlockOtherPayloadTypes() async {
        let day = makeDate(2026, 7, 3)
        seedDay(day, steps: 5000, workouts: [makeWorkout(on: day)])
        cache.storeRecoverySummary(.unknown, for: day, calendar: calendar)
        remoteClient.uploadDailyError = .uploadFailed(collection: "daily", reason: "transient")

        await service.syncRecentHealthSummaries(days: 1)

        XCTAssertTrue(remoteClient.uploadedDailySummaries.isEmpty)
        XCTAssertEqual(remoteClient.uploadedWorkoutSummaries.count, 1)
        XCTAssertEqual(remoteClient.uploadedRecoverySummaries.count, 1)

        let state = await service.getRemoteSyncState()
        XCTAssertEqual(state.phase, .partialSuccess)
        XCTAssertEqual(state.failedPayloadKinds, [.daily])
    }

    func testManualSyncBypassesBackoff() async {
        stateStore.save(
            HealthSummaryRemoteSyncPersistedState(
                lastSuccessfulRemoteSyncAt: nil,
                lastAttemptedRemoteSyncAt: Date(),
                consecutiveFailures: 3,
                backoffUntil: Date().addingTimeInterval(3600)
            ),
            for: "user-123"
        )
        seedDay(makeDate(2026, 7, 3))

        await service.syncRecentHealthSummaries(days: 1)

        XCTAssertEqual(remoteClient.uploadedDailySummaries.count, 1)
    }

    func testNonManualSyncRespectsBackoff() async {
        stateStore.save(
            HealthSummaryRemoteSyncPersistedState(
                lastSuccessfulRemoteSyncAt: Date(),
                lastAttemptedRemoteSyncAt: Date(),
                consecutiveFailures: 2,
                backoffUntil: Date().addingTimeInterval(3600)
            ),
            for: "user-123"
        )
        seedDay(makeDate(2026, 7, 3))

        await service.syncTodayHealthSummary()

        XCTAssertTrue(remoteClient.uploadedDailySummaries.isEmpty)
    }

    func testInitialSyncWindowUsesNinetyDaysBounded() {
        let days = HealthSummarySyncPolicy.resolvedSyncWindowDays(
            requestedDays: 7,
            trigger: .initial,
            hasPriorSuccessfulRemoteSync: false
        )
        XCTAssertEqual(days, min(90, HealthCachePolicy.retentionDays))
    }

    func testDefaultSyncWindowUsesThirtyDays() {
        let days = HealthSummarySyncPolicy.resolvedSyncWindowDays(
            requestedDays: 45,
            trigger: .afterLocalRefresh,
            hasPriorSuccessfulRemoteSync: true
        )
        XCTAssertEqual(days, 30)
    }

    func testConcurrentSyncIsIgnored() async {
        seedDay(makeDate(2026, 7, 3))
        remoteClient.uploadDelayNanoseconds = 200_000_000

        async let first = service.syncRecentHealthSummaries(days: 1)
        async let second = service.syncTodayHealthSummary()
        _ = await (first, second)

        XCTAssertLessThanOrEqual(remoteClient.dailyUploadCallCount, 2)
    }

    func testSyncWeeklyReviewIfAvailableUploadsCachedReview() async {
        guard let weekStart = WeeklyReviewWeekPolicy.latestCompletedWeekStart(
            referenceDate: Date(),
            calendar: calendar
        ), let weekEnd = WeeklyReviewWeekPolicy.weekEndDate(
            forWeekStarting: weekStart,
            calendar: calendar
        ) else {
            XCTFail("Expected completed week boundaries")
            return
        }

        let review = WeeklyHealthReview(
            weekStartDate: weekStart,
            weekEndDate: weekEnd,
            title: "Strong week",
            summary: "Summary",
            stats: .empty,
            wins: ["Consistent workouts"],
            risks: [],
            nextWeekFocus: ["Recovery"],
            confidence: .moderate,
            missingSignals: [],
            generatedAt: Date()
        )
        cache.storeWeeklyReview(review, calendar: calendar)

        await service.syncWeeklyReviewIfAvailable()

        XCTAssertEqual(remoteClient.uploadedWeeklyReviews.count, 1)
        XCTAssertEqual(remoteClient.uploadedMetadata.count, 1)
    }

    func testPayloadComposerMarksMissingSignalsFromPermissions() {
        let availability = HealthDataAvailability(
            isHealthDataAvailable: true,
            permissionStatus: HealthPermissionStatus(
                isHealthDataAvailable: true,
                signalAccess: [
                    .stepCount: .available,
                    .activeEnergyBurned: .denied,
                    .appleExerciseTime: .available,
                    .workout: .available,
                    .restingHeartRate: .available,
                    .heartRateVariabilitySDNN: .available,
                    .sleepAnalysis: .available,
                    .bodyMass: .available
                ],
                resolvedAt: Date()
            ),
            cachedDayCount: 1
        )

        let missing = HealthSummarySyncPayloadComposer.missingDailySignals(from: availability)
        XCTAssertEqual(missing, [.activeEnergy])
    }

    func testProductionRemoteSyncFlagDefaultsOff() {
        let snapshot = HealthIntelligenceFeatureFlags.snapshot()
        XCTAssertFalse(snapshot.healthSummaryRemoteSyncEnabled)
    }

    // MARK: - Helpers

    private func seedDay(
        _ day: Date,
        steps: Int = 1000,
        workouts: [NormalizedWorkout] = []
    ) {
        let bundle = HealthNormalizedDayBundle(
            dailyMetrics: DailyHealthMetrics(
                date: day,
                steps: steps,
                activeEnergyKcal: 100,
                exerciseMinutes: 10
            ),
            workouts: workouts,
            sleepRecords: [],
            heartMetrics: [],
            bodyMassRecords: []
        )
        cache.store(
            HealthCacheEntry(date: day, bundle: bundle, cachedAt: Date()),
            calendar: calendar
        )
    }

    private func makeWorkout(on day: Date) -> NormalizedWorkout {
        let start = calendar.date(bySettingHour: 8, minute: 0, second: 0, of: day)!
        let end = calendar.date(byAdding: .minute, value: 45, to: start)!
        return NormalizedWorkout(
            id: HealthStableIdentifier.workoutID(
                sourceName: "Apple Watch",
                startDate: start,
                endDate: end,
                durationMinutes: 45,
                category: .running
            ),
            category: .running,
            activityLabel: "Running",
            startDate: start,
            endDate: end,
            durationMinutes: 45,
            activeEnergyKcal: 300,
            sourceName: "Apple Watch"
        )
    }

    private func makeDate(_ year: Int, _ month: Int, _ day: Int) -> Date {
        calendar.date(from: DateComponents(year: year, month: month, day: day))!
    }
}

private final class SummarySyncMockRepository: HealthDataRepositorying, @unchecked Sendable {
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
