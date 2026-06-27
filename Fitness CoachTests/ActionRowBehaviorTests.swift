//
//  ActionRowBehaviorTests.swift
//  Fitness CoachTests
//
//  Guardrails for chevron vs quick-action chip vs informational row policy.
//

import XCTest
@testable import Fitness_Coach

final class ActionRowBehaviorTests: XCTestCase {

    func testCoachTapActionsNeverShowChevron() {
        let goals = TodayGoalsBuilder.goals(
            from: TodayDashboardFixtures.dashboardState(),
            trainingIntegration: .connected,
            trainingDataSource: .unavailable
        )

        for goal in goals {
            if case .coach = goal.tapAction {
                XCTAssertFalse(goal.showsChevron, "\(goal.label) should use a chip, not a chevron")
                XCTAssertTrue(goal.showsQuickActionButton)
            }
        }
    }

    func testInformationalWorkoutRowIsNotActionable() throws {
        let goals = TodayGoalsBuilder.goals(
            from: TodayDashboardFixtures.dashboardState(
                proteinConsumed: 170,
                proteinTarget: 180,
                proteinRemaining: 10,
                waterConsumedMl: 3_000,
                waterTargetMl: 3_150,
                waterRemainingMl: 150,
                weightKg: 90.15
            ),
            trainingIntegration: .connected,
            trainingDataSource: .appleHealth,
            appleHealthWorkoutCount: 0
        )

        let workout = try XCTUnwrap(goals.last { $0.kind == .workout })
        XCTAssertTrue(workout.isInformational)
        XCTAssertFalse(workout.isActionable)
        XCTAssertFalse(workout.showsChevron)
        XCTAssertFalse(workout.showsQuickActionButton)
    }

    func testTrainingInsightsNavigationRowsShowChevronOnly() throws {
        let goals = TodayGoalsBuilder.goals(
            from: TodayDashboardFixtures.dashboardState(
                proteinConsumed: 170,
                proteinTarget: 180,
                proteinRemaining: 10,
                waterConsumedMl: 3_000,
                waterTargetMl: 3_150,
                waterRemainingMl: 150,
                weightKg: 90.15
            ),
            trainingIntegration: .notConnected,
            trainingDataSource: .appleHealth
        )

        let workout = try XCTUnwrap(goals.last { $0.kind == .workout })
        XCTAssertEqual(workout.tapAction, .openTrainingInsights)
        XCTAssertTrue(workout.showsChevron)
        XCTAssertFalse(workout.showsQuickActionButton)
    }

    func testCompletedNutritionRowsAreStatic() {
        let goals = TodayGoalsBuilder.goals(
            from: TodayDashboardFixtures.dashboardState(
                proteinConsumed: 180,
                proteinTarget: 180,
                proteinRemaining: 0,
                waterConsumedMl: 3_150,
                waterTargetMl: 3_150,
                waterRemainingMl: 0,
                weightKg: 68.5
            ),
            trainingIntegration: .connected,
            trainingDataSource: .unavailable
        )

        XCTAssertTrue(
            goals.allSatisfy {
                !$0.showsChevron && !$0.showsQuickActionButton && !$0.isActionable
            }
        )
    }
}
