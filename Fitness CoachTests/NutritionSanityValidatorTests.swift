//
//  NutritionSanityValidatorTests.swift
//  Fitness CoachTests
//

import XCTest
@testable import Fitness_Coach

final class NutritionSanityValidatorTests: XCTestCase {

    func testAcceptableMealPassesValidation() {
        let meal = validBowlMeal()
        let result = NutritionSanityValidator.validate(
            meal: meal,
            prompt: bowlPrompt,
            confidence: .high
        )

        XCTAssertTrue(result.isAcceptable)
        XCTAssertTrue(result.issues.isEmpty)
        XCTAssertEqual(result.confidence, .high)
        XCTAssertNil(result.mealDraft.warnings.first {
            $0 == NutritionSanityResult.underEstimatedUserMessage
        })
    }

    func testMacroMismatchFlagsComponent() {
        let meal = FoodLogDraft(
            displayName: "Eggs",
            components: [
                FoodComponent(
                    name: "eggs",
                    quantity: 2,
                    unit: "count",
                    calories: 300,
                    protein: 10,
                    carbs: 2,
                    fat: 5
                )
            ],
            confidence: .high,
            source: .aiTextEstimate
        )

        let result = NutritionSanityValidator.validate(
            meal: meal,
            prompt: "log 2 eggs",
            confidence: .high
        )

        XCTAssertFalse(result.isAcceptable)
        XCTAssertTrue(result.issues.contains(where: { $0.contains("Macro calories") }))
        XCTAssertEqual(result.confidence, .low)
    }

    func testCookedChickenBreast150gTooLowProteinAndCalories() {
        let meal = FoodLogDraft(
            displayName: "Chicken bowl",
            components: [
                FoodComponent(
                    name: "cooked skinless chicken breast",
                    quantity: 150,
                    unit: "g",
                    preparationState: "cooked",
                    calories: 180,
                    protein: 28,
                    carbs: 0,
                    fat: 4,
                    sourceText: "150 g cooked skinless chicken breast"
                )
            ],
            confidence: .high,
            source: .aiTextEstimate
        )

        let result = NutritionSanityValidator.validate(
            meal: meal,
            prompt: bowlPrompt,
            confidence: .high
        )

        XCTAssertFalse(result.isAcceptable)
        XCTAssertTrue(result.issues.contains(where: { $0.contains("chicken breast protein") }))
        XCTAssertTrue(result.issues.contains(where: { $0.contains("chicken breast calories") }))
        XCTAssertEqual(result.confidence, .low)
        XCTAssertTrue(result.mealDraft.warnings.contains(NutritionSanityResult.underEstimatedUserMessage))
    }

    func testDessertFatTooLowIsFlagged() {
        let meal = FoodLogDraft(
            displayName: "Dessert",
            components: [
                FoodComponent(
                    name: "tiramisu",
                    quantity: 55,
                    unit: "g",
                    calories: 220,
                    protein: 4,
                    carbs: 28,
                    fat: 2,
                    sourceText: "50-60g tiramisu"
                )
            ],
            confidence: .medium,
            source: .aiTextEstimate
        )

        let result = NutritionSanityValidator.validate(
            meal: meal,
            prompt: "log 55g tiramisu",
            confidence: .medium
        )

        XCTAssertFalse(result.isAcceptable)
        XCTAssertTrue(result.issues.contains(where: { $0.contains("dessert") }))
        XCTAssertEqual(result.confidence, .low)
    }

    func testCreamyDressingFatTooLowIsFlagged() {
        let meal = FoodLogDraft(
            displayName: "Salad",
            components: [
                FoodComponent(
                    name: "creamy sesame mayo dressing",
                    quantity: 1,
                    unit: "tbsp",
                    calories: 35,
                    protein: 0,
                    carbs: 1,
                    fat: 1,
                    sourceText: "1 tbsp creamy sesame/mayo dressing"
                )
            ],
            confidence: .high,
            source: .aiTextEstimate
        )

        let result = NutritionSanityValidator.validate(
            meal: meal,
            prompt: "log 1 tbsp creamy sesame mayo dressing",
            confidence: .high
        )

        XCTAssertFalse(result.isAcceptable)
        XCTAssertTrue(result.issues.contains(where: { $0.contains("dressing") }))
        XCTAssertEqual(result.confidence, .low)
    }

