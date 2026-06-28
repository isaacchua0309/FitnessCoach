//
//  OnboardingDestinationTests.swift
//  Fitness CoachTests
//
//  Forma — Target weight validation and goal weight helpers.
//

import XCTest
@testable import Fitness_Coach

final class OnboardingDestinationTests: XCTestCase {

    func testTargetWeightBelowCurrentIsValid() {
        var state = filledBasics()
        state.goalWeightKgText = "65"

        XCTAssertTrue(state.canAdvance(from: .targetWeight))
    }

    func testTargetWeightEqualsCurrentAllowsMaintenanceAdvance() {
        var state = filledBasics()
        state.goalWeightKgText = state.currentWeightKgText

        XCTAssertTrue(state.canAdvance(from: .targetWeight))
    }

    func testGoalWeightDefaultUsesCurrentWeight() {
        var state = filledBasics()
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

    private func filledBasics() -> OnboardingFormState {
        var state = OnboardingFormState()
        state.heightCmText = "168"
        state.currentWeightKgText = "72"
        state.goalWeightKgText = "65"
        state.birthDate = BirthDatePersistence.decode("1996-01-15T00:00:00Z")
        return state
    }
}
