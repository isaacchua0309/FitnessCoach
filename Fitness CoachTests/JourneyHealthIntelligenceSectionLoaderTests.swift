//
//  JourneyHealthIntelligenceSectionLoaderTests.swift
//  Fitness CoachTests
//

import XCTest
@testable import Fitness_Coach

final class JourneyHealthIntelligenceSectionLoaderTests: XCTestCase {

    private var calendar: Calendar {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(secondsFromGMT: 0) ?? .gmt
        return calendar
    }

    private var referenceDay: Date {
        calendar.startOfDay(
            for: calendar.date(from: DateComponents(year: 2026, month: 7, day: 3))!
        )
    }

    func testLoadInputBuildsRecoveryDaysFromTodaySnapshot() async {
        let snapshot = makeSnapshot(on: referenceDay, score: 72)
        let snapshotProvider = LoaderMockSnapshotService(snapshot: snapshot)
        let cacheStore = MemoryHealthCacheStore()

        let input = await JourneyHealthIntelligenceSectionLoader.loadInput(
            referenceDate: referenceDay,
            isAppleHealthConnected: true,
            snapshotProvider: snapshotProvider,
            cacheStore: cacheStore,
            healthActivityQuery: makeActivityQuery(workouts: []),
            healthDataRepository: LoaderMockRepository(connected: true),
            enginesEnabled: false,
            calendar: calendar
        )

        XCTAssertEqual(input.healthConnection, .connected)
        XCTAssertEqual(input.recoveryDays.count, 1)
        XCTAssertEqual(input.recoveryDays.first?.recovery.score, 72)
        XCTAssertEqual(input.todaySnapshot?.date, referenceDay)
    }

    func testLoadInputUsesHealthActivityQueryWorkouts() async {
        let workoutDay = referenceDay
        let workout = HealthWorkoutRecord(
            id: UUID(),
            activityName: "Strength training",
            startDate: workoutDay,
            endDate: workoutDay.addingTimeInterval(3_000),
            durationMinutes: 45,
            activeCalories: 320
        )
        let snapshot = makeSnapshot(on: referenceDay, score: 70)

        let input = await JourneyHealthIntelligenceSectionLoader.loadInput(
            referenceDate: referenceDay,
            isAppleHealthConnected: true,
            snapshotProvider: LoaderMockSnapshotService(snapshot: snapshot),
            cacheStore: MemoryHealthCacheStore(),
            healthActivityQuery: makeActivityQuery(workouts: [workout]),
            healthDataRepository: LoaderMockRepository(connected: true),
            enginesEnabled: false,
            calendar: calendar
        )

        XCTAssertEqual(input.workoutRecords.count, 1)
        XCTAssertEqual(input.workoutRecords.first?.title, "Strength training")
        XCTAssertEqual(input.workoutRecords.first?.durationMinutes, 45)
    }

    func testDeniedPermissionsReturnNotConnectedInput() async {
        let input = await JourneyHealthIntelligenceSectionLoader.loadInput(
            referenceDate: referenceDay,
            isAppleHealthConnected: false,
            snapshotProvider: LoaderMockSnapshotService(snapshot: nil),
            cacheStore: MemoryHealthCacheStore(),
            healthActivityQuery: makeActivityQuery(workouts: []),
            healthDataRepository: LoaderMockRepository(connected: false),
            enginesEnabled: false,
            calendar: calendar
        )

        XCTAssertEqual(input.healthConnection, .notConnected)
        XCTAssertTrue(input.recoveryDays.isEmpty)
        XCTAssertTrue(input.workoutRecords.isEmpty)
    }

    func testCachedHistoricalSnapshotsFillRecoveryTimeline() async {
        let snapshotProvider = LoaderMockSnapshotService(snapshot: makeSnapshot(on: referenceDay, score: 80))
        let cacheStore = MemoryHealthCacheStore()
        let yesterday = calendar.date(byAdding: .day, value: -1, to: referenceDay)!
        cacheStore.storeIntelligenceSnapshot(
            makeSnapshot(on: yesterday, score: 65),
            for: yesterday,
            calendar: calendar
        )

        let input = await JourneyHealthIntelligenceSectionLoader.loadInput(
            referenceDate: referenceDay,
            isAppleHealthConnected: true,
            snapshotProvider: snapshotProvider,
            cacheStore: cacheStore,
            healthActivityQuery: makeActivityQuery(workouts: []),
            healthDataRepository: LoaderMockRepository(connected: true),
            enginesEnabled: false,
            recoveryTimelineDayCount: 7,
            calendar: calendar
        )

        XCTAssertEqual(input.recoveryDays.count, 2)
        XCTAssertTrue(input.recoveryDays.contains { $0.recovery.score == 65 })
        XCTAssertTrue(input.recoveryDays.contains { $0.recovery.score == 80 })
    }