    func testMultiComponentTotalBelowMinimumFloor() {
        let meal = underestimatedBowlMeal()

        let result = NutritionSanityValidator.validate(
            meal: meal,
            prompt: bowlPrompt,
            confidence: .high
        )

        XCTAssertFalse(result.isAcceptable)
        XCTAssertTrue(
            result.issues.contains(where: { $0.contains("sum of obvious component minimums") })
            || result.issues.contains(where: { $0.contains("Mixed meal with chicken") })
        )
        XCTAssertEqual(result.confidence, .low)
        XCTAssertTrue(result.mealDraft.warnings.contains(NutritionSanityResult.underEstimatedUserMessage))
    }

    func testCompositeMixedMealBelow550IsFlagged() {
        let meal = underestimatedBowlMeal()

        let result = NutritionSanityValidator.validate(
            meal: meal,
            prompt: bowlPrompt,
            confidence: .high
        )

        XCTAssertFalse(result.isAcceptable)
        XCTAssertTrue(result.issues.contains(where: { $0.contains("Mixed meal with chicken") }))
        XCTAssertLessThan(meal.totalCalories, 550)
        XCTAssertEqual(result.confidence, .low)
    }

    func testHighConfidenceIsDowngradedWhenSanityFails() {
        let meal = underestimatedBowlMeal()

        let result = NutritionSanityValidator.validate(
            meal: meal,
            prompt: bowlPrompt,
            confidence: .high
        )

        XCTAssertEqual(result.confidence, .low)
        XCTAssertEqual(result.mealDraft.confidence, .low)
    }

    // MARK: - Fixtures

    private let bowlPrompt = """
    log this bowl:
    - 150 g cooked skinless chicken breast
    - 150 g cooked barley rice
    - 1 tbsp creamy sesame/mayo dressing
    - 50-60 g tiramisu
    """

    private func underestimatedBowlMeal() -> FoodLogDraft {
        FoodLogDraft(
            displayName: "bowl with chicken breast, barley rice mix, sesame/mayo dressing, and tiramisu",
            components: [
                FoodComponent(
                    name: "cooked skinless chicken breast",
                    quantity: 150,
                    unit: "g",
                    preparationState: "cooked",
                    calories: 165,
                    protein: 31,
                    carbs: 0,
                    fat: 3.6,
                    sourceText: "150 g cooked skinless chicken breast"
                ),
                FoodComponent(
                    name: "cooked barley rice",
                    quantity: 150,
                    unit: "g",
                    preparationState: "cooked",
                    calories: 130,
                    protein: 3,
                    carbs: 28,
                    fat: 1,
                    sourceText: "150 g cooked barley rice"
                ),
                FoodComponent(
                    name: "creamy sesame/mayo dressing",
                    quantity: 1,
                    unit: "tbsp",
                    calories: 35,
                    protein: 0,
                    carbs: 1,
                    fat: 1,
                    sourceText: "1 tbsp creamy sesame/mayo dressing"
                ),
                FoodComponent(
                    name: "tiramisu",
                    quantity: 55,
                    unit: "g",
                    calories: 100,
                    protein: 2,
                    carbs: 13,
                    fat: 3.4,
                    sourceText: "50-60 g tiramisu"
                )
            ],
            confidence: .high,
            source: .aiTextEstimate
        )
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
                    protein: 46.5,
                    carbs: 0,
                    fat: 5.4,
                    sourceText: "150 g cooked skinless chicken breast"
                ),
                FoodComponent(
                    name: "cooked barley rice",
                    quantity: 150,
                    unit: "g",
                    preparationState: "cooked",
                    calories: 165,
                    protein: 4.5,
                    carbs: 34,
                    fat: 1.1,
                    sourceText: "150 g cooked barley rice"
                ),
                FoodComponent(
                    name: "creamy sesame/mayo dressing",
                    quantity: 1,
                    unit: "tbsp",
                    calories: 95,
                    protein: 0.5,
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
