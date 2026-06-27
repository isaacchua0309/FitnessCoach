//
//  TodayDashboardNutritionMapperTests.swift
//  Fitness CoachTests
//
//  Stage A2 — Today dashboard nutrition mapping uses shared DailyNutritionSummaryBuilder.
//

import XCTest
@testable import Fitness_Coach

final class TodayDashboardNutritionMapperTests: XCTestCase {

    private let accuracy = 0.000_1

    func testBaselineLogMatchesCharacterizedRuntimeOutputs() {
        assertParity(for: DailyNutritionSummaryTestFixtures.baselineLog)
    }

    func testOverCaloriesLogMatchesCharacterizedRuntimeOutputs() {
        assertParity(for: DailyNutritionSummaryTestFixtures.caloriesOverTargetLog)
    }

    func testWaterExactlyAtTargetMatchesCharacterizedRuntimeOutputs() {
        assertParity(for: DailyNutritionSummaryTestFixtures.waterExactlyAtTargetLog)
    }

    private func assertParity(for log: DailyLog) {
        let (calorie, macro, water) = TodayDashboardNutritionMapper.maps(from: log)
        let expected = RuntimeNutritionSummaryCharacterization.snapshot(from: log)

        XCTAssertEqual(calorie.consumed, expected.caloriesConsumed)
        XCTAssertEqual(calorie.target, expected.calorieTarget)
        XCTAssertEqual(calorie.remaining, expected.caloriesRemaining)
        XCTAssertEqual(calorie.progress, expected.calorieProgress, accuracy: accuracy)
        XCTAssertEqual(calorie.isOverTarget, expected.isOverCalorieTarget)

        XCTAssertEqual(macro.protein.consumed, expected.proteinConsumed, accuracy: accuracy)
        XCTAssertEqual(macro.protein.target, expected.proteinTarget, accuracy: accuracy)
        XCTAssertEqual(macro.protein.remaining, expected.proteinRemaining, accuracy: accuracy)
        XCTAssertEqual(macro.protein.progress, expected.proteinProgress, accuracy: accuracy)

        XCTAssertEqual(macro.carbs.consumed, expected.carbsConsumed, accuracy: accuracy)
        XCTAssertEqual(macro.carbs.target, expected.carbsTarget, accuracy: accuracy)
        XCTAssertEqual(macro.carbs.remaining, expected.carbsRemaining, accuracy: accuracy)
        XCTAssertEqual(macro.carbs.progress, expected.carbsProgress, accuracy: accuracy)

        XCTAssertEqual(macro.fat.consumed, expected.fatConsumed, accuracy: accuracy)
        XCTAssertEqual(macro.fat.target, expected.fatTarget, accuracy: accuracy)
        XCTAssertEqual(macro.fat.remaining, expected.fatRemaining, accuracy: accuracy)
        XCTAssertEqual(macro.fat.progress, expected.fatProgress, accuracy: accuracy)

        XCTAssertEqual(water.consumedMl, expected.waterConsumedMl)
        XCTAssertEqual(water.targetMl, expected.waterTargetMl)
        XCTAssertEqual(water.remainingMl, expected.waterRemainingMl)
        XCTAssertEqual(water.progress, expected.waterProgress, accuracy: accuracy)
    }
}
