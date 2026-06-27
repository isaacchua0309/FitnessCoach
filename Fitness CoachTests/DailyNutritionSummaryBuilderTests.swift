//
//  DailyNutritionSummaryBuilderTests.swift
//  Fitness CoachTests
//
//  Stage A1 — Shared runtime daily nutrition summary builder.
//

import XCTest
@testable import Fitness_Coach

final class DailyNutritionSummaryBuilderTests: XCTestCase {

    private let accuracy = 0.000_1

    func testNormalDayBelowTarget() {
        let log = DailyNutritionSummaryTestFixtures.baselineLog
        let summary = DailyNutritionSummaryBuilder.build(from: log)

        XCTAssertEqual(summary.targets.calories, 2_000)
        XCTAssertEqual(summary.totals.calories, 1_200)
        XCTAssertEqual(summary.remaining.calories, 800)
        XCTAssertEqual(summary.calorieProgress, 0.6, accuracy: accuracy)
        XCTAssertFalse(summary.isOverCalories)
        XCTAssertFalse(summary.hasMetProteinTarget)
        XCTAssertFalse(summary.hasMetWaterTarget)
        XCTAssertEqual(summary.water.remainingMl, 700)
        XCTAssertEqual(summary.water.progress, 1_800.0 / 2_500.0, accuracy: accuracy)
    }

    func testOverCalories() {
        let log = DailyNutritionSummaryTestFixtures.caloriesOverTargetLog
        let summary = DailyNutritionSummaryBuilder.build(from: log)

        XCTAssertTrue(summary.isOverCalories)
        XCTAssertEqual(summary.remaining.calories, -100)
        XCTAssertEqual(summary.calorieProgress, 1.0, accuracy: accuracy)
    }

    func testProteinTargetMet() {
        let log = DailyNutritionSummaryTestFixtures.dailyLog(
            targets: UserTargets(
                calorieTarget: 2_000,
                proteinTarget: 150,
                carbTarget: 200,
                fatTarget: 65,
                waterTargetMl: 2_500,
                expectedWeeklyWeightLossKg: nil,
                aggressiveness: .moderate
            ),
            totals: MacroTotals(
                calories: 1_800,
                protein: 150,
                carbs: 180,
                fat: 60,
                fiber: nil,
                sodium: nil
            ),
            waterConsumedMl: 1_000
        )
        let summary = DailyNutritionSummaryBuilder.build(from: log)

        XCTAssertTrue(summary.hasMetProteinTarget)
        XCTAssertEqual(summary.proteinProgress, 1.0, accuracy: accuracy)
        XCTAssertEqual(summary.remaining.protein, 0, accuracy: accuracy)
    }

    func testWaterExactlyAtTarget() {
        let log = DailyNutritionSummaryTestFixtures.waterExactlyAtTargetLog
        let summary = DailyNutritionSummaryBuilder.build(from: log)

        XCTAssertEqual(summary.water.consumedMl, 2_500)
        XCTAssertEqual(summary.water.remainingMl, 0)
        XCTAssertEqual(summary.water.progress, 1.0, accuracy: accuracy)
        XCTAssertTrue(summary.water.hasMetTarget)
        XCTAssertTrue(summary.hasMetWaterTarget)
    }

    func testWaterAboveTarget() {
        let log = DailyNutritionSummaryTestFixtures.caloriesOverTargetLog
        let summary = DailyNutritionSummaryBuilder.build(from: log)

        XCTAssertEqual(summary.water.consumedMl, 2_600)
        XCTAssertEqual(summary.water.targetMl, 2_500)
        XCTAssertEqual(summary.water.remainingMl, 0)
        XCTAssertEqual(summary.water.progress, 1.0, accuracy: accuracy)
        XCTAssertTrue(summary.water.hasMetTarget)
        XCTAssertTrue(summary.hasMetWaterTarget)
    }

    func testZeroMacroTargets() {
        let log = DailyNutritionSummaryTestFixtures.dailyLog(
            targets: UserTargets(
                calorieTarget: 0,
                proteinTarget: 0,
                carbTarget: 0,
                fatTarget: 0,
                waterTargetMl: 0,
                expectedWeeklyWeightLossKg: nil,
                aggressiveness: .moderate
            ),
            totals: MacroTotals(
                calories: 100,
                protein: 10,
                carbs: 20,
                fat: 5,
                fiber: nil,
                sodium: nil
            ),
            waterConsumedMl: 250
        )
        let summary = DailyNutritionSummaryBuilder.build(from: log)

        XCTAssertEqual(summary.calorieProgress, 0, accuracy: accuracy)
        XCTAssertEqual(summary.proteinProgress, 0, accuracy: accuracy)
        XCTAssertEqual(summary.carbProgress, 0, accuracy: accuracy)
        XCTAssertEqual(summary.fatProgress, 0, accuracy: accuracy)
        XCTAssertEqual(summary.water.progress, 0, accuracy: accuracy)
        XCTAssertTrue(summary.hasMetProteinTarget)
        XCTAssertTrue(summary.isOverCalories)
        XCTAssertEqual(summary.remaining.calories, -100)
        XCTAssertTrue(summary.water.hasMetTarget)
    }

