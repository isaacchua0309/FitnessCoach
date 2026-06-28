//
//  PlanActivityAssumptionsTests.swift
//  Fitness CoachTests
//

import XCTest
@testable import Fitness_Coach

final class PlanActivityAssumptionsTests: XCTestCase {

    // MARK: - Display

    func testAssumptionsShowActivityStepsAndTraining() {
        let assumptions = PlanMissionControlFixtures.loseDashboard.activityAssumptions

        XCTAssertEqual(assumptions.sectionTitle, "Plan Assumptions")
        XCTAssertEqual(assumptions.activityLevel, "Moderately active")
        XCTAssertEqual(assumptions.estimatedStepsLabel, "7,500/day")
        XCTAssertEqual(assumptions.trainingSessionsLabel, "3 sessions/week")
        XCTAssertEqual(assumptions.adjustActivityTitle, "Adjust activity")
    }

    func testAssumptionsNoteMentionsOnboardingAndNoAutoChange() {
        let note = PlanMissionControlFixtures.loseDashboard.activityAssumptions.assumptionsNote

        XCTAssertTrue(note.contains("onboarding"))
        XCTAssertTrue(note.contains("will not auto-change"))
        XCTAssertFalse(note.lowercased().contains("dynamic calor"))
        XCTAssertFalse(note.lowercased().contains("automatically adjust"))
    }

    // MARK: - Apple Health connected

    func testConnectedStateShowsAppleHealthStatus() {
        let assumptions = PlanMissionControlFixtures.connectedDashboard.activityAssumptions

        XCTAssertTrue(assumptions.showsAppleHealthStatus)
        XCTAssertTrue(assumptions.isAppleHealthConnected)
        XCTAssertEqual(assumptions.appleHealthStatusLabel, "Connected")
        XCTAssertFalse(assumptions.showsConnectAppleHealthCTA)
    }

    // MARK: - Apple Health disconnected

    func testDisconnectedStateShowsConnectCTA() {
        let assumptions = PlanMissionControlFixtures.loseDashboard.activityAssumptions

        XCTAssertTrue(assumptions.showsAppleHealthStatus)
        XCTAssertFalse(assumptions.isAppleHealthConnected)
        XCTAssertEqual(assumptions.appleHealthStatusLabel, "Not connected")
        XCTAssertTrue(assumptions.showsConnectAppleHealthCTA)
        XCTAssertEqual(assumptions.connectAppleHealthTitle, "Connect Apple Health")
    }

    func testAccessibilitySummaryIncludesAssumptionValues() {
        let summary = PlanMissionControlFixtures.loseDashboard.activityAssumptions.accessibilitySummary

        XCTAssertTrue(summary.contains("Plan Assumptions"))
        XCTAssertTrue(summary.contains("Moderately active"))
        XCTAssertTrue(summary.contains("7,500/day"))
        XCTAssertTrue(summary.contains("3 sessions/week"))
    }

    // MARK: - Edit wizard entry

    func testLifestyleStepIndexMatchesActivityEditFlow() {
        XCTAssertEqual(PlanEditWizard.lifestyleStepIndex, 3)
    }
}
