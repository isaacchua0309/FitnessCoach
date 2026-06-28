//
//  OnboardingHeightWeightMaintenanceEstimatorTests.swift
//  Fitness CoachTests
//
//  Forma — Maintenance preview estimator tests for height/weight onboarding.
//

import XCTest
@testable import Fitness_Coach

final class OnboardingHeightWeightMaintenanceEstimatorTests: XCTestCase {

    func testPreviewStateReturnsMaintenanceForValidMeasurements() {
        var state = OnboardingFormState()
        OnboardingHeightWeightValues.setHeightCm(175, in: &state)
        OnboardingHeightWeightValues.setWeightKg(72, in: &state)

        let preview = OnboardingHeightWeightMaintenanceEstimator.previewState(for: state)

        XCTAssertFalse(preview.isPlaceholder)
        XCTAssertNotNil(preview.maintenanceKcal)
        XCTAssertGreaterThan(preview.maintenanceKcal ?? 0, 0)
        XCTAssertTrue(preview.accessibilityValue.contains("Estimated maintenance"))
    }

    func testPreviewStateUpdatesWhenWeightChanges() {
        var state = OnboardingFormState()
        OnboardingHeightWeightValues.setHeightCm(175, in: &state)
        OnboardingHeightWeightValues.setWeightKg(72, in: &state)
        let initial = OnboardingHeightWeightMaintenanceEstimator.previewState(for: state)

        OnboardingHeightWeightValues.setWeightKg(85, in: &state)
        let updated = OnboardingHeightWeightMaintenanceEstimator.previewState(for: state)

        XCTAssertNotEqual(initial.maintenanceKcal, updated.maintenanceKcal)
    }

    func testPreviewStatePlaceholderForOutOfRangeMeasurements() {
        var state = OnboardingFormState()
        OnboardingHeightWeightValues.setHeightCm(250, in: &state)
        OnboardingHeightWeightValues.setWeightKg(72, in: &state)

        let preview = OnboardingHeightWeightMaintenanceEstimator.previewState(for: state)

        XCTAssertTrue(preview.isPlaceholder)
        XCTAssertNil(preview.maintenanceKcal)
    }
}
