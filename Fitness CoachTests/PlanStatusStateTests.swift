//
//  PlanStatusStateTests.swift
//  Fitness CoachTests
//

import XCTest
@testable import Fitness_Coach

final class PlanStatusStateTests: XCTestCase {

    private let referenceDate = Calendar.current.date(
        from: DateComponents(year: 2026, month: 6, day: 28)
    )!

    func testAggressiveCutClassification() {
        let status = PlanMissionControlFixtures.loseDashboard.status

        XCTAssertEqual(status.classification, .aggressiveCut)
        XCTAssertEqual(status.statusName, "Aggressive Cut")
        XCTAssertEqual(status.bestForValue, "Fast fat loss")
        XCTAssertTrue(status.watchForValue.contains("Low energy"))
        XCTAssertFalse(status.explanation.lowercased().contains("failed"))
    }

    func testModerateCutClassification() {
        let status = PlanMissionControlFixtures.moderateDeficitDashboard.status

        XCTAssertEqual(status.classification, .moderateCut)
        XCTAssertEqual(status.statusName, "Moderate Cut")
        XCTAssertEqual(status.bestForValue, "Sustainable fat loss")
    }

    func testMaintenanceClassification() {
        let status = PlanMissionControlFixtures.maintainDashboard.status

        XCTAssertEqual(status.classification, .maintenance)
        XCTAssertEqual(status.statusName, "Maintenance")
        XCTAssertEqual(status.bestForValue, "Weight stability")
    }

    func testLeanGainClassification() {
        let status = PlanMissionControlFixtures.gainDashboard.status

        XCTAssertEqual(status.classification, .leanGain)
        XCTAssertEqual(status.statusName, "Lean Gain")
        XCTAssertEqual(status.bestForValue, "Building muscle")
    }

    func testNeedsReviewFallback() {
        let status = PlanMissionControlFixtures.incompleteDataDashboard.status

        XCTAssertEqual(status.classification, .needsReview)
        XCTAssertEqual(status.statusName, "Needs Review")
        XCTAssertTrue(status.explanation.contains("more information"))
        XCTAssertFalse(status.watchForValue.lowercased().contains("shame"))
    }

    func testGentleCutClassification() {
        let status = PlanMissionControlFixtures.gentleDeficitDashboard.status

        XCTAssertEqual(status.classification, .gentleCut)
        XCTAssertEqual(status.statusName, "Gentle Cut")
    }

    func testRebuildClassification() {
        let status = PlanMissionControlFixtures.rebuildDashboard.status

        XCTAssertEqual(status.classification, .rebuild)
        XCTAssertEqual(status.statusName, "Rebuild / Recomposition")
    }

    func testClassifierUsesDeficitThresholds() {
        XCTAssertEqual(
            PlanStatusStateBuilder.classifyCut(
                aggressiveness: .moderate,
                dailyDeficitKcal: 600,
                safetyLevel: .ok
            ),
            .aggressiveCut
        )
        XCTAssertEqual(
            PlanStatusStateBuilder.classifyCut(
                aggressiveness: .conservative,
                dailyDeficitKcal: 300,
                safetyLevel: .ok
            ),
            .gentleCut
        )
    }

    func testAccessibilitySummaryIncludesStatusFields() {
        let status = PlanMissionControlFixtures.loseDashboard.status

        XCTAssertTrue(status.accessibilitySummary.contains("Plan Status"))
        XCTAssertTrue(status.accessibilitySummary.contains(status.statusName))
        XCTAssertTrue(status.accessibilitySummary.contains(status.bestForValue))
        XCTAssertTrue(status.accessibilitySummary.contains(status.watchForValue))
    }
}
