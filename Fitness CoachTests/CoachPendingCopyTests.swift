//
//  CoachPendingCopyTests.swift
//  Fitness CoachTests
//

import XCTest
@testable import Fitness_Coach

final class CoachPendingCopyTests: XCTestCase {

    private let chickenDraft = FoodDraft(
        mealType: nil,
        name: "chicken",
        quantity: nil,
        unit: nil,
        calories: 165,
        protein: 31,
        carbs: 0,
        fat: 4,
        fiber: nil,
        sodium: nil,
        source: .aiTextEstimate,
        confidence: .medium,
        imageUrl: nil,
        notes: nil
    )

    func testStandardFoodPendingCopyIsConcise() {
        let message = CoachResponseBuilder.aiFoodEstimatePending(
            draft: chickenDraft,
            confidence: .medium,
            originalText: "Log some chicken"
        )

        XCTAssertTrue(message.hasPrefix("Estimated chicken:"))
        XCTAssertTrue(message.contains("165 kcal · 31g protein · 0g carbs · 4g fat"))
        XCTAssertTrue(message.contains(FormaProductCopy.Coach.foodEditPortionFooter))
        XCTAssertFalse(message.contains("Here's my estimate"))
        XCTAssertFalse(message.contains(FormaProductCopy.Coach.pendingBarHint))
        XCTAssertFalse(message.contains("P 31g"))
        XCTAssertFalse(message.contains("Please confirm or edit"))
    }

    func testVagueFoodPendingUsesIngredientsFooter() {
        let draft = FoodDraft(
            mealType: nil,
            name: "mysterious protein bowl",
            quantity: 1,
            unit: "bowl",
            calories: 450,
            protein: 35,
            carbs: 30,
            fat: 20,
            fiber: nil,
            sodium: nil,
            source: .aiTextEstimate,
            confidence: .medium,
            imageUrl: nil,
            notes: nil
        )

        let message = CoachResponseBuilder.aiFoodEstimatePending(
            draft: draft,
            confidence: .medium,
            originalText: "Log a mysterious protein bowl"
        )

        XCTAssertTrue(message.hasPrefix("Estimated a generic protein bowl:"))
        XCTAssertTrue(message.contains("450 kcal · 35g protein · 30g carbs · 20g fat"))
        XCTAssertTrue(message.contains(FormaProductCopy.Coach.foodEditIngredientsFooter))
        XCTAssertFalse(message.contains(FormaProductCopy.Coach.pendingBarHint))
    }

    func testHighConfidenceFoodUsesCompactMacrosAndConfirmFooter() {
        let message = CoachResponseBuilder.aiFoodEstimatePending(
            draft: chickenDraft,
            confidence: .high,
            originalText: "log 2 eggs"
        )

        XCTAssertTrue(message.hasPrefix("Estimated chicken:"))
        XCTAssertTrue(message.contains("165 kcal · 31g protein"))
        XCTAssertFalse(message.contains("0g carbs"))
        XCTAssertTrue(message.contains(FormaProductCopy.Coach.foodConfirmBelowFooter))
    }

    func testWorkoutPendingOmitsBarHint() {
        let draft = WorkoutDraft(
            name: "Run",
            durationMinutes: 30,
            estimatedCaloriesBurned: 300,
            intensity: nil,
            recoveryDemand: nil,
            exerciseSets: []
        )

        let message = CoachResponseBuilder.workoutPending(
            draft,
            assistantMessage: "Drafted a 30-minute run. Please confirm before logging."
        )

        XCTAssertTrue(message.hasPrefix("Parsed workout:"))
        XCTAssertTrue(message.contains("Run"))
        XCTAssertTrue(message.contains("30 min · 300 kcal burned"))
        XCTAssertFalse(message.contains(FormaProductCopy.Coach.pendingBarHint))
        XCTAssertFalse(message.contains("Please confirm before logging"))
    }

    func testWaterPendingIsSingleLine() {
        let message = CoachResponseBuilder.waterPending(
            WaterDraft(amountMl: 500),
            assistantMessage: "Adding water."
        )

        XCTAssertEqual(message, "Log 500ml water?")
        XCTAssertFalse(message.contains(FormaProductCopy.Coach.pendingBarHint))
    }

    func testWeightPendingIsSingleLine() {
        let message = CoachResponseBuilder.weightPending(
            WeightDraft(weightKg: 75.5, note: nil),
            assistantMessage: nil
        )

        XCTAssertEqual(message, "Log 75.50 kg?")
        XCTAssertFalse(message.contains(FormaProductCopy.Coach.pendingBarHint))
    }
}
