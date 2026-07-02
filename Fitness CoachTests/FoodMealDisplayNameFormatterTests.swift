//
//  FoodMealDisplayNameFormatterTests.swift
//  Fitness CoachTests
//

import XCTest
@testable import Fitness_Coach

final class FoodMealDisplayNameFormatterTests: XCTestCase {

    func testGenericBowlNameBecomesReadableTitle() {
        let components = sampleBowlComponents()
        let name = FoodMealDisplayNameFormatter.readableDisplayName(
            proposed: "bowl with chicken breast, barley rice mix, sesame mayo dressing, tiramisu",
            components: components
        )

        XCTAssertEqual(name, "Chicken barley bowl with tiramisu")
    }

    func testKeepsCustomReadableName() {
        let components = sampleBowlComponents()
        let name = FoodMealDisplayNameFormatter.readableDisplayName(
            proposed: "Chicken barley bowl with tiramisu",
            components: components
        )

        XCTAssertEqual(name, "Chicken barley bowl with tiramisu")
    }

    func testSingleComponentUsesDisplayFoodName() {
        let name = FoodMealDisplayNameFormatter.readableDisplayName(
            proposed: "chicken breast",
            components: [
                FoodComponent(
                    name: "chicken breast",
                    quantity: 150,
                    unit: "g",
                    calories: 248,
                    protein: 46,
                    carbs: 0,
                    fat: 5
                )
            ]
        )

        XCTAssertEqual(name, "Chicken breast")
    }

    private func sampleBowlComponents() -> [FoodComponent] {
        [
            FoodComponent(
                name: "cooked skinless chicken breast",
                quantity: 150,
                unit: "g",
                preparationState: "cooked",
                calories: 248,
                protein: 46.5,
                carbs: 0,
                fat: 5.4
            ),
            FoodComponent(
                name: "cooked barley rice",
                quantity: 150,
                unit: "g",
                preparationState: "cooked",
                calories: 165,
                protein: 4.5,
                carbs: 34,
                fat: 1.1
            ),
            FoodComponent(
                name: "creamy sesame/mayo dressing",
                quantity: 1,
                unit: "tbsp",
                calories: 95,
                protein: 0.5,
                carbs: 2,
                fat: 10
            ),
            FoodComponent(
                name: "tiramisu",
                quantity: 55,
                unit: "g",
                calories: 352,
                protein: 5,
                carbs: 42,
                fat: 14
            )
        ]
    }
}
