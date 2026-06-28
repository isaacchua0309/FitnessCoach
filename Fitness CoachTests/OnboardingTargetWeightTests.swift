//
//  OnboardingTargetWeightTests.swift
//  Fitness CoachTests
//
//  Forma — target weight delta ruler tests.
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

    // MARK: - Initialization

    func testApplyDefaultsInitializesTargetToCurrentWeight() {
        var state = sampleForm(currentKg: 70)
        OnboardingTargetWeightValues.applyDefaultsIfNeeded(to: &state)

        XCTAssertEqual(state.parsedGoalWeightKg ?? 0, 70.0, accuracy: 0.01)
        XCTAssertEqual(OnboardingTargetWeightValues.resolvedDeltaKg(from: state), 0, accuracy: 0.01)
    }

    func testDraftRestorePreservesExistingGoalWeight() {
        var formState = sampleForm(currentKg: 70)
        OnboardingTargetWeightValues.setGoalFromDeltaKg(-3.5, in: &formState)
        formState.selectPaceChoice(.moderate)

        let restored = OnboardingDraft(formState: formState, step: .targetWeight).makeFormState()

        XCTAssertEqual(restored.parsedGoalWeightKg, formState.parsedGoalWeightKg)
        XCTAssertEqual(restored.parsedGoalWeightKg ?? 0, 66.5, accuracy: 0.01)
        XCTAssertEqual(restored.weightLossPaceChoice, .moderate)
    }

    // MARK: - Delta → goal mapping

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

    func testSelectingLowerTargetSetsNegativeDelta() {
        var state = sampleForm(currentKg: 70)
        OnboardingTargetWeightValues.setGoalWeightKg(66.5, in: &state)

        XCTAssertEqual(state.parsedGoalWeightKg ?? 0, 66.5, accuracy: 0.01)
        XCTAssertEqual(OnboardingTargetWeightValues.resolvedDeltaKg(from: state), -3.5, accuracy: 0.01)
    }

    func testSelectingHigherTargetSetsPositiveDelta() {
        var state = sampleForm(currentKg: 70)
        OnboardingTargetWeightValues.setGoalWeightKg(73, in: &state)

        XCTAssertEqual(state.parsedGoalWeightKg ?? 0, 73.0, accuracy: 0.01)
        XCTAssertEqual(OnboardingTargetWeightValues.resolvedDeltaKg(from: state), 3.0, accuracy: 0.01)
    }

    // MARK: - Bounds

    func testDeltaRangeRespectsGoalWeightBounds() {
        let current = 70.0
        let height = 170.0
        let goalRange = OnboardingGoalWeightBounds.rangeKg(
            currentWeightKg: current,
            heightCm: height
        )
        let deltaRange = OnboardingTargetWeightValues.deltaRangeKg(
            currentWeightKg: current,
            heightCm: height
        )

        XCTAssertEqual(deltaRange.lowerBound, goalRange.lowerBound - current, accuracy: 0.11)
        XCTAssertEqual(deltaRange.upperBound, goalRange.upperBound - current, accuracy: 0.11)
        XCTAssertTrue(deltaRange.contains(0))
    }

    func testLossRangeLegacyHelperMatchesPositiveLossSpan() {
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
        XCTAssertEqual(range.upperBound, current - minimumGoal, accuracy: 0.11)
    }

    func testUnsafeTargetIsClampedToBounds() {
        var state = sampleForm(currentKg: 70, heightCm: 170)
        let minimumGoal = OnboardingGoalWeightBounds.rangeKg(
            currentWeightKg: 70,
            heightCm: 170
        ).lowerBound

        OnboardingTargetWeightValues.setGoalWeightKg(minimumGoal - 5, in: &state)
        XCTAssertEqual(state.parsedGoalWeightKg ?? 0, minimumGoal, accuracy: 0.01)

        let maximumGoal = OnboardingGoalWeightBounds.rangeKg(
            currentWeightKg: 70,
            heightCm: 170
        ).upperBound
        OnboardingTargetWeightValues.setGoalWeightKg(maximumGoal + 10, in: &state)
        XCTAssertEqual(state.parsedGoalWeightKg ?? 0, maximumGoal, accuracy: 0.01)
    }

    // MARK: - Validation

    func testValidationAcceptsGainTarget() {
        var state = sampleForm(currentKg: 72, heightCm: 170)
        OnboardingTargetWeightValues.setGoalWeightKg(75, in: &state)
        state.selectPaceChoice(.moderate)

        XCTAssertTrue(state.canAdvance(from: .targetWeight))
    }

    func testValidationAcceptsSafeCutTarget() {
        var state = sampleForm(currentKg: 72, heightCm: 170)
        OnboardingTargetWeightValues.setGoalFromLossKg(3.5, in: &state)
        state.selectPaceChoice(.moderate)

        XCTAssertTrue(state.canAdvance(from: .targetWeight))
        XCTAssertEqual(state.weightLossPaceChoice, .moderate)
        XCTAssertEqual(state.aggressiveness, .moderate)
    }

    func testValidationAcceptsMaintainTarget() {
        var state = sampleForm(currentKg: 70)
        OnboardingTargetWeightValues.applyDefaultsIfNeeded(to: &state)

        XCTAssertTrue(state.canAdvance(from: .targetWeight))
    }

    // MARK: - Display copy

    func testHeroHeadlineAlwaysShowsTargetWeight() {
        var state = sampleForm(currentKg: 72)
        state.unitSystem = .metric
        OnboardingTargetWeightValues.setGoalFromLossKg(3.5, in: &state)

        XCTAssertEqual(OnboardingTargetWeightValues.heroHeadline(for: state), "Target 68.5 kg")
    }

    func testMaintainDifferenceCopy() {
        var state = sampleForm(currentKg: 70)
        state.unitSystem = .metric
        OnboardingTargetWeightValues.applyDefaultsIfNeeded(to: &state)

        XCTAssertEqual(
            OnboardingTargetWeightValues.differenceLabel(for: state),
            "0.0 kg"
        )
    }

    func testLossDifferenceCopy() {
        var state = sampleForm(currentKg: 70)
        state.unitSystem = .metric
        OnboardingTargetWeightValues.setGoalWeightKg(66.5, in: &state)

        XCTAssertEqual(
            OnboardingTargetWeightValues.differenceLabel(for: state),
            "Lose 3.5 kg"
        )
    }

    func testGainDifferenceCopy() {
        var state = sampleForm(currentKg: 70)
        state.unitSystem = .metric
        OnboardingTargetWeightValues.setGoalWeightKg(73, in: &state)

        XCTAssertEqual(
            OnboardingTargetWeightValues.differenceLabel(for: state),
            "Gain 3.0 kg"
        )
    }

    func testMetricDisplaySummaryUsesOneDecimalKg() {
        var state = sampleForm(currentKg: 70)
        state.unitSystem = .metric
        OnboardingTargetWeightValues.setGoalWeightKg(66.5, in: &state)

        let summary = OnboardingTargetWeightValues.currentToTargetSummary(for: state)
        XCTAssertEqual(summary, "Current 70.0 kg → Goal 66.5 kg")
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

    func testMetricFormattingAlwaysUsesOneDecimal() {
        XCTAssertEqual(
            OnboardingTargetWeightValues.targetWeightLabel(valueKg: 70, unitSystem: .metric),
            "70.0 kg"
        )
        XCTAssertEqual(
            OnboardingTargetWeightValues.targetWeightLabel(valueKg: 66.5, unitSystem: .metric),
            "66.5 kg"
        )
    }

    // MARK: - Ruler calibration

    func testRulerZeroAlignsWithDeltaZero() {
        let current = 70.0
        let height = 170.0
        let index = OnboardingTargetWeightValues.rulerIndexForZeroDelta(
            currentWeightKg: current,
            heightCm: height,
            unitSystem: .metric
        )
        let values = OnboardingRulerMath.buildValues(
            in: OnboardingTargetWeightValues.deltaRangeDisplay(
                currentWeightKg: current,
                heightCm: height,
                unitSystem: .metric
            ),
            step: OnboardingTargetWeightValues.rulerStepKg
        )

        XCTAssertNotNil(index)
        XCTAssertEqual(values[index ?? -1], 0, accuracy: 0.001)
    }

    func testResolvedDeltaDisplaySnapsToRulerGrid() {
        var state = sampleForm(currentKg: 70)
        state.unitSystem = .metric
        OnboardingTargetWeightValues.setGoalWeightKg(66.5, in: &state)

        let display = OnboardingTargetWeightValues.resolvedDeltaDisplay(from: state)
        let values = OnboardingRulerMath.buildValues(
            in: OnboardingTargetWeightValues.deltaRangeDisplay(
                currentWeightKg: 70,
                heightCm: 170,
                unitSystem: .metric
            ),
            step: OnboardingTargetWeightValues.rulerStepKg
        )
        XCTAssertNotNil(OnboardingRulerMath.index(for: display, in: values))
    }

    // MARK: - Downstream goal direction

    func testGoalDirectionForMaintainCutAndGain() {
        var maintain = sampleForm(currentKg: 70)
        OnboardingTargetWeightValues.applyDefaultsIfNeeded(to: &maintain)
        XCTAssertEqual(
            OnboardingGoalProjectionBuilder.goalDirection(
                currentWeightKg: 70,
                goalWeightKg: maintain.parsedGoalWeightKg ?? 0
            ),
            .maintain
        )

        var cut = sampleForm(currentKg: 70)
        OnboardingTargetWeightValues.setGoalWeightKg(66.5, in: &cut)
        XCTAssertEqual(
            OnboardingGoalProjectionBuilder.goalDirection(
                currentWeightKg: 70,
                goalWeightKg: cut.parsedGoalWeightKg ?? 0
            ),
            .cut
        )

        var gain = sampleForm(currentKg: 70)
        OnboardingTargetWeightValues.setGoalWeightKg(73, in: &gain)
        XCTAssertEqual(
            OnboardingGoalProjectionBuilder.goalDirection(
                currentWeightKg: 70,
                goalWeightKg: gain.parsedGoalWeightKg ?? 0
            ),
            .gain
        )
    }

    // MARK: - Routing / copy

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
        XCTAssertEqual(copy.subtitle, "Pick a realistic goal for your plan.")
    }
}
