//
//  FitnessActionCenterTests.swift
//  Fitness CoachTests
//
//  Stage D2 — FitnessActionCenter mutation facade guardrails.
//

import XCTest
@testable import Fitness_Coach

@MainActor
final class FitnessActionCenterTests: XCTestCase {

    private var harness: FitnessActionCenterTestSupport.Harness!

    override func setUp() async throws {
        harness = try FitnessActionCenterTestSupport.makeHarness(cloudUID: nil)
    }

    override func tearDown() {
        harness = nil
        super.tearDown()
    }

    // MARK: - Food

    func testLogFoodCreatesFoodEntryAndUpdatesDailyTotals() async throws {
        try harness.seedProfile()
        _ = try harness.actionCenter.ensureTodayLog()

        let entry = try harness.actionCenter.logFood(
            DailyLogServiceTestSupport.foodDraft(
                name: "Oatmeal",
                calories: 310,
                protein: 12,
                carbs: 45,
                fat: 8
            ),
            date: harness.today
        )

        XCTAssertEqual(entry.name, "Oatmeal")
        XCTAssertEqual(try harness.actionCenter.getFoodEntries(for: harness.today).count, 1)

        let log = try harness.dailyLogService.getLog(for: harness.today)
        XCTAssertEqual(log?.totals.calories, 310)
        XCTAssertEqual(log?.totals.protein, 12)
        XCTAssertEqual(log?.totals.carbs, 45)
        XCTAssertEqual(log?.totals.fat, 8)
    }

    func testLogFoodNotifiesRefreshCenter() async throws {
        try harness.seedProfile()
        _ = try harness.actionCenter.ensureTodayLog()

        let tokenBefore = harness.refreshCenter.refreshToken
        _ = try harness.actionCenter.logFood(
            DailyLogServiceTestSupport.foodDraft(name: "Banana", calories: 105, carbs: 27),
            date: harness.today
        )

        XCTAssertEqual(harness.refreshCenter.refreshToken, tokenBefore + 1)
    }

    func testDeleteFoodEntryRecalculatesDailyTotals() async throws {
        try harness.seedProfile()
        _ = try harness.actionCenter.ensureTodayLog()

        let entry = try harness.actionCenter.logFood(
            DailyLogServiceTestSupport.foodDraft(name: "Snack", calories: 200, protein: 10),
            date: harness.today
        )
        let tokenAfterAdd = harness.refreshCenter.refreshToken

        try harness.actionCenter.deleteFoodEntry(id: entry.id)

        XCTAssertEqual(try harness.actionCenter.getFoodEntries(for: harness.today).count, 0)
        let log = try XCTUnwrap(try harness.dailyLogService.getLog(for: harness.today))
        XCTAssertEqual(log.totals.calories, 0)
        XCTAssertEqual(log.totals.protein, 0)
        XCTAssertEqual(harness.refreshCenter.refreshToken, tokenAfterAdd + 1)
    }

    // MARK: - Water

    func testLogWaterCreatesWaterEntryAndUpdatesDailyWaterTotal() async throws {
        try harness.seedProfile()
        _ = try harness.actionCenter.ensureTodayLog()

        let entry = try harness.actionCenter.logWater(amountMl: 450, date: harness.today)

        XCTAssertEqual(entry.amountMl, 450)
        let log = try XCTUnwrap(try harness.dailyLogService.getLog(for: harness.today))
        XCTAssertEqual(log.waterConsumedMl, 450)
    }

    // MARK: - Weight

    func testLogDailyWeightStoresWeightEntryForTheDay() async throws {
        try harness.seedProfile()
        _ = try harness.actionCenter.ensureTodayLog()

        let entry = try harness.actionCenter.logDailyWeight(71.4, date: harness.today)

        XCTAssertEqual(entry.weightKg, 71.4)
        XCTAssertEqual(
            entry.date,
            harness.base.dateProvider.startOfDay(for: harness.today)
        )

        let entries = try harness.weightLogService.getWeightEntries(
            from: harness.today,
            to: harness.today
        )
        XCTAssertEqual(entries.count, 1)
        XCTAssertEqual(entries.first?.weightKg, 71.4)

        let log = try XCTUnwrap(try harness.dailyLogService.getLog(for: harness.today))
        XCTAssertEqual(log.weightKg, 71.4)
    }

