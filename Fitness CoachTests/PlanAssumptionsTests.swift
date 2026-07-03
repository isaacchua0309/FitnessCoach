//
//  PlanAssumptionsTests.swift
//  Fitness CoachTests
//

import XCTest
@testable import Fitness_Coach

final class PlanAssumptionsTests: XCTestCase {

    func testAssumptionsUseStoredProfileValues() {
        let assumptions = PlanMissionControlFixtures.loseDashboard.assumptions

        XCTAssertEqual(assumptions.estimatedStepsPerDay, 7500)
        XCTAssertEqual(assumptions.estimatedStepsLabel, "7,500/day")
        XCTAssertEqual(assumptions.trainingSessionsPerWeek, 3)
        XCTAssertTrue(assumptions.usesActivityLevelDefaults)
        XCTAssertEqual(assumptions.resolvedAgeYears, 28)
    }

    func testAssumptionsIncludeNoteWithoutAutoAdjustLanguage() {
        let note = PlanMissionControlFixtures.loseDashboard.assumptions.assumptionsNote

        XCTAssertFalse(note.lowercased().contains("onboarding"))
        XCTAssertTrue(note.lowercased().contains("won't change"))
        XCTAssertFalse(note.lowercased().contains("automatically change your calorie targets"))
    }

    func testAssumptionsAccessibilitySummaryIncludesAllRows() {
        let summary = PlanMissionControlFixtures.loseDashboard.assumptions.accessibilitySummary

        XCTAssertTrue(summary.contains("Activity level"))
        XCTAssertTrue(summary.contains("Estimated Steps"))
        XCTAssertTrue(summary.contains("Training"))
    }
}
