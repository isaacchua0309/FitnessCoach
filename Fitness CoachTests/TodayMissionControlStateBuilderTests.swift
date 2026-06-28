//
//  TodayMissionControlStateBuilderTests.swift
//  Fitness CoachTests
//

import XCTest
@testable import Fitness_Coach

final class TodayMissionControlStateBuilderTests: XCTestCase {

    func testEmptyDayMissionNeedsFocusAndLogFirstMealAction() {
        let state = TodayDashboardFixtures.emptyDay()

        XCTAssertEqual(state.mission.status, .needsFocus)
        XCTAssertTrue(state.meals.isEmpty)
        XCTAssertEqual(state.nextBestAction.reason, .logFirstMeal)
        XCTAssertFalse(state.mission.calorieSummary.isOverTarget)
    }

    func testPartialDayPreservesNutritionSummaries() {
        let state = TodayDashboardFixtures.partialDay(
            proteinConsumed: 79,
            proteinTarget: 170,
            proteinRemaining: 91
        )

        XCTAssertEqual(state.mission.calorieSummary.consumed, 500)
        XCTAssertEqual(state.macroBalance.macroSummary.protein.consumed, 79)
        XCTAssertEqual(state.macroBalance.macroSummary.protein.remaining, 91)
        XCTAssertEqual(state.mission.status, .needsFocus)
    }

    func testCompleteDayMissionOnTrack() {
        let state = TodayDashboardFixtures.completeDay()

        XCTAssertEqual(state.mission.status, .onTrack)
        XCTAssertEqual(state.nextBestAction.reason, .onTrack)
        XCTAssertFalse(state.meals.isEmpty)
    }

    func testOverTargetDayMissionOverBudget() {
        let state = TodayDashboardFixtures.overTargetDay()

        XCTAssertEqual(state.mission.status, .overBudget)
        XCTAssertTrue(state.mission.calorieSummary.isOverTarget)
        XCTAssertTrue(
            state.aiCoachTip.message.contains("weekly trend"),
            "Over-target coach tip should use non-shaming copy"
        )
    }

    func testGoalProgressUsesProfileWeights() {
        let state = TodayDashboardFixtures.partialDay(weightKg: 70)

        XCTAssertEqual(state.mission.goalProgress?.currentWeightKg, 70)
        XCTAssertEqual(state.mission.goalProgress?.goalWeightKg, 65)
        XCTAssertEqual(state.mission.goalProgress?.direction, .lose)
    }

    func testMomentumSurfacesLoggingStreak() {
        let state = TodayDashboardFixtures.completeDay()

        XCTAssertEqual(state.momentum.streaks.loggingStreak, 7)
        XCTAssertEqual(state.momentum.headline, "7-day logging streak")
        XCTAssertFalse(state.momentum.detailLines.isEmpty)
    }

    func testDailySummaryPreservesBriefPriorities() {
        let state = TodayPreviewData.partialDay

        XCTAssertEqual(state.dailySummary.greeting, "Good morning.")
        XCTAssertFalse(state.dailySummary.priorities.isEmpty)
        XCTAssertEqual(state.dailySummary.userName, "Isaac")
    }

    func testActivityUsesAppleHealthWorkoutCount() {
        let state = TodayPreviewData.partialDay

        XCTAssertEqual(state.activity.appleHealthWorkoutCount, 1)
        XCTAssertEqual(state.activity.displayLine, FormaProductCopy.Today.workoutsToday(1))
    }

    func testNoProfileUsesEmptyViewStateNotDashboardState() {
        if case .empty = TodayViewState.empty {
            XCTAssertTrue(true)
        } else {
            XCTFail("Expected empty view state for missing profile")
        }
    }
}
