//
//  CoachIntentConfidenceGateTests.swift
//  Fitness CoachTests
//

import XCTest
@testable import Fitness_Coach

final class CoachIntentConfidenceGateTests: XCTestCase {

    func testQuestionFormLogFoodRequiresHigherConfidence() {
        let result = CoachIntentResult(
            intent: .logFood,
            confidence: 0.80,
            domain: .nutrition,
            requiresAppMutation: true,
            requiresUserContext: true,
            canAnswerWithCheapModel: true,
            requiresEscalation: false
        )

        let decision = CoachIntentConfidenceGate.evaluate(
            result,
            originalText: "should I eat chicken rice?"
        )

        if case .clarify = decision {
            XCTAssertTrue(true)
        } else {
            XCTFail("Expected clarification for question-form log_food below elevated threshold")
        }
    }

    func testExplicitLogFoodAtSameConfidenceProceeds() {
        let result = CoachIntentResult(
            intent: .logFood,
            confidence: 0.80,
            domain: .nutrition,
            requiresAppMutation: true,
            requiresUserContext: true,
            canAnswerWithCheapModel: true,
            requiresEscalation: false
        )

        let decision = CoachIntentConfidenceGate.evaluate(
            result,
            originalText: "log chicken rice"
        )

        if case .proceed(let sanitized) = decision {
            XCTAssertEqual(sanitized.intent, .logFood)
        } else {
            XCTFail("Expected proceed for explicit logging at 0.80 confidence")
        }
    }

    func testNutritionEstimateQueryStripsSpuriousLogFoodAction() {
        let result = CoachIntentResult(
            intent: .nutritionEstimateQuery,
            confidence: 0.88,
            domain: .nutrition,
            requiresAppMutation: false,
            requiresUserContext: true,
            canAnswerWithCheapModel: true,
            requiresEscalation: false,
            action: .logFood(FoodDraft(
                mealType: nil,
                name: "chicken rice",
                quantity: 1,
                unit: "meal",
                calories: 500,
                protein: 20,
                carbs: 60,
                fat: 10,
                fiber: nil,
                sodium: nil,
                source: .manual,
                confidence: .medium,
                imageUrl: nil,
                notes: nil
            ))
        )

        let decision = CoachIntentConfidenceGate.evaluate(result)

        if case .proceed(let sanitized) = decision {
            XCTAssertNil(sanitized.action)
            XCTAssertEqual(sanitized.intent, .nutritionEstimateQuery)
        } else {
            XCTFail("Expected proceed with stripped action")
        }
    }
}
