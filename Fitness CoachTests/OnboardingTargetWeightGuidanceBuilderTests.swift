//
//  OnboardingTargetWeightGuidanceBuilderTests.swift
//  Fitness CoachTests
//
//  Forma — Target weight guidance builder tests.
//

import XCTest
@testable import Fitness_Coach

final class OnboardingTargetWeightGuidanceBuilderTests: XCTestCase {

    private func sampleForm(currentKg: Double = 72, heightCm: Double = 170) -> OnboardingFormState {
        var state = OnboardingFormState()
        OnboardingHeightWeightValues.setHeightCm(heightCm, in: &state)
        OnboardingHeightWeightValues.setWeightKg(currentKg, in: &state)
        OnboardingTargetWeightValues.setGoalFromLossKg(3.5, in: &state)
        return state
    }

    func testGuidanceIncludesRealisticTargetCopyForCutGoal() {
        let state = sampleForm()
        let guidance = OnboardingTargetWeightGuidanceBuilder.guidanceState(for: state)

        XCTAssertEqual(
            guidance?.title,
            FormaProductCopy.Onboarding.Flow.TargetWeight.realisticTargetTitle
        )
        XCTAssertEqual(
            guidance?.body,
            FormaProductCopy.Onboarding.Flow.TargetWeight.realisticTargetBody
        )
        XCTAssertNotNil(guidance?.paceLine)
        XCTAssertTrue(guidance?.paceLine?.contains("Expected weekly pace") == true)
    }

    func testGuidanceUsesMaintainCopyWhenGoalEqualsCurrent() {
        var state = sampleForm()
        OnboardingTargetWeightValues.setGoalFromLossKg(0, in: &state)

        let guidance = OnboardingTargetWeightGuidanceBuilder.guidanceState(for: state)

        XCTAssertEqual(
            guidance?.title,
            FormaProductCopy.Onboarding.Flow.TargetWeight.maintainGoalTitle
        )
        XCTAssertNil(guidance?.paceLine)
    }

    func testGuidanceUsesGainCopyForGainGoal() {
        var state = sampleForm()
        OnboardingTargetWeightValues.setGoalWeightKg(75, in: &state)

        let guidance = OnboardingTargetWeightGuidanceBuilder.guidanceState(for: state)

        XCTAssertEqual(
            guidance?.title,
            FormaProductCopy.Onboarding.Flow.TargetWeight.gainGoalTitle
        )
        XCTAssertNil(guidance?.paceLine)
    }
}
