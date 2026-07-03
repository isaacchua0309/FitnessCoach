//
//  CoachLaunchIntentTests.swift
//  Fitness CoachTests
//

import XCTest
@testable import Fitness_Coach

@MainActor
final class CoachLaunchIntentTests: XCTestCase {

    private var model: CoachModel!

    override func setUp() async throws {
        model = try AppContainer(inMemory: true).makeCoachModel()
    }

    func testLogMealLaunchClearsInputAndSetsMealLoggingPlaceholder() {
        model.inputText = "leftover text"

        model.launch(with: .logMeal(mealType: .lunch))

        XCTAssertEqual(model.inputText, "")
        XCTAssertEqual(
            model.resolvedComposerPlaceholder,
            FormaProductCopy.Coach.mealLoggingComposerPlaceholder(mealType: .lunch)
        )
        XCTAssertTrue(model.requestsComposerFocus)
    }

    func testLogMealLaunchUsesGenericPlaceholderWithoutMealType() {
        model.launch(with: .logMeal(mealType: nil))

        XCTAssertEqual(
            model.resolvedComposerPlaceholder,
            "What did you eat? Send a photo or describe your meal."
        )
    }

    func testScanFoodLaunchPrefillsScanPrompt() {
        model.launch(with: .scanFood)

        XCTAssertEqual(model.inputText, FormaProductCopy.Coach.scanMealPrefill)
        XCTAssertEqual(model.resolvedComposerPlaceholder, FormaProductCopy.Coach.composerPlaceholder)
        XCTAssertTrue(model.requestsComposerFocus)
    }

    func testSendClearsMealLoggingPlaceholder() async {
        model.launch(with: .logMeal(mealType: nil))
        model.inputText = "grilled chicken salad"

        await model.sendCurrentMessage()

        XCTAssertEqual(model.resolvedComposerPlaceholder, FormaProductCopy.Coach.composerPlaceholder)
    }

    func testConsumeComposerFocusRequest() {
        model.launch(with: .logMeal(mealType: nil))
        XCTAssertTrue(model.requestsComposerFocus)

        model.consumeComposerFocusRequest()

        XCTAssertFalse(model.requestsComposerFocus)
    }
}
