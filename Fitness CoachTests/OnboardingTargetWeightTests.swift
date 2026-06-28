//
//  OnboardingTargetWeightTests.swift
//  Fitness CoachTests
//
//  Forma — Target weight domain tests (absolute goal selection).
//

import XCTest
@testable import Fitness_Coach

final class OnboardingTargetWeightTests: XCTestCase {

    private let maintainCurrentKg = 90.0
    private let maintainHeightCm = 170.0

    private func sampleForm(
        currentKg: Double = 72,
        heightCm: Double = 170,
        unitSystem: UnitSystem = .metric
    ) -> OnboardingFormState {
        var state = OnboardingFormState()
        OnboardingHeightWeightValues.setHeightCm(heightCm, in: &state)
        OnboardingHeightWeightValues.setWeightKg(currentKg, in: &state)
        state.unitSystem = unitSystem
        return state
    }

    private func goalDirection(for state: OnboardingFormState) -> OnboardingGoalDirection? {
        guard let current = state.parsedCurrentWeightKg,
              let goal = state.parsedGoalWeightKg else {
            return nil
        }
        return OnboardingGoalProjectionBuilder.goalDirection(
            currentWeightKg: current,
            goalWeightKg: goal
        )
    }

    // MARK: - 1. Default target equals current weight

    func testApplyDefaultsSetsTargetToCurrentWeightAndMaintainDirection() {
        var state = sampleForm(currentKg: maintainCurrentKg, heightCm: maintainHeightCm)
        XCTAssertNil(state.parsedGoalWeightKg)

        OnboardingTargetWeightValues.applyDefaultsIfNeeded(to: &state)

        XCTAssertEqual(state.parsedGoalWeightKg ?? 0, maintainCurrentKg, accuracy: 0.01)
        XCTAssertEqual(OnboardingTargetWeightValues.resolvedDeltaKg(from: state), 0, accuracy: 0.01)
        XCTAssertEqual(goalDirection(for: state), .maintain)
        XCTAssertEqual(
            OnboardingTargetWeightValues.heroHeadline(for: state),
            "Target 90.0 kg"
        )
    }

    // MARK: - 2. Draft restore

    func testDraftRestorePreservesExistingTargetAndLossCopy() {
        var formState = sampleForm(currentKg: maintainCurrentKg, heightCm: maintainHeightCm)
        OnboardingTargetWeightValues.setGoalWeightKg(85.3, in: &formState)
        formState.selectPaceChoice(.moderate)

        let restored = OnboardingDraft(formState: formState, step: .targetWeight).makeFormState()

        XCTAssertEqual(restored.parsedGoalWeightKg ?? 0, 85.3, accuracy: 0.01)
        XCTAssertEqual(restored.weightLossPaceChoice, .moderate)
        XCTAssertEqual(
            OnboardingTargetWeightValues.differenceLabel(for: restored),
            "Lose 4.7 kg"
        )
    }

    // MARK: - 3. SwiftHorizontalRuler adapter binding — metric loss

    func testSetGoalFromDisplayMetricLossBinding() {
        var state = sampleForm(currentKg: maintainCurrentKg, heightCm: maintainHeightCm)
        OnboardingTargetWeightValues.setGoalFromDisplay(85.3, in: &state)

        XCTAssertEqual(state.parsedGoalWeightKg ?? 0, 85.3, accuracy: 0.01)
        XCTAssertEqual(OnboardingTargetWeightValues.displayGoalValue(from: state), 85.3, accuracy: 0.01)
        XCTAssertEqual(OnboardingTargetWeightValues.resolvedDeltaKg(from: state), -4.7, accuracy: 0.01)
        XCTAssertEqual(
            OnboardingTargetWeightValues.differenceLabel(for: state),
            "Lose 4.7 kg"
        )
        XCTAssertEqual(goalDirection(for: state), .cut)
    }

    // MARK: - 4. SwiftHorizontalRuler adapter binding — gain

