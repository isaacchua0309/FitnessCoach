//
//  CoachPendingConfirmationFormattingTests.swift
//  Fitness CoachTests
//
//  Confirmation bar summary lines (pure, no SwiftUI).
//

import XCTest
@testable import Fitness_Coach

final class CoachPendingConfirmationFormattingTests: XCTestCase {

    func testFoodSummaryIncludesMacros() {
        let pending = CoachPendingConfirmation.food(CoachMutationTestFixtures.chickenConfirmationDraft)

        XCTAssertEqual(pending.kindLabel, "Food")
        XCTAssertEqual(pending.summaryLine, "Chicken breast · 330 kcal · P 62g / C 0g / F 7g")
        XCTAssertTrue(pending.supportsEdit)
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
}
