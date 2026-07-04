//
//  CoachFoodAmbiguityPolicyTests.swift
//  Fitness CoachTests
//

import XCTest
@testable import Fitness_Coach

final class CoachFoodAmbiguityPolicyTests: XCTestCase {

    func testAmbiguousSGFoodTriggersLowConfidencePending() {
        let meal = FoodLogDraft(
            displayName: "Chicken rice",
            components: [
                FoodComponent(
                    name: "Chicken rice",
                    calories: 650,
                    protein: 35,
                    carbs: 75,
                    fat: 20,
                    confidence: .medium,
                    sourceText: "hawker chicken rice plate"
                )
            ],
            confidence: .medium
        )

        let outcome = CoachFoodAmbiguityPolicy.postEstimateOutcome(
            input: CoachFoodAmbiguityPostEstimateInput(
                prompt: "log chicken rice",
                meal: meal,
                confidence: .medium,
                fromPhotoAnalysis: false
            )
        )

        if case .proceedAmbiguous(let adjusted, let confidence) = outcome {
            XCTAssertEqual(confidence, .low)
            XCTAssertEqual(adjusted.confidence, .low)
            XCTAssertTrue(adjusted.requiresClarificationBeforeLogging)
            XCTAssertNotNil(adjusted.calorieRangeLower)
            XCTAssertNotNil(adjusted.calorieRangeUpper)
            XCTAssertFalse(adjusted.assumptions.isEmpty)
            XCTAssertFalse(adjusted.uncertaintyReasons.isEmpty)
        } else {
            XCTFail("Expected low-confidence pending outcome for ambiguous SG food")
        }
    }

    func testExactGramFoodDoesNotForceClarification() {
        let meal = FoodLogDraft(
            displayName: "Chicken breast",
            components: [
                FoodComponent(
                    name: "Chicken breast",
                    quantity: 200,
                    unit: "g",
                    calories: 330,
                    protein: 62,
                    carbs: 0,
                    fat: 7,
                    confidence: .high,
                    sourceText: "200g chicken breast"
                )
            ],
            confidence: .high
        )

        let outcome = CoachFoodAmbiguityPolicy.postEstimateOutcome(
            input: CoachFoodAmbiguityPostEstimateInput(
                prompt: "log 200g chicken breast",
                meal: meal,
                confidence: .high,
                fromPhotoAnalysis: false
            )
        )

        XCTAssertEqual(outcome, .proceed)
    }

    func testClearPortionFoodsDoNotForceClarification() {
        let cases: [(String, FoodLogDraft)] = [
            (
                "log 500ml milk",
                FoodLogDraft(
                    displayName: "Milk",
                    components: [FoodComponent(name: "Milk", quantity: 500, unit: "ml", calories: 210, protein: 7, carbs: 16, fat: 8, confidence: .high)],
                    confidence: .high
                )
            ),
            (
                "log 2 eggs",
                FoodLogDraft(
                    displayName: "Eggs",
                    components: [FoodComponent(name: "Eggs", quantity: 2, unit: "count", calories: 140, protein: 12, carbs: 1, fat: 10, confidence: .high)],
                    confidence: .high
                )
            ),
            (
                "log protein shake 1 scoop",
                FoodLogDraft(
                    displayName: "Protein shake",
                    components: [FoodComponent(name: "Protein shake", quantity: 1, unit: "scoop", calories: 120, protein: 24, carbs: 3, fat: 1, confidence: .high)],
                    confidence: .high
                )
            ),
            (
                "log grilled salmon 180g",
                FoodLogDraft(
                    displayName: "Grilled salmon",
                    components: [FoodComponent(name: "Grilled salmon", quantity: 180, unit: "g", calories: 360, protein: 40, carbs: 0, fat: 22, confidence: .high)],
                    confidence: .high
                )
            )
        ]

        for (prompt, meal) in cases {
            let outcome = CoachFoodAmbiguityPolicy.postEstimateOutcome(
                input: CoachFoodAmbiguityPostEstimateInput(
                    prompt: prompt,
                    meal: meal,
                    confidence: .high,
                    fromPhotoAnalysis: false
                )
            )
            XCTAssertEqual(outcome, .proceed, "Expected clear portion prompt to proceed: \(prompt)")
        }
    }