    func testSetGoalFromDisplayMetricGainBinding() {
        var state = sampleForm(currentKg: maintainCurrentKg, heightCm: maintainHeightCm)
        OnboardingTargetWeightValues.setGoalFromDisplay(93.0, in: &state)

        XCTAssertEqual(state.parsedGoalWeightKg ?? 0, 93.0, accuracy: 0.01)
        XCTAssertEqual(OnboardingTargetWeightValues.displayGoalValue(from: state), 93.0, accuracy: 0.01)
        XCTAssertEqual(OnboardingTargetWeightValues.resolvedDeltaKg(from: state), 3.0, accuracy: 0.01)
        XCTAssertEqual(
            OnboardingTargetWeightValues.differenceLabel(for: state),
            "Gain 3.0 kg"
        )
        XCTAssertEqual(goalDirection(for: state), .gain)
    }

    // MARK: - 5. Maintain

    func testMaintainShowsZeroChangeLabelAndGuidance() {
        var state = sampleForm(currentKg: maintainCurrentKg, heightCm: maintainHeightCm)
        OnboardingTargetWeightValues.applyDefaultsIfNeeded(to: &state)

        XCTAssertEqual(
            OnboardingTargetWeightValues.differenceLabel(for: state),
            "0.0 kg"
        )
        XCTAssertEqual(OnboardingTargetWeightValues.displayGoalValue(from: state), 90.0, accuracy: 0.01)
        XCTAssertEqual(goalDirection(for: state), .maintain)

        let guidance = OnboardingTargetWeightGuidanceBuilder.guidanceState(for: state)
        XCTAssertEqual(
            guidance?.title,
            FormaProductCopy.Onboarding.Flow.TargetWeight.maintainGoalTitle
        )
        XCTAssertEqual(
            guidance?.body,
            FormaProductCopy.Onboarding.Flow.TargetWeight.maintainGoalBody
        )
        XCTAssertNil(guidance?.paceLine)
    }

    // MARK: - 6. Bounds

    func testUnsafeGoalClampsToMinimumAndMaximum() {
        var state = sampleForm(currentKg: 70, heightCm: 170)
        let allowed = OnboardingGoalWeightBounds.rangeKg(
            currentWeightKg: 70,
            heightCm: 170
        )

        OnboardingTargetWeightValues.setGoalWeightKg(allowed.lowerBound - 5, in: &state)
        XCTAssertEqual(state.parsedGoalWeightKg ?? 0, allowed.lowerBound, accuracy: 0.01)

        OnboardingTargetWeightValues.setGoalWeightKg(allowed.upperBound + 10, in: &state)
        XCTAssertEqual(state.parsedGoalWeightKg ?? 0, allowed.upperBound, accuracy: 0.01)
    }

    func testValidateRejectsGoalOutsideSafeBounds() {
        var state = sampleForm(currentKg: 70, heightCm: 170)
        let allowed = OnboardingGoalWeightBounds.rangeKg(
            currentWeightKg: 70,
            heightCm: 170
        )
        state.goalWeightKgText = String(format: "%.1f", allowed.lowerBound - 5)

        XCTAssertThrowsError(try OnboardingTargetWeightValues.validate(formState: state))
    }

    func testSafetyBoundsAlwaysIncludeCurrentWeight() {
        let current = maintainCurrentKg
        let range = OnboardingGoalWeightBounds.rangeKg(
            currentWeightKg: current,
            heightCm: maintainHeightCm
        )

        XCTAssertLessThanOrEqual(range.lowerBound, current)
        XCTAssertGreaterThanOrEqual(range.upperBound, current)
    }

    func testGoalWeightRangeIncludesCurrentWeightAndDefaultGoal() {
        var state = sampleForm(currentKg: maintainCurrentKg, heightCm: maintainHeightCm)
        OnboardingTargetWeightValues.applyDefaultsIfNeeded(to: &state)

        let range = OnboardingTargetWeightValues.goalWeightRangeDisplay(from: state)
        XCTAssertNotNil(range)
        XCTAssertTrue(range?.contains(maintainCurrentKg) ?? false)
        XCTAssertTrue(range?.contains(OnboardingTargetWeightValues.displayGoalValue(from: state)) ?? false)
    }

