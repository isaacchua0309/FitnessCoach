//
//  OnboardingTargetWeightTests.swift
//  Fitness CoachTests
//
//  Forma — target weight loss ruler tests.
//

import XCTest
@testable import Fitness_Coach

final class OnboardingTargetWeightTests: XCTestCase {

    private func sampleForm(currentKg: Double = 72, heightCm: Double = 170) -> OnboardingFormState {
        var state = OnboardingFormState()
        OnboardingHeightWeightValues.setHeightCm(heightCm, in: &state)
        OnboardingHeightWeightValues.setWeightKg(currentKg, in: &state)
        return state
    }

    func testTargetEqualsCurrentMinusLoss() {
        var state = sampleForm(currentKg: 72)
        OnboardingTargetWeightValues.setGoalFromLossKg(3.4, in: &state)

        XCTAssertEqual(state.parsedGoalWeightKg ?? 0, 68.6, accuracy: 0.01)
        XCTAssertEqual(
            OnboardingTargetWeightValues.resolvedLossKg(from: state),
            3.4,
            accuracy: 0.01
        )
    }

    func testLossRangeRespectsGoalWeightBoundsMinimum() {
        let current = 72.0
        let height = 170.0
        let range = OnboardingTargetWeightValues.lossRangeKg(
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

        XCTAssertFalse(state.canAdvance(from: .targetWeight))
        XCTAssertEqual(
            state.validationMessage(for: .targetWeight),
            FormaProductCopy.Onboarding.V2.Goal.goalMustBeBelowCurrent
        )
    }

    func testValidationAcceptsSafeCutTarget() {
        var state = sampleForm(currentKg: 72, heightCm: 170)
        OnboardingTargetWeightValues.setGoalFromLossKg(3.5, in: &state)
        state.selectPaceChoice(.moderate)

        XCTAssertTrue(state.canAdvance(from: .targetWeight))
        XCTAssertEqual(state.weightLossPaceChoice, .moderate)
        XCTAssertEqual(state.aggressiveness, .moderate)
    }

    func testImperialDisplaySummaryUsesLbUnits() {
        var state = sampleForm(currentKg: 72)
        state.unitSystem = .imperial
        OnboardingTargetWeightValues.setGoalFromLossKg(3.5, in: &state)

        let summary = OnboardingTargetWeightValues.currentToTargetSummary(for: state)
        XCTAssertNotNil(summary)
        XCTAssertTrue(summary?.contains("lb") == true)
        XCTAssertTrue(summary?.contains("→") == true)
    }

    func testMetricDisplaySummaryUsesKgUnits() {
        var state = sampleForm(currentKg: 72)
        state.unitSystem = .metric
        OnboardingTargetWeightValues.setGoalFromLossKg(3.5, in: &state)

        let summary = OnboardingTargetWeightValues.currentToTargetSummary(for: state)
        XCTAssertEqual(summary, "Current 72 kg → Target 68.5 kg")
    }

    func testDraftRestoreReturnsTargetWeightWhenGoalMissing() {
        var formState = sampleForm()
        formState.goalWeightKgText = ""

        let restored = OnboardingDraftStepResolver.restoredStep(
            rawValue: OnboardingLegacyPersistedStep.goal.rawValue,
            formState: formState,
            flow: OnboardingStep.flow
        )

        XCTAssertEqual(restored, .targetWeight)
    }

    func testDraftRestoreSkipsToTargetEncouragementWhenGoalValid() {
        var formState = sampleForm()
        OnboardingTargetWeightValues.setGoalFromLossKg(4, in: &formState)

        let restored = OnboardingDraftStepResolver.restoredStep(
            rawValue: OnboardingLegacyPersistedStep.goal.rawValue,
            formState: formState,
            flow: OnboardingStep.flow
        )

        XCTAssertEqual(restored, .targetEncouragement)
    }

    func testTargetWeightRoutesToTargetEncouragement() {
        XCTAssertEqual(
            OnboardingStep.targetWeight.next(in: OnboardingStep.flow),
            .targetEncouragement
        )
    }

    func testStepCopyMatchesProductConstants() {
        let step = OnboardingStep.targetWeight
        let copy = FormaProductCopy.Onboarding.Flow.TargetWeight.self

        XCTAssertEqual(step.title, copy.title)
        XCTAssertEqual(step.subtitle, copy.subtitle)
    }

    func testDraftFormFieldsPreserveGoalWeight() {
        var formState = sampleForm()
        OnboardingTargetWeightValues.setGoalFromLossKg(5, in: &formState)
        formState.selectPaceChoice(.moderate)

        let restored = OnboardingDraft(formState: formState, step: .targetWeight).makeFormState()

        XCTAssertEqual(restored.parsedGoalWeightKg, formState.parsedGoalWeightKg)
        XCTAssertEqual(restored.parsedGoalWeightKg ?? 0, 67.0, accuracy: 0.01)
        XCTAssertEqual(restored.weightLossPaceChoice, .moderate)
    }
}
