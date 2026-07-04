//
//  HealthSummaryRemoteSyncTests.swift
//  Fitness CoachTests
//
//  Comprehensive Health Summary Remote Sync tests (mocks/fakes only).
//

import Foundation
import XCTest
@testable import Fitness_Coach

final class HealthSummaryRemoteSyncTests: XCTestCase {

    private var calendar: Calendar!
    private var cache: MemoryHealthCacheStore!
    private var remoteClient: MockHealthSummaryRemoteSyncClient!
    private var stateStore: LockedHealthSummaryRemoteSyncStateStore!
    private var repository: SummarySyncMockRepository!
    private var service: HealthSummarySyncService!
    private var context: HealthSummarySyncMappingContext!

    override func setUp() {
        super.setUp()
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(secondsFromGMT: 0)!
        self.calendar = calendar
        self.cache = MemoryHealthCacheStore()
        self.remoteClient = MockHealthSummaryRemoteSyncClient()
        self.stateStore = LockedHealthSummaryRemoteSyncStateStore()
        self.repository = SummarySyncMockRepository()
        self.context = HealthSummaryRemoteSyncTestSupport.makeMappingContext(calendar: calendar)
        self.service = makeService(remoteSyncEnabled: { true })
    }

    override func tearDown() {
        remoteClient.reset()
        HealthIntelligenceFeatureFlags.testOverride = nil
        super.tearDown()
    }

    // MARK: - 1. Payload encode/decode

    func testPayloadModelsEncodeAndDecodeCorrectly() throws {
        let day = makeDate(2026, 7, 3)
        let workout = HealthSummaryRemoteSyncTestSupport.makeWorkout(on: day, calendar: calendar)
        let metrics = DailyHealthMetrics(date: day, steps: 1000, activeEnergyKcal: 100, exerciseMinutes: 10)

        let daily = HealthDailySummarySyncPayload.make(from: metrics, dayWorkouts: [workout], context: context)
        let workoutPayload = HealthWorkoutSummarySyncPayload.make(from: workout, context: context)
        let recovery = RecoverySummarySyncPayload.make(
            from: .unknown,
            date: day,
            context: context
        )

        guard let weekStart = WeeklyReviewWeekPolicy.latestCompletedWeekStart(
            referenceDate: day,
            calendar: calendar
        ), let weekEnd = WeeklyReviewWeekPolicy.weekEndDate(forWeekStarting: weekStart, calendar: calendar) else {
            XCTFail("Expected week boundaries")
            return
        }
        let weekly = WeeklyHealthReviewSyncPayload.make(
            from: WeeklyHealthReview(
                weekStartDate: weekStart,
                weekEndDate: weekEnd,
                title: "Week",
                summary: "Summary",
                stats: .empty,
                wins: ["Win"],
                risks: [],
                nextWeekFocus: ["Focus"],
                confidence: .moderate,
                missingSignals: [],
                generatedAt: context.generatedAt
            ),
            context: context
        )

        let permission = HealthPermissionStatus.uniform(.available, isHealthDataAvailable: true)
        let metadata = HealthSyncMetadataPayload.make(
            from: .idle,
            permissionStatus: permission,
            cachedDayCount: 1,
            context: context
        )

        XCTAssertEqual(try HealthSummaryRemoteSyncTestSupport.roundTrip(daily), daily)
        XCTAssertEqual(try HealthSummaryRemoteSyncTestSupport.roundTrip(workoutPayload), workoutPayload)
        XCTAssertEqual(try HealthSummaryRemoteSyncTestSupport.roundTrip(recovery), recovery)
        XCTAssertNotNil(weekly)
        XCTAssertEqual(try HealthSummaryRemoteSyncTestSupport.roundTrip(weekly!), weekly!)
        XCTAssertEqual(try HealthSummaryRemoteSyncTestSupport.roundTrip(metadata), metadata)
    }

    // MARK: - 2. Daily document id stability

