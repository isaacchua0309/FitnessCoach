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

    func testPartialDayBuildsAllMissionControlSections() {
        let state = TodayPreviewData.partialDay

        XCTAssertFalse(state.meals.isEmpty)
        XCTAssertNotNil(state.nextBestAction.title)
        XCTAssertFalse(state.dailyScorecard.items.isEmpty)
        XCTAssertFalse(state.aiCoachTip.message.isEmpty)
        XCTAssertGreaterThan(state.macroBalance.macroSummary.protein.target, 0)
    }

    func testCompleteDayIncludesCoachTipAndDailyScorecard() {
        let state = TodayPreviewData.completeDay

        XCTAssertEqual(state.mission.status, .onTrack)
        XCTAssertFalse(state.aiCoachTip.message.isEmpty)
        XCTAssertEqual(state.dailyScorecard.overallPercent, 100)
    }

    func testEmptyDayStillBuildsDeterministicCoachTipAndScorecard() {
        let state = TodayDashboardFixtures.emptyDay()

        XCTAssertTrue(state.meals.isEmpty)
        XCTAssertEqual(state.dailyScorecard.overallPercent, 0)
        XCTAssertEqual(state.aiCoachTip.message, FormaProductCopy.Today.CoachTip.morningNoBreakfast)
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

    func testOverTargetDayUsesNonPunitiveCoachTip() {
        let state = TodayDashboardFixtures.overTargetDay()

        XCTAssertEqual(state.aiCoachTip.message, FormaProductCopy.Today.CoachTip.overTarget)
        XCTAssertEqual(state.mission.status, .overBudget)
    }
}