    func testLoadInputSkipsWeeklyReviewWhenFlagDisabled() async {
        let weeklyReviewService = LoaderMockWeeklyReviewService()
        weeklyReviewService.latestReview = makeWeeklyReview()

        let input = await JourneyHealthIntelligenceSectionLoader.loadInput(
            referenceDate: referenceDay,
            isAppleHealthConnected: true,
            snapshotProvider: LoaderMockSnapshotService(snapshot: makeSnapshot(on: referenceDay, score: 72)),
            weeklyReviewProvider: weeklyReviewService,
            cacheStore: MemoryHealthCacheStore(),
            healthActivityQuery: makeActivityQuery(workouts: []),
            healthDataRepository: LoaderMockRepository(connected: true),
            weeklyReviewEnabled: false,
            calendar: calendar
        )

        XCTAssertNil(input.weeklyReview)
        XCTAssertEqual(weeklyReviewService.getLatestCallCount, 0)
    }

    func testLoadInputUsesWeeklyReviewServiceWithoutForceRefresh() async {
        let weeklyReviewService = LoaderMockWeeklyReviewService()
        weeklyReviewService.latestReview = makeWeeklyReview()

        let input = await JourneyHealthIntelligenceSectionLoader.loadInput(
            referenceDate: referenceDay,
            isAppleHealthConnected: true,
            snapshotProvider: LoaderMockSnapshotService(snapshot: nil),
            weeklyReviewProvider: weeklyReviewService,
            cacheStore: MemoryHealthCacheStore(),
            healthActivityQuery: makeActivityQuery(workouts: []),
            healthDataRepository: LoaderMockRepository(connected: true),
            forceWeeklyReviewRefresh: false,
            enginesEnabled: false,
            weeklyReviewEnabled: true,
            calendar: calendar
        )

        XCTAssertEqual(weeklyReviewService.getLatestCallCount, 1)
        XCTAssertEqual(weeklyReviewService.generateCallCount, 0)
        XCTAssertEqual(input.weeklyReview?.title, "Solid training week")
    }

    func testLoadInputForceRefreshUsesGenerateWeeklyReview() async {
        let weeklyReviewService = LoaderMockWeeklyReviewService()
        weeklyReviewService.latestReview = makeWeeklyReview()

        _ = await JourneyHealthIntelligenceSectionLoader.loadInput(
            referenceDate: referenceDay,
            isAppleHealthConnected: true,
            snapshotProvider: LoaderMockSnapshotService(snapshot: nil),
            weeklyReviewProvider: weeklyReviewService,
            cacheStore: MemoryHealthCacheStore(),
            healthActivityQuery: makeActivityQuery(workouts: []),
            healthDataRepository: LoaderMockRepository(connected: true),
            forceWeeklyReviewRefresh: true,
            enginesEnabled: false,
            weeklyReviewEnabled: true,
            calendar: calendar
        )

        XCTAssertEqual(weeklyReviewService.generateCallCount, 1)
        XCTAssertTrue(weeklyReviewService.lastForceRefresh)
    }

    // MARK: - Helpers

    private func makeWeeklyReview() -> WeeklyHealthReview {
        let weekEnd = referenceDay
        let weekStart = calendar.date(byAdding: .day, value: -6, to: weekEnd) ?? weekEnd
        return WeeklyHealthReview(
            weekStartDate: weekStart,
            weekEndDate: weekEnd,
            title: "Solid training week",
            summary: "Summary",
            stats: .empty,
            wins: [],
            risks: [],
            nextWeekFocus: [],
            confidence: .moderate,
            missingSignals: [],
            generatedAt: weekEnd
        )
    }

