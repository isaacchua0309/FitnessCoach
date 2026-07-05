//
//  CoachPhotoPickerPresentationTests.swift
//  Fitness CoachTests
//
//  Legacy picker presentation state machine.
//
//  `CoachPhotoPickerPresentation` is retained in the codebase but is not
//  production wiring — Coach uses `CoachImagePickFlowController` with
//  `CoachInputState.pendingImage` instead. These tests guard the legacy struct
//  only; see `CoachImagePickFlowTests` and `CoachPhotoLibrarySelectionControllerTests`
//  for production picker behavior.
//

import XCTest
@testable import Fitness_Coach

final class CoachPhotoPickerPresentationTests: XCTestCase {

    func testPickerDestinationNoneIsNotPresenting() {
        XCTAssertFalse(CoachPhotoPickerDestination.none.isPresentingPicker)
    }

    func testActivePickerDestinationsArePresenting() {
        XCTAssertTrue(CoachPhotoPickerDestination.camera.isPresentingPicker)
        XCTAssertTrue(CoachPhotoPickerDestination.photoLibrary.isPresentingPicker)
    }

    func testCameraUnavailableErrorCopy() {
        XCTAssertTrue(
            CoachResponseBuilder.mealPhotoError(.cameraUnavailable)
                .localizedCaseInsensitiveContains("not available")
        )
    }

    func testIdlePresentationCannotPresentDuplicatePickers() {
        var presentation = CoachPhotoPickerPresentation.idle

        XCTAssertTrue(presentation.present(.photoLibrary))
        XCTAssertFalse(presentation.present(.camera))
        XCTAssertEqual(presentation.activePicker, .photoLibrary)
    }

    func testRequestSourceDialogIgnoresDuplicateOpen() {
        var presentation = CoachPhotoPickerPresentation.idle

        XCTAssertTrue(presentation.requestSourceDialogPresentation())
        XCTAssertFalse(presentation.requestSourceDialogPresentation())
    }

    func testPrepareSourceDialogClearsPendingDestination() {
        var presentation = CoachPhotoPickerPresentation.idle
        presentation.pendingDestination = .camera

        presentation.prepareSourceDialogPresentation()

        XCTAssertEqual(presentation.pendingDestination, .none)
        XCTAssertTrue(presentation.isSourceDialogPresented)
    }

    func testConsumePendingClearsDestinationWhenPickerBlocked() {
        var presentation = CoachPhotoPickerPresentation.idle
        presentation.pendingDestination = .photoLibrary
        presentation.activePicker = .camera

        let destination = presentation.consumePendingDestinationOnSourceDialogDismissed()

        XCTAssertEqual(destination, .none)
        XCTAssertEqual(presentation.pendingDestination, .none)
        XCTAssertFalse(presentation.isSourceDialogPresented)
    }

    func testRequestCameraPickerRequiresAvailability() {
        var presentation = CoachPhotoPickerPresentation.idle

        XCTAssertEqual(presentation.requestCameraPicker(isCameraAvailable: false), .none)
        XCTAssertEqual(presentation.requestCameraPicker(isCameraAvailable: true), .camera)
        XCTAssertEqual(presentation.activePicker, .camera)
    }

    func testSourceDialogDismissAfterLibrarySelectionReturnsLibraryDestination() {
        var presentation = CoachPhotoPickerPresentation.idle

        XCTAssertTrue(presentation.requestSourceDialogPresentation())
        presentation.selectAttachmentSource(.photoLibrary)

        let destination = presentation.finishSourceDialogDismissal()

        XCTAssertEqual(destination, .photoLibrary)
        XCTAssertFalse(presentation.isSourceDialogPresented)
    }

    func testSourceDialogDismissAfterCameraSelectionReturnsCameraDestination() {
        var presentation = CoachPhotoPickerPresentation.idle

        XCTAssertTrue(presentation.requestSourceDialogPresentation())
        presentation.selectAttachmentSource(.camera)

        let destination = presentation.finishSourceDialogDismissal()

        XCTAssertEqual(destination, .camera)
    }

    func testBlockingSheetDismissesAllPickerState() {
        var presentation = CoachPhotoPickerPresentation.idle
        presentation.selectAttachmentSource(.photoLibrary)
        _ = presentation.present(.photoLibrary)

        presentation.dismissForBlockingSheet()

        XCTAssertEqual(presentation, .idle)
    }

    func testRequestPhotoLibraryPickerWhileDialogOpenQueuesForDismissal() {
        var presentation = CoachPhotoPickerPresentation.idle
        XCTAssertTrue(presentation.requestSourceDialogPresentation())

        let immediate = presentation.requestPhotoLibraryPicker()

        XCTAssertEqual(immediate, .none)
        XCTAssertFalse(presentation.isSourceDialogPresented)
        XCTAssertEqual(presentation.pendingDestination, .photoLibrary)

        let destination = presentation.finishSourceDialogDismissal()
        XCTAssertEqual(destination, .photoLibrary)
    }

    func testRapidPresentationRequestsKeepSingleActiveSurface() {
        var presentation = CoachPhotoPickerPresentation.idle

        XCTAssertTrue(presentation.requestSourceDialogPresentation())
        XCTAssertFalse(presentation.requestSourceDialogPresentation())
        XCTAssertTrue(presentation.isSourceDialogPresented)
        XCTAssertFalse(presentation.isPresentingPicker)

        presentation.selectAttachmentSource(.photoLibrary)
        let destination = presentation.finishSourceDialogDismissal()
        XCTAssertEqual(destination, .photoLibrary)
        XCTAssertTrue(presentation.present(destination))
        XCTAssertEqual(presentation.activePicker, .photoLibrary)
        XCTAssertFalse(presentation.present(.camera))
        XCTAssertFalse(presentation.requestSourceDialogPresentation())
    }
}
