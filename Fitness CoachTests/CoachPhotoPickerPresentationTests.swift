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
                .localizedCaseInsensitiveContains("library")
        )
    }
}