    func testGoalWeightRangeIsCenteredNearCurrentNotAtBMIFloor() {
        let range = OnboardingTargetWeightValues.goalWeightRangeDisplay(
            currentWeightKg: maintainCurrentKg,
            heightCm: maintainHeightCm,
            unitSystem: .metric
        )
        let safetyLower = OnboardingGoalWeightBounds.rangeKg(
            currentWeightKg: maintainCurrentKg,
            heightCm: maintainHeightCm
        ).lowerBound

        XCTAssertGreaterThan(range.lowerBound, safetyLower + 5)
        XCTAssertLessThan(range.lowerBound, maintainCurrentKg - 20)
        XCTAssertGreaterThan(range.lowerBound, 0)
    }

    // MARK: - 7. Imperial

    func testImperialDisplayBindingPersistsCanonicalKg() {
        var state = sampleForm(currentKg: 72, heightCm: 170, unitSystem: .imperial)
        let displayGoal = OnboardingGoalWeightBounds.displayValue(fromKg: 68.6, unitSystem: .imperial)

        OnboardingTargetWeightValues.setGoalFromDisplay(displayGoal, in: &state)

        XCTAssertEqual(state.parsedGoalWeightKg ?? 0, 68.6, accuracy: 0.05)
        XCTAssertEqual(state.unitSystem, .imperial)
    }

    func testImperialLossGainMaintainCopy() {
        let currentKg = maintainCurrentKg
        var lossState = sampleForm(currentKg: currentKg, heightCm: maintainHeightCm, unitSystem: .imperial)
        let lossDisplay = OnboardingGoalWeightBounds.displayValue(fromKg: 85.3, unitSystem: .imperial)
        OnboardingTargetWeightValues.setGoalFromDisplay(lossDisplay, in: &lossState)
        XCTAssertEqual(lossState.parsedGoalWeightKg ?? 0, 85.3, accuracy: 0.05)
        XCTAssertEqual(
            OnboardingTargetWeightValues.differenceLabel(for: lossState),
            "Lose 10.4 lb"
        )

        var gainState = sampleForm(currentKg: currentKg, heightCm: maintainHeightCm, unitSystem: .imperial)
        let gainDisplay = OnboardingGoalWeightBounds.displayValue(fromKg: 93.0, unitSystem: .imperial)
        OnboardingTargetWeightValues.setGoalFromDisplay(gainDisplay, in: &gainState)
        XCTAssertEqual(gainState.parsedGoalWeightKg ?? 0, 93.0, accuracy: 0.05)
        XCTAssertEqual(
            OnboardingTargetWeightValues.differenceLabel(for: gainState),
            "Gain 6.6 lb"
        )

        var maintainState = sampleForm(currentKg: currentKg, heightCm: maintainHeightCm, unitSystem: .imperial)
        OnboardingTargetWeightValues.applyDefaultsIfNeeded(to: &maintainState)
        XCTAssertEqual(
            OnboardingTargetWeightValues.differenceLabel(for: maintainState),
            "0.0 lb"
        )
    }

    func testImperialGoalRangeIncludesCurrentDisplayWeight() {
        var state = sampleForm(currentKg: maintainCurrentKg, heightCm: maintainHeightCm, unitSystem: .imperial)
        OnboardingTargetWeightValues.applyDefaultsIfNeeded(to: &state)

        let currentLb = OnboardingGoalWeightBounds.displayValue(
            fromKg: maintainCurrentKg,
            unitSystem: .imperial
        )
        let range = OnboardingTargetWeightValues.goalWeightRangeDisplay(from: state)

        XCTAssertTrue(range?.contains(currentLb) ?? false)
        XCTAssertEqual(
            OnboardingTargetWeightValues.displayGoalValue(from: state),
            currentLb,
            accuracy: 0.25
        )
    }

    // MARK: - 8. Copy safety

