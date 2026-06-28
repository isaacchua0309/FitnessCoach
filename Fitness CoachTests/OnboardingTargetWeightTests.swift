//
//  OnboardingTargetWeightTests.swift
//  Fitness CoachTests
//
//  Forma — target weight absolute goal ruler tests.
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

    func testLossRangeStartsAtZero() {
        let current = 90.0
        let height = 170.0
        let range = OnboardingTargetWeightValues.lossRangeKg(
            currentWeightKg: current,
            heightCm: height
        )

        XCTAssertEqual(range.lowerBound, 0, accuracy: 0.001)
        XCTAssertGreaterThan(range.upperBound, 0)
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

    // MARK: - Ruler calibration (absolute goal weight)

    private func rulerValues(
        currentKg: Double,
        heightCm: Double = 170,
        unitSystem: UnitSystem = .metric,
        selectedGoalKg: Double? = nil
    ) -> [Double] {
        let range = OnboardingTargetWeightValues.goalWeightRangeDisplay(
            currentWeightKg: currentKg,
            heightCm: heightCm,
            unitSystem: unitSystem,
            selectedGoalKg: selectedGoalKg
        )
        return OnboardingRulerMath.buildValues(
            in: range,
            step: OnboardingTargetWeightValues.rulerStep(for: unitSystem)
        )
    }

    func testGoalWeightRangeIncludesCurrentWeight() {
        let current = 90.0
        let height = 170.0
        let range = OnboardingTargetWeightValues.goalWeightRangeDisplay(
            currentWeightKg: current,
            heightCm: height,
            unitSystem: .metric
        )
        let values = rulerValues(currentKg: current, heightCm: height)

        XCTAssertLessThanOrEqual(range.lowerBound, current)
        XCTAssertGreaterThanOrEqual(range.upperBound, current)
        XCTAssertTrue(values.contains(where: { abs($0 - current) < 0.05 }))
    }

    func testGoalWeightRangeIncludesDefaultGoalWeight() {
        let current = 90.0
        var state = sampleForm(currentKg: current, heightCm: 170)
        OnboardingTargetWeightValues.applyDefaultsIfNeeded(to: &state)

        XCTAssertEqual(state.parsedGoalWeightKg ?? 0, current, accuracy: 0.01)
        XCTAssertTrue(OnboardingTargetWeightValues.resolvedGoalDisplayIsInRulerRange(from: state))
    }

    func testInitialSelectedIndexResolvesToCurrentWeight() {
        let current = 90.0
        let height = 170.0
        var state = sampleForm(currentKg: current, heightCm: height)
        OnboardingTargetWeightValues.applyDefaultsIfNeeded(to: &state)

        let values = rulerValues(currentKg: current, heightCm: height)
        let index = OnboardingTargetWeightValues.rulerIndexForGoalWeight(
            goalKg: state.parsedGoalWeightKg ?? current,
            currentWeightKg: current,
            heightCm: height,
            unitSystem: .metric
        )

        XCTAssertNotNil(index)
        XCTAssertNotEqual(index, 0)
        XCTAssertEqual(values[index ?? -1], current, accuracy: 0.01)
    }

    func testRulerDoesNotDefaultToBMILowerBoundForMaintainState() {
        let current = 90.0
        let height = 170.0
        var state = sampleForm(currentKg: current, heightCm: height)
        OnboardingTargetWeightValues.applyDefaultsIfNeeded(to: &state)

        let values = rulerValues(currentKg: current, heightCm: height)
        let display = OnboardingTargetWeightValues.resolvedRulerDisplayValue(from: state)
        let index = OnboardingRulerMath.index(for: display, in: values) ?? 0

        XCTAssertEqual(values[index], current, accuracy: 0.01)
        XCTAssertGreaterThan(values[index], 80)
    }

    func testGoalWeightRangeIsCenteredNearCurrentNotAtBMIFloor() {
        let current = 90.0
        let height = 170.0
        let range = OnboardingTargetWeightValues.goalWeightRangeDisplay(
            currentWeightKg: current,
            heightCm: height,
            unitSystem: .metric
        )
        let safetyLower = OnboardingGoalWeightBounds.rangeKg(
            currentWeightKg: current,
            heightCm: height
        ).lowerBound

        XCTAssertGreaterThan(range.lowerBound, safetyLower + 5)
        XCTAssertLessThan(range.lowerBound, current - 20)
    }

    func testGoalWeightRangeDoesNotStartAtZero() {
        let current = 90.0
        let height = 170.0
        let range = OnboardingTargetWeightValues.goalWeightRangeDisplay(
            currentWeightKg: current,
            heightCm: height,
            unitSystem: .metric
        )
        let values = rulerValues(currentKg: current, heightCm: height)

        XCTAssertGreaterThan(range.lowerBound, 0)
        XCTAssertGreaterThan(values.first ?? 0, 0)
        XCTAssertTrue(values.contains(where: { abs($0 - 90.0) < 0.05 }))
        XCTAssertTrue(values.contains(where: { abs($0 - 87.0) < 0.11 }))
    }

    func testRulerIndexAtCurrentWeightOnFirstLand() {
        let current = 90.0
        let height = 170.0
        var state = sampleForm(currentKg: current, heightCm: height)
        OnboardingTargetWeightValues.applyDefaultsIfNeeded(to: &state)

        let values = rulerValues(currentKg: current, heightCm: height)
        let index = OnboardingTargetWeightValues.rulerIndexForGoalWeight(
            goalKg: state.parsedGoalWeightKg ?? current,
            currentWeightKg: current,
            heightCm: height,
            unitSystem: .metric
        )

        XCTAssertNotNil(index)
        XCTAssertEqual(values[index ?? -1], 90.0, accuracy: 0.01)
    }

    func testLossSelectionRulerCentersOnTarget() {
        let current = 90.0
        var state = sampleForm(currentKg: current, heightCm: 170)
        OnboardingTargetWeightValues.setGoalWeightKg(85.3, in: &state)

        let values = rulerValues(currentKg: current, selectedGoalKg: 85.3)
        let index = OnboardingTargetWeightValues.rulerIndexForGoalWeight(
            goalKg: 85.3,
            currentWeightKg: current,
            heightCm: 170,
            unitSystem: .metric
        )

        XCTAssertEqual(state.parsedGoalWeightKg ?? 0, 85.3, accuracy: 0.01)
        XCTAssertEqual(OnboardingTargetWeightValues.resolvedDeltaKg(from: state), -4.7, accuracy: 0.01)
        XCTAssertEqual(
            OnboardingTargetWeightValues.differenceLabel(for: state),
            "Lose 4.7 kg"
        )
        XCTAssertNotNil(index)
        XCTAssertEqual(values[index ?? -1], 85.3, accuracy: 0.01)
    }

    func testGainSelectionRulerCentersOnTarget() {
        let current = 90.0
        var state = sampleForm(currentKg: current, heightCm: 170)
        OnboardingTargetWeightValues.setGoalWeightKg(93, in: &state)

        let values = rulerValues(currentKg: current, selectedGoalKg: 93)
        let index = OnboardingTargetWeightValues.rulerIndexForGoalWeight(
            goalKg: 93,
            currentWeightKg: current,
            heightCm: 170,
            unitSystem: .metric
        )

        XCTAssertEqual(state.parsedGoalWeightKg ?? 0, 93.0, accuracy: 0.01)
        XCTAssertEqual(OnboardingTargetWeightValues.resolvedDeltaKg(from: state), 3.0, accuracy: 0.01)
        XCTAssertEqual(
            OnboardingTargetWeightValues.differenceLabel(for: state),
            "Gain 3.0 kg"
        )
        XCTAssertNotNil(index)
        XCTAssertEqual(values[index ?? -1], 93.0, accuracy: 0.01)
    }

    func testMaintainSelectionUsesZeroChangeLabel() {
        var state = sampleForm(currentKg: 90, heightCm: 170)
        OnboardingTargetWeightValues.applyDefaultsIfNeeded(to: &state)

        XCTAssertEqual(
            OnboardingTargetWeightValues.differenceLabel(for: state),
            "0.0 kg"
        )
        XCTAssertTrue(OnboardingTargetWeightValues.resolvedGoalDisplayIsInRulerRange(from: state))
    }

    func testDraftRestoresGoalAtRulerIndex() {
        let current = 90.0
        let height = 170.0
        var state = sampleForm(currentKg: current, heightCm: height)
        OnboardingTargetWeightValues.setGoalWeightKg(85.3, in: &state)

        let values = rulerValues(currentKg: current, selectedGoalKg: 85.3)
        let index = OnboardingTargetWeightValues.rulerIndexForGoalWeight(
            goalKg: 85.3,
            currentWeightKg: current,
            heightCm: height,
            unitSystem: .metric
        )

        XCTAssertNotNil(index)
        XCTAssertEqual(values[index ?? -1], 85.3, accuracy: 0.01)
        XCTAssertEqual(OnboardingTargetWeightValues.resolvedLossKg(from: state), 4.7, accuracy: 0.01)
    }

    func testSetGoalFromDisplayPersistsGoalKg() {
        var state = sampleForm(currentKg: 90, heightCm: 170)
        state.unitSystem = .metric
        OnboardingTargetWeightValues.setGoalFromDisplay(85.3, in: &state)

        XCTAssertEqual(state.parsedGoalWeightKg ?? 0, 85.3, accuracy: 0.01)
        XCTAssertTrue(OnboardingTargetWeightValues.resolvedGoalDisplayIsInRulerRange(from: state))
    }

    func testResolvedGoalDisplaySnapsToRulerGrid() {
        var state = sampleForm(currentKg: 70)
        state.unitSystem = .metric
        OnboardingTargetWeightValues.setGoalWeightKg(66.5, in: &state)

        let display = OnboardingTargetWeightValues.resolvedGoalDisplay(from: state)
        let values = rulerValues(currentKg: 70, selectedGoalKg: 66.5)
        XCTAssertNotNil(display)
        XCTAssertNotNil(OnboardingRulerMath.index(for: display ?? 0, in: values))
        XCTAssertEqual(display ?? 0, 66.5, accuracy: 0.01)
    }

    func testSafetyBoundsAlwaysIncludeCurrentWeight() {
        let current = 90.0
        let height = 170.0
        let range = OnboardingGoalWeightBounds.rangeKg(
            currentWeightKg: current,
            heightCm: height
        )

        XCTAssertLessThanOrEqual(range.lowerBound, current)
        XCTAssertGreaterThanOrEqual(range.upperBound, current)
    }

    func testImperialRulerRangeIncludesCurrentDisplayWeight() {
        let currentKg = 90.0
        var state = sampleForm(currentKg: currentKg, heightCm: 170)
        state.unitSystem = .imperial
        OnboardingTargetWeightValues.applyDefaultsIfNeeded(to: &state)

        let currentLb = OnboardingGoalWeightBounds.displayValue(
            fromKg: currentKg,
            unitSystem: .imperial
        )
        let values = rulerValues(currentKg: currentKg, unitSystem: .imperial)
        XCTAssertTrue(values.contains(where: { abs($0 - currentLb) < 0.25 }))
        XCTAssertEqual(state.parsedGoalWeightKg ?? 0, currentKg, accuracy: 0.01)
        XCTAssertTrue(OnboardingTargetWeightValues.resolvedGoalDisplayIsInRulerRange(from: state))
    }

    func testImperialSetGoalFromDisplayPersistsMetricGoal() {
        var state = sampleForm(currentKg: 72, heightCm: 170)
        state.unitSystem = .imperial
        let displayGoal = OnboardingGoalWeightBounds.displayValue(fromKg: 68.6, unitSystem: .imperial)
        OnboardingTargetWeightValues.setGoalFromDisplay(displayGoal, in: &state)

        XCTAssertEqual(state.parsedGoalWeightKg ?? 0, 68.6, accuracy: 0.05)
    }

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