    func testDailySummaryDocumentIDIsStable() {
        let day = makeDate(2026, 7, 3)
        let metrics = DailyHealthMetrics(date: day, steps: 100, activeEnergyKcal: 10, exerciseMinutes: 5)

        let first = HealthDailySummarySyncPayload.make(from: metrics, dayWorkouts: [], context: context)
        let second = HealthDailySummarySyncPayload.make(from: metrics, dayWorkouts: [], context: context)

        XCTAssertEqual(first.id, "2026-07-03")
        XCTAssertEqual(first.id, second.id)
        XCTAssertEqual(
            first.id,
            HealthSummarySyncDocumentID.daily(localDate: day, calendar: calendar)
        )
    }

    // MARK: - 3. Workout document id stability

    func testWorkoutSummaryDocumentIDIsStable() {
        let day = makeDate(2026, 7, 3)
        let workout = HealthSummaryRemoteSyncTestSupport.makeWorkout(on: day, calendar: calendar)

        let first = HealthWorkoutSummarySyncPayload.make(from: workout, context: context)
        let second = HealthWorkoutSummarySyncPayload.make(from: workout, context: context)

        XCTAssertEqual(first.id, second.id)
        XCTAssertEqual(first.id, workout.id.uuidString.lowercased())
        XCTAssertEqual(first.id, HealthSummarySyncDocumentID.workout(from: workout))
    }

    // MARK: - 4. No raw HealthKit samples in payloads

    func testPayloadsExcludeRawHealthKitSampleFields() throws {
        let day = makeDate(2026, 7, 3)
        let workout = HealthSummaryRemoteSyncTestSupport.makeWorkout(on: day, calendar: calendar)
        let metrics = DailyHealthMetrics(date: day, steps: 1000, activeEnergyKcal: 100, exerciseMinutes: 10)

        let payloads: [Encodable] = [
            HealthDailySummarySyncPayload.make(from: metrics, dayWorkouts: [workout], context: context),
            HealthWorkoutSummarySyncPayload.make(from: workout, context: context),
            RecoverySummarySyncPayload.make(from: .unknown, date: day, context: context),
            HealthSyncMetadataPayload.make(
                from: .idle,
                permissionStatus: .uniform(.available, isHealthDataAvailable: true),
                cachedDayCount: 1,
                context: context
            )
        ]

        for payload in payloads {
            let json = try HealthSummaryRemoteSyncTestSupport.encodeJSON(payload)
            HealthSummaryRemoteSyncTestSupport.assertNoForbiddenPayloadKeys(in: json)
        }
    }

    // MARK: - 5. Concurrent sync prevention

    func testSyncServicePreventsConcurrentSync() async {
        seedSingleDay()
        remoteClient.uploadDelayNanoseconds = 300_000_000

        async let first = service.syncRecentHealthSummaries(days: 1)
        async let second = service.syncTodayHealthSummary()
        _ = await (first, second)

        XCTAssertEqual(remoteClient.dailyUploadCallCount, 1)
    }

    // MARK: - 6. Uploads all payload types

    func testSyncServiceUploadsDailyWorkoutRecoveryAndWeeklyPayloads() async {
        let day = calendar.startOfDay(for: Date())
        let workout = HealthSummaryRemoteSyncTestSupport.makeWorkout(on: day, calendar: calendar)
        HealthSummaryRemoteSyncTestSupport.seedDay(
            day,
            in: cache,
            calendar: calendar,
            steps: 9000,
            workouts: [workout]
        )
        cache.storeRecoverySummary(.unknown, for: day, calendar: calendar)

        guard let weekStart = WeeklyReviewWeekPolicy.latestCompletedWeekStart(
            referenceDate: day,
            calendar: calendar
        ), let weekEnd = WeeklyReviewWeekPolicy.weekEndDate(forWeekStarting: weekStart, calendar: calendar) else {
            XCTFail("Expected week boundaries")
            return
        }
        cache.storeWeeklyReview(
            WeeklyHealthReview(
                weekStartDate: weekStart,
                weekEndDate: weekEnd,
                title: "Week",
                summary: "Summary",
                stats: .empty,
                wins: ["Win"],
                risks: [],
                nextWeekFocus: ["Focus"],
                confidence: .moderate,
                missingSignals: [],
                generatedAt: Date()
            ),
            calendar: calendar
        )

        await service.syncRecentHealthSummaries(days: 1)
        await service.syncWeeklyReviewIfAvailable()

        XCTAssertEqual(remoteClient.uploadedDailySummaries.count, 1)
        XCTAssertEqual(remoteClient.uploadedWorkoutSummaries.count, 1)
        XCTAssertEqual(remoteClient.uploadedRecoverySummaries.count, 1)
        XCTAssertEqual(remoteClient.uploadedWeeklyReviews.count, 1)
    }

