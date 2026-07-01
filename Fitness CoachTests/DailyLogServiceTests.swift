//
//  DailyLogServiceTests.swift
//  Fitness CoachTests
//
//  Stage D1 — Target sync and daily log recalculation guardrails.
//

import XCTest
@testable import Fitness_Coach

@MainActor
final class DailyLogServiceTests: XCTestCase {

    private var harness: DailyLogServiceTestSupport.Harness!

    override func setUp() async throws {
        harness = try DailyLogServiceTestSupport.makeHarness()
    }

    override func tearDown() {
        harness = nil
        super.tearDown()
    }

    // MARK: - Target seeding and sync

    func testGetOrCreateLogEntitySeedsTargetsFromCurrentProfile() async throws {
        let profile = try harness.seedProfile()

        let entity = try harness.dailyLogService.getOrCreateLogEntity(for: harness.today)
        let log = entity.toModel()

        XCTAssertEqual(log.targets, profile.targets)
    }

    func testSyncTodayTargetsFromProfileUpdatesTodayLogTargetFields() async throws {
        try harness.seedProfile()
        _ = try harness.dailyLogService.getOrCreateLogEntity(for: harness.today)

        let updatedTargets = DailyLogServiceTestSupport.alternateTargets
        _ = try harness.profileService.updateTargets(updatedTargets)
        try harness.dailyLogService.syncTodayTargetsFromProfile()

        let todayLog = try XCTUnwrap(try harness.dailyLogService.getLog(for: harness.today))
        XCTAssertEqual(todayLog.targets, updatedTargets)
    }

    func testSyncTodayTargetsFromProfileIsNoOpWhenValuesUnchanged() async throws {
        try harness.seedProfile()
        let entity = try harness.dailyLogService.getOrCreateLogEntity(for: harness.today)
        let beforeUpdatedAt = entity.updatedAt

        try harness.dailyLogService.syncTodayTargetsFromProfile()

        let afterEntity = try XCTUnwrap(try harness.dailyLogService.dailyLogEntity(for: harness.today))
        XCTAssertEqual(afterEntity.updatedAt, beforeUpdatedAt)
        XCTAssertEqual(afterEntity.toModel().targets, ProfileTestFixtures.sampleTargets)
    }

    func testSyncTodayTargetsFromProfileUpdatesAllTargetFields() async throws {
        try harness.seedProfile(targets: ProfileTestFixtures.sampleTargets)
        _ = try harness.dailyLogService.getOrCreateLogEntity(for: harness.today)

        let updatedTargets = DailyLogServiceTestSupport.alternateTargets
        _ = try harness.profileService.updateTargets(updatedTargets)
        try harness.dailyLogService.syncTodayTargetsFromProfile()

        let log = try XCTUnwrap(try harness.dailyLogService.getLog(for: harness.today))
        XCTAssertEqual(log.targets.calorieTarget, updatedTargets.calorieTarget)
        XCTAssertEqual(log.targets.proteinTarget, updatedTargets.proteinTarget)
        XCTAssertEqual(log.targets.carbTarget, updatedTargets.carbTarget)
        XCTAssertEqual(log.targets.fatTarget, updatedTargets.fatTarget)
        XCTAssertEqual(log.targets.waterTargetMl, updatedTargets.waterTargetMl)
        XCTAssertEqual(log.targets.expectedWeeklyWeightLossKg, updatedTargets.expectedWeeklyWeightLossKg)
        XCTAssertEqual(log.targets.aggressiveness, updatedTargets.aggressiveness)
    }

    func testSyncTodayTargetsFromProfileDoesNotChangePastDayLogs() async throws {
        let originalTargets = ProfileTestFixtures.sampleTargets
        try harness.seedProfile(targets: originalTargets)

        let yesterday = harness.day(offset: -1)
        let pastLog = try harness.dailyLogService.getOrCreateLog(for: yesterday)
        XCTAssertEqual(pastLog.targets, originalTargets)

        _ = try harness.dailyLogService.getOrCreateLog(for: harness.today)
        _ = try harness.profileService.updateTargets(DailyLogServiceTestSupport.alternateTargets)
        try harness.dailyLogService.syncTodayTargetsFromProfile()

        let unchangedPastLog = try XCTUnwrap(try harness.dailyLogService.getLog(for: yesterday))
        XCTAssertEqual(unchangedPastLog.targets, originalTargets)

        let todayLog = try XCTUnwrap(try harness.dailyLogService.getLog(for: harness.today))
        XCTAssertEqual(todayLog.targets, DailyLogServiceTestSupport.alternateTargets)
    }

    // MARK: - Recalculation

    func testRecalculateDailyTotalsSumsFoodEntriesCorrectly() async throws {
        try harness.seedProfile()

        _ = try harness.foodLogService.addFoodEntry(
            DailyLogServiceTestSupport.foodDraft(
                name: "Chicken bowl",
                calories: 420,
                protein: 35,
                carbs: 28,
                fat: 14,
                fiber: 6,
                sodium: 480
            ),
            date: harness.today
        )
        _ = try harness.foodLogService.addFoodEntry(
            DailyLogServiceTestSupport.foodDraft(
                name: "Greek yogurt",
                calories: 180,
                protein: 15,
                carbs: 12,
                fat: 4
            ),
            date: harness.today
        )

        let log = try harness.dailyLogService.recalculateDailyTotals(for: harness.today)
        XCTAssertEqual(log.totals.calories, 600)
        XCTAssertEqual(log.totals.protein, 50)
        XCTAssertEqual(log.totals.carbs, 40)
        XCTAssertEqual(log.totals.fat, 18)
        XCTAssertEqual(log.totals.fiber, 6)
        XCTAssertEqual(log.totals.sodium, 480)
    }

    func testRecalculateDailyTotalsSumsWaterEntriesCorrectly() async throws {
        try harness.seedProfile()

        _ = try harness.waterLogService.addWater(amountMl: 350, date: harness.today)
        _ = try harness.waterLogService.addWater(amountMl: 500, date: harness.today)

        let log = try harness.dailyLogService.recalculateDailyTotals(for: harness.today)
        XCTAssertEqual(log.waterConsumedMl, 850)
    }

    func testRecalculateDailyTotalsPreservesStoredWorkoutCaloriesWhenFoodChanges() async throws {
        try harness.seedProfile()

        _ = try harness.seedWorkoutCaloriesBurned(calories: 320)

        let afterWorkout = try XCTUnwrap(try harness.dailyLogService.getLog(for: harness.today))
        XCTAssertEqual(afterWorkout.workoutCaloriesBurned, 320)

        _ = try harness.foodLogService.addFoodEntry(
            DailyLogServiceTestSupport.foodDraft(name: "Snack", calories: 150, protein: 8),
            date: harness.today
        )

        let afterFood = try harness.dailyLogService.recalculateDailyTotals(for: harness.today)
        XCTAssertEqual(afterFood.workoutCaloriesBurned, 320)
        XCTAssertEqual(afterFood.totals.calories, 150)
    }
}
