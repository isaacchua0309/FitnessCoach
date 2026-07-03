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
        XCTAssertEqual(state.strategy.headline, "Lose 15 kg")
        XCTAssertFalse(state.dailyTargets.caloriesLabel.isEmpty)
    }

    func testMaintenanceStrategyState() {
        let state = PlanMissionControlFixtures.maintainDashboard

        XCTAssertEqual(state.strategy.goalDirection, .maintain)
        XCTAssertEqual(state.strategy.headline, "Maintain 72 kg")
        XCTAssertFalse(state.strategy.showsProgressBar)
    }

    func testMuscleGainStrategyState() {
        let state = PlanMissionControlFixtures.gainDashboard

        XCTAssertEqual(state.strategy.goalDirection, .gain)
        XCTAssertEqual(state.strategy.headline, "Gain 6 kg")
    }

    // MARK: - Deficit pacing

    func testAggressiveDeficitStatusTone() {
        let state = PlanMissionControlFixtures.activeUserDashboard

        XCTAssertEqual(state.profile.targets.aggressiveness, .aggressive)
        XCTAssertEqual(state.strategy.goalDirection, .lose)
        XCTAssertEqual(state.status.tone, .needsData)
        XCTAssertTrue(state.status.message.contains("faster cut"))
    }

    func testModerateDeficitStatusTone() {
        let state = PlanMissionControlFixtures.activeModerateDeficitDashboard

        XCTAssertEqual(state.profile.targets.aggressiveness, .moderate)
        XCTAssertEqual(state.strategy.goalDirection, .lose)
        XCTAssertEqual(state.status.tone, .onTrack)
        XCTAssertTrue(state.status.message.contains("recovery"))
    }

    // MARK: - Data gaps

    func testInsufficientDataProfileSurfacesNeedsDataStatus() {
        let state = PlanMissionControlFixtures.incompleteDataDashboard

        XCTAssertEqual(state.status.tone, .needsData)
        XCTAssertTrue(state.confidence.missingItems.contains {
            $0.text == FormaProductCopy.PlanMissionControl.missingBirthdayHeight
        })
    }

    func testNoRecentWeighInSurfacesNeedsDataStatus() {
        let state = PlanMissionControlFixtures.staleWeightDashboard

        XCTAssertEqual(state.status.tone, .needsData)
        XCTAssertTrue(state.status.message.lowercased().contains("weigh"))
        XCTAssertTrue(state.confidence.missingItems.contains {
            $0.text == FormaProductCopy.PlanMissionControl.missingRecentWeighIn
        })
    }

    func testNoFoodLogsSurfacesNeedsDataStatus() {
        let state = PlanMissionControlFixtures.noLogsDashboard

        XCTAssertEqual(state.status.tone, .needsData)
        XCTAssertTrue(state.status.message.lowercased().contains("log"))
        XCTAssertTrue(state.confidence.missingItems.contains {
            $0.text == FormaProductCopy.PlanMissionControl.missingFoodLogs
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
        XCTAssertFalse(state.status.message.isEmpty)
        XCTAssertFalse(state.explanation.summary.isEmpty)
        XCTAssertFalse(state.confidence.sectionTitle.isEmpty)
        XCTAssertFalse(state.adjustmentRules.rules.isEmpty)
        XCTAssertFalse(state.assumptions.sectionTitle.isEmpty)
        XCTAssertNotNil(state.review.lastUpdatedLabel)
        XCTAssertEqual(state.adjustPlanCTA.title, FormaProductCopy.PlanMissionControl.adjustPlan)
        XCTAssertTrue(state.adjustPlanCTA.isEnabled)
    }

    func testActiveUserWithFullDataHasHighConfidence() {
        let state = PlanMissionControlFixtures.activeUserDashboard

        XCTAssertEqual(state.status.tone, .needsData)
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