    // MARK: - 7. Partial failure preserves successful sections

    func testPartialUploadFailurePreservesSuccessfulSections() async {
        seedSingleDay(withWorkout: true)
        cache.storeRecoverySummary(.unknown, for: calendar.startOfDay(for: Date()), calendar: calendar)
        remoteClient.uploadDailyError = .uploadFailed(collection: "daily", reason: "transient")

        await service.syncRecentHealthSummaries(days: 1)

        XCTAssertTrue(remoteClient.uploadedDailySummaries.isEmpty)
        XCTAssertEqual(remoteClient.uploadedWorkoutSummaries.count, 1)
        XCTAssertEqual(remoteClient.uploadedRecoverySummaries.count, 1)

        let state = await service.getRemoteSyncState()
        XCTAssertEqual(state.phase, .partialSuccess)
        XCTAssertEqual(state.failedPayloadKinds, [.daily])
    }

    // MARK: - 8. Unauthenticated error handling

    func testUnauthenticatedRemoteClientErrorIsHandled() async {
        let unauthenticatedService = makeService(
            userID: nil,
            remoteSyncEnabled: { true }
        )
        seedSingleDay()

        await unauthenticatedService.syncRecentHealthSummaries(days: 1)

        XCTAssertTrue(remoteClient.uploadedDailySummaries.isEmpty)
        let state = await unauthenticatedService.getRemoteSyncState()
        XCTAssertEqual(state.lastError, HealthSummarySyncError.notAuthenticated)
    }

    func testFirestoreClientSurfacesNotAuthenticatedWithoutFirebase() async {
        let client = FirestoreHealthSummaryRemoteSyncClient(
            userProvider: StaticHealthCacheUserProvider(userID: nil)
        )
        let day = makeDate(2026, 7, 3)
        let metrics = DailyHealthMetrics(date: day, steps: 100, activeEnergyKcal: 10, exerciseMinutes: 5)
        let payload = HealthDailySummarySyncPayload.make(from: metrics, dayWorkouts: [], context: context)

        do {
            try await client.uploadDailySummaries([payload])
            XCTFail("Expected notAuthenticated")
        } catch let error as HealthSummarySyncError {
            XCTAssertEqual(error, .notAuthenticated)
        } catch {
            XCTFail("Unexpected error: \(error)")
        }
    }

    // MARK: - 9. Feature flag disabled uses noop client

    func testFeatureFlagDisabledUsesNoopClient() {
        HealthIntelligenceFeatureFlags.testOverride = TestHealthIntelligenceFeatureFlags(
            healthSummaryRemoteSyncEnabled: false
        )

        let client = HealthSummaryRemoteSyncTestSupport.makeRemoteSyncClient(
            inMemory: false,
            userProvider: StaticHealthCacheUserProvider(userID: "user-123")
        )

        XCTAssertTrue(client is NoopHealthSummaryRemoteSyncClient)
    }

    // MARK: - 10. Metadata only after successful uploads

    func testSyncMetadataUpdatesOnlyAfterSuccessfulUploads() async {
        seedSingleDay(withWorkout: true)
        remoteClient.uploadDailyError = .uploadFailed(collection: "daily", reason: "fail")
        remoteClient.uploadWorkoutError = .uploadFailed(collection: "workouts", reason: "fail")
        remoteClient.uploadRecoveryError = .uploadFailed(collection: "recovery", reason: "fail")

        await service.syncRecentHealthSummaries(days: 1)

        XCTAssertEqual(remoteClient.metadataUploadCallCount, 0)
        XCTAssertTrue(remoteClient.uploadedMetadata.isEmpty)
        XCTAssertNil(stateStore.load(for: "user-123").lastSuccessfulRemoteSyncAt)

        remoteClient.reset()
        remoteClient.uploadDailyError = nil
        remoteClient.uploadWorkoutError = nil
        remoteClient.uploadRecoveryError = nil
        seedSingleDay(withWorkout: true)

        await service.syncRecentHealthSummaries(days: 1)

        XCTAssertEqual(remoteClient.metadataUploadCallCount, 1)
        XCTAssertEqual(remoteClient.uploadedMetadata.count, 1)
        XCTAssertNotNil(stateStore.load(for: "user-123").lastSuccessfulRemoteSyncAt)
    }

