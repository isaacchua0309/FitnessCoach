//
//  CoachEstimateTrustMapperTests.swift
//  Fitness CoachTests
//

import XCTest
@testable import Fitness_Coach

final class CoachEstimateTrustMapperTests: XCTestCase {

    func testMealImageEnrichMapsTrustFields() {
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

        XCTAssertEqual(draft.totalCalories, 650)
        XCTAssertEqual(draft.calorieRangeLower, 580)
        XCTAssertEqual(draft.calorieRangeUpper, 720)
        XCTAssertEqual(draft.assumptions, ["Standard hawker portion"])
        XCTAssertTrue(draft.requiresClarificationBeforeLogging)
        XCTAssertEqual(draft.suggestedClarifications, ["Was this a large plate?"])
        XCTAssertEqual(draft.primaryUncertainty, "Rice amount")
        XCTAssertEqual(draft.componentTrustMetadata.count, 1)
        XCTAssertEqual(draft.components.first?.estimateTrustMetadata?.rangeLower, 580)
    }

    func testNutritionEstimateResponseBuildsTrustAwareDraft() {
        let response = NutritionEstimateResponse(
            foodName: "Big Mac",
            caloriesKcal: 550,
            caloriesRangeLowerKcal: 520,
            caloriesRangeUpperKcal: 580,
            proteinGrams: 25,
            confidenceLevel: .medium,
            assumptions: ["Standard US recipe"],
            uncertaintyReasons: ["Country variation"],
            suggestedClarifications: ["Which country?"],
            primaryUncertainty: "Country variation",
            requiresClarificationBeforeLogging: false,
            riskLevel: .medium
        )
        let action = NutritionSuggestedAction(
            title: "Log Big Mac",
            type: .logMeal,
            payload: [
                "foodName": "Big Mac",
                "caloriesKcal": "550",
                "proteinGrams": "25"
            ]
        )

        let draft = NutritionSuggestedActionHandler.mealDraft(from: response, action: action)

        XCTAssertEqual(draft?.displayName, "Big Mac")
        XCTAssertEqual(draft?.totalCalories, 550)
        XCTAssertEqual(draft?.calorieRangeLower, 520)
        XCTAssertEqual(draft?.calorieRangeUpper, 580)
        XCTAssertEqual(draft?.assumptions, ["Standard US recipe"])
        XCTAssertEqual(draft?.committedCalorieTotal, 550)
    }

    func testAssumptionsExtractedFromWarnings() {
        let warnings = [
            "Assumption: Regular portion",
            "Review before logging",
            "assumption: No extra sauce"
        ]

        XCTAssertEqual(
            CoachEstimateTrustMapper.assumptions(from: warnings),
            ["Regular portion", "No extra sauce"]
        )
        XCTAssertEqual(
            CoachEstimateTrustMapper.nonAssumptionWarnings(from: warnings),
            ["Review before logging"]
        )
    }
}
