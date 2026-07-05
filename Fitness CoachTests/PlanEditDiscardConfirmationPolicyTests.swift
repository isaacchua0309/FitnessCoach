//
//  PlanEditDiscardConfirmationPolicyTests.swift
//  Fitness CoachTests
//
//  Forma — Unit tests for discard confirmation routing state.
//

import XCTest
@testable import Fitness_Coach

final class PlanEditDiscardConfirmationPolicyTests: XCTestCase {

    func testCancelRequestActionWithNoChangesDismissesImmediately() {
        XCTAssertEqual(
            PlanEditDiscardConfirmationPolicy.cancelRequestAction(hasUnsavedChanges: false),
            .dismissImmediately
        )
    }

    func testCancelRequestActionWithUnsavedChangesPresentsConfirmation() {
        XCTAssertEqual(
            PlanEditDiscardConfirmationPolicy.cancelRequestAction(hasUnsavedChanges: true),
            .presentConfirmation
        )
    }

    func testHandleCancelRequestShowsConfirmationWhenDirty() {
        var state = PlanEditDiscardConfirmationState()

        let action = state.handleCancelRequest(hasUnsavedChanges: true)

        XCTAssertEqual(action, .presentConfirmation)
        XCTAssertTrue(state.isShowingConfirmation)
    }

    func testHandleCancelRequestLeavesConfirmationHiddenWhenClean() {
        var state = PlanEditDiscardConfirmationState()

        let action = state.handleCancelRequest(hasUnsavedChanges: false)

        XCTAssertEqual(action, .dismissImmediately)
        XCTAssertFalse(state.isShowingConfirmation)
    }

    func testKeepEditingHidesConfirmation() {
        var state = PlanEditDiscardConfirmationState()
        _ = state.handleCancelRequest(hasUnsavedChanges: true)
        XCTAssertTrue(state.isShowingConfirmation)

        state.keepEditing()

        XCTAssertFalse(state.isShowingConfirmation)
    }

    func testDismissConfirmationHidesConfirmation() {
        var state = PlanEditDiscardConfirmationState()
        _ = state.handleCancelRequest(hasUnsavedChanges: true)

        state.dismissConfirmation()

        XCTAssertFalse(state.isShowingConfirmation)
    }
}