    // MARK: - 11. Retry guard / backoff

    func testRetryGuardPreventsExcessiveRepeatedSyncAttempts() async {
        stateStore.save(
            HealthSummaryRemoteSyncPersistedState(
                lastSuccessfulRemoteSyncAt: Date(),
                lastAttemptedRemoteSyncAt: Date(),
                consecutiveFailures: 2,
                backoffUntil: Date().addingTimeInterval(3600)
            ),
            for: "user-123"
        )
        seedSingleDay()

        await service.syncAfterLocalHealthRefresh(days: 1)
        await service.syncTodayHealthSummary()

        XCTAssertEqual(remoteClient.dailyUploadCallCount, 0)

        await service.syncRecentHealthSummaries(days: 1)
        XCTAssertEqual(remoteClient.dailyUploadCallCount, 1)
    }

    // MARK: - 12. 30-day default sync window

    func testThirtyDayDefaultSyncWindowIsRespected() async {
        stateStore.save(
            HealthSummaryRemoteSyncPersistedState(
                lastSuccessfulRemoteSyncAt: Date(),
                lastAttemptedRemoteSyncAt: Date(),
                consecutiveFailures: 0,
                backoffUntil: nil
            ),
            for: "user-123"
        )

        let endDay = calendar.startOfDay(for: Date())
        _ = HealthSummaryRemoteSyncTestSupport.seedConsecutiveDays(
            count: 40,
            endingOn: endDay,
            in: cache,
            calendar: calendar
        )

        await service.syncAfterLocalHealthRefresh(days: 40)

        XCTAssertEqual(remoteClient.uploadedDailySummaries.count, 30)
    }

    // MARK: - 13. 90-day initial sync bounded

    func testNinetyDayInitialSyncIsBounded() async {
        let endDay = calendar.startOfDay(for: Date())
        let seededDays = HealthSummaryRemoteSyncTestSupport.seedConsecutiveDays(
            count: 95,
            endingOn: endDay,
            in: cache,
            calendar: calendar
        )
        XCTAssertEqual(seededDays.count, 95)

        await service.syncRecentHealthSummaries(days: 5)

        XCTAssertEqual(
            remoteClient.uploadedDailySummaries.count,
            min(HealthSummarySyncPolicy.initialSyncWindowDays, HealthCachePolicy.retentionDays)
        )
    }

    // MARK: - Helpers

    private func makeService(
        userID: String? = "user-123",
        remoteSyncEnabled: @escaping @Sendable () -> Bool = { true }
    ) -> HealthSummarySyncService {
        HealthSummarySyncService(
            remoteSyncClient: remoteClient,
            cacheStore: cache,
            repository: repository,
            userProvider: StaticHealthCacheUserProvider(userID: userID),
            stateStore: stateStore,
            calendar: calendar,
            foregroundMinimumInterval: 0,
            remoteSyncEnabled: remoteSyncEnabled
        )
    }

    private func seedSingleDay(withWorkout: Bool = false) {
        let day = calendar.startOfDay(for: Date())
        let workouts = withWorkout
            ? [HealthSummaryRemoteSyncTestSupport.makeWorkout(on: day, calendar: calendar)]
            : []
        HealthSummaryRemoteSyncTestSupport.seedDay(
            day,
            in: cache,
            calendar: calendar,
            workouts: workouts
        )
    }

    private func makeDate(_ year: Int, _ month: Int, _ day: Int) -> Date {
        calendar.date(from: DateComponents(year: year, month: month, day: day))!
    }
}
