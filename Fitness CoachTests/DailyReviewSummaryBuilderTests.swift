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
        let log = TestFixtureFactory.nutritionLog(.baseline)
        let nutrition = DailyNutritionSummaryBuilder.build(from: log)
        let review = buildReviewSummary(for: log)

        assertNutritionParity(review: review, nutrition: nutrition)
    }

    func testDailyReviewMatchesTodayDashboardNutrition() {
        let log = TestFixtureFactory.nutritionLog(.baseline)
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
        let log = TestFixtureFactory.nutritionLog(.caloriesOverTarget)
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
        let log = TestFixtureFactory.nutritionLog(.waterOneMlBelowTarget)
        let review = buildReviewSummary(for: log)

        XCTAssertFalse(review.hasMetWaterTarget)
        XCTAssertEqual(review.waterRemainingMl, 1)
        XCTAssertTrue(review.deterministicNotes.contains("Hydration goal not reached today."))
    }

    func testReviewAIContextDoesNotDefaultRemainingFieldsToZero() {
        let log = TestFixtureFactory.nutritionLog(.baseline)
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
        let scenarios: [DailyLogFixtures.NutritionScenario] = [
            .baseline,
            .waterExactlyAtTarget,
            .zeroProteinTarget,
            .caloriesOverTarget
        ]

        for scenario in scenarios {
            let log = TestFixtureFactory.nutritionLog(scenario)
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

    func testHasEnoughLogsForReviewRequiresMeaningfulSignal() {
        XCTAssertFalse(
            DailyReviewSummaryBuilder.hasEnoughLogsForReview(
                foodEntryCount: 0,
                waterConsumedMl: 0,
                workoutCaloriesBurned: 0,
                weightLogged: false
            )
        )
        XCTAssertTrue(
            DailyReviewSummaryBuilder.hasEnoughLogsForReview(
                foodEntryCount: 1,
                waterConsumedMl: 0,
                workoutCaloriesBurned: 0,
                weightLogged: false
            )
        )
        XCTAssertTrue(
            DailyReviewSummaryBuilder.hasEnoughLogsForReview(
                foodEntryCount: 0,
                waterConsumedMl: 250,
                workoutCaloriesBurned: 0,
                weightLogged: false
            )
        )
        XCTAssertTrue(
            DailyReviewSummaryBuilder.hasEnoughLogsForReview(
                foodEntryCount: 0,
                waterConsumedMl: 0,
                workoutCaloriesBurned: 120,
                weightLogged: false
            )
        )
        XCTAssertTrue(
            DailyReviewSummaryBuilder.hasEnoughLogsForReview(
                foodEntryCount: 0,
                waterConsumedMl: 0,
                workoutCaloriesBurned: 0,
                weightLogged: true
            )
        )
    }

    func testHasEnoughLogsAlignsWithTodayTeaserEligibility() {
        let eligibleSignals: [(Int, Int, Int, Bool)] = [
            (2, 0, 0, false),
            (0, 500, 0, false),
            (0, 0, 180, false),
            (0, 0, 0, true)
        ]

        for signal in eligibleSignals {
            XCTAssertTrue(
                DailyReviewSummaryBuilder.hasEnoughLogsForReview(
                    foodEntryCount: signal.0,
                    waterConsumedMl: signal.1,
                    workoutCaloriesBurned: signal.2,
                    weightLogged: signal.3
                ),
                "Expected teaser eligibility for signal \(signal)"
            )
        }
    }

    func testTeaserLinesPreferSummaryAndSections() {
        let review = DailyReview(
            id: UUID(),
            dailyLogId: UUID(),
            summaryText: "Strong protein day.",
            caloriesSummary: "Calories: 1,700 / 1,800 kcal.",
            proteinSummary: "Protein: 165 / 170g.",
            hydrationSummary: "Water: 2,800 / 3,500ml.",
            workoutSummary: nil,
            weightSummary: nil,
            tomorrowRecommendation: "Repeat tomorrow.",
            createdAt: Date()
        )

        let lines = DailyReviewSummaryBuilder.teaserLines(from: review)
        XCTAssertEqual(lines.count, 2)
        XCTAssertEqual(lines[0], "Strong protein day.")
        XCTAssertEqual(lines[1], "Calories: 1,700 / 1,800 kcal.")
    }

    func testTeaserLinesUseDeterministicReviewSectionsNotCoachPipeline() {
        let review = DailyReview(
            id: UUID(),
            dailyLogId: UUID(),
            summaryText: "",
            caloriesSummary: DailyReviewFormatter.caloriesSummary(
                from: buildReviewSummary(for: DailyNutritionSummaryTestFixtures.baselineLog)
            ),
            proteinSummary: DailyReviewFormatter.proteinSummary(
                from: buildReviewSummary(for: DailyNutritionSummaryTestFixtures.baselineLog)
            ),
            hydrationSummary: DailyReviewFormatter.hydrationSummary(
                from: buildReviewSummary(for: DailyNutritionSummaryTestFixtures.baselineLog)
            ),
            workoutSummary: nil,
            weightSummary: nil,
            tomorrowRecommendation: DailyReviewFormatter.tomorrowRecommendation(
                from: buildReviewSummary(for: DailyNutritionSummaryTestFixtures.baselineLog)
            ),
            createdAt: Date()
        )

        let lines = DailyReviewSummaryBuilder.teaserLines(from: review)
        XCTAssertFalse(lines.isEmpty)
        XCTAssertTrue(lines[0].contains("Calories:"))
        XCTAssertFalse(lines.joined(separator: " ").localizedCaseInsensitiveContains("coach note"))
    }
}
