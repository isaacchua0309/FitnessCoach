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
        XCTAssertFalse(PlanDashboardHealthIntelligenceVisibility.showsSection(
            uiEnabled: false,
            sectionState: PlanHealthIntelligencePresentationPreviewData.strongFit
        ))
        XCTAssertTrue(PlanDashboardHealthIntelligenceVisibility.showsSection(
            uiEnabled: true,
            sectionState: PlanHealthIntelligencePresentationPreviewData.strongFit
        ))
        XCTAssertFalse(PlanDashboardHealthIntelligenceVisibility.showsSection(
            uiEnabled: true,
            sectionState: nil
        ))
    }
}

enum PlanDashboardHealthIntelligenceVisibility {
    static func showsSection(
        uiEnabled: Bool,
        sectionState: PlanHealthIntelligenceSectionState?
    ) -> Bool {
        uiEnabled && sectionState != nil
    }
}
