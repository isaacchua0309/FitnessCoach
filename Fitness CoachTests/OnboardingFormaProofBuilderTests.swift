//
//  OnboardingFormaProofBuilderTests.swift
//  Fitness CoachTests
//
//  Forma — goal-aware forma proof builder tests.
//

import XCTest
@testable import Fitness_Coach

final class OnboardingFormaProofBuilderTests: XCTestCase {

    func testComparisonAccessibilitySummarizesBothSides() {
        let state = makeFormState(currentKg: 70, goalDeltaKg: -3.5)
        let proof = OnboardingFormaProofBuilder.build(from: state)

        XCTAssertTrue(proof.comparison.accessibilityLabel.contains("Without structure"))
        XCTAssertTrue(proof.comparison.accessibilityLabel.contains("With Forma"))
        XCTAssertTrue(proof.comparison.accessibilityLabel.contains("Daily calorie and macro targets"))
    }

    func testMaintainUsesTargetWeightInHero() {
        let state = makeFormState(currentKg: 72.5, goalDeltaKg: 0)
        let proof = OnboardingFormaProofBuilder.build(from: state)

        XCTAssertEqual(proof.heroMetric, "Maintain around 72.5 kg")
    }

    private func makeFormState(
        currentKg: Double,
        goalDeltaKg: Double,
        unitSystem: UnitSystem = .metric
    ) -> OnboardingFormState {
        var state = OnboardingFormState()
        state.unitSystem = unitSystem
        OnboardingHeightWeightValues.setWeightKg(currentKg, in: &state)
        OnboardingTargetWeightValues.setGoalFromDeltaKg(goalDeltaKg, in: &state)
        return state
    }
}
