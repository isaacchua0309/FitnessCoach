//
//  FoodEstimateTrustNormalizerTests.swift
//  Fitness CoachTests
//

import XCTest
@testable import Fitness_Coach

final class FoodEstimateTrustNormalizerTests: XCTestCase {

    func testDecodesResponseWithRangeFields() throws {
        let json = """
        {
          "foodLogDrafts": [{
            "displayName": "Chicken rice",
            "components": [{
              "name": "Chicken rice",
              "calories": 650,
              "protein": 35,
              "carbs": 75,
              "fat": 20,
              "confidence": "medium",
              "sourceText": "hawker chicken rice"
            }],
            "confidence": "medium",
            "source": "aiTextEstimate",
            "calorieRangeLower": 580,
            "calorieRangeUpper": 720,
            "assumptions": ["Standard plate"],
            "uncertaintyReasons": ["Rice amount unclear"],
            "suggestedClarifications": ["Large plate?"],
            "primaryUncertainty": "Rice amount",
            "requiresClarificationBeforeLogging": true
          }],
          "foodDrafts": [],
          "confidence": "medium",
          "requiresConfirmation": true
        }
        """.data(using: .utf8)!

        let response = try JSONDecoder().decode(AIFoodEstimateResponse.self, from: json)
        let meal = try XCTUnwrap(FoodLogDraftMapper.primaryMeal(from: response, prompt: "log chicken rice"))

        XCTAssertEqual(meal.totalCalories, 650)
        XCTAssertEqual(meal.calorieRangeLower, 580)
        XCTAssertEqual(meal.calorieRangeUpper, 720)
        XCTAssertEqual(meal.assumptions, ["Standard plate"])
        XCTAssertEqual(meal.uncertaintyReasons, ["Rice amount unclear"])
        XCTAssertTrue(meal.requiresClarificationBeforeLogging)
    }

    func testDecodesLegacyResponseWithoutRangeFields() throws {
        let json = """
        {
          "foodLogDrafts": [{
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
          }],
          "foodDrafts": [],
          "confidence": "medium",
          "requiresConfirmation": true
        }
        """.data(using: .utf8)!

        let response = try JSONDecoder().decode(AIFoodEstimateResponse.self, from: json)
        let meal = try XCTUnwrap(FoodLogDraftMapper.primaryMeal(from: response, prompt: "2 eggs"))

        XCTAssertEqual(meal.totalCalories, 140)
        XCTAssertNotNil(meal.calorieRangeLower)
        XCTAssertNotNil(meal.calorieRangeUpper)
        XCTAssertGreaterThan(meal.calorieRangeUpper!, meal.calorieRangeLower!)
    }

    func testDecodesTotalCaloriesRangeAliases() throws {
        let json = """
        {
          "displayName": "Laksa",
          "components": [{
            "name": "Laksa",
            "calories": 520,
            "protein": 18,
            "carbs": 55,
            "fat": 24
          }],
          "confidence": "medium",
          "source": "aiTextEstimate",
          "totalCaloriesRangeLower": 470,
          "totalCaloriesRangeUpper": 610
        }
        """.data(using: .utf8)!

        let draft = try JSONDecoder().decode(FoodLogDraft.self, from: json)

        XCTAssertEqual(draft.calorieRangeLower, 470)
        XCTAssertEqual(draft.calorieRangeUpper, 610)
    }

    func testMapsBackendFieldsIntoFoodLogDraft() {
        let meal = FoodLogDraft(
            displayName: "Nasi lemak",
            components: [
                FoodComponent(name: "Nasi lemak", calories: 600, protein: 15, carbs: 70, fat: 28)
            ],
            confidence: .low,
            assumptions: ["Standard plate"],
            uncertaintyReasons: [],
            suggestedClarifications: ["How much sambal?"],
            primaryUncertainty: "Sambal amount",
            requiresClarificationBeforeLogging: true
        )

        let normalized = FoodEstimateTrustNormalizer.normalize(meal)

        XCTAssertEqual(normalized.totalCalories, 600)
        XCTAssertNotNil(normalized.calorieRangeLower)
        XCTAssertNotNil(normalized.calorieRangeUpper)
        XCTAssertEqual(normalized.assumptions, ["Standard plate"])
        XCTAssertTrue(normalized.uncertaintyReasons.contains("Portion size is unclear."))
        XCTAssertEqual(normalized.suggestedClarifications, ["How much sambal?"])
        XCTAssertTrue(normalized.requiresClarificationBeforeLogging)
    }

    func testDerivesFallbackRangeWhenMissing() {
        let meal = FoodLogDraft(
            displayName: "Oatmeal",
            components: [
                FoodComponent(name: "Oatmeal", calories: 300, protein: 8, carbs: 45, fat: 6, confidence: .medium)
            ],
            confidence: .medium
        )

        let normalized = FoodEstimateTrustNormalizer.normalize(meal)

        XCTAssertEqual(normalized.calorieRangeLower, 232)
        XCTAssertEqual(normalized.calorieRangeUpper, 368)
    }

    func testRepairsInvalidRangeAndAddsWarning() {
        let meal = FoodLogDraft(
            displayName: "Salad",
            components: [
                FoodComponent(name: "Salad", calories: 500, protein: 20, carbs: 40, fat: 25, confidence: .medium)
            ],
            confidence: .medium,
            calorieRangeLower: 700,
            calorieRangeUpper: 400
        )

        let normalized = FoodEstimateTrustNormalizer.normalize(meal)

        XCTAssertLessThanOrEqual(normalized.calorieRangeLower!, 500)
        XCTAssertGreaterThanOrEqual(normalized.calorieRangeUpper!, 500)
        XCTAssertTrue(normalized.warnings.contains(where: { $0.localizedCaseInsensitiveContains("repaired") || $0.localizedCaseInsensitiveContains("reversed") }))
    }