    func testTargetWeightCopyAvoidsLegacyRulerAndLossOnlyStrings() {
        let copy = FormaProductCopy.Onboarding.Flow.TargetWeight.self

        XCTAssertFalse(copy.interactionHint.localizedCaseInsensitiveContains("drag the ruler"))
        XCTAssertFalse(copy.interactionHint.localizedCaseInsensitiveContains("how much you want to lose"))

        var maintainState = sampleForm(currentKg: maintainCurrentKg, heightCm: maintainHeightCm)
        OnboardingTargetWeightValues.applyDefaultsIfNeeded(to: &maintainState)
        let maintainGuidance = OnboardingTargetWeightGuidanceBuilder.guidanceState(for: maintainState)
        XCTAssertEqual(maintainGuidance?.title, copy.maintainGoalTitle)
        XCTAssertNotEqual(maintainGuidance?.title, copy.realisticTargetTitle)

        var gainState = sampleForm(currentKg: maintainCurrentKg, heightCm: maintainHeightCm)
        OnboardingTargetWeightValues.setGoalWeightKg(93, in: &gainState)
        let gainGuidance = OnboardingTargetWeightGuidanceBuilder.guidanceState(for: gainState)
        XCTAssertEqual(gainGuidance?.title, copy.gainGoalTitle)
        XCTAssertNotEqual(gainGuidance?.title, copy.realisticTargetTitle)
    }

    func testStepCopyMatchesProductConstants() {
        let step = OnboardingStep.targetWeight
        let copy = FormaProductCopy.Onboarding.Flow.TargetWeight.self

        XCTAssertEqual(step.title, copy.title)
        XCTAssertEqual(step.subtitle, copy.subtitle)
        XCTAssertEqual(copy.interactionHint, "Slide to choose the weight you want to reach.")
        XCTAssertEqual(copy.maintainGoalTitle, "You're maintaining your current weight.")
        XCTAssertEqual(copy.realisticTargetTitle, "This is a realistic target.")
        XCTAssertEqual(copy.gainGoalTitle, "We'll build targets to help you gain steadily.")
    }

    // MARK: - Display formatting

    func testHeroHeadlineAndJourneySummaryUseAbsoluteTargetWeight() {
        var state = sampleForm(currentKg: 70, heightCm: 170)
        OnboardingTargetWeightValues.setGoalFromDeltaKg(-3.5, in: &state)

        XCTAssertEqual(OnboardingTargetWeightValues.heroHeadline(for: state), "Target 66.5 kg")
        XCTAssertEqual(
            OnboardingTargetWeightValues.currentToTargetSummary(for: state),
            "Current 70.0 kg → Goal 66.5 kg"
        )
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

    // MARK: - Validation & routing

    func testValidationAcceptsMaintainCutAndGainTargets() {
        var maintain = sampleForm(currentKg: 72, heightCm: 170)
        OnboardingTargetWeightValues.applyDefaultsIfNeeded(to: &maintain)
        XCTAssertTrue(maintain.canAdvance(from: .targetWeight))

        var cut = sampleForm(currentKg: 72, heightCm: 170)
        OnboardingTargetWeightValues.setGoalFromDeltaKg(-3.5, in: &cut)
        cut.selectPaceChoice(.moderate)
        XCTAssertTrue(cut.canAdvance(from: .targetWeight))

        var gain = sampleForm(currentKg: 72, heightCm: 170)
        OnboardingTargetWeightValues.setGoalWeightKg(75, in: &gain)
        XCTAssertTrue(gain.canAdvance(from: .targetWeight))
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
        OnboardingTargetWeightValues.setGoalFromDeltaKg(-4, in: &formState)

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

    func testSelectorIdentityStaysStableWhileGoalChanges() {
        var state = sampleForm(currentKg: 90, heightCm: 170)
        let identityBefore = OnboardingTargetWeightValues.selectorIdentity(for: state)

        OnboardingTargetWeightValues.setGoalFromDisplay(70.1, in: &state)

        XCTAssertEqual(
            OnboardingTargetWeightValues.selectorIdentity(for: state),
            identityBefore
        )
        XCTAssertEqual(state.parsedGoalWeightKg ?? 0, 70.1, accuracy: 0.01)
    }

    func testSelectorIdentityChangesWhenUnitSystemChanges() {
        var state = sampleForm(currentKg: 90, heightCm: 170)
        let metricIdentity = OnboardingTargetWeightValues.selectorIdentity(for: state)

        state.unitSystem = .imperial

        XCTAssertNotEqual(
            OnboardingTargetWeightValues.selectorIdentity(for: state),
            metricIdentity
        )
    }
}