    func testHiddenSauceAddsUncertaintyInAmbiguousPending() {
        let meal = FoodLogDraft(
            displayName: "Salad with dressing",
            components: [
                FoodComponent(
                    name: "Salad with dressing",
                    calories: 320,
                    protein: 8,
                    carbs: 18,
                    fat: 24,
                    confidence: .medium,
                    sourceText: "salad with creamy dressing"
                )
            ],
            confidence: .medium
        )

        let outcome = CoachFoodAmbiguityPolicy.postEstimateOutcome(
            input: CoachFoodAmbiguityPostEstimateInput(
                prompt: "log salad with dressing",
                meal: meal,
                confidence: .medium,
                fromPhotoAnalysis: false
            )
        )

        if case .proceedAmbiguous(let adjusted, _) = outcome {
            XCTAssertTrue(
                adjusted.uncertaintyReasons.contains(where: {
                    $0.localizedCaseInsensitiveContains("sauce") || $0.localizedCaseInsensitiveContains("oil")
                })
            )
            XCTAssertGreaterThan(adjusted.calorieRangeUpper! - adjusted.calorieRangeLower!, 40)
        } else {
            XCTFail("Expected ambiguous pending for salad with dressing")
        }
    }

    func testLogThisWithoutImageClarifiesBeforeEstimate() {
        let outcome = CoachFoodAmbiguityPolicy.preEstimateOutcome(
            prompt: "log this",
            hasImageAttachment: false
        )

        if case .clarifyFirst(let question) = outcome {
            XCTAssertTrue(question.localizedCaseInsensitiveContains("what"))
        } else {
            XCTFail("Expected clarification for bare log this without image")
        }
    }

    func testLogThisWithImageDoesNotPreClarify() {
        XCTAssertNil(
            CoachFoodAmbiguityPolicy.preEstimateOutcome(
                prompt: "log this",
                hasImageAttachment: true
            )
        )
    }

    func testMealSlotOnlyPromptClarifiesBeforeEstimate() {
        let outcome = CoachFoodAmbiguityPolicy.preEstimateOutcome(
            prompt: "log dinner",
            hasImageAttachment: false
        )

        if case .clarifyFirst = outcome {
            XCTAssertTrue(true)
        } else {
            XCTFail("Expected clarification for meal-slot-only prompt")
        }
    }

    func testEstimateOnlyPhraseGuardRoutesAwayFromLogFood() {
        let result = CoachIntentResult(
            intent: .logFood,
            confidence: 0.92,
            domain: .nutrition,
            requiresAppMutation: true,
            requiresUserContext: true,
            canAnswerWithCheapModel: true,
            requiresEscalation: false
        )

        let guarded = CoachIntentPhraseGuard.applyGuards(
            to: result,
            text: "estimate chicken rice but don't log it"
        )

        XCTAssertEqual(guarded.intent, .nutritionEstimateQuery)
        XCTAssertNil(guarded.action)
        XCTAssertFalse(guarded.requiresAppMutation)
    }

    func testAdviceQueryDoesNotRemainLogMutation() {
        let result = CoachIntentResult(
            intent: .logFood,
            confidence: 0.92,
            domain: .nutrition,
            requiresAppMutation: true,
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

        let guarded = CoachIntentPhraseGuard.applyGuards(
            to: result,
            text: "should I eat chicken rice?"
        )

        XCTAssertNotEqual(guarded.intent, .logFood)
        XCTAssertNil(guarded.action)
    }

    func testConfirmationPolicyReturnsClarifyForBareLogThisMeal() {
        let presentation = ConfirmationPolicy.foodPresentation(
            meal: FoodLogDraft(
                displayName: "",
                components: [],
                confidence: .medium
            ),
            prompt: "log this",
            confidence: .medium
        )

        if case .clarifyFirst = presentation {
            XCTAssertTrue(true)
        } else {
            XCTFail("Expected clarification when no usable estimate exists")
        }
    }

    func testConfirmationPolicyReturnsPendingForAmbiguousSGFood() {
        let meal = FoodLogDraft(
            displayName: "Laksa",
            components: [
                FoodComponent(name: "Laksa", calories: 520, protein: 18, carbs: 55, fat: 24, confidence: .medium)
            ],
            confidence: .medium
        )

        let presentation = ConfirmationPolicy.foodPresentation(
            meal: meal,
            prompt: "log laksa",
            confidence: .medium
        )

        if case .pending(let presented, let confidence) = presentation {
            XCTAssertEqual(confidence, .low)
            XCTAssertEqual(presented.confidence, .low)
            XCTAssertTrue(presented.requiresClarificationBeforeLogging)
        } else {
            XCTFail("Expected pending low-confidence card for laksa")
        }
    }

    func testPhotoCroppedSignalRequestsClarification() {
        let result = ImageAnalysisSessionResult(
            mealDraft: FoodLogDraft(
                displayName: "Mixed plate",
                components: [
                    FoodComponent(name: "Mixed plate", calories: 500, protein: 20, carbs: 50, fat: 20, confidence: .medium)
                ],
                confidence: .medium,
                uncertaintyReasons: ["Photo is cropped and portion is unclear"]
            ),
            confidence: .medium,
            summary: "Cropped mixed plate",
            clarifyingQuestion: "Was this a full plate?"
        )

        XCTAssertTrue(ImageAnalysisSessionReducer.shouldRequestClarification(for: result))
    }
}
