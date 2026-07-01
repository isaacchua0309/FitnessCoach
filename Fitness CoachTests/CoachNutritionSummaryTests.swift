//
//  CoachNutritionSummaryTests.swift
//  Fitness CoachTests
//
//  Stage A3 — Coach runtime nutrition summaries use DailyNutritionSummaryBuilder.
//

import XCTest
@testable import Fitness_Coach

final class CoachNutritionSummaryTests: XCTestCase {

    private let accuracy = 0.000_1

    func testCoachAIContextTodaySummaryMatchesSharedBuilder() {
        let log = DailyNutritionSummaryTestFixtures.baselineLog
        let expected = RuntimeNutritionSummaryCharacterization.snapshot(from: log)
        let summary = TodayAISummaryMapper.from(dailyLog: log, workoutsToday: 2, recentMeals: ["200 g chicken"])

        XCTAssertEqual(summary.calorieTarget, expected.calorieTarget)
        XCTAssertEqual(summary.caloriesConsumed, expected.caloriesConsumed)
        XCTAssertEqual(summary.caloriesRemaining, expected.caloriesRemaining)
        XCTAssertEqual(summary.proteinTarget, expected.proteinTarget, accuracy: accuracy)
        XCTAssertEqual(summary.proteinConsumed, expected.proteinConsumed, accuracy: accuracy)
        XCTAssertEqual(summary.proteinRemaining, expected.proteinRemaining, accuracy: accuracy)
        XCTAssertEqual(summary.carbsTarget, expected.carbsTarget, accuracy: accuracy)
        XCTAssertEqual(summary.carbsConsumed, expected.carbsConsumed, accuracy: accuracy)
        XCTAssertEqual(summary.carbsRemaining, expected.carbsRemaining, accuracy: accuracy)
        XCTAssertEqual(summary.fatTarget, expected.fatTarget, accuracy: accuracy)
        XCTAssertEqual(summary.fatConsumed, expected.fatConsumed, accuracy: accuracy)
        XCTAssertEqual(summary.fatRemaining, expected.fatRemaining, accuracy: accuracy)
        XCTAssertEqual(summary.waterTargetMl, expected.waterTargetMl)
        XCTAssertEqual(summary.waterConsumedMl, expected.waterConsumedMl)
        XCTAssertEqual(summary.waterRemainingMl, expected.waterRemainingMl)
        XCTAssertEqual(summary.workoutsToday, 2)
        XCTAssertEqual(summary.recentMeals, ["200 g chicken"])
        XCTAssertEqual(summary.isOverCalorieTarget, expected.isOverCalorieTarget)
        XCTAssertEqual(summary.hasMetProteinTarget, expected.hasMetProteinTarget)
        XCTAssertEqual(summary.hasMetWaterTarget, expected.hasMetWaterTarget)
    }

    func testDailyReviewAIInputUsesSharedStatusFlags() {
        let log = DailyNutritionSummaryTestFixtures.baselineLog
        let nutrition = DailyNutritionSummaryBuilder.build(from: log)
        let summary = TodayAISummaryMapper.from(
            nutrition: nutrition,
            dailyLog: log,
            workoutsToday: 1,
            recentMeals: ["chicken"]
        )
        let input = TodayAISummaryMapper.dailyReviewAIInput(from: summary, date: log.date)

        XCTAssertEqual(input.isOverCalorieTarget, nutrition.isOverCalories)
        XCTAssertEqual(input.hasMetProteinTarget, nutrition.hasMetProteinTarget)
        XCTAssertEqual(input.hasMetWaterTarget, nutrition.hasMetWaterTarget)
    }

    func testReviewAIContextIncludesRemainingMacroFields() {
        let log = DailyNutritionSummaryTestFixtures.baselineLog
        let reviewSummary = RuntimeNutritionSummaryCharacterization.reviewSummary(from: log)
        let aiSummary = TodayAISummaryMapper.from(reviewSummary: reviewSummary)

        XCTAssertEqual(aiSummary.proteinRemaining, reviewSummary.proteinRemaining, accuracy: accuracy)
        XCTAssertEqual(aiSummary.carbsRemaining, reviewSummary.carbsRemaining, accuracy: accuracy)
        XCTAssertEqual(aiSummary.fatRemaining, reviewSummary.fatRemaining, accuracy: accuracy)
        XCTAssertEqual(aiSummary.waterRemainingMl, reviewSummary.waterRemainingMl)
        XCTAssertEqual(aiSummary.workoutsToday, reviewSummary.workoutCount)
        XCTAssertEqual(aiSummary.isOverCalorieTarget, reviewSummary.isOverCalorieTarget)
        XCTAssertEqual(aiSummary.hasMetProteinTarget, reviewSummary.hasMetProteinTarget)
        XCTAssertEqual(aiSummary.hasMetWaterTarget, reviewSummary.hasMetWaterTarget)
    }

    func testStatusResponseUsesSharedRemainingValues() {
        let log = DailyNutritionSummaryTestFixtures.baselineLog
        let nutrition = DailyNutritionSummaryBuilder.build(from: log)
        let message = CoachResponseBuilder.status(log)

        let remainingCalories = max(nutrition.remaining.calories, 0)
        XCTAssertTrue(message.contains("\(nutrition.totals.calories) / \(nutrition.targets.calories) kcal"))
        XCTAssertTrue(message.contains("\(formatMacro(nutrition.totals.protein)) / \(formatMacro(nutrition.targets.protein))g"))
        XCTAssertTrue(message.contains("\(nutrition.water.consumedMl) / \(nutrition.water.targetMl)ml"))
        XCTAssertTrue(message.contains("\(remainingCalories) kcal remaining"))
    }

    func testMealAdviceUsesSharedCalorieProteinAndWaterValues() {
        let log = DailyNutritionSummaryTestFixtures.baselineLog
        let nutrition = DailyNutritionSummaryBuilder.build(from: log)
        let message = CoachResponseBuilder.mealAdvice(
            log: log,
            profile: ProfileTestFixtures.sampleProfile,
            hasWorkoutToday: false,
            assistantMessage: nil
        )

        XCTAssertTrue(message.contains("\(nutrition.remaining.calories) kcal left"))
        XCTAssertTrue(
            message.contains("You still need about \(formatMacro(nutrition.remaining.protein))g protein today.")
        )
        XCTAssertTrue(message.contains("\(formatWater(nutrition.water.remainingMl))ml more water"))
    }

    func testFoodResponseUsesClampedProteinRemaining() {
        let log = DailyNutritionSummaryTestFixtures.caloriesOverTargetLog
        let nutrition = DailyNutritionSummaryBuilder.build(from: log)
        let entry = CoachMutationTestFixtures.chickenFoodEntry
        let message = CoachResponseBuilder.food(entry, log: log)

        XCTAssertTrue(message.contains("\(formatMacro(max(nutrition.remaining.protein, 0)))g protein remaining"))
    }

    private func formatMacro(_ value: Double) -> String {
        value.truncatingRemainder(dividingBy: 1) == 0
            ? String(format: "%.0f", value)
            : String(format: "%.1f", value)
    }

    private func formatWater(_ ml: Int) -> String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .decimal
        return formatter.string(from: NSNumber(value: ml)) ?? "\(ml)"
    }
}
