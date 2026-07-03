//
//  TodayReadOnlyCompositionTests.swift
//  Fitness CoachTests
//
//  Verifies Mission Control dashboard state for the flat Today section stack.
//

import XCTest
@testable import Fitness_Coach

final class TodayReadOnlyCompositionTests: XCTestCase {

    func testLoadedViewStateIdentifiesItself() {
        let state = TodayDashboardFixtures.partialDay()
        XCTAssertTrue(TodayViewState.loaded(state).isLoaded)
        XCTAssertFalse(TodayViewState.loading.isLoaded)
        XCTAssertFalse(TodayViewState.empty.isLoaded)
        XCTAssertFalse(TodayViewState.error("x").isLoaded)
    }

    func testPartialDayBuildsCoreMissionControlSections() {
        let state = TodayPreviewData.partialDay

        XCTAssertFalse(state.meals.isEmpty)
        XCTAssertNotNil(state.nextBestAction.title)
        XCTAssertGreaterThan(state.macroHydration.macroSummary.protein.target, 0)
        XCTAssertFalse(state.activity.displayLine.isEmpty)
    }

    func testCompleteDayMissionOnTrack() {
        let state = TodayPreviewData.completeDay

        XCTAssertEqual(state.mission.status, .onTrack)
        XCTAssertEqual(state.nextBestAction.reason, .allTargetsMet)
    }

    func testEmptyDayBuildsMealsAndNextAction() {
        let state = TodayDashboardFixtures.emptyDay()

        XCTAssertTrue(state.meals.isEmpty)
        XCTAssertEqual(state.nextBestAction.reason, .logBreakfast)
    }

    func testQuickActionsSectionIncludesPrimaryLoggingActions() {
        let configuration = TodayQuickActionPolicy.configuration(isScanFoodAvailable: true)

        XCTAssertTrue(TodayQuickActionPolicy.isVisible(.logMeal, isScanFoodAvailable: true))
        XCTAssertFalse(TodayQuickActionPolicy.isVisible(.addWater, isScanFoodAvailable: true))
        XCTAssertTrue(configuration.showsScanMeal)
        XCTAssertFalse(TodayQuickActionPolicy.isVisible(.logWeight, isScanFoodAvailable: true))
        XCTAssertFalse(TodayQuickActionPolicy.isVisible(.logWorkout, isScanFoodAvailable: true))
    }

    func testOverTargetDayMissionOverBudget() {
        let state = TodayDashboardFixtures.overTargetDay()

        XCTAssertEqual(state.mission.status, .overBudget)
        XCTAssertTrue(state.mission.calorieSummary.isOverTarget)
    }
}
