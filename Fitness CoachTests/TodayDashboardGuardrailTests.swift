//
//  TodayDashboardGuardrailTests.swift
//  Fitness CoachTests
//
//  Guardrails for Today target rows and action checklist formatting.
//

import XCTest
@testable import Fitness_Coach

final class TodayDashboardGuardrailTests: XCTestCase {

    func testMacroProgressUsesWholeNumberFormatting() {
        XCTAssertEqual(
            TodayTargetsFormatter.macroProgress(consumed: 100, target: 130),
            "100 / 130 g"
        )
    }

    func testCompletedNutritionGoalsUseStatusCopyWithoutChevrons() {
        let state = TodayDashboardFixtures.dashboardState(
            proteinConsumed: 180,
            proteinTarget: 180,
            proteinRemaining: 0,
            waterConsumedMl: 3_150,
            waterTargetMl: 3_150,
            waterRemainingMl: 0,
            weightKg: 68.5
        )

        let goals = TodayGoalsBuilder.goals(
            from: state,
            trainingIntegration: .connected,
            trainingDataSource: .unavailable
        )

        XCTAssertEqual(goals.map(\.label), [
            FormaProductCopy.Today.statusWeightLogged,
            FormaProductCopy.Today.statusProteinOnTrack,
            FormaProductCopy.Today.statusHydrationOnTrack
        ])
        XCTAssertTrue(goals.allSatisfy { $0.isComplete })
        XCTAssertTrue(goals.allSatisfy { !$0.showsChevron })
    }

    func testIncompleteGoalsUseQuickActionChipsNotChevrons() {
        let goals = TodayGoalsBuilder.goals(
            from: TodayDashboardFixtures.dashboardState(),
            trainingIntegration: .connected,
            trainingDataSource: .unavailable
        )

        XCTAssertTrue(goals.allSatisfy { $0.showsQuickActionButton && !$0.showsChevron })
    }

    func testIncompleteGoalsExposeCoachPrefillActions() {
        let state = TodayDashboardFixtures.dashboardState()

        let goals = TodayGoalsBuilder.goals(
            from: state,
            trainingIntegration: .connected,
            trainingDataSource: .unavailable
        )

        XCTAssertEqual(goals[0].tapAction, .coach(prefill: TodayCoachPrompt.logWeight))
        XCTAssertEqual(goals[1].tapAction, .coach(prefill: TodayCoachPrompt.logProtein))
        XCTAssertEqual(goals[2].tapAction, .coach(prefill: TodayCoachPrompt.logWater))
    }

    func testShowsGenericCoachCTAWhenMealsLoggedAndNextActionComplete() {
        let completeState = TodayDashboardFixtures.dashboardState(
            proteinConsumed: 180,
            proteinTarget: 180,
            proteinRemaining: 0,
            waterConsumedMl: 3_150,
            waterTargetMl: 3_150,
            waterRemainingMl: 0,
            weightKg: 68.5,
            foodEntries: TodayPreviewData.foodEntries
        )

        XCTAssertTrue(
            TodayCoachCTAPolicy.showsGenericCoachCTA(
                foodEntries: TodayPreviewData.foodEntries,
                nextBestAction: completeState.nextBestAction
            )
        )
    }

    func testHidesGenericCoachCTAWhenMealsEmpty() {
        let state = TodayDashboardFixtures.dashboardState()

        XCTAssertFalse(
            TodayCoachCTAPolicy.showsGenericCoachCTA(
                foodEntries: [],
                nextBestAction: state.nextBestAction
            )
        )
    }

    func testHidesGenericCoachCTAWhenNextActionNeedsCoach() {
        let state = TodayDashboardFixtures.dashboardState()

        XCTAssertFalse(
            TodayCoachCTAPolicy.showsGenericCoachCTA(
                foodEntries: TodayPreviewData.foodEntries,
                nextBestAction: state.nextBestAction
            )
        )
    }

    func testFailedTrainingIntegrationShowsUnlockAction() throws {
        let state = TodayDashboardFixtures.dashboardState(
            proteinConsumed: 170,
            proteinTarget: 180,
            proteinRemaining: 10,
            waterConsumedMl: 3_000,
            waterTargetMl: 3_150,
            waterRemainingMl: 150,
            weightKg: 90.15
        )

        let goals = TodayGoalsBuilder.goals(
            from: state,
            trainingIntegration: .failed(message: "timeout"),
            trainingDataSource: .appleHealth
        )

        let workout = try XCTUnwrap(goals.last)
        XCTAssertEqual(workout.label, FormaProductCopy.Today.actionManageHealthAccess)
        XCTAssertEqual(workout.tapAction, .openTrainingInsights)
        XCTAssertFalse(workout.isComplete)
    }
}
