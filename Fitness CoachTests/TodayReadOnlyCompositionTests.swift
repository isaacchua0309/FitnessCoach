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
        XCTAssertEqual(state.nextBestAction.reason, .onTrack)
    }

    func testEmptyDayBuildsMealsAndNextAction() {
        let state = TodayDashboardFixtures.emptyDay()

        XCTAssertTrue(state.meals.isEmpty)
        XCTAssertEqual(state.nextBestAction.reason, .logFirstMeal)
    }

    func testQuickActionsSectionIncludesCoreLoggingActions() {
        let items = TodayQuickActionPolicy.menuItems(isScanFoodAvailable: false)
        let kinds = Set(items.map(\.kind))

        XCTAssertTrue(kinds.contains(.manualEntry))
        XCTAssertTrue(kinds.contains(.addWater))
        XCTAssertTrue(kinds.contains(.logWeight))
        XCTAssertTrue(kinds.contains(.askCoach))
        XCTAssertFalse(kinds.contains(.scanFood))
    }

    func testOverTargetDayMissionOverBudget() {
        let state = TodayDashboardFixtures.overTargetDay()

        XCTAssertEqual(state.mission.status, .overBudget)
        XCTAssertTrue(state.mission.calorieSummary.isOverTarget)
    }
}
