//
//  FoodComponentDisplayFormatterTests.swift
//  Fitness CoachTests
//

import XCTest
@testable import Fitness_Coach

final class FoodComponentDisplayFormatterTests: XCTestCase {

    func testPortionLineIncludesQuantityUnitAndPreparation() {
        let component = FoodComponent(
            name: "cooked skinless chicken breast",
            quantity: 150,
            unit: "g",
            preparationState: "cooked",
            calories: 248,
            protein: 46.5,
            carbs: 0,
            fat: 5.4
        )

        XCTAssertEqual(
            FoodComponentDisplayFormatter.portionLine(component),
            "Chicken breast — 150g cooked"
        )
    }

    func testPortionLineFormatsTablespoonWithoutPreparation() {
        let component = FoodComponent(
            name: "creamy sesame/mayo dressing",
            quantity: 1,
            unit: "tbsp",
            calories: 95,
            protein: 0.5,
            carbs: 2,
            fat: 10
        )

        XCTAssertEqual(
            FoodComponentDisplayFormatter.portionLine(component),
            "Sesame/mayo dressing — 1 tbsp"
        )
    }

    func testSummaryLineIncludesCalories() {
        let component = FoodComponent(
            name: "barley rice",
            quantity: 150,
            unit: "g",
            preparationState: "cooked",
            calories: 165,
            protein: 4.5,
            carbs: 34,
            fat: 1.1
        )

        XCTAssertEqual(
            FoodComponentDisplayFormatter.summaryLine(component),
            "• Barley rice — 150g cooked · 165 kcal"
        )
    }
}
