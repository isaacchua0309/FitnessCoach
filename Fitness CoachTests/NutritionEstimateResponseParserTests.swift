//
//  NutritionEstimateResponseParserTests.swift
//  Fitness CoachTests
//

import XCTest
@testable import Fitness_Coach

final class NutritionEstimateResponseParserTests: XCTestCase {

    func testDecodeSuccessBuildsCardState() {
        let response = NutritionEstimateResponse(
            foodName: "Big Mac",
            caloriesKcal: 550,
            proteinGrams: 25,
            carbsGrams: 45,
            fatGrams: 30,
            confidenceLevel: .high,
            coachSummary: "Fits today if portions stay moderate.",
            coachTip: "Skip fries to save calories."
        )

        let outcome = NutritionEstimateResponseParser.parseEstimate(response, dailyLog: nil)
        guard case .estimate(let card) = outcome else {
            return XCTFail("Expected estimate card")
        }

        XCTAssertEqual(card.foodName, "Big Mac")
        XCTAssertEqual(card.caloriesDisplay, "550 kcal")
        XCTAssertTrue(card.hasMacros)
        XCTAssertEqual(card.confidenceLevel, .high)
    }

    func testCopyLimitsApplied() {
        let longSummary = String(repeating: "a", count: 200)
        let response = NutritionEstimateResponse(
            foodName: "Burger",
            caloriesKcal: 500,
            confidenceLevel: .medium,
            coachSummary: longSummary
        )

        let sanitized = NutritionEstimateCopyValidator.sanitize(response)
        XCTAssertLessThanOrEqual(sanitized.coachSummary?.count ?? 0, 121)
    }

    func testFallbackExtractsCaloriesFromText() {
        let outcome = NutritionEstimateResponseParser.parseEstimateFallback(
            from: "A Big Mac has about 550 kcal and 25g protein.",
            prompt: "calories in a Big Mac",
            dailyLog: nil
        )

        guard case .estimate(let card) = outcome else {
            return XCTFail("Expected fallback estimate card")
        }
        XCTAssertEqual(card.caloriesDisplay, "550 kcal")
        XCTAssertEqual(card.confidenceLevel, .low)
    }

    func testFallbackPlainTextMaxFourLines() {
        let paragraph = """
        Line one about food.
        Line two with details.
        Line three continues.
        Line four still going.
        Line five should be dropped.
        """

        let outcome = NutritionEstimateResponseParser.parseEstimateFallback(
            from: paragraph,
            prompt: "unknown food",
            dailyLog: nil
        )

        guard case .plainText(let text) = outcome else {
            return XCTFail("Expected plain text fallback")
        }
        XCTAssertEqual(text.components(separatedBy: "\n").count, 4)
    }
}
