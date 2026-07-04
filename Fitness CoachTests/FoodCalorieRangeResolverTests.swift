//
//  FoodCalorieRangeResolverTests.swift
//  Fitness CoachTests
//

import XCTest
@testable import Fitness_Coach

final class FoodCalorieRangeResolverTests: XCTestCase {

    func testUsesExplicitRangeWhenPresent() {
        let meal = FoodLogDraft(
            displayName: "Chicken rice",
            components: [
                FoodComponent(name: "Chicken rice", calories: 520, protein: 30, carbs: 60, fat: 15)
            ],
            confidence: .medium,
            caloriesRangeLower: 450,
            caloriesRangeUpper: 750
        )

        let range = FoodCalorieRangeResolver.resolvedRange(for: meal)
        XCTAssertEqual(range?.lower, 450)
        XCTAssertEqual(range?.upper, 750)
    }

    func testDerivesRangeFromConfidenceWhenMissing() {
        let meal = FoodLogDraft(
            displayName: "Oatmeal",
            components: [
                FoodComponent(name: "Oatmeal", calories: 300, protein: 8, carbs: 45, fat: 6)
            ],
            confidence: .medium
        )

        let range = FoodCalorieRangeResolver.resolvedRange(for: meal)
        XCTAssertEqual(range?.lower, 264)
        XCTAssertEqual(range?.upper, 336)
    }

    func testFillMissingRangesWritesDerivedBounds() {
        let meal = FoodLogDraft(
            displayName: "Kopi o",
            components: [
                FoodComponent(name: "Kopi o", calories: 100, protein: 0, carbs: 10, fat: 2)
            ],
            confidence: .high
        )

        let filled = FoodCalorieRangeResolver.fillMissingRanges(meal)
        XCTAssertEqual(filled.caloriesRangeLower, 95)
        XCTAssertEqual(filled.caloriesRangeUpper, 105)
    }

    func testDecodesBackwardCompatibleDraftWithoutRangeFields() throws {
        let json = """
        {
          "displayName": "Eggs",
          "components": [{
            "name": "eggs",
            "calories": 140,
            "protein": 12,
            "carbs": 1,
            "fat": 10
          }],
          "confidence": "medium",
          "source": "aiTextEstimate"
        }
        """.data(using: .utf8)!

        let draft = try JSONDecoder().decode(FoodLogDraft.self, from: json)
        XCTAssertNil(draft.caloriesRangeLower)
        XCTAssertNil(draft.caloriesRangeUpper)
        XCTAssertTrue(draft.assumptions.isEmpty)
    }
}
