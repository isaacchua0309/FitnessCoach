//
//  PlanStructureTests.swift
//  Fitness CoachTests
//

import XCTest
@testable import Fitness_Coach

final class PlanStructureTests: XCTestCase {

    func testProductSectionOrderMatchesCanonicalLayout() {
        XCTAssertEqual(PlanProductLayout.sectionOrder, [
            .goalProgress,
            .todayMission,
            .thisWeek,
            .nextMilestone,
            .whyThisWorks,
            .activityAssumptions,
            .planConfidence,
            .appleHealth,
            .adjustPlan
        ])
        XCTAssertEqual(PlanProductLayout.sectionOrder.last, .adjustPlan)
    }

    func testRemovedSectionsAreNotPartOfCanonicalOrder() {
        let identifiers = Set(PlanProductLayout.sectionOrder.map(\.rawValue))

        for removed in PlanProductLayout.removedSectionIdentifiers {
            XCTAssertFalse(
                identifiers.contains(removed),
                "Removed section \(removed) should not appear in canonical order"
            )
        }
    }

    func testMissionControlSectionTitlesMatchProductLayout() {
        let dashboard = PlanMissionControlFixtures.loseDashboard

        XCTAssertEqual(dashboard.mission.sectionTitle, FormaProductCopy.PlanMissionControl.heroSectionTitle)
        XCTAssertEqual(dashboard.todayMission.sectionTitle, "Today's Mission")
        XCTAssertEqual(dashboard.week.sectionTitle, "This Week")
        XCTAssertEqual(dashboard.nextMilestone.sectionTitle, "Next Milestone")
        XCTAssertEqual(FormaProductCopy.PlanRationale.sectionTitle, "Why This Works")
        XCTAssertEqual(dashboard.activityAssumptions.sectionTitle, "Activity Assumptions")
        XCTAssertEqual(dashboard.confidence.sectionTitle, "Plan Confidence")
        XCTAssertEqual(
            PlanTrainingIntegrationPresentationBuilder.build(integrationState: .notConnected).sectionTitle,
            "Apple Health"
        )
        XCTAssertEqual(dashboard.adjustment.sectionTitle, "Adjust Plan")
    }

    func testRationaleKeepsCalculationDetailsAccessible() throws {
        let profile = PlanMissionControlFixtures.loseProfile
        let result = try PlanCalculationBridge.planResult(from: profile)
        let rationale = PlanRationaleCopyBuilder.build(profile: profile, result: result)

        XCTAssertNotNil(rationale.calculationDetails)
        XCTAssertEqual(rationale.seeCalculationTitle, FormaProductCopy.PlanRationale.seeCalculation)
    }
}
