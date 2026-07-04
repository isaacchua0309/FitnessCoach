//
//  CoachMutationFormattingTests.swift
//  Fitness CoachTests
//
//  Post-mutation and status copy from CoachResponseBuilder (pure formatting).
//

import XCTest
@testable import Fitness_Coach

final class CoachMutationFormattingTests: XCTestCase {

    func testFoodLoggedIncludesEntryTimelineNoteAndTodaySummary() {
        let entry = CoachMutationTestFixtures.chickenFoodEntry
        let log = CoachMutationTestFixtures.sampleDailyLog

        let message = CoachResponseBuilder.food(entry, log: log)

        XCTAssertTrue(message.hasPrefix("Logged Chicken breast."))
        XCTAssertTrue(message.contains("330 kcal · 62g protein · 0g carbs · 7g fat"))
        XCTAssertTrue(message.contains("900 / 1800 kcal"))
        XCTAssertTrue(message.contains("protein remaining"))
        XCTAssertTrue(message.contains(FormaProductCopy.Coach.foodLoggedTimelineNote))
    }

    func testPhotoFoodLoggedMentionsReviewedEstimateAndAboutMacros() {
        var entry = CoachMutationTestFixtures.chickenFoodEntry
        entry.source = .aiPhotoEstimate

        let message = CoachResponseBuilder.food(
            entry,
            log: nil,
            fromPhotoAnalysis: true
        )

        XCTAssertTrue(message.contains(FormaProductCopy.Coach.loggedReviewedPhotoEstimate))
        XCTAssertTrue(message.contains("About 330 kcal"))
        XCTAssertTrue(message.contains(FormaProductCopy.Coach.foodLoggedTimelineNote))
    }

    func testAIFoodLoggedMentionsReviewedEstimate() {
        var entry = CoachMutationTestFixtures.chickenFoodEntry
        entry.source = .aiTextEstimate

        let message = CoachResponseBuilder.food(entry, log: nil)

        XCTAssertTrue(message.contains(FormaProductCopy.Coach.loggedReviewedEstimate))
        XCTAssertTrue(message.contains("About 330 kcal"))
    }

    func testWaterLoggedStaysConciseWhenLogPresent() {
        let log = CoachMutationTestFixtures.sampleDailyLog
        let message = CoachResponseBuilder.water(loggedMl: 500, log: log)

        XCTAssertEqual(message, "Logged 500ml water. 1,200 / 2,400 ml today.")
    }

    func testWeightLoggedFormatsTwoDecimals() {
        let message = CoachResponseBuilder.weight(75.5)
        XCTAssertEqual(message, "Logged your weight as 75.50 kg.")
    }

    func testStatusIncludesMacroAndWaterLines() {
        let message = CoachResponseBuilder.status(CoachMutationTestFixtures.sampleDailyLog)

        XCTAssertTrue(message.contains("Today so far:"))
        XCTAssertTrue(message.contains("Calories: 900 / 1800 kcal"))
        XCTAssertTrue(message.contains("Protein: 70 / 130g"))
        XCTAssertTrue(message.contains("Water: 1200 / 2400ml"))
        XCTAssertTrue(message.contains("You still have 900 kcal remaining"))
    }

    func testUndoFoodUsesEntryName() {
        let entry = CoachMutationTestFixtures.chickenFoodEntry
        XCTAssertEqual(
            CoachResponseBuilder.undoFood(entry),
            "Undid your last food entry: Chicken breast."
        )
    }

    func testUndoFoodWithoutEntryIsExplicit() {
        XCTAssertEqual(
            CoachResponseBuilder.undoFood(nil),
            "There was no food entry to undo."
        )
    }

    func testDeleteAndEditFoodUseShortConfirmation() {
        let entry = CoachMutationTestFixtures.chickenFoodEntry
        XCTAssertEqual(CoachResponseBuilder.deleteFood(entry), "Deleted Chicken breast.")
        XCTAssertEqual(CoachResponseBuilder.editFood(entry), "Updated Chicken breast.")
    }

    func testMutationPendingFallsBackWhenAssistantMessageEmpty() {
        XCTAssertEqual(
            CoachResponseBuilder.mutationPending(assistantMessage: "   "),
            "Review this change before applying it."
        )
        XCTAssertEqual(
            CoachResponseBuilder.mutationPending(assistantMessage: "Delete lunch entry?"),
            "Delete lunch entry?"
        )
    }

    func testPendingRejectedUsesStableCopy() {
        XCTAssertEqual(
            CoachResponseBuilder.pendingRejected,
            "No problem — I did not log it."
        )
    }
}
