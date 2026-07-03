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

    func testLogMealLaunchShowsStarterPresentationWithoutChatMessages() {
        model.inputText = "leftover text"

        model.launch(with: .logMeal(mealType: .lunch))

        XCTAssertEqual(model.inputText, "")
        XCTAssertEqual(model.messages.count, 0)
        XCTAssertEqual(model.activeLaunchPresentation?.headline, "Log lunch")
        XCTAssertEqual(
            model.activeLaunchPresentation?.chips,
            [.takePhoto, .describeMeal, .useVoice]
        )
        XCTAssertEqual(
            model.resolvedComposerPlaceholder,
            FormaProductCopy.Coach.mealLoggingComposerPlaceholder(mealType: .lunch)
        )
        XCTAssertTrue(model.requestsComposerFocus)
    }

    func testAnalyzePhotoMealLaunchDoesNotPrefillComposerText() {
        model.launch(with: .analyzePhotoMeal)

        XCTAssertEqual(model.inputText, "")
        XCTAssertEqual(model.messages.count, 0)
        XCTAssertEqual(model.activeLaunchPresentation?.headline, FormaProductCopy.Coach.Launch.analyzePhotoHeadline)
        XCTAssertEqual(model.activeLaunchPresentation?.chips, [.takePhoto, .describeMeal])
        XCTAssertFalse(model.requestsComposerFocus)
    }

    func testLogWaterLaunchShowsWaterChip() {
        model.launch(with: .logWater(amountMl: 500))

        XCTAssertEqual(model.activeLaunchPresentation?.chips, [.addWater(amountMl: 500)])
        XCTAssertEqual(model.inputText, "")
        XCTAssertEqual(model.messages.count, 0)
    }

    func testNormalLaunchDoesNotShowStarterPresentation() {
        model.launch(with: .logMeal(mealType: nil))
        model.launch(with: .normal)

        XCTAssertNil(model.activeLaunchPresentation)
        XCTAssertEqual(model.resolvedComposerPlaceholder, FormaProductCopy.Coach.composerPlaceholder)
    }

    func testSendConsumesLaunchPresentationAndPlaceholder() async {
        model.launch(with: .logMeal(mealType: nil))
        model.inputText = "grilled chicken salad"

        await model.sendCurrentMessage()

        XCTAssertNil(model.activeLaunchPresentation)
        XCTAssertEqual(model.resolvedComposerPlaceholder, FormaProductCopy.Coach.composerPlaceholder)
        XCTAssertEqual(model.messages.count, 1)
    }

    func testHandleCoachBecameInactiveConsumesStarterWithoutInsertingMessages() {
        model.launch(with: .logMeal(mealType: nil))
        XCTAssertNotNil(model.activeLaunchPresentation)

        model.handleCoachBecameInactive()

        XCTAssertNil(model.activeLaunchPresentation)
        XCTAssertEqual(model.messages.count, 0)
        XCTAssertEqual(model.resolvedComposerPlaceholder, FormaProductCopy.Coach.composerPlaceholder)
    }

    func testComposerInteractionConsumesStarterButKeepsPlaceholderUntilSend() {
        model.launch(with: .logMeal(mealType: nil))

        model.noteComposerInteraction()

        XCTAssertNil(model.activeLaunchPresentation)
        XCTAssertEqual(
            model.resolvedComposerPlaceholder,
            FormaProductCopy.Coach.mealLoggingComposerPlaceholder(mealType: nil)
        )
    }

    func testConsumeComposerFocusRequest() {
        model.launch(with: .logMeal(mealType: nil))
        XCTAssertTrue(model.requestsComposerFocus)

        model.consumeComposerFocusRequest()

        XCTAssertFalse(model.requestsComposerFocus)
    }

    func testPresentationBuilderMapsMealTypes() {
        XCTAssertEqual(
            CoachLaunchPresentationBuilder.presentation(for: .logMeal(mealType: .breakfast))?.headline,
            "Log breakfast"
        )
        XCTAssertNil(CoachLaunchPresentationBuilder.presentation(for: .normal))
        XCTAssertNil(CoachLaunchPresentationBuilder.presentation(for: .prefill("Review my day")))
    }
}
