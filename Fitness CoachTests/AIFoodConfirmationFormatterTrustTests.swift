//
//  AIFoodConfirmationFormatterTrustTests.swift
//  Fitness CoachTests
//

import XCTest
@testable import Fitness_Coach

final class AIFoodConfirmationFormatterTrustTests: XCTestCase {

    func testCaloriesDisplayUsesRangeWhenPresent() {
        let meal = FoodLogDraft(
            displayName: "Chicken rice",
            components: [
                FoodComponent(name: "Chicken rice", calories: 520, protein: 30, carbs: 60, fat: 15)
            ],
            confidence: .medium,
            assumptions: ["Medium plate portion"],
            caloriesRangeLower: 450,
            caloriesRangeUpper: 750
        )

        XCTAssertEqual(
            AIFoodConfirmationFormatter.caloriesDisplay(for: meal),
            "450–750 kcal"
        )
        XCTAssertEqual(
            AIFoodConfirmationFormatter.compactCaloriesDisplay(for: meal),
            "450–750 kcal"
        )
    }

    func testCaloriesDisplayFallsBackToScalarEstimate() {
        let meal = FoodLogDraft(
            displayName: "Kopi o",
            components: [
                FoodComponent(name: "Kopi o", calories: 100, protein: 0, carbs: 10, fat: 2)
            ],
            confidence: .high
        )

        XCTAssertEqual(
            AIFoodConfirmationFormatter.caloriesDisplay(for: meal),
            "95–105 kcal"
        )
    }

    func testAssumptionLinesIncludeMealAndComponentAssumptions() {
        let meal = FoodLogDraft(
            displayName: "Salad",
            components: [
                FoodComponent(
                    name: "dressing",
                    calories: 90,
                    protein: 0,
                    carbs: 2,
                    fat: 9,
                    sourceText: "1 tbsp sesame dressing"
                )
            ],
            assumptions: ["Regular bowl size"],
            confidence: .medium
        )

        let lines = AIFoodConfirmationFormatter.explicitAssumptionSection(for: meal)
        XCTAssertTrue(lines.contains("Assumption: Regular bowl size"))
        XCTAssertTrue(lines.contains(where: { $0.contains("dressing") }))
    }
}
