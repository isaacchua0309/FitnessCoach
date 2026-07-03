//
//  HealthIntelligenceCompositionTests.swift
//  Fitness CoachTests
//

import XCTest
@testable import Fitness_Coach

final class HealthIntelligenceCompositionTests: XCTestCase {

    func testAppContainerRegistersHealthIntelligenceEngines() throws {
        let container = try AppContainer(inMemory: true)

        XCTAssertTrue(container.trainingLoadEngine is TrainingLoadEngine)
        XCTAssertTrue(container.workoutIntelligenceEngine is WorkoutIntelligenceEngine)
        XCTAssertTrue(container.recoveryEngine is RecoveryEngine)
        XCTAssertTrue(container.adaptiveNutritionEngine is AdaptiveNutritionEngine)
        XCTAssertTrue(container.nextBestActionEngine is HealthNextBestActionEngine)
        XCTAssertTrue(container.weeklyReviewEngine is WeeklyReviewEngine)
        XCTAssertTrue(container.healthBaselineService is HealthBaselineService)
        XCTAssertTrue(container.healthIntelligenceContextBuilder is HealthIntelligenceContextBuilder)
        XCTAssertNotNil(container.makeHealthIntelligenceEngine())
    }

    func testSnapshotServiceCachesComposedSnapshot() async {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(secondsFromGMT: 0) ?? .gmt
        let today = calendar.startOfDay(for: Date())

        let repository = CompositionMockRepository(calendar: calendar)
        repository.dailyMetricsByDay[today] = DailyHealthMetrics(
            date: today,
            steps: 5_000,
            activeEnergyKcal: 300,
            exerciseMinutes: 30
        )

        let engine = HealthIntelligenceEngine(
            contextBuilder: HealthIntelligenceContextBuilder(repository: repository),
            dependencies: .production()
        )
        let cache = MemoryHealthCacheStore()
        let service = HealthIntelligenceSnapshotService(
            engine: engine,
            cacheStore: cache,
            enginesEnabled: true
        )

        await service.refreshTodaySnapshot(calendar: calendar)

        let cached = cache.intelligenceSnapshot(for: today, calendar: calendar)
        XCTAssertNotNil(cached)
        XCTAssertEqual(cached?.activity.steps, 5_000)
    }

    func testSnapshotServiceNoOpsWhenEnginesDisabled() async {
        let cache = MemoryHealthCacheStore()
        let service = HealthIntelligenceSnapshotService(
            engine: NoOpCompositionEngine(),
            cacheStore: cache,
            enginesEnabled: false
        )

        await service.refreshTodaySnapshot(calendar: .current)

        XCTAssertNil(cache.intelligenceSnapshot(for: Date(), calendar: .current))
    }

    func testUIEnabledRemainsFalseByDefault() {
        XCTAssertFalse(HealthIntelligenceFeatureFlags.isUIEnabled)
    }

    func testTodayModelLoadDisabledByDefaultWhenUIIsOff() {
        XCTAssertFalse(HealthIntelligenceFeatureFlags.shouldTodayModelLoadHealthIntelligence)
    }

    func testLoadTodaySnapshotUsesCacheWithoutRecomposing() async {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(secondsFromGMT: 0) ?? .gmt
        let today = calendar.startOfDay(for: Date())

        let repository = CompositionMockRepository(calendar: calendar)
        repository.dailyMetricsByDay[today] = DailyHealthMetrics(
            date: today,
            steps: 5_000,
            activeEnergyKcal: 300,
            exerciseMinutes: 30
        )

        let engine = SpyCompositionEngine(
            base: HealthIntelligenceEngine(
                contextBuilder: HealthIntelligenceContextBuilder(repository: repository),
                dependencies: .production()
            )
        )
        let cache = MemoryHealthCacheStore()
        let service = HealthIntelligenceSnapshotService(
            engine: engine,
            cacheStore: cache,
            enginesEnabled: true
        )

        let first = await service.loadTodaySnapshot(for: today, calendar: calendar)
        let second = await service.loadTodaySnapshot(for: today, calendar: calendar)

        XCTAssertNotNil(first)
        XCTAssertEqual(first?.activity.steps, 5_000)
        XCTAssertEqual(second?.activity.steps, 5_000)
        XCTAssertEqual(engine.composeCallCount, 1)
    }
}

