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
            .planStatus,
            .whyThisWorks,
            .planAssumptions,
            .whenToAdjust,
            .planConfidence
        ])
        XCTAssertEqual(PlanProductLayout.sectionOrder.last, .planConfidence)
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

    func testPresentationSectionTitlesMatchProductLayout() {
        let dashboard = PlanMissionControlFixtures.loseDashboard

        XCTAssertEqual(dashboard.strategy.sectionTitle, FormaProductCopy.PlanStrategyHero.sectionTitle)
        XCTAssertEqual(dashboard.dailyTargets.sectionTitle, "Daily Targets")
        XCTAssertEqual(dashboard.status.sectionTitle, "Plan Status")
        XCTAssertEqual(dashboard.explanation.sectionTitle, "Why This Works")
        XCTAssertEqual(dashboard.assumptions.sectionTitle, "Plan Assumptions")
        XCTAssertEqual(dashboard.adjustmentRules.sectionTitle, "When to Adjust")
        XCTAssertEqual(dashboard.confidence.sectionTitle, "Plan Confidence")
    }

    func testRationaleKeepsCalculationDetailsAccessible() throws {
        let profile = PlanMissionControlFixtures.loseProfile
        let result = try PlanCalculationBridge.planResult(from: profile)
        let rationale = PlanRationaleCopyBuilder.build(profile: profile, result: result)

        XCTAssertNotNil(rationale.calculationDetails)
        XCTAssertEqual(rationale.seeCalculationTitle, FormaProductCopy.PlanRationale.seeCalculation)
    }
}
