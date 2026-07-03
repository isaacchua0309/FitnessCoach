//
//  PlanPresentationStateTests.swift
//  Fitness CoachTests
//
//  Forma — Unit tests for Plan presentation state construction.
//

import XCTest
@testable import Fitness_Coach

final class PlanPresentationStateTests: XCTestCase {

    private let referenceDate = Calendar.current.date(
        from: DateComponents(year: 2026, month: 6, day: 28)
    )!

    // MARK: - Goal directions

    func testWeightLossStrategyState() {
        let state = PlanMissionControlFixtures.loseDashboard

        XCTAssertEqual(state.strategy.goalDirection, .lose)
        XCTAssertEqual(state.strategy.primaryGoal, "Lose 15 kg")
        XCTAssertFalse(state.dailyTargets.caloriesLabel.isEmpty)
    }

    func testMaintenanceStrategyState() {
        let state = PlanMissionControlFixtures.maintainDashboard

        XCTAssertEqual(state.strategy.goalDirection, .maintain)
        XCTAssertEqual(state.strategy.primaryGoal, "Maintain weight")
        XCTAssertNil(state.strategy.expectedPaceValue)
    }

    func testMuscleGainStrategyState() {
        let state = PlanMissionControlFixtures.gainDashboard

        XCTAssertEqual(state.strategy.goalDirection, .gain)
        XCTAssertEqual(state.strategy.primaryGoal, "Build muscle")
    }

    // MARK: - Plan status

    func testAggressiveCutStatusCard() {
        let state = PlanMissionControlFixtures.loseDashboard

        XCTAssertEqual(state.status.classification, .aggressiveCut)
        XCTAssertEqual(state.status.statusName, "Aggressive Cut")
    }

    func testModerateCutStatusCard() {
        let state = PlanMissionControlFixtures.moderateDeficitDashboard

        XCTAssertEqual(state.status.classification, .moderateCut)
    }

    // MARK: - Data gaps

    func testInsufficientDataProfileSurfacesNeedsReviewStatus() {
        let state = PlanMissionControlFixtures.incompleteDataDashboard

        XCTAssertEqual(state.status.classification, .needsReview)
        XCTAssertTrue(state.confidence.missingItems.contains {
            $0.text == FormaProductCopy.PlanMissionControl.missingBirthdayHeight
        })
    }

    // MARK: - Apple Health

    func testAppleHealthConnectedConfidence() {
        let state = PlanMissionControlFixtures.connectedDashboard

        XCTAssertTrue(state.confidence.showsAppleHealthStatus)
        XCTAssertFalse(state.confidence.showsAppleHealthAction)
        XCTAssertTrue(state.confidence.whyItems.contains {
            $0.text == FormaProductCopy.PlanMissionControl.confidenceAppleHealthConnected
        })
    }

    func testAppleHealthDisconnectedConfidence() {
        let state = PlanMissionControlFixtures.loseDashboard

        XCTAssertTrue(state.confidence.showsAppleHealthStatus)
        XCTAssertTrue(state.confidence.showsAppleHealthAction)
        XCTAssertTrue(state.confidence.missingItems.contains {
            $0.text == FormaProductCopy.PlanMissionControl.missingAppleHealthConnection
        })
    }

    // MARK: - Section completeness

    func testDashboardStateIncludesAllPresentationSections() {
        let state = PlanMissionControlFixtures.activeUserDashboard

        XCTAssertFalse(state.strategy.sectionTitle.isEmpty)
        XCTAssertFalse(state.dailyTargets.sectionTitle.isEmpty)
        XCTAssertFalse(state.status.statusName.isEmpty)
        XCTAssertFalse(state.explanation.guidanceCopy.isEmpty)
        XCTAssertFalse(state.confidence.sectionTitle.isEmpty)
        XCTAssertFalse(state.adjustmentRules.rules.isEmpty)
        XCTAssertFalse(state.assumptions.sectionTitle.isEmpty)
        XCTAssertNotNil(state.review.lastUpdatedLabel)
        XCTAssertEqual(state.adjustPlanCTA.title, FormaProductCopy.PlanMissionControl.adjustPlan)
        XCTAssertTrue(state.adjustPlanCTA.isEnabled)
    }

    func testActiveUserWithFullDataHasHighConfidence() {
        let state = PlanMissionControlFixtures.activeUserDashboard

        XCTAssertEqual(state.status.classification, .aggressiveCut)
        XCTAssertGreaterThanOrEqual(state.confidence.confidenceScore, 85)
        XCTAssertFalse(state.confidence.missingItems.contains {
            $0.text == FormaProductCopy.PlanMissionControl.missingRecentWeighIn
        })
    }

    func testPlanStateBuilderUsesPresentationBuilder() {
        let state = PlanStateBuilder.dashboardState(
            profile: PlanMissionControlFixtures.loseProfile,
            referenceDate: referenceDate
        )

        XCTAssertEqual(state.strategy.goalDirection, .lose)
        XCTAssertNotNil(state.explanation.calculationDetails)
        XCTAssertGreaterThan(state.adjustmentRules.rules.count, 0)
    }
}
