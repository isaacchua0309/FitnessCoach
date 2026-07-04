//
//  CoachIntentPhraseGuardTests.swift
//  Fitness CoachTests
//

import XCTest
@testable import Fitness_Coach

final class CoachIntentPhraseGuardTests: XCTestCase {

    // MARK: - Advice / lookup (NOT log_food)

    func testShouldIEatIsAdviceNotLogging() {
        XCTAssertTrue(CoachIntentPhraseGuard.isAmbiguousAdvicePhrase("should I eat chicken rice?"))
        XCTAssertFalse(CoachIntentPhraseGuard.hasExplicitLoggingIntent("should I eat chicken rice?"))
    }

    func testCanIFitIsAdviceNotLogging() {
        XCTAssertTrue(CoachIntentPhraseGuard.isAmbiguousAdvicePhrase("can I fit a burger today?"))
    }

    func testCaloriesInIsLookupNotLogging() {
        XCTAssertTrue(CoachIntentPhraseGuard.isAmbiguousAdvicePhrase("how many calories in chicken rice?"))
        XCTAssertEqual(
            CoachIntentPhraseGuard.suggestedIntent(for: "how many calories in chicken rice?"),
            .nutritionEstimateQuery
        )
    }

    func testIsSushiOkayIsMealDecision() {
        XCTAssertTrue(CoachIntentPhraseGuard.isAmbiguousAdvicePhrase("is sushi okay for dinner?"))
        XCTAssertEqual(
            CoachIntentPhraseGuard.suggestedIntent(for: "is sushi okay for dinner?"),
            .mealDecision
        )
    }

    func testWhatShouldIEatIsNutritionAdvice() {
        XCTAssertTrue(CoachIntentPhraseGuard.isAmbiguousAdvicePhrase("what should I eat after workout?"))
        XCTAssertEqual(
            CoachIntentPhraseGuard.suggestedIntent(for: "what should I eat after workout?"),
            .nutritionAdvice
        )
    }

    func testWhatWasBreakfastIsLookupNotLogging() {
        XCTAssertTrue(CoachIntentPhraseGuard.isAmbiguousAdvicePhrase("what was breakfast?"))
        XCTAssertEqual(
            CoachIntentPhraseGuard.suggestedIntent(for: "what was breakfast?"),
            .nutritionEstimateQuery
        )
    }

    func testSameAsBreakfastWithoutLoggingIsReferenceOnly() {
        XCTAssertTrue(CoachIntentPhraseGuard.isReferenceOnlyWithoutLogging("same as breakfast"))
        XCTAssertFalse(CoachIntentPhraseGuard.hasExplicitLoggingIntent("same as breakfast"))
    }

    // MARK: - Explicit logging (SHOULD log_food)

    func testIAteChickenRiceIsExplicitLogging() {
        XCTAssertTrue(CoachIntentPhraseGuard.hasExplicitLoggingIntent("I ate chicken rice"))
        XCTAssertFalse(CoachIntentPhraseGuard.isAmbiguousAdvicePhrase("I ate chicken rice"))
    }

    func testLogChickenRiceIsExplicitLogging() {
        XCTAssertTrue(CoachIntentPhraseGuard.hasExplicitLoggingIntent("log chicken rice"))
    }

    func testAddChickenRiceToLunchIsExplicitLogging() {
        XCTAssertTrue(CoachIntentPhraseGuard.hasExplicitLoggingIntent("add chicken rice to lunch"))
    }

    func testIHadSushiEarlierIsExplicitLogging() {
        XCTAssertTrue(CoachIntentPhraseGuard.hasExplicitLoggingIntent("I had sushi earlier"))
    }

    func testLogSameAsBreakfastIsExplicitLogging() {
        XCTAssertTrue(CoachIntentPhraseGuard.hasExplicitLoggingIntent("log same as breakfast"))
    }

    func testIAteSameAsBreakfastIsExplicitLogging() {
        XCTAssertTrue(CoachIntentPhraseGuard.hasExplicitLoggingIntent("I ate the same as breakfast"))
    }

    // MARK: - Guard correction

    func testGuardCorrectsMisclassifiedLogFoodForAdviceQuestion() {
        let raw = CoachIntentResult(
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
                calories: 0,
                protein: 0,
                carbs: 0,
                fat: 0,
                fiber: nil,
                sodium: nil,
                source: .manual,
                confidence: .medium,
                imageUrl: nil,
                notes: nil
            ))
        )

        let corrected = CoachIntentPhraseGuard.applyGuards(to: raw, text: "should I eat chicken rice?")

        XCTAssertEqual(corrected.intent, .mealDecision)
        XCTAssertFalse(corrected.requiresAppMutation)
        XCTAssertNil(corrected.action)
    }

    func testGuardPreservesExplicitLoggingClassification() {
        let raw = CoachIntentResult(
            intent: .logFood,
            confidence: 0.92,
            domain: .nutrition,
            requiresAppMutation: true,
            requiresUserContext: true,
            canAnswerWithCheapModel: true,
            requiresEscalation: false
        )

        let corrected = CoachIntentPhraseGuard.applyGuards(to: raw, text: "log chicken rice")

        XCTAssertEqual(corrected.intent, .logFood)
        XCTAssertTrue(corrected.requiresAppMutation)
    }
}