    func testParityWithCharacterizedRuntimeOutputs() {
        let logs = [
            DailyNutritionSummaryTestFixtures.baselineLog,
            DailyNutritionSummaryTestFixtures.waterExactlyAtTargetLog,
            DailyNutritionSummaryTestFixtures.waterOneMlBelowTargetLog,
            DailyNutritionSummaryTestFixtures.zeroProteinTargetLog,
            DailyNutritionSummaryTestFixtures.caloriesOverTargetLog
        ]

        for log in logs {
            let summary = DailyNutritionSummaryBuilder.build(from: log)
            let expected = RuntimeNutritionSummaryCharacterization.snapshot(from: log)
            assertParity(summary: summary, expected: expected, log: log)
        }
    }

    private func assertParity(
        summary: DailyNutritionSummary,
        expected: RuntimeNutritionSummaryCharacterization.Snapshot,
        log: DailyLog
    ) {
        XCTAssertEqual(summary.targets.calories, expected.calorieTarget, "calorie target", file: #file, line: #line)
        XCTAssertEqual(summary.totals.calories, expected.caloriesConsumed, "calories consumed", file: #file, line: #line)
        XCTAssertEqual(summary.remaining.calories, expected.caloriesRemaining, "calories remaining", file: #file, line: #line)
        XCTAssertEqual(summary.calorieProgress, expected.calorieProgress, accuracy: accuracy, "calorie progress", file: #file, line: #line)
        XCTAssertEqual(summary.isOverCalories, expected.isOverCalorieTarget, "over calories", file: #file, line: #line)

        XCTAssertEqual(summary.targets.protein, expected.proteinTarget, accuracy: accuracy, "protein target", file: #file, line: #line)
        XCTAssertEqual(summary.totals.protein, expected.proteinConsumed, accuracy: accuracy, "protein consumed", file: #file, line: #line)
        XCTAssertEqual(summary.remaining.protein, expected.proteinRemaining, accuracy: accuracy, "protein remaining", file: #file, line: #line)
        XCTAssertEqual(summary.proteinProgress, expected.proteinProgress, accuracy: accuracy, "protein progress", file: #file, line: #line)
        XCTAssertEqual(summary.hasMetProteinTarget, expected.hasMetProteinTarget, "protein met", file: #file, line: #line)

        XCTAssertEqual(summary.targets.carbs, expected.carbsTarget, accuracy: accuracy, "carbs target", file: #file, line: #line)
        XCTAssertEqual(summary.totals.carbs, expected.carbsConsumed, accuracy: accuracy, "carbs consumed", file: #file, line: #line)
        XCTAssertEqual(summary.remaining.carbs, expected.carbsRemaining, accuracy: accuracy, "carbs remaining", file: #file, line: #line)
        XCTAssertEqual(summary.carbProgress, expected.carbsProgress, accuracy: accuracy, "carbs progress", file: #file, line: #line)

        XCTAssertEqual(summary.targets.fat, expected.fatTarget, accuracy: accuracy, "fat target", file: #file, line: #line)
        XCTAssertEqual(summary.totals.fat, expected.fatConsumed, accuracy: accuracy, "fat consumed", file: #file, line: #line)
        XCTAssertEqual(summary.remaining.fat, expected.fatRemaining, accuracy: accuracy, "fat remaining", file: #file, line: #line)
        XCTAssertEqual(summary.fatProgress, expected.fatProgress, accuracy: accuracy, "fat progress", file: #file, line: #line)

        XCTAssertEqual(summary.water.targetMl, expected.waterTargetMl, "water target", file: #file, line: #line)
        XCTAssertEqual(summary.water.consumedMl, expected.waterConsumedMl, "water consumed", file: #file, line: #line)
        XCTAssertEqual(summary.water.remainingMl, expected.waterRemainingMl, "water remaining", file: #file, line: #line)
        XCTAssertEqual(summary.water.progress, expected.waterProgress, accuracy: accuracy, "water progress", file: #file, line: #line)
        XCTAssertEqual(summary.water.hasMetTarget, expected.hasMetWaterTarget, "water met", file: #file, line: #line)
        XCTAssertEqual(summary.hasMetWaterTarget, expected.hasMetWaterTarget, "summary water met", file: #file, line: #line)

        XCTAssertEqual(summary.totals, log.totals, "totals snapshot", file: #file, line: #line)
        XCTAssertEqual(
            summary.targets,
            MacroCalculator.macroTargets(from: log.targets),
            "targets snapshot",
            file: #file,
            line: #line
        )
    }
}
