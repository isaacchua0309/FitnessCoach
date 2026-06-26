//
//  FoodDraftNutritionCompleterTests.swift
//  Fitness CoachTests
//

import XCTest
@testable import Fitness_Coach

final class FoodDraftNutritionCompleterTests: XCTestCase {

    func testSanitizeClearsPortionWhenQuantityMatchesProteinGrams() {
        let confused = FoodDraft(
            mealType: nil,
            name: "chicken",
            quantity: 50,
            unit: "g",
            calories: 83,
            protein: 50,
            carbs: 0,
            fat: 2,
            fiber: nil,
            sodium: nil,
            source: .manual,
            confidence: .medium,
            imageUrl: nil,
            notes: nil
        )

        let sanitized = FoodDraftNutritionCompleter.sanitizePartial(
            confused,
            hintText: "log chicken 50 protein"
        )

        XCTAssertNil(sanitized.quantity)
        XCTAssertNil(sanitized.unit)
        XCTAssertEqual(sanitized.protein, 50)
    }

    func testSanitizeClearsPortionWhenQuantityMatchesCalories() {
        let confused = FoodDraft(
            mealType: nil,
            name: "chicken",
            quantity: 400,
            unit: "g",
            calories: 400,
            protein: 0,
            carbs: 0,
            fat: 0,
            fiber: nil,
            sodium: nil,
            source: .manual,
            confidence: .medium,
            imageUrl: nil,
            notes: nil
        )

        let sanitized = FoodDraftNutritionCompleter.sanitizePartial(
            confused,
            hintText: "log chicken 400 calories"
        )

        XCTAssertNil(sanitized.quantity)
        XCTAssertNil(sanitized.unit)
        XCTAssertEqual(sanitized.calories, 400)
    }

    func testMergeExplicitKeepsUserProteinAndAIPortion() {
        let explicit = FoodDraft(
            mealType: nil,
            name: "chicken",
            quantity: 50,
            unit: "g",
            calories: 0,
            protein: 50,
            carbs: 0,
            fat: 0,
            fiber: nil,
            sodium: nil,
            source: .manual,
            confidence: .medium,
            imageUrl: nil,
            notes: nil
        )
        let estimate = FoodDraft(
            mealType: nil,
            name: "chicken breast",
            quantity: 220,
            unit: "g",
            calories: 360,
            protein: 68,
            carbs: 0,
            fat: 8,
            fiber: nil,
            sodium: nil,
            source: .aiTextEstimate,
            confidence: .medium,
            imageUrl: nil,
            notes: nil
        )

        let merged = FoodDraftNutritionCompleter.mergeExplicit(
            explicit,
            into: estimate,
            hintText: "log chicken 50 protein"
        )

        XCTAssertEqual(merged.protein, 50)
        XCTAssertEqual(merged.quantity, 220)
        XCTAssertEqual(merged.unit, "g")
        XCTAssertEqual(merged.calories, 360)
    }

    func testPartialCaloriesRoutesToEstimateFood() async throws {
        let partial = FoodDraft(
            mealType: nil,
            name: "chicken",
            quantity: nil,
            unit: nil,
            calories: 400,
            protein: 0,
            carbs: 0,
            fat: 0,
            fiber: nil,
            sodium: nil,
            source: .manual,
            confidence: .medium,
            imageUrl: nil,
            notes: nil
        )

        let router = CoachIntentRouter()
        let route = router.route(
            intentResult: CoachIntentResult(
                intent: .logFood,
                confidence: 0.9,
                domain: .nutrition,
                requiresAppMutation: true,
                requiresUserContext: true,
                canAnswerWithCheapModel: false,
                requiresEscalation: false,
                action: .logFood(partial)
            ),
            originalText: "log chicken 400 calories"
        )

        if case .ai(let task) = route {
            if case .estimateFood = task.task {
                XCTAssertEqual(task.tier, .cheap)
            } else {
                XCTFail("Expected estimateFood task")
            }
        } else {
            XCTFail("Expected AI estimate route, got \(route)")
        }
    }
}
