//
//  AccountDataRemoteStoreIncrementalFetchTests.swift
//  Fitness CoachTests
//
//  Phase 5 — incremental `updatedAt` fetch contract for AccountDataRemoteStore.
//

import XCTest
@testable import Fitness_Coach

final class AccountDataRemoteStoreIncrementalFetchTests: XCTestCase {

    private var store: InMemoryAccountDataRemoteStore!
    private let userA = "user-a"
    private let userB = "user-b"
    private let localDate = "2026-07-04"

    private var t0: Date!
    private var t1: Date!
    private var t2: Date!
    private var t3: Date!

    override func setUp() async throws {
        try await super.setUp()
        store = InMemoryAccountDataRemoteStore()
        t0 = makeDate(year: 2026, month: 7, day: 1, hour: 10)
        t1 = makeDate(year: 2026, month: 7, day: 2, hour: 10)
        t2 = makeDate(year: 2026, month: 7, day: 3, hour: 10)
        t3 = makeDate(year: 2026, month: 7, day: 4, hour: 10)
    }

    override func tearDown() async throws {
        store = nil
        try await super.tearDown()
    }

    func testFetchDailyLogsUpdatedSinceReturnsOnlyNewerDocumentsOrderedByUpdatedAt() async throws {
        var older = FirestoreAccountDataRemoteStoreTestFixtures.dailyLog(
            userId: userA,
            localDate: "2026-07-01",
            referenceDate: t0
        )
        var newer = FirestoreAccountDataRemoteStoreTestFixtures.dailyLog(
            userId: userA,
            localDate: localDate,
            referenceDate: t2
        )
        older.updatedAt = t0
        newer.updatedAt = t2

        try await store.saveDailyLog(older, uid: userA)
        try await store.saveDailyLog(newer, uid: userA)

        let results = try await store.fetchDailyLogsUpdatedSince(uid: userA, since: t1, limit: 50)

        XCTAssertEqual(results.count, 1)
        XCTAssertEqual(results[0].localDate, localDate)
        XCTAssertEqual(results[0].updatedAt, t2)
    }

    func testFetchDailyLogsUpdatedSinceIncludesTombstonedDocuments() async throws {
        var tombstoned = FirestoreAccountDataRemoteStoreTestFixtures.dailyLog(
            userId: userA,
            localDate: localDate,
            referenceDate: t2
        )
        tombstoned.updatedAt = t2
        tombstoned.deletedAt = t2

        try await store.saveDailyLog(tombstoned, uid: userA)

        let results = try await store.fetchDailyLogsUpdatedSince(uid: userA, since: t1, limit: 50)

        XCTAssertEqual(results.count, 1)
        XCTAssertNotNil(results[0].deletedAt)
    }

    func testFetchDailyLogsUpdatedSinceNeverReturnsCrossUserDocuments() async throws {
        var foreignOwned = FirestoreAccountDataRemoteStoreTestFixtures.dailyLog(
            userId: userB,
            localDate: localDate,
            referenceDate: t2
        )
        foreignOwned.updatedAt = t2

        try await store.saveDailyLog(foreignOwned, uid: userA)

        let results = try await store.fetchDailyLogsUpdatedSince(uid: userA, since: t1, limit: 50)

        XCTAssertTrue(results.isEmpty)
    }

    func testFetchFoodEntriesUpdatedSinceRespectsDateRangeAndSince() async throws {
        try await seedDailyLog(uid: userA, localDate: localDate)

        var inRange = FirestoreAccountDataRemoteStoreTestFixtures.foodEntry(
            userId: userA,
            localDate: localDate,
            referenceDate: t2,
            entryId: "food-new"
        )
        inRange.updatedAt = t2

        var outOfRangeDay = FirestoreAccountDataRemoteStoreTestFixtures.foodEntry(
            userId: userA,
            localDate: "2026-07-01",
            referenceDate: t3,
            entryId: "food-old-day"
        )
        outOfRangeDay.updatedAt = t3

        try await store.saveFoodEntry(inRange, uid: userA)
        try await seedDailyLog(uid: userA, localDate: "2026-07-01")
        try await store.saveFoodEntry(outOfRangeDay, uid: userA)

        let results = try await store.fetchFoodEntriesUpdatedSince(
            uid: userA,
            since: t1,
            from: localDate,
            to: localDate,
            limit: 50
        )

        XCTAssertEqual(results.count, 1)
        XCTAssertEqual(results[0].id, "food-new")
    }