    private func makeSnapshot(on day: Date, score: Int) -> HealthIntelligenceSnapshot {
        HealthIntelligenceSnapshot(
            date: day,
            recovery: RecoverySummary(
                score: score,
                status: .moderate,
                title: "Moderate recovery",
                explanation: "Recovery is acceptable.",
                recommendedTraining: "Train based on how you feel.",
                recommendedNutrition: "Stay on your usual plan.",
                confidence: .moderate,
                contributingFactors: [],
                missingSignals: []
            ),
            workout: nil,
            activity: ActivitySummary(steps: 8_000, activeEnergyKcal: 400, exerciseMinutes: 30),
            nutritionAdjustment: .none,
            weeklyReview: nil,
            planConfidence: PlanHealthConfidence(score: 0.7, label: "Moderate"),
            nextBestAction: .none
        )
    }

    private func makeActivityQuery(workouts: [HealthWorkoutRecord]) -> HealthActivityQueryService {
        HealthActivityQueryService(
            workoutReader: MockHealthKitWorkoutReader(workouts: workouts),
            stepReader: MockHealthKitStepReader(stepCount: 0),
            repositoryReadRoutingEnabled: false
        )
    }
}

// MARK: - Loader mocks

private final class LoaderMockSnapshotService: HealthIntelligenceSnapshotServing, @unchecked Sendable {
    let snapshot: HealthIntelligenceSnapshot?

    init(snapshot: HealthIntelligenceSnapshot?) {
        self.snapshot = snapshot
    }

    func refreshTodaySnapshot(calendar: Calendar) async {}

    func loadTodaySnapshot(for date: Date, calendar: Calendar) async -> HealthIntelligenceSnapshot? {
        snapshot
    }
}

private final class LoaderMockRepository: HealthDataRepositorying, @unchecked Sendable {
    let connected: Bool

    init(connected: Bool) {
        self.connected = connected
    }

    func normalizedSamples(for date: Date, calendar: Calendar) async throws -> [HealthNormalizedSample] { [] }

    func getDailyMetrics(for date: Date, calendar: Calendar) async -> DailyHealthMetrics {
        .empty(for: date)
    }

    func getDailyMetrics(from startDate: Date, to endDate: Date, calendar: Calendar) async -> [DailyHealthMetrics] {
        []
    }

    func getRecentWorkouts(days: Int, calendar: Calendar) async -> [NormalizedWorkout] { [] }

    func getWorkouts(from startDate: Date, to endDate: Date, calendar: Calendar) async -> [NormalizedWorkout] { [] }

    func getRecentSleep(days: Int, calendar: Calendar) async -> [NormalizedSleepRecord] { [] }

    func getSleepRecords(from startDate: Date, to endDate: Date, calendar: Calendar) async -> [NormalizedSleepRecord] {
        []
    }

    func getRecentHeartMetrics(days: Int, calendar: Calendar) async -> [NormalizedHeartMetric] { [] }

    func getHeartMetrics(from startDate: Date, to endDate: Date, calendar: Calendar) async -> [NormalizedHeartMetric] {
        []
    }

    func getBodyMassHistory(days: Int, calendar: Calendar) async -> [NormalizedBodyMass] { [] }

    func getHealthDataAvailability() async -> HealthDataAvailability {
        HealthDataAvailability(
            isHealthDataAvailable: connected,
            permissionStatus: connected
                ? .uniform(.available, isHealthDataAvailable: true)
                : .uniform(.denied, isHealthDataAvailable: true),
            cachedDayCount: connected ? 1 : 0
        )
    }

    func refreshHealthData(days: Int, endingOn date: Date, calendar: Calendar) async -> HealthRefreshResult {
        HealthRefreshResult(daysRefreshed: 0, refreshedAt: Date())
    }
}

private final class LoaderMockWeeklyReviewService: WeeklyReviewServing, @unchecked Sendable {
    var latestReview: WeeklyHealthReview?
    private(set) var getLatestCallCount = 0
    private(set) var generateCallCount = 0
    var lastForceRefresh = false

    func getLatestCompletedWeeklyReview(calendar: Calendar) async -> WeeklyHealthReview? {
        getLatestCallCount += 1
        return latestReview
    }

    func getWeeklyReview(for weekStartDate: Date, calendar: Calendar) async -> WeeklyHealthReview? {
        latestReview
    }

    func generateWeeklyReview(
        for weekStartDate: Date,
        forceRefresh: Bool,
        allowPreview: Bool,
        calendar: Calendar
    ) async -> WeeklyHealthReview? {
        generateCallCount += 1
        lastForceRefresh = forceRefresh
        return latestReview
    }
}
