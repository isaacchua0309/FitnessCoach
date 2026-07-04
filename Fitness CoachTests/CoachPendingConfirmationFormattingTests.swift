//
//  CoachPendingConfirmationFormattingTests.swift
//  Fitness CoachTests
//
//  Confirmation bar summary lines (pure, no SwiftUI).
//

import XCTest
@testable import Fitness_Coach

final class CoachPendingConfirmationFormattingTests: XCTestCase {

    func testFoodSummaryIncludesEstimateMacrosAndConfidence() {
        let pending = CoachPendingConfirmation.food(CoachMutationTestFixtures.chickenConfirmationDraft)

        XCTAssertEqual(pending.kindLabel, "Food")
        XCTAssertTrue(pending.summaryLine.contains("Chicken breast · Estimated: about 330 kcal · P 62g / C 0g / F 7g"))
        XCTAssertTrue(pending.summaryLine.contains(AIFoodConfirmationFormatter.confidenceLabel(.high)))
        XCTAssertTrue(pending.supportsEdit)
    }

    func testLowConfidenceFoodShowsUncertaintyWarning() {
        var draft = CoachMutationTestFixtures.chickenConfirmationDraft
        draft.confidence = .low
        draft.mealDraft.confidence = .low

        let pending = CoachPendingConfirmation.food(draft)

        XCTAssertTrue(pending.summaryLine.contains(FormaProductCopy.Coach.pendingLowConfidenceWarning))
    }

    func testPhotoFoodPendingShowsSourceLabel() {
        var draft = CoachMutationTestFixtures.chickenConfirmationDraft
        draft.sourceAttribution = .mealImage
        draft.mealDraft.source = .aiPhotoEstimate

        let pending = CoachPendingConfirmation.food(draft)

        XCTAssertTrue(pending.summaryLine.contains(FormaProductCopy.Coach.pendingSourceMealPhoto))
    }

    func testCommonFoodPendingShowsSourceLabel() {
        var draft = CoachMutationTestFixtures.chickenConfirmationDraft
        draft.sourceAttribution = .commonFoodReference

        let pending = CoachPendingConfirmation.food(draft)

        XCTAssertTrue(pending.summaryLine.contains(FormaProductCopy.Coach.pendingSourceCommonFood))
    }

    func testWaterAndWeightSummaries() {
        XCTAssertEqual(
            CoachPendingConfirmation.water(WaterDraft(amountMl: 500), assistantMessage: nil).summaryLine,
            "500 ml water"
        )
        XCTAssertEqual(
            CoachPendingConfirmation.weight(WeightDraft(weightKg: 68.25, note: nil), assistantMessage: nil).summaryLine,
            "68.25 kg"
        )
    }

    func testEditDeleteUndoUseAssistantMessageOrFallback() {
        let action = AICommandAction(type: .editEntry, targetEntrySelector: "lunch")

        XCTAssertEqual(
            CoachPendingConfirmation.edit(action, originalText: "edit lunch", assistantMessage: "Edit lunch entry?").summaryLine,
            "Edit lunch entry?"
        )
        XCTAssertEqual(
            CoachPendingConfirmation.delete(action, originalText: "delete lunch", assistantMessage: nil).summaryLine,
            "Review this change before applying it."
        )
        XCTAssertFalse(
            CoachPendingConfirmation.delete(action, originalText: "delete lunch", assistantMessage: nil).supportsEdit
        )
    }

    func testFoodCompactPresentationCopy() {
        let pending = CoachPendingConfirmation.food(CoachMutationTestFixtures.chickenConfirmationDraft)

        XCTAssertEqual(pending.compactTitle, FormaProductCopy.Coach.foodEstimatePending)
        XCTAssertEqual(pending.compactDetailLine, "About 330 kcal")
    }

    func testFoodCompactPresentationWithoutCaloriesUsesDisplayName() {
        var draft = CoachMutationTestFixtures.chickenConfirmationDraft
        draft.mealDraft.components = [
            FoodComponent(
                name: "Mystery bowl",
                quantity: 1,
                unit: "bowl",
                calories: 0,
                protein: 0,
                carbs: 0,
                fat: 0,
                confidence: .low
            )
        ]
        draft.mealDraft.displayName = "Mystery bowl"

        let pending = CoachPendingConfirmation.food(draft)

        XCTAssertEqual(pending.compactDetailLine, "Mystery bowl")
    }

    func testWaterAndWeightCompactPresentation() {
        XCTAssertEqual(
            CoachPendingConfirmation.water(WaterDraft(amountMl: 500), assistantMessage: nil).compactDetailLine,
            "500 ml"
        )
        XCTAssertEqual(
            CoachPendingConfirmation.weight(WeightDraft(weightKg: 68.25, note: nil), assistantMessage: nil).compactDetailLine,
            "68.2 kg"
        )
    }
}
