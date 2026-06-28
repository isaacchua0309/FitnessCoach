//
//  OnboardingFormaProofBuilderTests.swift
//  Fitness CoachTests
//
//  Forma — goal-aware forma proof builder tests.
//

import XCTest
@testable import Fitness_Coach

final class OnboardingFormaProofBuilderTests: XCTestCase {

    func testBenefitsAccessibilitySummarizesAllItems() {
        let state = makeFormState(currentKg: 70, goalDeltaKg: -3.5)
        let proof = OnboardingFormaProofBuilder.build(from: state)

        XCTAssertTrue(proof.benefitsAccessibilityLabel.contains("A pace you can hold"))
        XCTAssertTrue(proof.benefitsAccessibilityLabel.contains("Daily clarity, not willpower"))
        XCTAssertTrue(proof.benefitsAccessibilityLabel.contains("Progress that compounds"))
    }

    func testMaintainUsesTargetWeightInHero() {
        let state = makeFormState(currentKg: 72.5, goalDeltaKg: 0)
        let proof = OnboardingFormaProofBuilder.build(from: state)

        XCTAssertEqual(proof.goalIntentLabel, "Maintain")
        XCTAssertEqual(proof.targetWeightLabel, "72.5 kg")
        XCTAssertEqual(proof.ringProgress, 1)
        XCTAssertEqual(proof.pathStyle, .maintain)
    }

    func testMaintainBenefitsUseFutureVisionCopy() {
        let state = makeFormState(currentKg: 70, goalDeltaKg: 0)
        let proof = OnboardingFormaProofBuilder.build(from: state)

        XCTAssertEqual(proof.benefits.map(\.title), [
            "Guardrails, not restrictions",
            "Catch drift before it sticks",
            "Balance you can live with"
        ])
        XCTAssertEqual(proof.visionHeadline, "This becomes your new normal.")
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
