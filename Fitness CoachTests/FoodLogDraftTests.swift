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

    func testDecodesLiteralNullMealTypeStringAsNil() throws {
        let json = """
        {
          "displayName": "Chicken rice",
          "mealType": "null",
          "components": [],
          "confidence": "medium",
          "source": "aiTextEstimate"
        }
        """.data(using: .utf8)!

        let draft = try JSONDecoder().decode(FoodLogDraft.self, from: json)
        XCTAssertNil(draft.mealType)
    }

    func testDecodesEmptyMealTypeStringAsNil() throws {
        let json = """
        {
          "displayName": "Chicken rice",
          "mealType": "  ",
          "components": [],
          "confidence": "medium",
          "source": "aiTextEstimate"
        }
        """.data(using: .utf8)!

        let draft = try JSONDecoder().decode(FoodLogDraft.self, from: json)
        XCTAssertNil(draft.mealType)
    }

    func testCreatesWithoutRangeOrTrustFields() {
        let meal = sampleBowlMeal()

        XCTAssertNil(meal.calorieRangeLower)
        XCTAssertNil(meal.calorieRangeUpper)
        XCTAssertTrue(meal.assumptions.isEmpty)
        XCTAssertTrue(meal.uncertaintyReasons.isEmpty)
        XCTAssertTrue(meal.suggestedClarifications.isEmpty)
        XCTAssertNil(meal.primaryUncertainty)
        XCTAssertFalse(meal.requiresClarificationBeforeLogging)
        XCTAssertNil(meal.riskLevel)
        XCTAssertTrue(meal.componentTrustMetadata.isEmpty)
        XCTAssertTrue(meal.isSafeToPresentDirectly)
        XCTAssertNil(meal.calorieRange)
    }

    func testCarriesRangeAndTrustFields() {
        let meal = FoodLogDraft(
            displayName: "Laksa",
            components: [
                FoodComponent(name: "Laksa", calories: 520, protein: 18, carbs: 55, fat: 24)
            ],
            confidence: .low,
            calorieRangeLower: 450,
            calorieRangeUpper: 620,
            assumptions: ["Regular coconut broth"],
            uncertaintyReasons: ["Portion size unclear"],
            suggestedClarifications: ["Was this a large bowl?"],
            primaryUncertainty: "Portion size",
            requiresClarificationBeforeLogging: true,
            riskLevel: .high,
            componentTrustMetadata: [
                ComponentEstimateTrustMetadata(
                    componentName: "Laksa",
                    estimatedCalories: 520,
                    rangeLower: 450,
                    rangeUpper: 620,
                    assumptions: ["Regular coconut broth"],
                    uncertaintyReasons: ["Portion size unclear"]
                )
            ]
        )

        XCTAssertEqual(meal.calorieRangeLower, 450)
        XCTAssertEqual(meal.calorieRangeUpper, 620)
        XCTAssertEqual(meal.assumptions, ["Regular coconut broth"])
        XCTAssertEqual(meal.uncertaintyReasons, ["Portion size unclear"])
        XCTAssertEqual(meal.suggestedClarifications, ["Was this a large bowl?"])
        XCTAssertEqual(meal.primaryUncertainty, "Portion size")
        XCTAssertTrue(meal.requiresClarificationBeforeLogging)
        XCTAssertFalse(meal.isSafeToPresentDirectly)
        XCTAssertEqual(meal.riskLevel, .high)
        XCTAssertEqual(meal.estimateTrust.confidence, .low)
        XCTAssertEqual(meal.calorieRange?.displayText, "450–620 kcal")
    }

    func testDecodesLegacyJSONWithoutTrustFields() throws {
        let json = """
        {
          "displayName": "Chicken rice",
          "components": [
            {
              "name": "Chicken rice",
              "calories": 650,
              "protein": 35,
              "carbs": 75,
              "fat": 20,
              "confidence": "medium"
            }
          ],
          "confidence": "medium",
          "source": "aiTextEstimate"
        }
        """.data(using: .utf8)!

        let draft = try JSONDecoder().decode(FoodLogDraft.self, from: json)

        XCTAssertEqual(draft.totalCalories, 650)
        XCTAssertEqual(draft.committedCalorieTotal, 650)
        XCTAssertNil(draft.calorieRangeLower)
        XCTAssertFalse(draft.requiresClarificationBeforeLogging)
    }

    func testRoundTripsRangeAndTrustFields() throws {
        let original = FoodLogDraft(
            displayName: "Nasi lemak",
            components: [
                FoodComponent(name: "Nasi lemak", calories: 600, protein: 15, carbs: 70, fat: 28)
            ],
            confidence: .medium,
            calorieRangeLower: 520,
            calorieRangeUpper: 700,
            assumptions: ["Standard plate"],
            uncertaintyReasons: ["Sambal amount unknown"],
            suggestedClarifications: ["How spicy was the sambal?"],
            primaryUncertainty: "Sambal amount",
            requiresClarificationBeforeLogging: false,
            riskLevel: .medium
        )

        let data = try JSONEncoder().encode(original)
        let decoded = try JSONDecoder().decode(FoodLogDraft.self, from: data)

        XCTAssertEqual(decoded, original)
        XCTAssertEqual(decoded.committedCalorieTotal, 600)
        XCTAssertEqual(decoded.totalCalories, 600)
    }

    func testDecodesNestedEstimateTrustPayload() throws {
        let json = """
        {
          "displayName": "Bubble tea",
          "components": [],
          "confidence": "medium",
          "source": "aiTextEstimate",
          "calorieRange": {
            "estimated": 350,
            "lowerBound": 300,
            "upperBound": 420
          },
          "estimateTrust": {
            "confidence": "low",
            "assumptions": ["Regular sugar"],
            "uncertaintyReasons": ["Topping count unclear"],
            "suggestedClarifications": ["Which toppings?"],
            "requiresClarificationBeforeLogging": true,
            "primaryUncertainty": "Toppings",
            "riskLevel": "high"
          }
        }
        """.data(using: .utf8)!

        let draft = try JSONDecoder().decode(FoodLogDraft.self, from: json)

        XCTAssertEqual(draft.calorieRangeLower, 300)
        XCTAssertEqual(draft.calorieRangeUpper, 420)
        XCTAssertEqual(draft.confidence, .low)
        XCTAssertEqual(draft.assumptions, ["Regular sugar"])
        XCTAssertTrue(draft.requiresClarificationBeforeLogging)
        XCTAssertEqual(draft.riskLevel, .high)
    }

    func testCommittedCalorieTotalUsesScalarComponentSum() {
        let meal = FoodLogDraft(
            displayName: "Range-only meal",
            components: [
                FoodComponent(name: "Meal", calories: 500, protein: 20, carbs: 50, fat: 15)
            ],
            calorieRangeLower: 400,
            calorieRangeUpper: 650
        )

        XCTAssertEqual(meal.totalCalories, 500)
        XCTAssertEqual(meal.committedCalorieTotal, 500)
        XCTAssertNotEqual(meal.committedCalorieTotal, meal.calorieRangeUpper)
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
