//
//  CoachPhotoPickerPresentationTests.swift
//  Fitness CoachTests
//
//  Forma — Coach photo picker destination state.
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
}
