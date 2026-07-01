//
//  PlanStateBuilderWhatHappensNextTests.swift
//  Fitness CoachTests
//
//  Forma — Legacy "What Happens Next" and strategy-first sections stay out of Mission Control.
//

import XCTest
@testable import Fitness_Coach

final class PlanStateBuilderWhatHappensNextTests: XCTestCase {

    func testCanonicalLayoutExcludesWhatHappensNext() {
        XCTAssertFalse(PlanProductLayout.sectionOrder.map(\.rawValue).contains("what_happens_next"))
        XCTAssertTrue(PlanProductLayout.removedSectionIdentifiers.contains("what_happens_next"))
    }

    func testDashboardStateEmbedsMissionControlNotLegacyProductSections() {
        let state = PlanStateBuilder.dashboardState(profile: PlanMissionControlFixtures.loseProfile)

        XCTAssertEqual(state.missionControl.mission.goalDirection, .lose)
        XCTAssertFalse(state.missionControl.todayMission.caloriesLabel.isEmpty)
        XCTAssertFalse(state.missionControl.week.sectionTitle.isEmpty)
        XCTAssertNotNil(state.rationale.calculationDetails)
    }

    func testRemovedLegacyPlanSectionsStayOutOfMissionControlLayout() {
        XCTAssertTrue(PlanProductLayout.removedSectionIdentifiers.contains("current_strategy"))
        XCTAssertTrue(PlanProductLayout.removedSectionIdentifiers.contains("todays_targets"))
        XCTAssertTrue(PlanProductLayout.removedSectionIdentifiers.contains("plan_lifestyle"))
    }

    func testMissionControlRationaleMatchesTopLevelRationale() {
        let state = PlanStateBuilder.dashboardState(profile: PlanMissionControlFixtures.loseProfile)

        XCTAssertEqual(
            state.rationale.summary,
            state.missionControl.rationale.summary
        )
    }
}
