//
//  FoodEstimateResponseValidatorTests.swift
//  Fitness CoachTests
//

import XCTest
@testable import Fitness_Coach

final class FoodEstimateResponseValidatorTests: XCTestCase {

    private let bowlPrompt = """
    log this bowl:
    - 150 g cooked skinless chicken breast
    - 150 g cooked barley rice
    - 1 tbsp creamy sesame/mayo dressing
    - 50-60 g tiramisu
    """

    func testValidMultiComponentResponsePasses() {
        let response = AIFoodEstimateResponse(
            foodLogDrafts: [validBowlMeal()],
            confidence: .high,
            requiresConfirmation: true
        )

        let result = FoodEstimateResponseValidator.validate(response: response, prompt: bowlPrompt)
        XCTAssertTrue(result.isValid)
    }

    func testCollapsedSingleComponentFailsValidation() {
        let response = AIFoodEstimateResponse(
            foodLogDrafts: [
                FoodLogDraft(
                    displayName: "bowl",
                    components: [
                        FoodComponent(
                            name: "generic bowl",
                            quantity: 150,
                            unit: "g",
                            calories: 430,
                            protein: 38,
                            carbs: 42,
                            fat: 9,
                            sourceText: "log this bowl"
                        )
                    ],
                    confidence: .high,
                    source: .aiTextEstimate
                )
            ],
            confidence: .high,
            requiresConfirmation: true
        )

        let result = FoodEstimateResponseValidator.validate(response: response, prompt: bowlPrompt)
        XCTAssertFalse(result.isValid)
        XCTAssertTrue(result.errors.contains(where: { $0.contains("collapsed") }))
    }

    func testMismatchedTotalsFailValidation() {
        var meal = validBowlMeal()
        meal.components[0].calories = 100
        let response = AIFoodEstimateResponse(
            foodLogDrafts: [meal],
            confidence: .high,
            requiresConfirmation: true
        )

        let result = FoodEstimateResponseValidator.validate(response: response, prompt: bowlPrompt)
        XCTAssertFalse(result.isValid)
        XCTAssertTrue(result.errors.contains(where: { $0.contains("total calories") }))
    }

    func testRepairPromptIncludesValidationErrors() {
        let prompt = FoodEstimateResponseValidator.repairPrompt(
            original: bowlPrompt,
            errors: ["Meal collapsed 4 listed ingredients into 1 component(s)."]
        )

        XCTAssertTrue(prompt.contains("REPAIR REQUIRED"))
        XCTAssertTrue(prompt.contains(bowlPrompt))
        XCTAssertTrue(prompt.contains("collapsed"))
    }

    private func validBowlMeal() -> FoodLogDraft {
        FoodLogDraft(
            displayName: "Chicken barley bowl",
            components: [
                FoodComponent(
                    name: "cooked skinless chicken breast",
                    quantity: 150,
                    unit: "g",
                    preparationState: "cooked",
                    calories: 248,
                    protein: 46,
                    carbs: 0,
                    fat: 5,
                    sourceText: "150 g cooked skinless chicken breast"
                ),
                FoodComponent(
                    name: "cooked barley rice",
                    quantity: 150,
                    unit: "g",
                    preparationState: "cooked",
                    calories: 165,
                    protein: 4,
                    carbs: 34,
                    fat: 1,
                    sourceText: "150 g cooked barley rice"
                ),
                FoodComponent(
                    name: "creamy sesame/mayo dressing",
                    quantity: 1,
                    unit: "tbsp",
                    calories: 95,
                    protein: 0,
                    carbs: 2,
                    fat: 10,
                    sourceText: "1 tbsp creamy sesame/mayo dressing"
                ),
                FoodComponent(
                    name: "tiramisu",
                    quantity: 55,
                    unit: "g",
                    calories: 180,
                    protein: 4,
                    carbs: 18,
                    fat: 10,
                    sourceText: "50-60 g tiramisu"
                )
            ],
            confidence: .high,
            source: .aiTextEstimate
        )
    }
}
