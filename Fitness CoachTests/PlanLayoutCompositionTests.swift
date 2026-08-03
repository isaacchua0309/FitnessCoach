//
//  PlanLayoutCompositionTests.swift
//  Fitness CoachTests
//

import XCTest
@testable import Fitness_Coach

final class PlanLayoutCompositionTests: XCTestCase {

    func testPreviewScenariosCoverRequestedPersonas() {
        XCTAssertEqual(PlanPreviewScreens.Scenario.allCases.count, 6)
        XCTAssertTrue(PlanPreviewScreens.Scenario.allCases.contains(.aggressiveCut))
        XCTAssertTrue(PlanPreviewScreens.Scenario.allCases.contains(.moderateCut))
        XCTAssertTrue(PlanPreviewScreens.Scenario.allCases.contains(.maintenance))
        XCTAssertTrue(PlanPreviewScreens.Scenario.allCases.contains(.leanGain))
        XCTAssertTrue(PlanPreviewScreens.Scenario.allCases.contains(.lowConfidence))
        XCTAssertTrue(PlanPreviewScreens.Scenario.allCases.contains(.strongConfidence))
    }

    func testAggressiveCutPreviewUsesAggressiveStatus() {
        let state = PlanPreviewScreens.dashboard(.aggressiveCut)
        XCTAssertEqual(state.status.classification, .aggressiveCut)
    }

    func testModerateCutPreviewUsesModerateStatus() {
        let state = PlanPreviewScreens.dashboard(.moderateCut)
        XCTAssertEqual(state.status.classification, .moderateCut)
    }

    func testMaintenancePreviewUsesMaintenanceStrategy() {
        let state = PlanPreviewScreens.dashboard(.maintenance)
        XCTAssertEqual(state.strategy.goalDirection, .maintain)
    }

    func testLeanGainPreviewUsesGainStrategy() {
        let state = PlanPreviewScreens.dashboard(.leanGain)
        XCTAssertEqual(state.strategy.goalDirection, .gain)
    }

    func testLowConfidencePreviewSurfacesImprovementActions() {
        let state = PlanPreviewScreens.dashboard(.lowConfidence)
        XCTAssertFalse(state.confidence.improvementActions.isEmpty)
        XCTAssertEqual(
            state.confidence.compactSignals.first { $0.id == "foodLogs" }?.value,
            "Not enough"
        )
    }

    func testStrongConfidencePreviewUsesStrongBucket() {
        let state = PlanPreviewScreens.dashboard(.strongConfidence)
        XCTAssertEqual(state.confidence.estimateBucket, .strong)
    }

    func testRemovedLegacySectionsStayOutOfLayout() {
        let removed = PlanProductLayout.removedSectionIdentifiers
        XCTAssertTrue(removed.contains("next_milestone"))
        XCTAssertTrue(removed.contains("this_week"))
        XCTAssertTrue(removed.contains("apple_health"))
        XCTAssertTrue(removed.contains("activity_assumptions"))
        XCTAssertTrue(removed.contains("adjust_plan"))
        XCTAssertTrue(removed.contains("plan_status"))
        XCTAssertTrue(removed.contains("why_this_works"))
        XCTAssertTrue(removed.contains("when_to_adjust"))
        XCTAssertTrue(removed.contains("plan_assumptions"))
        XCTAssertTrue(removed.contains("adjust_plan_cta"))
    }

    func testScrollBottomPaddingUsesMainTabInset() {
        XCTAssertGreaterThan(FormaMainTabLayout.scrollContentBottomPadding, 0)
        XCTAssertGreaterThanOrEqual(
            FormaMainTabLayout.scrollBottomInset,
            FormaMainTabLayout.scrollContentBottomPadding
        )
        XCTAssertGreaterThan(
            FormaMainTabLayout.bottomContentInset(safeAreaBottom: FormaMainTabLayout.defaultBottomSafeAreaFallback),
            FormaMainTabLayout.tabBarReservedHeight + FormaMainTabLayout.tabBarBreathingRoom
        )
    }

    func testPlanSectionSpacingMatchesMainTabLayout() {
        XCTAssertEqual(PlanLayout.sectionSpacing, FormaMainTabLayout.sectionSpacing)
        XCTAssertEqual(PlanLayout.headerToCardSpacing, FormaMainTabLayout.sectionContentSpacing)
    }

    func testPlanHeaderAdjustUsesDashboardEntryPoint() {
        XCTAssertEqual(PlanAdjustPlanEntryPoint.dashboard, .planTab)
        XCTAssertEqual(PlanAdjustPlanEntryPoint.adjustPlanCTA.rawValue, "plan_adjust_cta")
    }
}
