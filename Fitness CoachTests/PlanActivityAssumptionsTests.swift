//
//  PlanActivityAssumptionsTests.swift
//  Fitness CoachTests
//

import XCTest
@testable import Fitness_Coach

final class PlanActivityAssumptionsTests: XCTestCase {

    func testAssumptionsShowActivityLevelOnlyInPrimarySummary() {
        let assumptions = PlanMissionControlFixtures.loseDashboard.activityAssumptions

        XCTAssertEqual(assumptions.sectionTitle, "Activity Assumptions")
        XCTAssertEqual(assumptions.activityLevel, "Moderately active")
        XCTAssertEqual(assumptions.activityFieldLabel, "Activity level")
        XCTAssertEqual(assumptions.adjustActivityTitle, "Update activity level")
    }

    func testAssumptionsNoteAvoidsOnboardingAndAutoTargetChanges() {
        let note = PlanMissionControlFixtures.loseDashboard.activityAssumptions.assumptionsNote

        XCTAssertFalse(note.lowercased().contains("onboarding"))
        XCTAssertTrue(note.lowercased().contains("won't change"))
        XCTAssertNil(PlanCopySafetyPolicy.forbiddenViolation(in: note))
    }

    func testAccessibilitySummaryFocusesOnActivityLevel() {
        let summary = PlanMissionControlFixtures.loseDashboard.activityAssumptions.accessibilitySummary

        XCTAssertTrue(summary.contains("Activity Assumptions"))
        XCTAssertTrue(summary.contains("Moderately active"))
        XCTAssertFalse(summary.contains("7,500/day"))
        XCTAssertFalse(summary.contains("sessions/week"))
    }

    func testActivityStepIndexMatchesEditFlowWhenBirthdayRequired() {
        var formState = PlanFormState(profile: PlanMissionControlFixtures.loseProfile)
        formState.birthDate = nil

        XCTAssertEqual(
            PlanEditWizardFlow.index(of: .activityLevel, formState: formState),
            3
        )
    }
}