    func testFetchWeightEntriesUpdatedSinceRespectsLimit() async throws {
        var first = FirestoreAccountDataRemoteStoreTestFixtures.weightEntry(
            userId: userA,
            localDate: "2026-07-01",
            referenceDate: t1,
            entryId: "weight-1"
        )
        first.updatedAt = t1

        var second = FirestoreAccountDataRemoteStoreTestFixtures.weightEntry(
            userId: userA,
            localDate: localDate,
            referenceDate: t2,
            entryId: "weight-2"
        )
        second.updatedAt = t2

        var third = FirestoreAccountDataRemoteStoreTestFixtures.weightEntry(
            userId: userA,
            localDate: "2026-07-05",
            referenceDate: t3,
            entryId: "weight-3"
        )
        third.updatedAt = t3

        try await store.saveWeightEntry(first, uid: userA)
        try await store.saveWeightEntry(second, uid: userA)
        try await store.saveWeightEntry(third, uid: userA)

        let results = try await store.fetchWeightEntriesUpdatedSince(uid: userA, since: nil, limit: 2)

        XCTAssertEqual(results.count, 2)
        XCTAssertEqual(results[0].id, "weight-1")
        XCTAssertEqual(results[1].id, "weight-2")
    }

    func testFetchCloudProfileUpdatedSinceReturnsProfileWhenNewer() async throws {
        let profile = makeCloudProfileDocument(updatedAt: t3, goalWeightKg: 68)
        try await store.seedCloudProfile(profile, uid: userA)

        let result = try await store.fetchCloudProfileUpdatedSince(uid: userA, since: t2)

        XCTAssertEqual(result?.goalWeightKg, 68)
        XCTAssertEqual(result?.updatedAt, t3)
    }

    func testFetchCloudProfileUpdatedSinceReturnsNilWhenNotNewer() async throws {
        let profile = makeCloudProfileDocument(updatedAt: t1)
        try await store.seedCloudProfile(profile, uid: userA)

        let result = try await store.fetchCloudProfileUpdatedSince(uid: userA, since: t2)

        XCTAssertNil(result)
    }

    func testIncrementalSupportClampLimitBounds() {
        XCTAssertEqual(AccountDataRemoteStoreIncrementalSupport.clampLimit(0), 1)
        XCTAssertEqual(AccountDataRemoteStoreIncrementalSupport.clampLimit(-5), 1)
        XCTAssertEqual(AccountDataRemoteStoreIncrementalSupport.clampLimit(10), 10)
        XCTAssertEqual(
            AccountDataRemoteStoreIncrementalSupport.clampLimit(10_000),
            AccountDataRemoteStoreIncrementalSupport.maximumFetchLimit
        )
    }

    // MARK: - Helpers

    private func seedDailyLog(uid: String, localDate: String) async throws {
        let log = FirestoreAccountDataRemoteStoreTestFixtures.dailyLog(
            userId: uid,
            localDate: localDate,
            referenceDate: t0
        )
        try await store.saveDailyLog(log, uid: uid)
    }

    private func makeCloudProfileDocument(updatedAt: Date, goalWeightKg: Double = 70) -> CloudUserProfileDocument {
        CloudUserProfileDocument(
            name: "Alex",
            birthDate: nil,
            age: 30,
            sex: Sex.female.rawValue,
            heightCm: 170,
            currentWeightKg: 72,
            goalWeightKg: goalWeightKg,
            estimatedBodyFatPercentage: nil,
            activityLevel: ActivityLevel.moderatelyActive.rawValue,
            trainingFrequencyPerWeek: 3,
            averageSteps: 8000,
            dietPreference: nil,
            unitSystem: UnitSystem.metric.rawValue,
            targets: CloudUserTargets(
                calorieTarget: 2000,
                proteinTarget: 140,
                carbTarget: 180,
                fatTarget: 65,
                waterTargetMl: 2500,
                expectedWeeklyWeightLossKg: 0.5,
                aggressiveness: CalorieAggressiveness.moderate.rawValue
            ),
            onboardingCompletedAt: updatedAt,
            updatedAt: updatedAt
        )
    }

    private func makeDate(year: Int, month: Int, day: Int, hour: Int) -> Date {
        var components = DateComponents()
        components.calendar = Calendar(identifier: .gregorian)
        components.timeZone = TimeZone(secondsFromGMT: 0)
        components.year = year
        components.month = month
        components.day = day
        components.hour = hour
        return components.date!
    }
}
