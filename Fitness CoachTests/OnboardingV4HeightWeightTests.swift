//
//  OnboardingV4HeightWeightTests.swift
//  Fitness CoachTests
//
//  Forma — V4 height/weight persistence, conversion, validation, and routing tests.
//

import XCTest
@testable import Fitness_Coach

final class OnboardingV4HeightWeightValuesTests: XCTestCase {

    func testMetricPersistenceWritesCanonicalKgAndCmFields() {
        var state = OnboardingFormState()
        OnboardingV4HeightWeightValues.setHeightCm(175, in: &state)
        OnboardingV4HeightWeightValues.setWeightKg(72.5, in: &state)

        XCTAssertEqual(state.heightCmText, "175.0")
        XCTAssertEqual(state.currentWeightKgText, "72.50")
        XCTAssertEqual(state.parsedHeightCm, 175)
        XCTAssertEqual(state.parsedCurrentWeightKg, 72.5)
    }

    func testImperialConversionPersistsCanonicalMetricFields() {
        var state = OnboardingFormState()
        state.unitSystem = .imperial
        OnboardingV4HeightWeightValues.setImperialHeight(feet: 5, inches: 10, in: &state)
        OnboardingV4HeightWeightValues.setWeightLb(160, in: &state)

        XCTAssertEqual(OnboardingV4HeightWeightValues.imperialFeet(from: state), 5)
        XCTAssertEqual(OnboardingV4HeightWeightValues.imperialInches(from: state), 10)

        let expectedCm = 177.8
        XCTAssertEqual(state.parsedHeightCm ?? 0, expectedCm, accuracy: 0.05)

        let expectedKg = 160 / OnboardingFormState.poundsPerKilogram
        XCTAssertEqual(state.parsedCurrentWeightKg ?? 0, expectedKg, accuracy: 0.01)
    }

    func testDefaultsOnlyFillHeightAndWeightNotAgeOrSex() {
        var state = OnboardingFormState()
        OnboardingV4HeightWeightValues.applyDefaultsIfNeeded(to: &state)

        XCTAssertFalse(state.heightCmText.isEmpty)
        XCTAssertFalse(state.currentWeightKgText.isEmpty)
        XCTAssertTrue(state.ageText.isEmpty)
        XCTAssertEqual(state.sex, .preferNotToSay)
        XCTAssertTrue(state.estimatedBodyFatPercentageText.isEmpty)
    }

    func testValidationRejectsEmptyHeightAndWeight() {
        let state = OnboardingFormState()
        XCTAssertFalse(state.canAdvanceV4(from: .heightWeight))
        XCTAssertEqual(
            state.validationMessageV4(for: .heightWeight),
            FormaProductCopy.Onboarding.Validation.height
        )
    }

    func testValidationRejectsOutOfRangeHeight() {
        var state = OnboardingFormState()
        OnboardingV4HeightWeightValues.setHeightCm(250, in: &state)
        OnboardingV4HeightWeightValues.setWeightKg(70, in: &state)

        XCTAssertFalse(state.canAdvanceV4(from: .heightWeight))
        XCTAssertEqual(
            state.validationMessageV4(for: .heightWeight),
            FormaProductCopy.Onboarding.V4.Validation.heightOutOfRange
        )
    }

    func testValidationAcceptsInRangeMeasurements() {
        var state = OnboardingFormState()
        OnboardingV4HeightWeightValues.applyDefaultsIfNeeded(to: &state)

        XCTAssertTrue(state.canAdvanceV4(from: .heightWeight))
        XCTAssertNil(state.validationMessageV4(for: .heightWeight))
    }

    func testDraftRestoreReturnsHeightWeightWhenMeasurementsMissing() {
        var formState = OnboardingFormState()
        let flow = OnboardingV4Step.fullFlow

        let restored = OnboardingV4DraftBridge.restoredV4Step(
            legacyStep: .body,
            formState: formState,
            flow: flow
        )

        XCTAssertEqual(restored, .heightWeight)
    }

    func testDraftRestoreSkipsToTargetWeightWhenMeasurementsValid() {
        var formState = OnboardingFormState()
        OnboardingV4HeightWeightValues.applyDefaultsIfNeeded(to: &formState)

        let restored = OnboardingV4DraftBridge.restoredV4Step(
            legacyStep: .body,
            formState: formState,
            flow: OnboardingV4Step.fullFlow
        )

        XCTAssertEqual(restored, .targetWeight)
    }

    func testHeightWeightRoutesToTargetWeight() {
        let flow = OnboardingV4Step.fullFlow
        XCTAssertEqual(OnboardingV4Step.heightWeight.next(in: flow), .targetWeight)
    }

    func testDraftFormFieldsPreserveHeightWeightAndUnitSystem() {
        var formState = OnboardingFormState()
        OnboardingV4HeightWeightValues.setHeightCm(182, in: &formState)
        OnboardingV4HeightWeightValues.setWeightKg(78, in: &formState)
        formState.unitSystem = .imperial

        let draft = OnboardingDraft(formState: formState, currentStep: .body)
        let restored = draft.makeFormState()

        XCTAssertEqual(restored.parsedHeightCm, 182)
        XCTAssertEqual(restored.parsedCurrentWeightKg, 78)
        XCTAssertEqual(restored.unitSystem, .imperial)
    }

    func testFirstInvalidRequiredV4StepIncludesHeightWeight() {
        let empty = OnboardingFormState()
        XCTAssertEqual(
            OnboardingFormState.firstInvalidRequiredV4Step(for: empty),
            .heightWeight
        )
    }
}
