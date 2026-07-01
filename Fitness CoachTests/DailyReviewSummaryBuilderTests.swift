//
//  DailyReviewSummaryBuilderTests.swift
//  Fitness CoachTests
//
//  Stage A4 — Daily Review deterministic summary uses DailyNutritionSummaryBuilder.
//

import XCTest
@testable import Fitness_Coach

final class DailyReviewSummaryBuilderTests: XCTestCase {

    private let accuracy = 0.000_1

    func testNormalDayMatchesSharedNutritionSummary() {
        let log = DailyNutritionSummaryTestFixtures.baselineLog
        let nutrition = DailyNutritionSummaryBuilder.build(from: log)
        let review = buildReviewSummary(for: log)

        assertNutritionParity(review: review, nutrition: nutrition)
    }

    func testDailyReviewMatchesTodayDashboardNutrition() {
        let log = DailyNutritionSummaryTestFixtures.baselineLog
        let review = buildReviewSummary(for: log)
        let (calorie, macro, water) = TodayDashboardNutritionMapper.maps(from: log)

        XCTAssertEqual(review.calorieTarget, calorie.target)
        XCTAssertEqual(review.caloriesConsumed, calorie.consumed)
        XCTAssertEqual(review.caloriesRemaining, calorie.remaining)
        XCTAssertEqual(review.isOverCalorieTarget, calorie.isOverTarget)

        XCTAssertEqual(review.proteinTarget, macro.protein.target, accuracy: accuracy)
        XCTAssertEqual(review.proteinConsumed, macro.protein.consumed, accuracy: accuracy)
        XCTAssertEqual(review.proteinRemaining, macro.protein.remaining, accuracy: accuracy)

        XCTAssertEqual(review.waterTargetMl, water.targetMl)
        XCTAssertEqual(review.waterConsumedMl, water.consumedMl)
        XCTAssertEqual(review.waterRemainingMl, water.remainingMl)
    }

    func testOverTargetDay() {
        let log = DailyNutritionSummaryTestFixtures.caloriesOverTargetLog
        let nutrition = DailyNutritionSummaryBuilder.build(from: log)
        let review = buildReviewSummary(for: log)

        XCTAssertTrue(review.isOverCalorieTarget)
        XCTAssertEqual(review.caloriesRemaining, -100)
        XCTAssertTrue(review.hasMetWaterTarget)
        XCTAssertTrue(review.hasMetProteinTarget)
        XCTAssertTrue(review.deterministicNotes.contains("Calories ended above target."))
        XCTAssertTrue(review.deterministicNotes.contains("Hydration goal reached."))
        assertNutritionParity(review: review, nutrition: nutrition)
    }

    func testWaterOneMilliliterBelowTargetNotes() {
        let log = DailyNutritionSummaryTestFixtures.waterOneMlBelowTargetLog
        let review = buildReviewSummary(for: log)

        XCTAssertFalse(review.hasMetWaterTarget)
        XCTAssertEqual(review.waterRemainingMl, 1)
        XCTAssertTrue(review.deterministicNotes.contains("Hydration goal not reached today."))
    }

    func testReviewAIContextDoesNotDefaultRemainingFieldsToZero() {
        let log = DailyNutritionSummaryTestFixtures.baselineLog
        let review = buildReviewSummary(for: log)
        let aiSummary = TodayAISummaryMapper.from(reviewSummary: review)

        XCTAssertEqual(aiSummary.caloriesRemaining, review.caloriesRemaining)
        XCTAssertEqual(aiSummary.proteinRemaining, review.proteinRemaining, accuracy: accuracy)
        XCTAssertEqual(aiSummary.carbsRemaining, review.carbsRemaining, accuracy: accuracy)
        XCTAssertEqual(aiSummary.fatRemaining, review.fatRemaining, accuracy: accuracy)
        XCTAssertEqual(aiSummary.waterRemainingMl, review.waterRemainingMl)

        XCTAssertNotEqual(aiSummary.proteinRemaining, 0, accuracy: accuracy)
        XCTAssertNotEqual(aiSummary.carbsRemaining, 0, accuracy: accuracy)
        XCTAssertNotEqual(aiSummary.fatRemaining, 0, accuracy: accuracy)
        XCTAssertNotEqual(aiSummary.waterRemainingMl, 0)
    }

