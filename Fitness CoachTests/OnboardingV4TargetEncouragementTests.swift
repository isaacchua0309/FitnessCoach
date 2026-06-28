//
//  OnboardingV4TargetEncouragementTests.swift
//  Fitness CoachTests
//
//  Forma — V4 target encouragement copy and routing tests.
//

import XCTest
@testable import Fitness_Coach

final class OnboardingV4TargetEncouragementTests: XCTestCase {

    private func sampleCutForm(
        currentKg: Double = 72,
        lossKg: Double = 3.4,
        unitSystem: UnitSystem = .metric
    ) -> OnboardingFormState {
        var state = OnboardingFormState()
        OnboardingV4HeightWeightValues.setWeightKg(currentKg, in: &state)
        OnboardingV4TargetWeightValues.setGoalFromLossKg(lossKg, in: &state)
        state.unitSystem = unitSystem
        return state
    }

    func testDynamicCopyUsesLossAmountInMetricTitle() {
        let copy = OnboardingV4TargetEncouragementCopyBuilder.build(from: sampleCutForm())

        XCTAssertEqual(
            copy.accessibilityHeadline,
            "Losing 3.4 kg is a realistic target."
        )
        XCTAssertEqual(
            copy.headline,
            .lossAmount(
                prefix: "Losing ",
                amount: "3.4 kg",
                suffix: " is a realistic target."
            )
        )
        XCTAssertTrue(copy.usesAccentAmount)
    }

    func testDynamicCopyUsesLossAmountInImperialTitle() {
        let copy = OnboardingV4TargetEncouragementCopyBuilder.build(
            from: sampleCutForm(lossKg: 3.5, unitSystem: .imperial)
        )

        XCTAssertTrue(copy.accessibilityHeadline.hasPrefix("Losing "))
        XCTAssertTrue(copy.accessibilityHeadline.hasSuffix(" is a realistic target."))
        XCTAssertTrue(copy.accessibilityHeadline.contains("lb"))
    }

    func testFallbackCopyWhenWeightsUnavailable() {
        let copy = OnboardingV4TargetEncouragementCopyBuilder.build(from: OnboardingFormState())

        XCTAssertEqual(copy.headline, .fallback("This is a realistic target."))
        XCTAssertEqual(copy.accessibilityHeadline, "This is a realistic target.")
        XCTAssertFalse(copy.usesAccentAmount)
    }

    func testFallbackCopyWhenGoalMatchesCurrentWeight() {
        var state = OnboardingFormState()
        OnboardingV4HeightWeightValues.setWeightKg(72, in: &state)
        state.goalWeightKgText = state.currentWeightKgText

        let copy = OnboardingV4TargetEncouragementCopyBuilder.build(from: state)

        XCTAssertEqual(copy.headline, .fallback("This is a realistic target."))
    }

    func testFormattedLossAmountMatchesCurrentMinusGoal() {
        let state = sampleCutForm(currentKg: 80, lossKg: 5)
        let amount = OnboardingV4TargetEncouragementCopyBuilder.formattedLossAmount(from: state)

        XCTAssertEqual(amount, "5 kg")
        XCTAssertEqual(state.parsedGoalWeightKg ?? 0, 75, accuracy: 0.01)
    }

    func testSubtitleUsesProductCopy() {
        let copy = OnboardingV4TargetEncouragementCopyBuilder.build(from: sampleCutForm())

        XCTAssertEqual(
            copy.subtitle,
            FormaProductCopy.Onboarding.V4.TargetEncouragement.subtitle
        )
    }

    func testTargetEncouragementRoutesToBirthday() {
        XCTAssertEqual(
            OnboardingV4Step.targetEncouragement.next(in: OnboardingV4Step.fullFlow),
            .birthday
        )
    }

    func testStepSubtitleMatchesProductCopy() {
        XCTAssertEqual(
            OnboardingV4Step.targetEncouragement.subtitle,
            FormaProductCopy.Onboarding.V4.TargetEncouragement.subtitle
        )
    }

    func testContinueCTAUsesNextLabel() {
        XCTAssertEqual(
            FormaProductCopy.Onboarding.V4.TargetEncouragement.continueCTA,
            "Next"
        )
    }
}
