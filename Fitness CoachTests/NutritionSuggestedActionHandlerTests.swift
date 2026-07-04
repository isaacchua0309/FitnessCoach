//
//  NutritionSuggestedActionHandlerTests.swift
//  Fitness CoachTests
//

import XCTest
@testable import Fitness_Coach

@MainActor
final class NutritionSuggestedActionHandlerTests: XCTestCase {

    func testLogMealPayloadBuildsFoodDraft() {
        let action = NutritionSuggestedAction(
            title: "Log Big Mac",
            type: .logMeal,
            payload: [
                "foodName": "Big Mac",
                "caloriesKcal": "550",
                "proteinGrams": "25",
                "carbsGrams": "45",
                "fatGrams": "30"
            ]
        )

        let draft = NutritionSuggestedActionHandler.mealDraft(from: action)
        XCTAssertEqual(draft?.displayName, "Big Mac")
        XCTAssertEqual(draft?.totalCalories, 550)
        XCTAssertEqual(draft?.committedCalorieTotal, 550)
    }

    func testLogMealPayloadParsesOptionalRangeFields() {
        let action = NutritionSuggestedAction(
            title: "Log Laksa",
            type: .logMeal,
            payload: [
                "foodName": "Laksa",
                "caloriesKcal": "520",
                "caloriesRangeLowerKcal": "450",
                "caloriesRangeUpperKcal": "620",
                "requiresClarificationBeforeLogging": "true"
            ]
        )

        let draft = NutritionSuggestedActionHandler.mealDraft(from: action)

        XCTAssertEqual(draft?.calorieRangeLower, 450)
        XCTAssertEqual(draft?.calorieRangeUpper, 620)
        XCTAssertTrue(draft?.requiresClarificationBeforeLogging == true)
    }

    func testAddSideFollowUpQuery() {
        let action = NutritionSuggestedAction(
            title: "Add fries",
            type: .addCommonSide,
            payload: ["foodName": "Medium fries"]
        )

        XCTAssertEqual(
            NutritionSuggestedActionHandler.followUpQuery(for: action),
            "Estimate calories in Medium fries"
        )
    }

    func testEstimateActionDoesNotProduceFollowUpQuery() {
        let action = NutritionSuggestedAction(title: "Estimate another", type: .estimateAnother)
        XCTAssertNil(NutritionSuggestedActionHandler.followUpQuery(for: action))
    }
}
