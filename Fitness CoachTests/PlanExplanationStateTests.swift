//
//  PlanExplanationStateTests.swift
//  Fitness CoachTests
//

import XCTest
@testable import Fitness_Coach

final class PlanExplanationStateTests: XCTestCase {

    private let referenceDate = Calendar.current.date(
        from: DateComponents(year: 2026, month: 6, day: 28)
    )!

    func testMaintenanceDeficitTargetRender() throws {
        let profile = PlanMissionControlFixtures.loseProfile
        let result = try PlanCalculationBridge.planResult(
            from: profile,
            referenceDate: referenceDate
        )
        let explanation = PlanExplanationStateBuilder.build(
            profile: profile,
            planResult: result,
            referenceDate: referenceDate
        )

        XCTAssertEqual(explanation.sectionTitle, "Why This Works")
        XCTAssertEqual(explanation.energyLines.map(\.id), ["maintenance", "adjustment", "target"])
        XCTAssertEqual(explanation.energyLines[0].label, "Maintenance")
        XCTAssertEqual(explanation.energyLines[1].label, "Deficit")
        XCTAssertEqual(explanation.energyLines[2].label, "Target")
        XCTAssertTrue(explanation.energyLines[0].value.contains("kcal"))
        XCTAssertEqual(
            explanation.energyLines[1].value,
            PlanDisplayFormatter.formatKcal(result.dailyDeficitKcal)
        )
        XCTAssertFalse(explanation.guidanceCopy.isEmpty)
        XCTAssertNil(explanation.energyLines.first { $0.label == "Surplus" })
    }

    func testSurplusPlanRendersCorrectly() throws {
        let profile = PlanMissionControlFixtures.gainProfile
        let result = try PlanCalculationBridge.planResult(
            from: profile,
            referenceDate: referenceDate
        )
        let explanation = PlanExplanationStateBuilder.build(
            profile: profile,
            planResult: result,
            referenceDate: referenceDate
        )

        let surplus = max(result.calorieTargetKcal - result.tdeeKcal, 0)
        XCTAssertGreaterThan(surplus, 0)
        XCTAssertEqual(explanation.energyLines.map(\.label), ["Maintenance", "Surplus", "Target"])
        XCTAssertEqual(
            explanation.energyLines[1].value,
            PlanDisplayFormatter.formatKcal(surplus)
        )
        XCTAssertEqual(explanation.guidanceCopy, FormaProductCopy.PlanRationale.guidanceLeanGain)
        XCTAssertFalse(explanation.energyLines.contains { $0.label == "Deficit" })
    }

    func testMaintenancePlanRendersCorrectly() throws {
        let profile = PlanMissionControlFixtures.maintainProfile
        let result = try PlanCalculationBridge.planResult(
            from: profile,
            referenceDate: referenceDate
        )
        let explanation = PlanExplanationStateBuilder.build(
            profile: profile,
            planResult: result,
            referenceDate: referenceDate
        )

        XCTAssertEqual(explanation.energyLines.map(\.id), ["maintenance", "target"])
        XCTAssertEqual(explanation.energyLines[0].label, "Maintenance")
        XCTAssertEqual(explanation.energyLines[1].label, "Target")
        XCTAssertFalse(explanation.energyLines.contains { $0.label == "Deficit" })
        XCTAssertFalse(explanation.energyLines.contains { $0.label == "Surplus" })
        XCTAssertEqual(explanation.guidanceCopy, FormaProductCopy.PlanRationale.guidanceMaintenance)
    }

    func testViewCalculationRouteWorksIfPresent() throws {
        let profile = PlanMissionControlFixtures.loseProfile
        let result = try PlanCalculationBridge.planResult(
            from: profile,
            referenceDate: referenceDate
        )
        let explanation = PlanExplanationStateBuilder.build(
            profile: profile,
            planResult: result,
            referenceDate: referenceDate
        )

        XCTAssertTrue(explanation.showsCalculationAction)
        XCTAssertEqual(explanation.seeCalculationTitle, "View calculation")
        XCTAssertNotNil(explanation.calculationDetails)
        XCTAssertTrue(explanation.accessibilitySummary.contains("View calculation"))
    }

    func testFallbackOmitsCalculationActionWithoutPlanResult() {
        let explanation = PlanExplanationStateBuilder.build(
            profile: PlanMissionControlFixtures.incompleteDataDashboard.profile,
            planResult: nil,
            referenceDate: referenceDate
        )

        XCTAssertFalse(explanation.showsCalculationAction)
        XCTAssertNil(explanation.calculationDetails)
        XCTAssertEqual(explanation.guidanceCopy, FormaProductCopy.PlanRationale.guidanceFallback)
    }

    func testDashboardExplanationUsesCompactLayout() {
        let explanation = PlanMissionControlFixtures.loseDashboard.explanation

        XCTAssertEqual(explanation.energyLines.count, 3)
        XCTAssertFalse(explanation.guidanceCopy.contains("Based on your weight"))
        XCTAssertFalse(explanation.accessibilitySummary.contains("Based on:"))
    }
}
