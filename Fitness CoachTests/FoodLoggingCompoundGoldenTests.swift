//
//  FoodLoggingCompoundGoldenTests.swift
//  Fitness CoachTests
//

import XCTest
@testable import Fitness_Coach

final class FoodLoggingCompoundGoldenTests: XCTestCase {

    func testCompoundGoldenCasesPassValidator() {
        for goldenCase in FoodLoggingCompoundGoldenFixtures.allCases {
            let result = FoodEstimateResponseValidator.validate(
                response: goldenCase.gatewayResponse,
                prompt: goldenCase.prompt
            )
            XCTAssertTrue(result.isValid, "Expected valid response for \(goldenCase.id): \(result.errors)")
        }
    }

    func testCollapsedChickenRiceFailsValidator() {
        guard let collapsed = FoodLoggingCompoundGoldenFixtures.chickenRice.collapsedResponse else {
            return XCTFail("Missing collapsed chicken rice fixture")
        }
        let result = FoodEstimateResponseValidator.validate(
            response: collapsed,
            prompt: FoodLoggingCompoundGoldenFixtures.chickenRice.prompt
        )
        XCTAssertFalse(result.isValid)
        XCTAssertTrue(result.errors.contains(where: { $0.contains("compound dish") }))
    }

    func testNegativeMacrosFailValidator() {
        let response = AIFoodEstimateResponse(
            foodLogDrafts: [
                FoodLogDraft(
                    displayName: "Eggs",
                    components: [
                        FoodComponent(
                            name: "eggs",
                            quantity: 2,
                            unit: "count",
                            calories: 140,
                            protein: -2,
                            carbs: 1,
                            fat: 10,
                            sourceText: "2 eggs"
                        )
                    ],
                    confidence: .high,
                    source: .aiTextEstimate
                )
            ],
            confidence: .high,
            requiresConfirmation: true
        )

        let result = FoodEstimateResponseValidator.validate(response: response, prompt: "2 eggs")
        XCTAssertFalse(result.isValid)
        XCTAssertTrue(result.errors.contains(where: { $0.contains("negative protein") }))
    }

    func testAmbiguousRiceBowlSanitizeAddsReviewWarning() {
        let goldenCase = FoodLoggingCompoundGoldenFixtures.ambiguousRiceBowl
        guard let meal = FoodLogDraftMapper.primaryMeal(from: goldenCase.gatewayResponse) else {
            return XCTFail("Missing meal draft")
        }
        let sanitized = FoodLogDraftNutritionCompleter.sanitize(meal, hintText: goldenCase.prompt)
        XCTAssertTrue(sanitized.warnings.contains(FoodLogDraftNutritionCompleter.lowConfidenceReviewWarning))
    }

    func testCompoundCasesHaveMinimumComponents() {
        for goldenCase in FoodLoggingCompoundGoldenFixtures.allCases {
            guard let meal = FoodLogDraftMapper.primaryMeal(from: goldenCase.gatewayResponse) else {
                XCTFail("Missing meal for \(goldenCase.id)")
                continue
            }
            XCTAssertGreaterThanOrEqual(
                meal.components.count,
                goldenCase.minComponents,
                "Component count mismatch for \(goldenCase.id)"
            )
        }
    }
}
