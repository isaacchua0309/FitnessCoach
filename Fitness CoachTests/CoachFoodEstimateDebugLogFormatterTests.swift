//
//  CoachFoodEstimateDebugLogFormatterTests.swift
//  Fitness CoachTests
//

import XCTest
@testable import Fitness_Coach

final class CoachFoodEstimateDebugLogFormatterTests: XCTestCase {

    func testComponentsSummaryFormatsPortionAndMacros() {
        let components = [
            FoodComponent(
                name: "cooked chicken breast",
                quantity: 150,
                unit: "g",
                preparationState: "cooked",
                calories: 248,
                protein: 46.5,
                carbs: 0,
                fat: 5.4,
                sourceText: "150g cooked chicken breast"
            )
        ]

        let summary = CoachFoodEstimateDebugLogFormatter.componentsSummary(components)

        XCTAssertTrue(summary.contains("cooked chicken breast"))
        XCTAssertTrue(summary.contains("150g"))
        XCTAssertTrue(summary.contains("cooked"))
        XCTAssertTrue(summary.contains("248kcal"))
    }

    func testTotalsSummaryUsesMealTotals() {
        let meal = FoodLogDraft(
            displayName: "Bowl",
            components: [
                FoodComponent(
                    name: "chicken",
                    quantity: 150,
                    unit: "g",
                    calories: 248,
                    protein: 46,
                    carbs: 0,
                    fat: 5
                ),
                FoodComponent(
                    name: "rice",
                    quantity: 150,
                    unit: "g",
                    calories: 165,
                    protein: 4,
                    carbs: 34,
                    fat: 1
                )
            ],
            confidence: .high,
            source: .aiTextEstimate
        )

        let summary = CoachFoodEstimateDebugLogFormatter.totalsSummary(for: meal)

        XCTAssertTrue(summary.contains("cal=413"))
        XCTAssertTrue(summary.contains("P=50"))
    }

    func testSanitySummaryIncludesIssuesWhenFlagged() {
        let meal = FoodLogDraft(
            displayName: "Bowl",
            components: [
                FoodComponent(
                    name: "bowl",
                    quantity: 150,
                    unit: "g",
                    calories: 430,
                    protein: 38,
                    carbs: 42,
                    fat: 9
                )
            ],
            confidence: .low,
            source: .aiTextEstimate,
            warnings: [NutritionSanityResult.underEstimatedUserMessage]
        )
        let result = NutritionSanityResult(
            isAcceptable: false,
            issues: ["Mixed meal with chicken, grain, dressing, and dessert looks under-estimated."],
            mealDraft: meal,
            confidence: .low
        )

        let summary = CoachFoodEstimateDebugLogFormatter.sanitySummary(result)

        XCTAssertTrue(summary.contains("flagged"))
        XCTAssertTrue(summary.contains("confidence=low"))
        XCTAssertTrue(summary.contains("under-estimated"))
    }
}
