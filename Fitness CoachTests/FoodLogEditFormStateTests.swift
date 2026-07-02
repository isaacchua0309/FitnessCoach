//
//  FoodLogEditFormStateTests.swift
//  Fitness CoachTests
//

import XCTest
@testable import Fitness_Coach

final class FoodLogEditFormStateTests: XCTestCase {

    func testMultiComponentFormUsesReadableNameAndTotalFields() {
        let meal = sampleBowlMeal(
            displayName: "bowl with chicken breast, barley rice mix, dressing, tiramisu"
        )
        let form = FoodLogEditFormState(mealDraft: meal)

        XCTAssertTrue(form.isMultiComponent)
        XCTAssertEqual(form.displayName, "Chicken barley bowl with tiramisu")
        XCTAssertEqual(form.totalCaloriesText, "860")
        XCTAssertEqual(form.componentStates.count, 4)
        XCTAssertEqual(
            form.componentStates[0].portionLine,
            "Chicken breast — 150g cooked"
        )
    }

    func testMultiComponentSaveScalesTotalsAndPreservesComponentMetadata() throws {
        let original = sampleBowlMeal(displayName: "Chicken barley bowl with tiramisu")
        var form = FoodLogEditFormState(mealDraft: original)
        form.totalCaloriesText = "900"
        form.totalProteinText = "70"
        form.totalCarbsText = "80"
        form.totalFatText = "32"

        let saved = try form.makeMealDraft(original: original)

        XCTAssertEqual(saved.totalCalories, 900)
        XCTAssertEqual(saved.totalProtein, 70, accuracy: 0.01)
        XCTAssertEqual(saved.totalCarbs, 80, accuracy: 0.01)
        XCTAssertEqual(saved.totalFat, 32, accuracy: 0.01)
        XCTAssertEqual(saved.components.count, 4)
        XCTAssertEqual(saved.components[0].name, original.components[0].name)
        XCTAssertEqual(saved.components[0].quantity, 150)
        XCTAssertEqual(saved.components[0].unit, "g")
        XCTAssertEqual(saved.components[2].unit, "tbsp")
        XCTAssertEqual(saved.source, .corrected)
    }

    func testSingleComponentSaveStillEditsPortionAndMacros() throws {
        let original = FoodLogDraft(
            displayName: "Chicken rice",
            components: [
                FoodComponent(
                    name: "Chicken rice",
                    quantity: 1,
                    unit: "plate",
                    calories: 650,
                    protein: 35,
                    carbs: 75,
                    fat: 20
                )
            ],
            confidence: .medium,
            source: .aiTextEstimate
        )
        var form = FoodLogEditFormState(mealDraft: original)
        form.componentStates[0].caloriesText = "700"

        let saved = try form.makeMealDraft(original: original)

        XCTAssertEqual(saved.totalCalories, 700)
        XCTAssertEqual(saved.components.count, 1)
        XCTAssertEqual(saved.source, .corrected)
    }

    private func sampleBowlMeal(displayName: String) -> FoodLogDraft {
        FoodLogDraft(
            displayName: displayName,
            components: [
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
            ],
            confidence: .medium,
            source: .aiTextEstimate
        )
    }
}