// MARK: - Mocks

private struct NoOpCompositionEngine: HealthIntelligenceEngineing {
    func composeSnapshot(
        for date: Date,
        calendar: Calendar,
        mode: HealthIntelligenceComposeMode
    ) async -> HealthIntelligenceSnapshot {
        .placeholder(for: date)
    }

    func generateSnapshot(for date: Date, calendar: Calendar) async throws -> HealthIntelligenceSnapshot {
        await composeSnapshot(for: date, calendar: calendar, mode: .today)
    }
}

private final class SpyCompositionEngine: HealthIntelligenceEngineing, @unchecked Sendable {
    private let base: any HealthIntelligenceEngineing
    private(set) var composeCallCount = 0

    init(base: any HealthIntelligenceEngineing) {
        self.base = base
    }

    func composeSnapshot(
        for date: Date,
        calendar: Calendar,
        mode: HealthIntelligenceComposeMode
    ) async -> HealthIntelligenceSnapshot {
        composeCallCount += 1
        return await base.composeSnapshot(for: date, calendar: calendar, mode: mode)
    }

    func generateSnapshot(for date: Date, calendar: Calendar) async throws -> HealthIntelligenceSnapshot {
        try await base.generateSnapshot(for: date, calendar: calendar)
    }
}

private final class CompositionMockRepository: HealthDataRepositorying, @unchecked Sendable {
    let calendar: Calendar
    var dailyMetricsByDay: [Date: DailyHealthMetrics] = [:]

    init(calendar: Calendar) {
        self.calendar = calendar
    }

    func normalizedSamples(for date: Date, calendar: Calendar) async throws -> [HealthNormalizedSample] { [] }

    func getDailyMetrics(for date: Date, calendar: Calendar) async -> DailyHealthMetrics {
        dailyMetricsByDay[calendar.startOfDay(for: date)] ?? .empty(for: date)
    }

    func getDailyMetrics(from startDate: Date, to endDate: Date, calendar: Calendar) async -> [DailyHealthMetrics] {
        let start = calendar.startOfDay(for: startDate)
        let end = calendar.startOfDay(for: endDate)
        var metrics: [DailyHealthMetrics] = []
        var cursor = start
        while cursor <= end {
            metrics.append(dailyMetricsByDay[cursor] ?? .empty(for: cursor))
            guard let next = calendar.date(byAdding: .day, value: 1, to: cursor) else { break }
            cursor = next
        }
        return metrics
    }

    func getRecentWorkouts(days: Int, calendar: Calendar) async -> [NormalizedWorkout] { [] }
    func getWorkouts(from startDate: Date, to endDate: Date, calendar: Calendar) async -> [NormalizedWorkout] { [] }
    func getRecentSleep(days: Int, calendar: Calendar) async -> [NormalizedSleepRecord] { [] }
    func getSleepRecords(from startDate: Date, to endDate: Date, calendar: Calendar) async -> [NormalizedSleepRecord] { [] }
    func getRecentHeartMetrics(days: Int, calendar: Calendar) async -> [NormalizedHeartMetric] { [] }
    func getHeartMetrics(from startDate: Date, to endDate: Date, calendar: Calendar) async -> [NormalizedHeartMetric] { [] }
    func getBodyMassHistory(days: Int, calendar: Calendar) async -> [NormalizedBodyMass] { [] }

    func getHealthDataAvailability() async -> HealthDataAvailability {
        HealthDataAvailability(
            isHealthDataAvailable: true,
            permissionStatus: .uniform(.available, isHealthDataAvailable: true),
            cachedDayCount: 28
        )
    }

    func refreshHealthData(days: Int, endingOn date: Date, calendar: Calendar) async -> HealthRefreshResult {
        HealthRefreshResult(daysRefreshed: days, refreshedAt: Date())
    }
}
