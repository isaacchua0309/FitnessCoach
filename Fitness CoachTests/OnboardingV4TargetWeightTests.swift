//
//  OnboardingV4TargetWeightTests.swift
//  Fitness CoachTests
//
//  Forma — V4 target weight loss ruler tests.
//

import XCTest
@testable import Fitness_Coach

final class OnboardingV4TargetWeightTests: XCTestCase {

    private func sampleForm(currentKg: Double = 72, heightCm: Double = 170) -> OnboardingFormState {
        var state = OnboardingFormState()
        OnboardingV4HeightWeightValues.setHeightCm(heightCm, in: &state)
        OnboardingV4HeightWeightValues.setWeightKg(currentKg, in: &state)
        return state
    }

    func testTargetEqualsCurrentMinusLoss() {
        var state = sampleForm(currentKg: 72)
        OnboardingV4TargetWeightValues.setGoalFromLossKg(3.4, in: &state)

        XCTAssertEqual(state.parsedGoalWeightKg ?? 0, 68.6, accuracy: 0.01)
        XCTAssertEqual(
            OnboardingV4TargetWeightValues.resolvedLossKg(from: state),
            3.4,
            accuracy: 0.01
        )
    }

    func testLossRangeRespectsGoalWeightBoundsMinimum() {
        let current = 72.0
        let height = 170.0
        let range = OnboardingV4TargetWeightValues.lossRangeKg(
            currentWeightKg: current,
            heightCm: height
        )
        let minimumGoal = OnboardingGoalWeightBounds.rangeKg(
            currentWeightKg: current,
            heightCm: height
        ).lowerBound

        XCTAssertEqual(range.lowerBound, 0)
        XCTAssertEqual(range.upperBound, current - minimumGoal, accuracy: 0.01)
    }

    func testValidationRejectsGoalAboveCurrent() {
        var state = sampleForm(currentKg: 72)
        state.goalWeightKgText = "75.0"

        XCTAssertFalse(state.canAdvanceV4(from: .targetWeight))
        XCTAssertEqual(
            state.validationMessageV4(for: .targetWeight),
            FormaProductCopy.Onboarding.V2.Goal.goalMustBeBelowCurrent
        )
    }

    func testValidationAcceptsSafeCutTarget() {
        var state = sampleForm(currentKg: 72, heightCm: 170)
        OnboardingV4TargetWeightValues.setGoalFromLossKg(3.5, in: &state)
        state.selectPaceChoice(.moderate)

        XCTAssertTrue(state.canAdvanceV4(from: .targetWeight))
        XCTAssertEqual(state.weightLossPaceChoice, .moderate)
        XCTAssertEqual(state.aggressiveness, .moderate)
    }

    func testImperialDisplaySummaryUsesLbUnits() {
        var state = sampleForm(currentKg: 72)
        state.unitSystem = .imperial
        OnboardingV4TargetWeightValues.setGoalFromLossKg(3.5, in: &state)

        let summary = OnboardingV4TargetWeightValues.currentToTargetSummary(for: state)
        XCTAssertNotNil(summary)
        XCTAssertTrue(summary?.contains("lb") == true)
        XCTAssertTrue(summary?.contains("→") == true)
    }

    func testMetricDisplaySummaryUsesKgUnits() {
        var state = sampleForm(currentKg: 72)
        state.unitSystem = .metric
        OnboardingV4TargetWeightValues.setGoalFromLossKg(3.5, in: &state)

        let summary = OnboardingV4TargetWeightValues.currentToTargetSummary(for: state)
        XCTAssertEqual(summary, "Current 72 kg → Target 68.5 kg")
    }

    func testDraftRestoreReturnsTargetWeightWhenGoalMissing() {
        var formState = sampleForm()
        formState.goalWeightKgText = ""

        let restored = OnboardingV4DraftBridge.restoredV4Step(
            legacyStep: .goal,
            formState: formState,
            flow: OnboardingV4Step.fullFlow
        )

        XCTAssertEqual(restored, .targetWeight)
    }

    func testDraftRestoreSkipsToTargetEncouragementWhenGoalValid() {
        var formState = sampleForm()
        OnboardingV4TargetWeightValues.setGoalFromLossKg(4, in: &formState)

        let restored = OnboardingV4DraftBridge.restoredV4Step(
            legacyStep: .goal,
            formState: formState,
            flow: OnboardingV4Step.fullFlow
        )

        XCTAssertEqual(restored, .targetEncouragement)
    }

    func testTargetWeightRoutesToTargetEncouragement() {
        XCTAssertEqual(
            OnboardingV4Step.targetWeight.next(in: OnboardingV4Step.fullFlow),
            .targetEncouragement
        )
    }

    func testStepCopyMatchesProductConstants() {
        let step = OnboardingV4Step.targetWeight
        let copy = FormaProductCopy.Onboarding.V4.TargetWeight.self

        XCTAssertEqual(step.title, copy.title)
        XCTAssertEqual(step.subtitle, copy.subtitle)
    }

    func testDraftFormFieldsPreserveGoalWeight() {
        var formState = sampleForm()
        OnboardingV4TargetWeightValues.setGoalFromLossKg(5, in: &formState)
        formState.selectPaceChoice(.moderate)

        let restored = OnboardingDraft(formState: formState, currentStep: .goal).makeFormState()

        XCTAssertEqual(restored.parsedGoalWeightKg, formState.parsedGoalWeightKg)
        XCTAssertEqual(restored.parsedGoalWeightKg ?? 0, 67.0, accuracy: 0.01)
        XCTAssertEqual(restored.weightLossPaceChoice, .moderate)
    }
}
