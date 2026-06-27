//
//  DailyNutritionSummaryCharacterizationTests.swift
//  Fitness CoachTests
//
//  Stage A0 — Lock down runtime nutrition summary behavior before extracting
//  DailyNutritionSummaryBuilder.
//

import XCTest
@testable import Fitness_Coach

final class DailyNutritionSummaryCharacterizationTests: XCTestCase {

    private let accuracy = 0.000_1

    // MARK: - Baseline fixture (requirements 1–6)

    func testMacroTargetsAreReadFromDailyLogTargets() {
        let log = DailyNutritionSummaryTestFixtures.baselineLog
        let snapshot = RuntimeNutritionSummaryCharacterization.snapshot(from: log)

        XCTAssertEqual(snapshot.calorieTarget, log.targets.calorieTarget)
        XCTAssertEqual(snapshot.proteinTarget, log.targets.proteinTarget)
        XCTAssertEqual(snapshot.carbsTarget, log.targets.carbTarget)
        XCTAssertEqual(snapshot.fatTarget, log.targets.fatTarget)
        XCTAssertEqual(snapshot.waterTargetMl, log.targets.waterTargetMl)
    }

    func testTotalsAreReadFromDailyLogTotals() {
        let log = DailyNutritionSummaryTestFixtures.baselineLog
        let snapshot = RuntimeNutritionSummaryCharacterization.snapshot(from: log)

        XCTAssertEqual(snapshot.caloriesConsumed, log.totals.calories)
        XCTAssertEqual(snapshot.proteinConsumed, log.totals.protein)
        XCTAssertEqual(snapshot.carbsConsumed, log.totals.carbs)
        XCTAssertEqual(snapshot.fatConsumed, log.totals.fat)
        XCTAssertEqual(snapshot.waterConsumedMl, log.waterConsumedMl)
    }

    func testRemainingMacrosAreCalculatedFromTargetsMinusTotals() {
        let log = DailyNutritionSummaryTestFixtures.baselineLog
        let snapshot = RuntimeNutritionSummaryCharacterization.snapshot(from: log)

        XCTAssertEqual(snapshot.caloriesRemaining, 800)
        XCTAssertEqual(snapshot.proteinRemaining, 60, accuracy: accuracy)
        XCTAssertEqual(snapshot.carbsRemaining, 90, accuracy: accuracy)
        XCTAssertEqual(snapshot.fatRemaining, 25, accuracy: accuracy)
        XCTAssertEqual(snapshot.waterRemainingMl, 700)
    }

    func testProgressValuesAreCalculatedAndClamped() {
        let log = DailyNutritionSummaryTestFixtures.baselineLog
        let snapshot = RuntimeNutritionSummaryCharacterization.snapshot(from: log)

        XCTAssertEqual(snapshot.calorieProgress, 0.6, accuracy: accuracy)
        XCTAssertEqual(snapshot.proteinProgress, 0.6, accuracy: accuracy)
        XCTAssertEqual(snapshot.carbsProgress, 0.55, accuracy: accuracy)
        XCTAssertEqual(snapshot.fatProgress, 40.0 / 65.0, accuracy: accuracy)
        XCTAssertEqual(snapshot.waterProgress, 1_800.0 / 2_500.0, accuracy: accuracy)
    }

    func testOverTargetFlagsPreservedForBaselineUnderTargetDay() {
        let log = DailyNutritionSummaryTestFixtures.baselineLog
        let snapshot = RuntimeNutritionSummaryCharacterization.snapshot(from: log)

        XCTAssertFalse(snapshot.isOverCalorieTarget)
        XCTAssertFalse(snapshot.hasMetProteinTarget)
        XCTAssertFalse(snapshot.hasMetWaterTarget)
    }

    func testWaterTargetRemainingAndProgressPreservedForBaseline() {
        let log = DailyNutritionSummaryTestFixtures.baselineLog
        let snapshot = RuntimeNutritionSummaryCharacterization.snapshot(from: log)

        XCTAssertEqual(snapshot.waterTargetMl, 2_500)
        XCTAssertEqual(snapshot.waterConsumedMl, 1_800)
        XCTAssertEqual(snapshot.waterRemainingMl, 700)
        XCTAssertEqual(snapshot.waterProgress, 0.72, accuracy: accuracy)
    }

