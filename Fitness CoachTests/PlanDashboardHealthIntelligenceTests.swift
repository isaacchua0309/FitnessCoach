//
//  PlanDashboardHealthIntelligenceTests.swift
//  Fitness CoachTests
//

import XCTest
@testable import Fitness_Coach

final class PlanDashboardHealthIntelligenceTests: XCTestCase {

    func testPlanConfidenceSectionAppearsNearStrategyInLayout() {
        let order = PlanProductLayout.sectionOrder
        let strategyIndex = order.firstIndex(of: .goalProgress)
        let confidenceIndex = order.firstIndex(of: .planConfidence)

        XCTAssertEqual(strategyIndex, 1)
        XCTAssertEqual(confidenceIndex, 5)
        XCTAssertLessThan(strategyIndex!, confidenceIndex!)
    }

    func testShouldPlanModelLoadHealthIntelligenceRequiresEnginesAndUIOrDebugFetch() {
        XCTAssertFalse(HealthIntelligenceFeatureFlags.shouldPlanModelLoadHealthIntelligence)
    }

    func testHealthIntelligenceVisibilityRequiresFlagAndState() {
        XCTAssertFalse(PlanDashboardCompositionPolicy.showsHealthIntelligenceSection(
            isUIEnabled: false,
            sectionState: PlanHealthIntelligencePresentationPreviewData.strongFit
        ))
        XCTAssertTrue(PlanDashboardCompositionPolicy.showsHealthIntelligenceSection(
            isUIEnabled: true,
            sectionState: PlanHealthIntelligencePresentationPreviewData.strongFit
        ))
        XCTAssertFalse(PlanDashboardCompositionPolicy.showsHealthIntelligenceSection(
            isUIEnabled: true,
            sectionState: nil
        ))
    }

    func testFlagOffShowsLegacyPlanConfidenceSection() {
        XCTAssertTrue(PlanDashboardCompositionPolicy.showsLegacyPlanConfidenceSection(
            isUIEnabled: false,
            sectionState: PlanHealthIntelligencePresentationPreviewData.strongFit
        ))
        XCTAssertFalse(PlanDashboardCompositionPolicy.showsHealthIntelligenceSection(
            isUIEnabled: false,
            sectionState: PlanHealthIntelligencePresentationPreviewData.strongFit
        ))
    }

    func testFlagOnWithStateHidesLegacyPlanConfidenceSection() {
        XCTAssertFalse(PlanDashboardCompositionPolicy.showsLegacyPlanConfidenceSection(
            isUIEnabled: true,
            sectionState: PlanHealthIntelligencePresentationPreviewData.strongFit
        ))
        XCTAssertTrue(PlanDashboardCompositionPolicy.showsHealthIntelligenceSection(
            isUIEnabled: true,
            sectionState: PlanHealthIntelligencePresentationPreviewData.strongFit
        ))
    }

    func testFlagOnWithoutStateFallsBackToLegacyPlanConfidenceSection() {
        XCTAssertTrue(PlanDashboardCompositionPolicy.showsLegacyPlanConfidenceSection(
            isUIEnabled: true,
            sectionState: nil
        ))
        XCTAssertFalse(PlanDashboardCompositionPolicy.showsHealthIntelligenceSection(
            isUIEnabled: true,
            sectionState: nil
        ))
    }
}

enum PlanDashboardHealthIntelligenceVisibility {
    static func showsSection(
        uiEnabled: Bool,
        sectionState: PlanHealthIntelligenceSectionState?
    ) -> Bool {
        PlanDashboardCompositionPolicy.showsHealthIntelligenceSection(
            isUIEnabled: uiEnabled,
            sectionState: sectionState
        )
    }
}
