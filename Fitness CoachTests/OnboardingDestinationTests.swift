//
//  OnboardingDestinationTests.swift
//  Fitness CoachTests
//
//  Forma — Picker-first destination step validation and goal weight helpers.
//

import XCTest
@testable import Fitness_Coach

final class OnboardingDestinationTests: XCTestCase {

    func testGoalBelowCurrentRequiresPaceValidation() {
        var state = filledDestinationBasics()
        state.goalWeightKgText = "65"
        state.selectPaceChoice(.moderate)

        XCTAssertTrue(state.isPaceApplicable())
        XCTAssertTrue(state.canAdvance(from: .goal))
        XCTAssertTrue(state.canAdvanceV3(from: .goalWeight))
    }

    func testGoalEqualsCurrentAllowsMaintenanceAdvance() {
        var state = filledDestinationBasics()
        state.goalWeightKgText = state.currentWeightKgText

        XCTAssertFalse(state.isPaceApplicable())
        XCTAssertTrue(state.canAdvance(from: .goal))
        XCTAssertTrue(state.canAdvanceV3(from: .goalWeight))
    }

    func testVisiblePaceChoicesExcludeAdvanced() {
        XCTAssertEqual(
            OnboardingV3InteractionPolicy.visiblePaceChoices,
            [.gentle, .moderate, .aggressive]
        )
    }

    func testAdvancedPaceInvalidBlocksAdvance() {
        var state = filledDestinationBasics()
        state.goalWeightKgText = "65"
        state.selectPaceChoice(.advanced)
        state.advancedPaceDraft = WeightLossAdvancedPaceDraft(period: .weekly, amountText: "")

        XCTAssertFalse(state.canAdvance(from: .goal))
        XCTAssertFalse(state.canAdvanceV3(from: .goalWeight))
    }

    func testGoalWeightDefaultUsesCurrentWeight() {
        var state = filledDestinationBasics()
        state.goalWeightKgText = ""
        state.applyGoalWeightDefaultIfNeeded()

        XCTAssertEqual(state.parsedGoalWeightKg, state.parsedCurrentWeightKg)
    }

    func testChangeSummaryForCut() {
        let summary = OnboardingGoalWeightBounds.changeSummary(
            currentKg: 90,
            goalKg: 75,
            unitSystem: .metric
        )
        XCTAssertTrue(summary.contains("Lose"))
        XCTAssertTrue(summary.contains("15"))
        XCTAssertTrue(summary.contains("kg"))
    }

    func testChangeSummaryForMaintenance() {
        let summary = OnboardingGoalWeightBounds.changeSummary(
            currentKg: 72,
            goalKg: 72,
            unitSystem: .metric
        )
        XCTAssertEqual(summary, FormaProductCopy.Onboarding.V2.Goal.changeMaintainLabel)
    }

    private func filledDestinationBasics() -> OnboardingFormState {
        var state = OnboardingFormState()
        state.ageText = "28"
        state.heightCmText = "168"
        state.currentWeightKgText = "72"
        state.goalWeightKgText = "65"
        return state
    }
}
