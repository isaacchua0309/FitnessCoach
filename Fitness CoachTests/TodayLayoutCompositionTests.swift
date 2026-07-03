//
//  TodayLayoutCompositionTests.swift
//  Fitness CoachTests
//
//  Verifies final Today dashboard section order and preview scenarios.
//

import XCTest
@testable import Fitness_Coach

final class TodayLayoutCompositionTests: XCTestCase {

    func testCanonicalSectionOrder() {
        XCTAssertEqual(
            TodayDashboardSectionOrder.sections.map(\.rawValue),
            [
                "header",
                "missionHero",
                "nextBestAction",
                "quickActions",
                "meals",
                "macroHydration",
                "activity",
                "dailyVictory",
                "smartCoach",
                "endOfDayWrapUp"
            ]
        )
    }

    func testBrandNewDayPreviewBuildsMorningNextAction() {
        let state = TodayPreviewData.brandNewDay

        XCTAssertEqual(state.mission.phase, .brandNewUser)
        XCTAssertTrue(
            state.nextBestAction.reason == .logBreakfast
                || state.nextBestAction.reason == .logFirstMeal
        )
        XCTAssertEqual(state.victory.kind, .startEncouragement)
        XCTAssertFalse(state.endOfDay.isVisible)
    }

    func testBreakfastLoggedPreviewShowsFirstMealVictory() {
        let state = TodayPreviewData.breakfastLogged

        XCTAssertEqual(state.meals.entryCount, 1)
        XCTAssertEqual(state.victory.kind, .firstMeal)
        XCTAssertEqual(state.smartCoach.context, .proteinBehind)
    }

    func testProteinBehindPreviewShowsSmartCoachBanner() {
        let state = TodayPreviewData.proteinBehind

        XCTAssertEqual(state.smartCoach.context, .proteinBehind)
        XCTAssertEqual(state.nextBestAction.reason, .eatProtein)
    }

    func testWaterBehindPreviewShowsSmartCoachBanner() {
        let state = TodayPreviewData.waterBehind

        XCTAssertEqual(state.smartCoach.context, .waterBehind)
        XCTAssertEqual(state.nextBestAction.reason, .addWater)
    }

    func testCaloriesExceededPreviewShowsOverBudgetMission() {
        let state = TodayPreviewData.caloriesExceeded

        XCTAssertEqual(state.mission.status, .overBudget)
        XCTAssertEqual(state.smartCoach.context, .caloriesExceeded)
    }

    func testWorkoutCompletedPreviewShowsActivityWorkout() {
        let state = TodayPreviewData.workoutCompleted

        XCTAssertTrue(state.activity.hasWorkout)
        XCTAssertEqual(state.activity.phase, .workoutCompleted)
    }

    func testEndOfDayPreviewShowsWrapUp() {
        let state = TodayPreviewData.endOfDay

        XCTAssertTrue(state.endOfDay.isVisible)
        XCTAssertEqual(state.endOfDay.sectionTitle, FormaProductCopy.Today.EndOfDay.sectionTitle)
        XCTAssertFalse(state.endOfDay.rows.isEmpty)
    }

    func testHeaderDateFormattingIsNonEmpty() {
        let line = TodayDashboardHeaderFormatting.dateLine(
            for: TodayDashboardFixtures.date(hour: 9)
        )

        XCTAssertFalse(line.isEmpty)
    }
}