    func testParityWithCharacterizedRuntimeOutputs() {
        let logs = [
            DailyNutritionSummaryTestFixtures.baselineLog,
            DailyNutritionSummaryTestFixtures.waterExactlyAtTargetLog,
            DailyNutritionSummaryTestFixtures.zeroProteinTargetLog,
            DailyNutritionSummaryTestFixtures.caloriesOverTargetLog
        ]

        for log in logs {
            let review = buildReviewSummary(for: log)
            let expected = RuntimeNutritionSummaryCharacterization.snapshot(from: log)

            XCTAssertEqual(review.calorieTarget, expected.calorieTarget)
            XCTAssertEqual(review.caloriesConsumed, expected.caloriesConsumed)
            XCTAssertEqual(review.caloriesRemaining, expected.caloriesRemaining)
            XCTAssertEqual(review.isOverCalorieTarget, expected.isOverCalorieTarget)
            XCTAssertEqual(review.proteinTarget, expected.proteinTarget, accuracy: accuracy)
            XCTAssertEqual(review.proteinConsumed, expected.proteinConsumed, accuracy: accuracy)
            XCTAssertEqual(review.proteinRemaining, expected.proteinRemaining, accuracy: accuracy)
            XCTAssertEqual(review.hasMetProteinTarget, expected.hasMetProteinTarget)
            XCTAssertEqual(review.waterTargetMl, expected.waterTargetMl)
            XCTAssertEqual(review.waterConsumedMl, expected.waterConsumedMl)
            XCTAssertEqual(review.waterRemainingMl, expected.waterRemainingMl)
            XCTAssertEqual(review.hasMetWaterTarget, expected.hasMetWaterTarget)
        }
    }

    private func buildReviewSummary(for log: DailyLog) -> DailyReviewSummary {
        DailyReviewSummaryBuilder.build(
            dailyLog: log,
            foodEntries: [],
            waterEntries: [],
            weightEntry: nil,
            latestWeightEntry: nil,
            training: .empty
        )
    }

    private func assertNutritionParity(
        review: DailyReviewSummary,
        nutrition: DailyNutritionSummary
    ) {
        XCTAssertEqual(review.calorieTarget, nutrition.targets.calories)
        XCTAssertEqual(review.caloriesConsumed, nutrition.totals.calories)
        XCTAssertEqual(review.caloriesRemaining, nutrition.remaining.calories)
        XCTAssertEqual(review.isOverCalorieTarget, nutrition.isOverCalories)
        XCTAssertEqual(review.proteinTarget, nutrition.targets.protein, accuracy: accuracy)
        XCTAssertEqual(review.proteinConsumed, nutrition.totals.protein, accuracy: accuracy)
        XCTAssertEqual(review.proteinRemaining, nutrition.remaining.protein, accuracy: accuracy)
        XCTAssertEqual(review.hasMetProteinTarget, nutrition.hasMetProteinTarget)
        XCTAssertEqual(review.carbsTarget, nutrition.targets.carbs, accuracy: accuracy)
        XCTAssertEqual(review.carbsRemaining, nutrition.remaining.carbs, accuracy: accuracy)
        XCTAssertEqual(review.fatTarget, nutrition.targets.fat, accuracy: accuracy)
        XCTAssertEqual(review.fatRemaining, nutrition.remaining.fat, accuracy: accuracy)
        XCTAssertEqual(review.waterTargetMl, nutrition.water.targetMl)
        XCTAssertEqual(review.waterConsumedMl, nutrition.water.consumedMl)
        XCTAssertEqual(review.waterRemainingMl, nutrition.water.remainingMl)
        XCTAssertEqual(review.hasMetWaterTarget, nutrition.hasMetWaterTarget)
    }
}
