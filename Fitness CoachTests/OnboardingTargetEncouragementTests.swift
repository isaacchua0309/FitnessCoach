//
//  OnboardingTargetEncouragementTests.swift
//  Fitness CoachTests
//
//  Forma — target encouragement copy and routing tests.
//

import XCTest
@testable import Fitness_Coach

final class OnboardingTargetEncouragementTests: XCTestCase {

    private func sampleCutForm(
        currentKg: Double = 72,
        lossKg: Double = 3.4,
        unitSystem: UnitSystem = .metric
    ) -> OnboardingFormState {
        var state = OnboardingFormState()
        OnboardingHeightWeightValues.setWeightKg(currentKg, in: &state)
        OnboardingTargetWeightValues.setGoalFromLossKg(lossKg, in: &state)
        state.unitSystem = unitSystem
        return state
    }

    func testLossGoalUsesPersonalizedHeroAndJourney() {
        let state = OnboardingTargetEncouragementCopyBuilder.build(from: sampleCutForm())

        XCTAssertEqual(state.title, "Your goal is realistic")
        XCTAssertEqual(state.heroMetric, "Lose 3.4 kg")
        XCTAssertEqual(state.journeyLine, "72 kg → 68.6 kg")
        XCTAssertTrue(state.usesPersonalizedGoal)
        XCTAssertTrue(state.accessibilityLabel.contains("Lose 3.4 kilograms"))
        XCTAssertTrue(state.accessibilityLabel.contains("Current weight 72 kilograms"))
        XCTAssertTrue(state.accessibilityLabel.contains("Target weight 68.6 kilograms"))
    }

    func testImperialLossGoalUsesPoundUnits() {
        let state = OnboardingTargetEncouragementCopyBuilder.build(
            from: sampleCutForm(lossKg: 3.5, unitSystem: .imperial)
        )

        XCTAssertTrue(state.heroMetric.contains("lb"))
        XCTAssertTrue(state.journeyLine?.contains("lb") == true)
        XCTAssertTrue(state.accessibilityLabel.contains("pounds"))
    }

    func testGainGoalUsesGainHeroCopy() {
        var state = OnboardingFormState()
        OnboardingHeightWeightValues.setWeightKg(70, in: &state)
        state.goalWeightKgText = "73.0"

        let built = OnboardingTargetEncouragementCopyBuilder.build(from: state)

        XCTAssertEqual(built.heroMetric, "Gain 3 kg")
        XCTAssertEqual(built.journeyLine, "70 kg → 73 kg")
    }

    func testMaintainGoalUsesMaintainHeroCopy() {
        var state = OnboardingFormState()
        OnboardingHeightWeightValues.setWeightKg(72, in: &state)
        OnboardingTargetWeightValues.setGoalFromLossKg(0, in: &state)

        let built = OnboardingTargetEncouragementCopyBuilder.build(from: state)

        XCTAssertEqual(
            built.heroMetric,
            FormaProductCopy.Onboarding.Flow.TargetEncouragement.maintainHero
        )
        XCTAssertEqual(built.journeyLine, "72 kg → 72 kg")
    }

    func testFallbackWhenWeightsUnavailable() {
        let state = OnboardingTargetEncouragementCopyBuilder.build(from: OnboardingFormState())

        XCTAssertEqual(
            state.heroMetric,
            FormaProductCopy.Onboarding.Flow.TargetEncouragement.fallbackHero
        )
        XCTAssertNil(state.journeyLine)
        XCTAssertFalse(state.usesPersonalizedGoal)
        XCTAssertTrue(state.accessibilityLabel.contains("Your goal is set."))
    }

    func testReassuranceAndBenefitsUseProductCopy() {
        let state = OnboardingTargetEncouragementCopyBuilder.build(from: sampleCutForm())
        let copy = FormaProductCopy.Onboarding.Flow.TargetEncouragement.self

        XCTAssertEqual(state.reassuranceTitle, copy.reassuranceTitle)
        XCTAssertEqual(state.reassuranceBody, copy.reassuranceBody)
        XCTAssertEqual(state.benefits.count, copy.benefits.count)
        XCTAssertEqual(state.benefits.first?.title, copy.benefits.first?.title)
    }

    func testFormattedLossAmountMatchesCurrentMinusGoal() {
        let form = sampleCutForm(currentKg: 80, lossKg: 5)
        let amount = OnboardingTargetEncouragementCopyBuilder.formattedLossAmount(from: form)

        XCTAssertEqual(amount, "5 kg")
        XCTAssertEqual(form.parsedGoalWeightKg ?? 0, 75, accuracy: 0.01)
    }

    func testTargetEncouragementRoutesToBirthday() {
        XCTAssertEqual(
            OnboardingStep.targetEncouragement.next(in: OnboardingStep.flow),
            .birthday
        )
    }

    func testStepCopyMatchesProductConstants() {
        XCTAssertEqual(
            OnboardingStep.targetEncouragement.title,
            FormaProductCopy.Onboarding.Flow.TargetEncouragement.title
        )
        XCTAssertEqual(
            OnboardingStep.targetEncouragement.subtitle,
            FormaProductCopy.Onboarding.Flow.TargetEncouragement.subtitle
        )
    }

    func testContinueCTAUsesContinueLabel() {
        XCTAssertEqual(
            FormaProductCopy.Onboarding.Flow.TargetEncouragement.continueCTA,
            "Continue"
        )
    }
}