    func testDailyReviewBuilderMatchesBaselineRuntimeNumbers() {
        let log = DailyNutritionSummaryTestFixtures.baselineLog
        let snapshot = RuntimeNutritionSummaryCharacterization.snapshot(from: log)
        let review = RuntimeNutritionSummaryCharacterization.reviewSummary(from: log)

        XCTAssertEqual(review.calorieTarget, snapshot.calorieTarget)
        XCTAssertEqual(review.caloriesConsumed, snapshot.caloriesConsumed)
        XCTAssertEqual(review.caloriesRemaining, snapshot.caloriesRemaining)
        XCTAssertEqual(review.isOverCalorieTarget, snapshot.isOverCalorieTarget)
        XCTAssertEqual(review.proteinTarget, snapshot.proteinTarget, accuracy: accuracy)
        XCTAssertEqual(review.proteinConsumed, snapshot.proteinConsumed, accuracy: accuracy)
        XCTAssertEqual(review.proteinRemaining, snapshot.proteinRemaining, accuracy: accuracy)
        XCTAssertEqual(review.hasMetProteinTarget, snapshot.hasMetProteinTarget)
        XCTAssertEqual(review.waterTargetMl, snapshot.waterTargetMl)
        XCTAssertEqual(review.waterConsumedMl, snapshot.waterConsumedMl)
        XCTAssertEqual(review.waterRemainingMl, snapshot.waterRemainingMl)
        XCTAssertEqual(review.hasMetWaterTarget, snapshot.hasMetWaterTarget)
    }

    // MARK: - Edge cases (requirements 7–10)

    func testWaterExactlyAtTarget() {
        let log = DailyNutritionSummaryTestFixtures.waterExactlyAtTargetLog
        let snapshot = RuntimeNutritionSummaryCharacterization.snapshot(from: log)

        XCTAssertEqual(snapshot.waterRemainingMl, 0)
        XCTAssertEqual(snapshot.waterProgress, 1.0, accuracy: accuracy)
        XCTAssertTrue(snapshot.hasMetWaterTarget)

        let review = RuntimeNutritionSummaryCharacterization.reviewSummary(from: log)
        XCTAssertTrue(review.hasMetWaterTarget)
        XCTAssertTrue(review.deterministicNotes.contains("Hydration goal reached."))
    }

    func testWaterOneMilliliterBelowTarget() {
        let log = DailyNutritionSummaryTestFixtures.waterOneMlBelowTargetLog
        let snapshot = RuntimeNutritionSummaryCharacterization.snapshot(from: log)

        XCTAssertEqual(snapshot.waterRemainingMl, 1)
        XCTAssertEqual(snapshot.waterProgress, 2_499.0 / 2_500.0, accuracy: accuracy)
        XCTAssertFalse(snapshot.hasMetWaterTarget)

        let review = RuntimeNutritionSummaryCharacterization.reviewSummary(from: log)
        XCTAssertFalse(review.hasMetWaterTarget)
        XCTAssertTrue(review.deterministicNotes.contains("Hydration goal not reached today."))
    }

    func testZeroProteinTargetTreatedAsAlreadyMetWithZeroProgress() {
        let log = DailyNutritionSummaryTestFixtures.zeroProteinTargetLog
        let snapshot = RuntimeNutritionSummaryCharacterization.snapshot(from: log)

        XCTAssertEqual(snapshot.proteinTarget, 0, accuracy: accuracy)
        XCTAssertEqual(snapshot.proteinProgress, 0, accuracy: accuracy)
        XCTAssertTrue(snapshot.hasMetProteinTarget)

        let review = RuntimeNutritionSummaryCharacterization.reviewSummary(from: log)
        XCTAssertTrue(review.hasMetProteinTarget)
        XCTAssertTrue(review.deterministicNotes.contains("Protein target reached."))
    }

    func testCaloriesOverTargetPreservesNegativeRemainingAndClampedProgress() {
        let log = DailyNutritionSummaryTestFixtures.caloriesOverTargetLog
        let snapshot = RuntimeNutritionSummaryCharacterization.snapshot(from: log)

        XCTAssertTrue(snapshot.isOverCalorieTarget)
        XCTAssertEqual(snapshot.caloriesRemaining, -100)
        XCTAssertEqual(snapshot.calorieProgress, 1.0, accuracy: accuracy)
        XCTAssertEqual(snapshot.waterRemainingMl, 0)
        XCTAssertTrue(snapshot.hasMetWaterTarget)

        let review = RuntimeNutritionSummaryCharacterization.reviewSummary(from: log)
        XCTAssertTrue(review.isOverCalorieTarget)
        XCTAssertEqual(review.caloriesRemaining, -100)
        XCTAssertTrue(review.deterministicNotes.contains("Calories ended above target."))
    }
}
