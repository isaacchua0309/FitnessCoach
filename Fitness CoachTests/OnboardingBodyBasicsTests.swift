//
//  OnboardingBodyBasicsTests.swift
//  Fitness CoachTests
//
//  Forma — Picker-first body basics validation and body-fat presets.
//

import XCTest
@testable import Fitness_Coach

final class OnboardingBodyBasicsTests: XCTestCase {

    func testBodyBasicsBlocksAdvanceWhenRequiredFieldsEmpty() {
        let state = OnboardingFormState()
        XCTAssertFalse(state.canAdvanceV3(from: .bodyBasics))
        XCTAssertFalse(state.canAdvance(from: .body))
    }

    func testBodyBasicsAllowsAdvanceWhenRequiredFieldsFilled() {
        var state = OnboardingFormState()
        state.applyBodyBasicsDefaultsIfNeeded()
        XCTAssertTrue(state.canAdvanceV3(from: .bodyBasics))
        XCTAssertTrue(state.canAdvance(from: .body))
    }

    func testBodyFatPresetFifteenStoresValue() {
        var state = OnboardingFormState()
        state.applyBodyBasicsDefaultsIfNeeded()
        state.selectBodyFatPreset(.fifteen)
        XCTAssertEqual(state.estimatedBodyFatPercentageText, "15")
        XCTAssertEqual(state.bodyFatPreset, .fifteen)
        XCTAssertTrue(state.canAdvanceV3(from: .bodyBasics))
    }

    func testBodyFatUnknownClearsValue() {
        var state = OnboardingFormState()
        state.applyBodyBasicsDefaultsIfNeeded()
        state.estimatedBodyFatPercentageText = "24"
        state.selectBodyFatPreset(.unknown)
        XCTAssertEqual(state.estimatedBodyFatPercentageText, "")
        XCTAssertNil(state.bodyFatPreset)
        XCTAssertTrue(state.canAdvanceV3(from: .bodyBasics))
    }

    func testBodyFatCustomValidAcceptsPercentSuffix() throws {
        var state = OnboardingFormState()
        state.applyBodyBasicsDefaultsIfNeeded()
        state.estimatedBodyFatPercentageText = "24%"
        XCTAssertEqual(state.bodyFatPreset, .custom)
        XCTAssertTrue(state.canAdvanceV3(from: .bodyBasics))
        XCTAssertNoThrow(try state.validateV3(step: .bodyBasics))
    }

    func testBodyFatCustomInvalidBlocksAdvance() {
        var state = OnboardingFormState()
        state.applyBodyBasicsDefaultsIfNeeded()
        state.estimatedBodyFatPercentageText = "71"
        XCTAssertFalse(state.canAdvanceV3(from: .bodyBasics))
        XCTAssertEqual(
            state.validationMessageV3(for: .bodyBasics),
            FormaProductCopy.Onboarding.Validation.bodyFatRange
        )
    }

    func testBodyFatInferredFromPresetPercentages() {
        var state = OnboardingFormState()
        state.estimatedBodyFatPercentageText = "25"
        XCTAssertEqual(state.bodyFatPreset, .twentyFive)
    }
}
