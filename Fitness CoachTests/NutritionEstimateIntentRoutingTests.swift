//
//  NutritionEstimateIntentRoutingTests.swift
//  Fitness CoachTests
//

import XCTest
@testable import Fitness_Coach

@MainActor
final class NutritionEstimateIntentRoutingTests: XCTestCase {

    private let router = CoachIntentRouter()

    func testNutritionEstimateQueryRoutesToNutritionEstimateTask() {
        let result = CoachIntentResult(
            intent: .nutritionEstimateQuery,
            confidence: 0.9,
            domain: .nutrition,
            requiresAppMutation: false,
            requiresUserContext: true,
            canAnswerWithCheapModel: true,
            requiresEscalation: false
        )

        let route = router.route(intentResult: result, originalText: "calories in a Big Mac")
        guard case .ai(let task) = route else {
            return XCTFail("Expected AI route")
        }
        guard case .nutritionEstimate = task.task else {
            return XCTFail("Expected nutritionEstimate task")
        }
    }

    func testNutritionComparisonQueryRoutesToComparisonTask() {
        let result = CoachIntentResult(
            intent: .nutritionComparisonQuery,
            confidence: 0.9,
            domain: .nutrition,
            requiresAppMutation: false,
            requiresUserContext: false,
            canAnswerWithCheapModel: true,
            requiresEscalation: false
        )

        let route = router.route(intentResult: result, originalText: "Big Mac vs McSpicy")
        guard case .ai(let task) = route else {
            return XCTFail("Expected AI route")
        }
        guard case .nutritionComparison = task.task else {
            return XCTFail("Expected nutritionComparison task")
        }
    }

    func testLogFoodStillRoutesToEstimateFood() {
        let result = CoachIntentResult(
            intent: .logFood,
            confidence: 0.9,
            domain: .nutrition,
            requiresAppMutation: true,
            requiresUserContext: false,
            canAnswerWithCheapModel: true,
            requiresEscalation: false
        )

        let route = router.route(intentResult: result, originalText: "log a Big Mac")
        guard case .ai(let task) = route else {
            return XCTFail("Expected AI route")
        }
        guard case .estimateFood = task.task else {
            return XCTFail("Expected estimateFood task")
        }
    }

    func testLegacyCalorieLookupRoutesToNutritionEstimate() {
        let result = CoachIntentResult(
            intent: .calorieLookup,
            confidence: 0.9,
            domain: .nutrition,
            requiresAppMutation: false,
            requiresUserContext: false,
            canAnswerWithCheapModel: true,
            requiresEscalation: false
        )

        let route = router.route(intentResult: result, originalText: "how many calories in chicken rice")
        guard case .ai(let task) = route else {
            return XCTFail("Expected AI route")
        }
        guard case .nutritionEstimate = task.task else {
            return XCTFail("Expected nutritionEstimate task")
        }
    }
}
