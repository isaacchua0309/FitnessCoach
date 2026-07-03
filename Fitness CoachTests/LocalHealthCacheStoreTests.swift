//
//  LocalHealthCacheStoreTests.swift
//  Fitness CoachTests
//

import XCTest
@testable import Fitness_Coach

final class LocalHealthCacheStoreTests: XCTestCase {

    private var calendar: Calendar!
    private var tempDirectory: URL!
    private var cache: LocalHealthCacheStore!

    override func setUp() {
        super.setUp()
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(secondsFromGMT: 0) ?? .gmt
        self.calendar = calendar

        tempDirectory = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString, isDirectory: true)
        try? FileManager.default.createDirectory(at: tempDirectory, withIntermediateDirectories: true)

        cache = LocalHealthCacheStore(
            userProvider: StaticHealthCacheUserProvider(userID: "test-user"),
            rootDirectory: tempDirectory
        )
    }

    override func tearDown() {
        try? FileManager.default.removeItem(at: tempDirectory)
        super.tearDown()
    }

    func testSaveAndReadDailyMetricsRoundTrip() {
        let day = makeDate(2026, 7, 3)
        let metrics = DailyHealthMetrics(
            date: day,
            steps: 11_234,
            activeEnergyKcal: 480,
            exerciseMinutes: 38
        )
        let bundle = HealthNormalizedDayBundle(
            dailyMetrics: metrics,
            workouts: [],
            sleepRecords: [],
            heartMetrics: [],
            bodyMassRecords: []
        )

        cache.store(
            HealthCacheEntry(date: day, bundle: bundle, cachedAt: Date()),
            calendar: calendar
        )

        XCTAssertEqual(cache.dailyMetrics(for: day, calendar: calendar)?.steps, 11_234)
        XCTAssertEqual(cache.dailyMetrics(for: day, calendar: calendar)?.activeEnergyKcal, 480)
    }

    func testCorruptedDayFileReturnsNilWithoutCrashing() throws {
        let day = makeDate(2026, 7, 3)
        let userDirectory = tempDirectory.appendingPathComponent("test-user", isDirectory: true)
        let daysDirectory = userDirectory.appendingPathComponent("days", isDirectory: true)
        try FileManager.default.createDirectory(at: daysDirectory, withIntermediateDirectories: true)

        let formatter = DateFormatter()
        formatter.calendar = calendar
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.timeZone = calendar.timeZone
        formatter.dateFormat = "yyyy-MM-dd"
        let key = formatter.string(from: day)
        let corruptURL = daysDirectory.appendingPathComponent("\(key).json")
        try Data("{ not valid json".utf8).write(to: corruptURL)

        let reloaded = LocalHealthCacheStore(
            userProvider: StaticHealthCacheUserProvider(userID: "test-user"),
            rootDirectory: tempDirectory
        )

        XCTAssertNil(reloaded.entry(for: day, calendar: calendar))
        XCTAssertNil(reloaded.dailyMetrics(for: day, calendar: calendar))
    }

    func testStoreAndReloadDayBundleFromDisk() {
        let day = makeDate(2026, 7, 3)
        let bundle = HealthNormalizedDayBundle(
            dailyMetrics: DailyHealthMetrics(date: day, steps: 9_000, activeEnergyKcal: 450, exerciseMinutes: 40),
            workouts: [makeWorkout(on: makeDate(2026, 7, 3, hour: 8))],
            sleepRecords: [],
            heartMetrics: [],
            bodyMassRecords: []
        )

        cache.store(
            HealthCacheEntry(date: day, bundle: bundle, cachedAt: Date()),
            calendar: calendar
        )

        let reloadedCache = LocalHealthCacheStore(
            userProvider: StaticHealthCacheUserProvider(userID: "test-user"),
            rootDirectory: tempDirectory
        )

        let entry = reloadedCache.entry(for: day, calendar: calendar)
        XCTAssertEqual(entry?.bundle.dailyMetrics.steps, 9_000)
        XCTAssertEqual(entry?.bundle.workouts.count, 1)
    }

    func testWorkoutsAreDeduplicatedByStableID() {
        let workout = makeWorkout(on: makeDate(2026, 7, 3, hour: 8))
        cache.upsertWorkouts([workout], calendar: calendar)
        cache.upsertWorkouts([workout], calendar: calendar)

        let workouts = cache.workouts(
            from: makeDate(2026, 7, 1),
            to: makeDate(2026, 7, 5),
            calendar: calendar
        )

        XCTAssertEqual(workouts.count, 1)
    }

    func testUserScopedDirectoriesAreIsolated() {
        let day = makeDate(2026, 7, 3)
        let bundle = HealthNormalizedDayBundle(
            dailyMetrics: .empty(for: day),
            workouts: [],
            sleepRecords: [],
            heartMetrics: [],
            bodyMassRecords: []
        )

        cache.store(
            HealthCacheEntry(date: day, bundle: bundle, cachedAt: Date()),
            calendar: calendar
        )

        let otherUserCache = LocalHealthCacheStore(
            userProvider: StaticHealthCacheUserProvider(userID: "other-user"),
            rootDirectory: tempDirectory
        )

        XCTAssertNil(otherUserCache.entry(for: day, calendar: calendar))
        XCTAssertEqual(cache.cachedDayCount(calendar: calendar), 1)
    }

    func testRecoveryAndSnapshotPlaceholdersRoundTrip() {
        let day = makeDate(2026, 7, 3)
        let recovery = RecoverySummary(
            score: 82,
            status: .ready,
            title: "Ready for training",
            explanation: "Recovery signals look supportive for your usual training plan.",
            recommendedTraining: "Your usual training plan looks reasonable today.",
            recommendedNutrition: "Stick with your normal protein and hydration rhythm.",
            confidence: .high,
            contributingFactors: [],
            missingSignals: []
        )
        cache.storeRecoverySummary(recovery, for: day, calendar: calendar)

        let reloaded = LocalHealthCacheStore(
            userProvider: StaticHealthCacheUserProvider(userID: "test-user"),
            rootDirectory: tempDirectory
        )

        XCTAssertEqual(reloaded.recoverySummary(for: day, calendar: calendar), recovery)

        let snapshot = HealthIntelligenceSnapshot.placeholder(for: day)
        cache.storeIntelligenceSnapshot(snapshot, for: day, calendar: calendar)

        XCTAssertEqual(
            reloaded.intelligenceSnapshot(for: day, calendar: calendar)?.date,
            day
        )
    }

    func testPruneRemovesOldDayFiles() {
        let oldDay = makeDate(2026, 1, 1)
        let recentDay = makeDate(2026, 7, 3)
        let emptyBundle = HealthNormalizedDayBundle(
            dailyMetrics: .empty(for: oldDay),
            workouts: [],
            sleepRecords: [],
            heartMetrics: [],
            bodyMassRecords: []
        )

        cache.store(
            HealthCacheEntry(date: oldDay, bundle: emptyBundle, cachedAt: Date()),
            calendar: calendar
        )
        cache.store(
            HealthCacheEntry(date: recentDay, bundle: emptyBundle, cachedAt: Date()),
            calendar: calendar
        )

        cache.pruneOldEntries(keepingLastDays: 30, calendar: calendar)

        XCTAssertNil(cache.entry(for: oldDay, calendar: calendar))
        XCTAssertNotNil(cache.entry(for: recentDay, calendar: calendar))
    }

    // MARK: - Helpers

    private func makeDate(
        _ year: Int,
        _ month: Int,
        _ day: Int,
        hour: Int = 0
    ) -> Date {
        calendar.date(from: DateComponents(year: year, month: month, day: day, hour: hour))!
    }

    private func makeWorkout(on start: Date) -> WorkoutRecord {
        WorkoutRecord(
            id: UUID(),
            category: .running,
            activityLabel: "Running",
            startDate: start,
            endDate: calendar.date(byAdding: .hour, value: 1, to: start) ?? start,
            durationMinutes: 60,
            activeEnergyKcal: 400,
            sourceName: "Apple Watch"
        )
    }
}