    // MARK: - Plan targets

    func testApplyPlanTargetsUpdatesProfileAndTodayDailyLogTargets() async throws {
        try harness.seedProfile()
        _ = try harness.actionCenter.ensureTodayLog()

        let newTargets = DailyLogServiceTestSupport.alternateTargets
        let profile = try harness.actionCenter.applyPlanTargets(newTargets)

        XCTAssertEqual(profile.targets, newTargets)

        let todayLog = try XCTUnwrap(try harness.dailyLogService.getLog(for: harness.today))
        XCTAssertEqual(todayLog.targets, newTargets)
    }

    func testUpdatePlanWithoutTargetsDoesNotSyncDailyLogTargets() async throws {
        let originalTargets = ProfileTestFixtures.sampleTargets
        try harness.seedProfile(targets: originalTargets)
        _ = try harness.actionCenter.ensureTodayLog()

        // Drift profile targets without going through ActionCenter sync.
        let driftedTargets = DailyLogServiceTestSupport.alternateTargets
        _ = try harness.profileService.updateTargets(driftedTargets)

        let profile = try harness.actionCenter.updatePlan(
            UserProfileUpdate(name: "Updated Name")
        )

        XCTAssertEqual(profile.name, "Updated Name")
        XCTAssertEqual(profile.targets, driftedTargets)

        // Read via entity accessor — `getLog(for:)` auto-syncs today's targets from profile.
        let todayEntity = try XCTUnwrap(try harness.dailyLogService.dailyLogEntity(for: harness.today))
        XCTAssertEqual(todayEntity.toModel().targets, originalTargets)
    }

    func testUpdatePlanWithTargetChangesTriggersCloudProfileSync() async throws {
        let cloudHarness = try FitnessActionCenterTestSupport.makeHarness()
        try cloudHarness.seedProfile()
        _ = try cloudHarness.actionCenter.ensureTodayLog()

        let newTargets = DailyLogServiceTestSupport.alternateTargets
        _ = try cloudHarness.actionCenter.updatePlan(UserProfileUpdate(targets: newTargets))

        await cloudHarness.waitForCloudSave()

        XCTAssertEqual(cloudHarness.cloudStore.saveCallCount, 1)
        XCTAssertEqual(cloudHarness.cloudStore.lastSavedUID, "test-user-1")
        XCTAssertEqual(cloudHarness.cloudStore.lastSavedProfile?.targets, newTargets)
    }

    // MARK: - Failure handling

    func testMutationFailuresSurfaceErrorsWithoutCorruptingState() async throws {
        try harness.seedProfile()
        _ = try harness.actionCenter.ensureTodayLog()
        let tokenBefore = harness.refreshCenter.refreshToken

        let invalidFood = FoodDraft(
            mealType: nil,
            name: "   ",
            quantity: nil,
            unit: nil,
            calories: 100,
            protein: 0,
            carbs: 0,
            fat: 0,
            fiber: nil,
            sodium: nil,
            source: .manual,
            confidence: .high,
            imageUrl: nil,
            notes: nil
        )

        XCTAssertThrowsError(
            try harness.actionCenter.logFood(invalidFood, date: harness.today)
        ) { error in
            XCTAssertEqual(
                error as? ServiceError,
                .invalidInput("Food name cannot be empty.")
            )
        }

        XCTAssertThrowsError(
            try harness.actionCenter.logWater(amountMl: 0, date: harness.today)
        ) { error in
            XCTAssertEqual(
                error as? ServiceError,
                .invalidInput("Water amount must be greater than zero.")
            )
        }

        XCTAssertThrowsError(
            try harness.actionCenter.deleteFoodEntry(id: UUID())
        ) { error in
            XCTAssertEqual(error as? ServiceError, .foodEntryNotFound)
        }

        XCTAssertEqual(harness.refreshCenter.refreshToken, tokenBefore)
        XCTAssertEqual(try harness.actionCenter.getFoodEntries(for: harness.today).count, 0)
        let log = try XCTUnwrap(try harness.dailyLogService.getLog(for: harness.today))
        XCTAssertEqual(log.totals.calories, 0)
        XCTAssertEqual(log.waterConsumedMl, 0)
    }
}
