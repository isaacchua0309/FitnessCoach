//
//  NutritionEstimateContextBuilderTests.swift
//  Fitness CoachTests
//

import XCTest
@testable import Fitness_Coach

final class NutritionEstimateContextBuilderTests: XCTestCase {

    func testTodayContextCalculation() {
        let log = DailyLogFixtures.dailyLog(
            targets: UserTargets(
                calorieTarget: 2_086,
                proteinTarget: 198,
                carbTarget: 200,
                fatTarget: 65,
                waterTargetMl: 2_500,
                expectedWeeklyWeightLossKg: nil,
                aggressiveness: .moderate
            ),
            totals: MacroTotals(
                calories: 1_000,
                protein: 80,
                carbs: 100,
                fat: 35,
                fiber: nil,
                sodium: nil
            ),
            waterConsumedMl: 1_000
        )

        var response = NutritionEstimateResponse(
            foodName: "Big Mac",
            caloriesKcal: 550,
            proteinGrams: 25,
            confidenceLevel: .high
        )
        response = NutritionEstimateContextBuilder.enrich(response, dailyLog: log)

        let today = NutritionEstimateContextBuilder.todayContext(from: response)
        XCTAssertNotNil(today)
        XCTAssertTrue(today?.caloriesAfterLine.contains("1,550") == true)
        XCTAssertTrue(today?.proteinLine.contains("105") == true)
    }

    func testNilLogHidesTodayContext() {
        let response = NutritionEstimateResponse(
            foodName: "Burger",
            caloriesKcal: 500,
            confidenceLevel: .medium
        )

        let today = NutritionEstimateContextBuilder.todayContext(
            from: NutritionEstimateContextBuilder.enrich(response, dailyLog: nil)
        )
        XCTAssertNil(today)
    }
}
