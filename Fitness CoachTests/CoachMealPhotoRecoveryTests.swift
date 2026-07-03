//
//  CoachMealPhotoRecoveryTests.swift
//  Fitness CoachTests
//
//  Meal photo preparation failure copy and composer retry behavior.
//

import XCTest
@testable import Fitness_Coach

final class CoachMealPhotoRecoveryTests: XCTestCase {

    func testEncodingFailedUsesPreparationCopyWithoutCropGuidance() {
        let message = CoachResponseBuilder.mealPhotoError(.encodingFailed)
        XCTAssertEqual(message, FormaProductCopy.Coach.mealPhotoPreparationFailed)
        XCTAssertFalse(message.localizedCaseInsensitiveContains("crop"))
        XCTAssertFalse(message.localizedCaseInsensitiveContains("too large"))
    }

    func testEncodingFailedSupportsComposerRetry() {
        XCTAssertTrue(CoachMealPhotoError.encodingFailed.supportsComposerRetry)
        XCTAssertFalse(CoachMealPhotoError.cameraPermissionDenied.supportsComposerRetry)
    }

    func testInputStateExposesRetryForRecoverablePreparationFailure() {
        var state = CoachInputState.empty
        state.failImageProcessing(.encodingFailed)

        XCTAssertTrue(state.imageErrorSupportsRetry)
        XCTAssertEqual(state.imageErrorMessage, FormaProductCopy.Coach.mealPhotoPreparationFailed)
    }

    func testAnalysisPayloadTooLargeUsesPreparationCopy() {
        let message = CoachResponseBuilder.mealPhotoAnalysisFailed(.payloadTooLarge)
        XCTAssertEqual(message, FormaProductCopy.Coach.mealPhotoPreparationFailed)
        XCTAssertFalse(message.localizedCaseInsensitiveContains("crop"))
    }
}
