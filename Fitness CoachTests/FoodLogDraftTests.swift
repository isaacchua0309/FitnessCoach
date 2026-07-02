//
//  FoodLogDraftTests.swift
//  Fitness CoachTests
//

import XCTest
@testable import Fitness_Coach

final class FoodLogDraftTests: XCTestCase {

    func testMultiComponentMealOmitsLegacyPortion() {
        let meal = sampleBowlMeal()

        XCTAssertTrue(meal.isMultiComponent)
        XCTAssertNil(meal.legacyQuantity)
        XCTAssertNil(meal.legacyUnit)
    }

    func testTotalsAreSumOfComponents() {
        let meal = sampleBowlMeal()

        XCTAssertEqual(meal.totalCalories, 860)
        XCTAssertEqual(meal.totalProtein, 63.5, accuracy: 0.01)
        XCTAssertEqual(meal.totalCarbs, 78, accuracy: 0.01)
        XCTAssertEqual(meal.totalFat, 30.5, accuracy: 0.01)
    }

    func testLegacyDraftConversionClearsMixedMealPortion() {
        let legacy = FoodLogDraftMapper.toLegacyDraft(sampleBowlMeal())

        XCTAssertEqual(legacy.name, "Chicken barley bowl")
        XCTAssertEqual(legacy.calories, 860)
        XCTAssertNil(legacy.quantity)
        XCTAssertNil(legacy.unit)
    }

    func testLegacyFoodDraftResponseMapsToComponents() {
        let draft = FoodDraft(
            mealType: nil,
            name: "Eggs",
            quantity: 2,
            unit: "count",
            calories: 140,
            protein: 12,
            carbs: 1,
            fat: 10,
            fiber: nil,
            sodium: nil,
            source: .aiTextEstimate,
            confidence: .medium,
            imageUrl: nil,
            notes: nil
        )
        let response = AIFoodEstimateResponse(
            foodDrafts: [draft],
            confidence: .medium,
            requiresConfirmation: true
        )

        let meal = FoodLogDraftMapper.primaryMeal(from: response)

        XCTAssertEqual(meal?.components.count, 1)
        XCTAssertEqual(meal?.components.first?.name, "Eggs")
        XCTAssertEqual(meal?.components.first?.quantity, 2)
        XCTAssertEqual(meal?.legacyQuantity, 2)
    }

    func testSanitizePreservesPerComponentPortions() {
        let meal = sampleBowlMeal()
        let sanitized = FoodLogDraftNutritionCompleter.sanitize(meal, hintText: meal.components[0].sourceText ?? "")

        XCTAssertEqual(sanitized.components[0].quantity, 150)
        XCTAssertEqual(sanitized.components[1].quantity, 150)
        XCTAssertEqual(sanitized.components[2].unit, "tbsp")
        XCTAssertNil(sanitized.legacyQuantity)
    }

    func testFoodEntryRoundTripStoresComponentsJSON() {
        let meal = sampleBowlMeal()
        let entry = FoodLogDraftMapper.toFoodEntry(meal, dailyLogId: UUID())

        XCTAssertTrue(entry.isMultiComponent)
        XCTAssertEqual(entry.components?.count, 4)
        XCTAssertEqual(entry.calories, meal.totalCalories)
        XCTAssertNil(entry.quantity)
    }

    private func sampleBowlMeal() -> FoodLogDraft {
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
                    calories: 352,
                    protein: 5,
                    carbs: 42,
                    fat: 14,
                    sourceText: "50–60g tiramisu"
                )
            ],
            confidence: .medium,
            source: .aiTextEstimate
        )
    }
}
