//
//  FoodEstimateTrustPolicyTests.swift
//  Fitness CoachTests
//

import XCTest
@testable import Fitness_Coach

final class FoodEstimateTrustPolicyTests: XCTestCase {

    func testSanityFailureBlocksConfirmUntilEdited() {
        let sanity = NutritionSanityValidator.validate(
            meal: underestimatedBowlMeal(),
            prompt: bowlPrompt,
            confidence: .high
        )

        let gate = FoodEstimateTrustPolicy.confirmGate(
            sanityResult: sanity,
            userEditedBeforeConfirm: false
        )

        XCTAssertFalse(gate.canConfirm)
        XCTAssertTrue(gate.sanityFailed)
        XCTAssertTrue(gate.requiresEditBeforeConfirm)
        XCTAssertEqual(gate.blockedReason, FoodEstimateTrustPolicy.editBeforeLoggingMessage)
    }

    func testUserEditClearsConfirmBlockAfterSanityFailure() {
        let sanity = NutritionSanityValidator.validate(
            meal: underestimatedBowlMeal(),
            prompt: bowlPrompt,
            confidence: .high
        )

        let gate = FoodEstimateTrustPolicy.confirmGate(
            sanityResult: sanity,
            userEditedBeforeConfirm: true
        )

        XCTAssertTrue(gate.canConfirm)
        XCTAssertTrue(gate.sanityFailed)
        XCTAssertFalse(gate.requiresEditBeforeConfirm)
        XCTAssertNil(gate.blockedReason)
    }

    func testAcceptableSanityAllowsConfirm() {
        let meal = FoodLogDraft(
            displayName: "Chicken rice",
            components: [
                FoodComponent(name: "rice", calories: 300, protein: 6, carbs: 65, fat: 1),
                FoodComponent(name: "chicken", calories: 280, protein: 35, carbs: 0, fat: 12),
                FoodComponent(name: "sauce", calories: 60, protein: 1, carbs: 4, fat: 5)
            ],
            confidence: .medium,
            source: .aiTextEstimate
        )

        let sanity = NutritionSanityValidator.validate(
            meal: meal,
            prompt: "log chicken rice",
            confidence: .medium
        )
        let gate = FoodEstimateTrustPolicy.confirmGate(
            sanityResult: sanity,
            userEditedBeforeConfirm: false
        )

        XCTAssertTrue(gate.canConfirm)
        XCTAssertFalse(gate.requiresEditBeforeConfirm)
    }

    private let bowlPrompt = """
    log this bowl:
    - 150 g cooked skinless chicken breast
    - 150 g cooked barley rice
    - 1 tbsp creamy sesame/mayo dressing
    - 50-60 g tiramisu
    """

    private func underestimatedBowlMeal() -> FoodLogDraft {
        FoodLogDraft(
            displayName: "bowl",
            components: [
                FoodComponent(name: "chicken", quantity: 150, unit: "g", calories: 165, protein: 31, carbs: 0, fat: 4),
                FoodComponent(name: "rice", quantity: 150, unit: "g", calories: 120, protein: 3, carbs: 25, fat: 1),
                FoodComponent(name: "dressing", quantity: 1, unit: "tbsp", calories: 35, protein: 0, carbs: 1, fat: 1),
                FoodComponent(name: "tiramisu", quantity: 55, unit: "g", calories: 110, protein: 2, carbs: 14, fat: 4)
            ],
            confidence: .high,
            source: .aiTextEstimate
        )
    }
}
