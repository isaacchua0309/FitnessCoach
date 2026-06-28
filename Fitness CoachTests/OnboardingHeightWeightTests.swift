//
//  OnboardingHeightWeightTests.swift
//  Fitness CoachTests
//
//  Forma — height/weight persistence, conversion, validation, and routing tests.
//

import XCTest
@testable import Fitness_Coach

final class OnboardingHeightWeightValuesTests: XCTestCase {

    func testMetricPersistenceWritesCanonicalKgAndCmFields() {
        var state = OnboardingFormState()
        OnboardingHeightWeightValues.setHeightCm(175, in: &state)
        OnboardingHeightWeightValues.setWeightKg(72.5, in: &state)

        XCTAssertEqual(state.heightCmText, "175.0")
        XCTAssertEqual(state.currentWeightKgText, "72.50")
        XCTAssertEqual(state.parsedHeightCm, 175)
        XCTAssertEqual(state.parsedCurrentWeightKg, 72.5)
    }

    func testImperialConversionPersistsCanonicalMetricFields() {
        var state = OnboardingFormState()
        state.unitSystem = .imperial
        OnboardingHeightWeightValues.setImperialHeight(feet: 5, inches: 10, in: &state)
        OnboardingHeightWeightValues.setWeightLb(160, in: &state)

        XCTAssertEqual(OnboardingHeightWeightValues.imperialFeet(from: state), 5)
        XCTAssertEqual(OnboardingHeightWeightValues.imperialInches(from: state), 10)

        let expectedCm = 177.8
        XCTAssertEqual(state.parsedHeightCm ?? 0, expectedCm, accuracy: 0.05)

        let expectedKg = 160 / OnboardingFormState.poundsPerKilogram
        XCTAssertEqual(state.parsedCurrentWeightKg ?? 0, expectedKg, accuracy: 0.01)
    }

    func testDefaultsOnlyFillHeightAndWeightNotBirthdaySexOrBodyFat() {
        var state = OnboardingFormState()
        OnboardingHeightWeightValues.applyDefaultsIfNeeded(to: &state)

        XCTAssertFalse(state.heightCmText.isEmpty)
        XCTAssertFalse(state.currentWeightKgText.isEmpty)
        XCTAssertTrue(state.ageText.isEmpty)
        XCTAssertEqual(state.sex, .preferNotToSay)
        XCTAssertTrue(state.estimatedBodyFatPercentageText.isEmpty)
    }

    func testValidationRejectsEmptyHeightAndWeight() {
        let state = OnboardingFormState()
        XCTAssertFalse(state.canAdvance(from: .heightWeight))
        XCTAssertEqual(
            state.validationMessage(for: .heightWeight),
            FormaProductCopy.Onboarding.Validation.height
        )
    }

    func testValidationRejectsOutOfRangeHeight() {
        var state = OnboardingFormState()
        OnboardingHeightWeightValues.setHeightCm(250, in: &state)
        OnboardingHeightWeightValues.setWeightKg(70, in: &state)

        XCTAssertFalse(state.canAdvance(from: .heightWeight))
        XCTAssertEqual(
            state.validationMessage(for: .heightWeight),
            FormaProductCopy.Onboarding.Flow.Validation.heightOutOfRange
        )
    }

    func testValidationAcceptsInRangeMeasurements() {
        var state = OnboardingFormState()
        OnboardingHeightWeightValues.applyDefaultsIfNeeded(to: &state)

        XCTAssertTrue(state.canAdvance(from: .heightWeight))
        XCTAssertNil(state.validationMessage(for: .heightWeight))
    }

    func testDraftRestoreReturnsHeightWeightWhenMeasurementsMissing() {
        var formState = OnboardingFormState()
        let flow = OnboardingStep.flow

        let restored = OnboardingDraftStepResolver.restoredStep(
            rawValue: OnboardingLegacyPersistedStep.body.rawValue,
            formState: formState,
            flow: flow
        )

        XCTAssertEqual(restored, .heightWeight)
    }

    func testDraftRestoreRoutesToBirthdayWhenHeightWeightValid() {
        var formState = OnboardingFormState()
        OnboardingHeightWeightValues.applyDefaultsIfNeeded(to: &formState)

        let restored = OnboardingDraftStepResolver.restoredStep(
            rawValue: OnboardingLegacyPersistedStep.body.rawValue,
            formState: formState,
            flow: OnboardingStep.flow
        )

        XCTAssertEqual(restored, .birthday)
    }

    func testHeightWeightRoutesToTargetWeight() {
        let flow = OnboardingStep.flow
        XCTAssertEqual(OnboardingStep.heightWeight.next(in: flow), .targetWeight)
    }

    func testDraftFormFieldsPreserveHeightWeightAndUnitSystem() {
        var formState = OnboardingFormState()
        OnboardingHeightWeightValues.setHeightCm(182, in: &formState)
        OnboardingHeightWeightValues.setWeightKg(78, in: &formState)
        formState.unitSystem = .imperial

        let draft = OnboardingDraft(formState: formState, step: .heightWeight)
        let restored = draft.makeFormState()

        XCTAssertEqual(restored.parsedHeightCm, 182)
        XCTAssertEqual(restored.parsedCurrentWeightKg, 78)
        XCTAssertEqual(restored.unitSystem, .imperial)
    }

    func testFirstInvalidRequiredStepIncludesHeightWeight() {
        let empty = OnboardingFormState()
        XCTAssertEqual(
            OnboardingFormState.firstInvalidRequiredStep(for: empty),
            .heightWeight
        )
    }
}
