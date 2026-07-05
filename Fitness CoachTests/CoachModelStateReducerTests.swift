//
//  CoachModelStateReducerTests.swift
//  Fitness CoachTests
//
//  Forma — Pure Coach surface-state transition coverage.
//

import XCTest
@testable import Fitness_Coach

final class CoachModelStateReducerTests: XCTestCase {

    func testIdleProcessingPhaseIsNotSending() {
        XCTAssertFalse(
            CoachModelStateReducer.isSending(processingPhase: .idle)
        )
    }

    func testActiveProcessingPhaseIsSending() {
        XCTAssertTrue(
            CoachModelStateReducer.isSending(
                processingPhase: .active(.text)
            )
        )
        XCTAssertTrue(
            CoachModelStateReducer.isSending(
                processingPhase: .active(.mealPhoto(userMessageID: UUID(), prompt: "lunch"))
            )
        )
    }

    func testSessionFailureAndClearErrorStates() {
        let failure = CoachModelStateReducer.sessionFailureError()
        XCTAssertEqual(failure.title, AIServiceError.coachSessionFailureTitle)
        XCTAssertEqual(failure.message, AIServiceError.coachSessionFailureMessage)
        XCTAssertTrue(failure.showsAuthRetry)

        XCTAssertEqual(CoachModelStateReducer.clearedError(), .cleared)
    }

    func testConsumeLaunchPresentationClearsActivePresentationAndFocus() {
        let presentation = CoachLaunchPresentation(
            headline: "Log meal",
            body: "Describe what you ate",
            composerPlaceholder: "Describe your meal",
            chips: [.describeMeal],
            focusesComposer: true
        )
        var chrome = CoachLaunchChromeState.initial
        chrome = CoachModelStateReducer.applyLaunchPresentation(
            chrome,
            presentation: presentation,
            requestsCameraPresentation: false
        )

        let consumed = CoachModelStateReducer.consumeLaunchPresentation(chrome)

        XCTAssertNil(consumed.activeLaunchPresentation)
        XCTAssertFalse(consumed.requestsComposerFocus)
        XCTAssertEqual(consumed.composerPlaceholderOverride, presentation.composerPlaceholder)
    }

    func testAbandonLaunchSessionResetsChrome() {
        let presentation = CoachLaunchPresentation(
            headline: "Analyze photo",
            body: "Add a meal photo",
            composerPlaceholder: "Add a caption",
            chips: [.takePhoto],
            focusesComposer: true
        )
        var chrome = CoachModelStateReducer.applyLaunchPresentation(
            .initial,
            presentation: presentation,
            requestsCameraPresentation: true
        )

        let abandoned = CoachModelStateReducer.abandonLaunchSession(chrome)

        XCTAssertEqual(abandoned, .initial)
    }

    func testConsumeComposerFocusAndCameraPresentationRequests() {
        var chrome = CoachModelStateReducer.requestComposerFocus(
            CoachModelStateReducer.applyLaunchPresentation(
                .initial,
                presentation: CoachLaunchPresentation(
                    headline: "Log meal",
                    body: "Describe what you ate",
                    composerPlaceholder: "Describe your meal",
                    chips: [.describeMeal],
                    focusesComposer: true
                ),
                requestsCameraPresentation: true
            )
        )

        let focusConsumed = CoachModelStateReducer.consumeComposerFocusRequest(chrome)
        XCTAssertFalse(focusConsumed.requestsComposerFocus)
        XCTAssertTrue(focusConsumed.requestsCameraPresentation)

        let cameraCleared = CoachModelStateReducer.clearCameraPresentationRequest(chrome)
        XCTAssertFalse(cameraCleared.requestsCameraPresentation)
    }

    func testPendingConfirmationUISetAndClear() {
        let draft = AIFoodConfirmationDraft(
            originalText: "log chicken",
            assistantMessage: nil,
            mealDraft: FoodLogDraft(displayName: "Chicken"),
            confidence: .medium
        )
        var ui = CoachPendingConfirmationUIState.empty
        ui.foodEditErrorMessage = "stale"
        ui.isShowingFoodEditSheet = true

        let set = CoachModelStateReducer.setPendingConfirmationUI(ui, confirmation: .food(draft))

        XCTAssertEqual(set.pendingConfirmation, .food(draft))
        XCTAssertNil(set.foodEditErrorMessage)
        XCTAssertFalse(set.isShowingFoodEditSheet)

        let cleared = CoachModelStateReducer.clearPendingConfirmationUI(set)
        XCTAssertEqual(cleared, .empty)
    }

    func testConfirmingPendingGuardTransitions() {
        let began = CoachModelStateReducer.beginConfirmingPendingUI(.empty)
        XCTAssertTrue(began.isConfirmingPending)

        let ended = CoachModelStateReducer.endConfirmingPendingUI(began)
        XCTAssertFalse(ended.isConfirmingPending)
    }

    func testFoodEditSheetTransitions() {
        let draft = AIFoodConfirmationDraft(
            originalText: "log oats",
            assistantMessage: nil,
            mealDraft: FoodLogDraft(displayName: "Oats"),
            confidence: .low
        )
        let base = CoachModelStateReducer.setPendingConfirmationUI(.empty, confirmation: .food(draft))

        XCTAssertNotNil(CoachModelStateReducer.openFoodEditSheetUI(base))
        XCTAssertNil(CoachModelStateReducer.openFoodEditSheetUI(.empty))

        let opened = try XCTUnwrap(CoachModelStateReducer.openFoodEditSheetUI(base))
        XCTAssertTrue(opened.isShowingFoodEditSheet)

        let dismissed = CoachModelStateReducer.dismissFoodEditSheetUI(opened)
        XCTAssertFalse(dismissed.isShowingFoodEditSheet)

        var updatedDraft = draft
        updatedDraft.mealDraft = FoodLogDraft(displayName: "Oats bowl")
        let saved = CoachModelStateReducer.saveFoodEditSucceededUI(opened, draft: updatedDraft)
        XCTAssertEqual(saved.pendingConfirmation, .food(updatedDraft))
        XCTAssertFalse(saved.isShowingFoodEditSheet)

        let failed = CoachModelStateReducer.saveFoodEditFailedUI(opened, message: "Invalid")
        XCTAssertEqual(failed.foodEditErrorMessage, "Invalid")
        XCTAssertTrue(failed.isShowingFoodEditSheet)
    }

    func testInputStateSendingSyncPreservesOtherFields() {
        var input = CoachInputState.empty
        input.updateText("hello")
        input.beginProcessingNewSelection(source: .library)

        let synced = CoachModelStateReducer.inputState(input, syncedToSending: true)

        XCTAssertTrue(synced.isSending)
        XCTAssertEqual(synced.text, "hello")
        XCTAssertTrue(synced.isImageProcessing)
    }
}
