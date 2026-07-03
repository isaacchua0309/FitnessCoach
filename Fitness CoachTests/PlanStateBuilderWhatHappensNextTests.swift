//
//  PlanStateBuilderWhatHappensNextTests.swift
//  Fitness CoachTests
//
//  Forma — Legacy Plan sections stay out of the strategy layout.
//

import XCTest
@testable import Fitness_Coach

final class PlanStateBuilderWhatHappensNextTests: XCTestCase {

    func testCanonicalLayoutExcludesWhatHappensNext() {
        XCTAssertFalse(PlanProductLayout.sectionOrder.map(\.rawValue).contains("what_happens_next"))
        XCTAssertTrue(PlanProductLayout.removedSectionIdentifiers.contains("what_happens_next"))
    }

    func testDashboardStateEmbedsPresentationSectionsNotLegacyProductSections() {
        let state = PlanStateBuilder.dashboardState(profile: PlanMissionControlFixtures.loseProfile)

        XCTAssertEqual(state.strategy.goalDirection, .lose)
        XCTAssertFalse(state.dailyTargets.caloriesLabel.isEmpty)
        XCTAssertFalse(state.assumptions.activityLevel.isEmpty)
        XCTAssertNotNil(state.explanation.calculationDetails)
    }

    func testRemovedLegacyPlanSectionsStayOutOfMissionControlLayout() {
        XCTAssertTrue(PlanProductLayout.removedSectionIdentifiers.contains("current_strategy"))
        XCTAssertTrue(PlanProductLayout.removedSectionIdentifiers.contains("todays_targets"))
        XCTAssertTrue(PlanProductLayout.removedSectionIdentifiers.contains("plan_lifestyle"))
        XCTAssertTrue(PlanProductLayout.removedSectionIdentifiers.contains("this_week"))
        XCTAssertTrue(PlanProductLayout.removedSectionIdentifiers.contains("next_milestone"))
        XCTAssertTrue(PlanProductLayout.removedSectionIdentifiers.contains("adjust_plan"))
    }
}