    func testAddsHiddenSauceUncertaintyWhenLikely() {
        let meal = FoodLogDraft(
            displayName: "Chicken rice",
            components: [
                FoodComponent(
                    name: "chili sauce and chicken oil",
                    calories: 70,
                    protein: 0,
                    carbs: 2,
                    fat: 7,
                    confidence: .medium,
                    sourceText: "1 tbsp chili sauce and chicken oil"
                )
            ],
            confidence: .medium
        )

        let normalized = FoodEstimateTrustNormalizer.normalize(meal, prompt: "log chicken rice with chili sauce")

        XCTAssertTrue(
            normalized.uncertaintyReasons.contains(where: {
                $0.localizedCaseInsensitiveContains("sauce") || $0.localizedCaseInsensitiveContains("oil")
            })
        )
    }

    func testImageAnalysisMapsAssumptionsAndUncertaintyIntoPendingDraft() {
        let response = AIMealImageAnalysisResponse(
            summary: "Chicken rice plate",
            items: [
                AIMealImageAnalysisItem(
                    name: "Chicken rice",
                    quantity: "1 plate",
                    calories: 650,
                    protein: 35,
                    carbs: 75,
                    fat: 20,
                    confidence: .low,
                    assumptions: ["Standard hawker portion"],
                    uncertaintyReasons: ["Rice amount unclear"],
                    suggestedClarifications: ["Was this a large plate?"],
                    primaryUncertainty: "Rice amount",
                    calorieRangeLower: 580,
                    calorieRangeUpper: 720
                )
            ],
            total: AIMealImageAnalysisTotals(
                calories: 650,
                protein: 35,
                carbs: 75,
                fat: 20,
                calorieRangeLower: 580,
                calorieRangeUpper: 720
            ),
            needsUserReview: true,
            clarifyingQuestion: "Was this a large plate?",
            primaryUncertainty: "Rice amount"
        )

        let draft = MealImageAnalysisMapper.foodLogDraft(from: response)

        XCTAssertEqual(draft.assumptions, ["Standard hawker portion"])
        XCTAssertTrue(draft.uncertaintyReasons.contains(where: { $0.contains("Rice amount unclear") }))
        XCTAssertEqual(draft.calorieRangeLower, 580)
        XCTAssertEqual(draft.calorieRangeUpper, 720)
        XCTAssertTrue(draft.requiresClarificationBeforeLogging)
    }

    func testRecommissionPreservesTrustMetadata() {
        let draft = FoodLogDraft(
            displayName: "Grain bowl",
            components: [
                FoodComponent(
                    name: "Grain bowl",
                    quantity: 1,
                    unit: "bowl",
                    calories: 400,
                    protein: 16,
                    carbs: 52,
                    fat: 10,
                    confidence: .low,
                    sourceText: "Looked like quinoa",
                    estimateTrustMetadata: ComponentEstimateTrustMetadata(
                        componentName: "Grain bowl",
                        estimatedCalories: 400,
                        rangeLower: 340,
                        rangeUpper: 470,
                        assumptions: ["Looked like quinoa"],
                        uncertaintyReasons: ["Grain type unclear"]
                    )
                )
            ],
            confidence: .low,
            calorieRangeLower: 340,
            calorieRangeUpper: 470,
            assumptions: ["Looked like quinoa"],
            uncertaintyReasons: ["Grain type unclear"],
            suggestedClarifications: ["Was it barley or quinoa?"],
            primaryUncertainty: "Grain type",
            requiresClarificationBeforeLogging: true
        )

        let result = ImageAnalysisSessionResult(
            mealDraft: draft,
            confidence: .low,
            summary: "Grain bowl",
            clarifyingQuestion: "Was it barley or quinoa?"
        )

        let previous = MealImageAnalysisMapper.previousAnalysis(from: result)

        XCTAssertEqual(previous.total.calorieRangeLower, 340)
        XCTAssertEqual(previous.total.calorieRangeUpper, 470)
        XCTAssertEqual(previous.items.first?.calorieRangeLower, 340)
        XCTAssertEqual(previous.items.first?.uncertaintyReasons, ["Grain type unclear"])
        XCTAssertEqual(previous.items.first?.suggestedClarifications, ["Was it barley or quinoa?"])
        XCTAssertEqual(previous.items.first?.primaryUncertainty, "Grain type unclear")
    }

    func testSanitizeFoodEstimateResponseNormalizesDrafts() {
        let response = AIFoodEstimateResponse(
            foodLogDrafts: [
                FoodLogDraft(
                    displayName: "Kopi o",
                    components: [
                        FoodComponent(name: "Kopi o", calories: 100, protein: 0, carbs: 10, fat: 2, confidence: .high)
                    ],
                    confidence: .high
                )
            ],
            confidence: .high,
            requiresConfirmation: true
        )

        let sanitized = FoodEstimateResponseValidator.sanitize(response: response, prompt: "kopi o")

        XCTAssertNotNil(sanitized.foodLogDrafts.first?.calorieRangeLower)
        XCTAssertNotNil(sanitized.foodLogDrafts.first?.calorieRangeUpper)
    }
}
