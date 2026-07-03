//
//  MealImageAnalysisResponseValidatorTests.swift
//  Fitness CoachTests
//

import XCTest
@testable import Fitness_Coach

final class MealImageAnalysisResponseValidatorTests: XCTestCase {

    func testValidStructuredResponsePasses() {
        let result = MealImageAnalysisResponseValidator.validate(response: sampleResponse())
        XCTAssertTrue(result.isValid)
    }

    func testGenericItemNameIsRejected() {
        var response = sampleResponse()
        response.items[0].name = "generic meal"

        let result = MealImageAnalysisResponseValidator.validate(response: response)

        XCTAssertFalse(result.isValid)
        XCTAssertTrue(result.errors.contains(where: { $0.contains("too generic") }))
    }

    func testMismatchedTotalsAreRejected() {
        var response = sampleResponse()
        response.total.calories = 1

        let result = MealImageAnalysisResponseValidator.validate(response: response)

        XCTAssertFalse(result.isValid)
        XCTAssertTrue(result.errors.contains(where: { $0.contains("total.calories") }))
    }

    func testEmptyItemsAreRejected() {
        var response = sampleResponse()
        response.items = []

        let result = MealImageAnalysisResponseValidator.validate(response: response)

        XCTAssertFalse(result.isValid)
        XCTAssertTrue(result.errors.contains(where: { $0.contains("at least one identified food") }))
    }

    func testStructuredMealNameIsAccepted() {
        let response = AIMealImageAnalysisResponse(
            summary: "Fruit + toast with spread",
            items: [
                AIMealImageAnalysisItem(
                    name: "Fresh fruit",
                    quantity: "1 cup",
                    calories: 80,
                    protein: 1,
                    carbs: 20,
                    fat: 0.5,
                    confidence: .medium,
                    assumptions: ["Mixed berries and banana"]
                ),
                AIMealImageAnalysisItem(
                    name: "Toast with spread",
                    quantity: "1 slice",
                    calories: 140,
                    protein: 4,
                    carbs: 18,
                    fat: 6,
                    confidence: .medium,
                    assumptions: ["Butter or jam spread"]
                )
            ],
            total: AIMealImageAnalysisTotals(calories: 220, protein: 5, carbs: 38, fat: 6.5),
            needsUserReview: true,
            clarifyingQuestion: nil
        )

        XCTAssertTrue(MealImageAnalysisResponseValidator.validate(response: response).isValid)
    }

    private func sampleResponse() -> AIMealImageAnalysisResponse {
        AIMealImageAnalysisResponse(
            summary: "Chicken bowl",
            items: [
                AIMealImageAnalysisItem(
                    name: "Grilled chicken breast",
                    quantity: "150 g",
                    calories: 248,
                    protein: 46,
                    carbs: 0,
                    fat: 5,
                    confidence: .high,
                    assumptions: ["Skinless portion"]
                )
            ],
            total: AIMealImageAnalysisTotals(calories: 248, protein: 46, carbs: 0, fat: 5),
            needsUserReview: true,
            clarifyingQuestion: nil
        )
    }
}
