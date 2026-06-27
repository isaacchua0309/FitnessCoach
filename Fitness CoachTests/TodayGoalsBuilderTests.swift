//
//  TodayGoalsBuilderTests.swift
//  Fitness CoachTests
//

import XCTest
@testable import Fitness_Coach

final class TodayGoalsBuilderTests: XCTestCase {

    func testIncompleteNutritionGoalsUseActionOrientedCopy() {
        let state = TodayDashboardFixtures.dashboardState(
            proteinConsumed: 31,
            proteinTarget: 180,
            proteinRemaining: 149,
            waterConsumedMl: 500,
            waterTargetMl: 3_150,
            waterRemainingMl: 2_650,
            weightKg: nil,
            hasWorkout: false
        )

        let goals = TodayGoalsBuilder.goals(
            from: state,
            trainingIntegration: .connected,
            trainingDataSource: .unavailable
        )
        XCTAssertEqual(goals.map(\.label), [
            FormaProductCopy.Today.actionLogWeight,
            FormaProductCopy.Today.actionPlanProteinMeal,
            FormaProductCopy.Today.actionDrinkWater
        ])
        XCTAssertTrue(goals.allSatisfy { $0.showsQuickActionButton && $0.isActionable && !$0.showsChevron })
    }

    func testChevronMatchesNavigationActionsOnly() throws {
        let scenarios: [(TrainingIntegrationState, TrainingDataSource, Int?, [Bool])] = [
            (.notConnected, .appleHealth, nil, [false, false, false, true]),
            (.connected, .appleHealth, 1, [false, false, false, true]),
            (.connected, .appleHealth, 0, [false, false, false, false]),
            (.connected, .appleHealth, 2, [false, false, false, true])
        ]

        for (integration, dataSource, workoutCount, expectedChevrons) in scenarios {
            let goals = TodayGoalsBuilder.goals(
                from: TodayDashboardFixtures.dashboardState(
                    proteinConsumed: 170,
                    proteinTarget: 180,
                    proteinRemaining: 10,
                    waterConsumedMl: 3_000,
                    waterTargetMl: 3_150,
                    waterRemainingMl: 150,
                    weightKg: 90.15,
                    hasWorkout: (workoutCount ?? 0) > 0
                ),
                trainingIntegration: integration,
                trainingDataSource: dataSource,
                appleHealthWorkoutCount: workoutCount
            )
            XCTAssertEqual(
                goals.map(\.showsChevron),
                expectedChevrons,
                "Unexpected chevron flags for integration=\(integration) source=\(dataSource) count=\(String(describing: workoutCount))"
            )
            XCTAssertEqual(
                goals.map(\.showsQuickActionButton),
                [false, false, false, false],
                "Completed nutrition goals should not show quick-action chips"
            )
        }
    }

    func testAppleHealthNotConnectedShowsConnectAction() throws {
        let goals = TodayGoalsBuilder.goals(
            from: TodayDashboardFixtures.dashboardState(
                proteinConsumed: 170,
                proteinTarget: 180,
                proteinRemaining: 10,
                waterConsumedMl: 3_000,
                waterTargetMl: 3_150,
                waterRemainingMl: 150,
                weightKg: 90.15,
                hasWorkout: false
            ),
            trainingIntegration: .notConnected,
            trainingDataSource: .appleHealth
        )
        let workout = try XCTUnwrap(goals.last)
        XCTAssertEqual(workout.label, FormaProductCopy.Training.Integration.connectAppleHealth)
        XCTAssertEqual(workout.tapAction, .openTrainingInsights)
        XCTAssertFalse(workout.isComplete)
        XCTAssertTrue(workout.isActionable)
    }

    func testAppleHealthDeniedShowsUnlockInsightsAction() throws {
        let goals = TodayGoalsBuilder.goals(
            from: TodayDashboardFixtures.dashboardState(
                proteinConsumed: 170,
                proteinTarget: 180,
                proteinRemaining: 10,
                waterConsumedMl: 3_000,
                waterTargetMl: 3_150,
                waterRemainingMl: 150,
                weightKg: 90.15,
                hasWorkout: false
            ),
            trainingIntegration: .denied,
            trainingDataSource: .appleHealth
        )
        let workout = try XCTUnwrap(goals.last)
        XCTAssertEqual(workout.label, FormaProductCopy.Today.actionManageHealthAccess)
        XCTAssertEqual(workout.tapAction, .openTrainingInsights)
    }

    func testAppleHealthConnectedWithOneWorkoutShowsCountLabel() throws {
        let goals = TodayGoalsBuilder.goals(
            from: TodayDashboardFixtures.dashboardState(
                proteinConsumed: 170,
                proteinTarget: 180,
                proteinRemaining: 10,
                waterConsumedMl: 3_000,
                waterTargetMl: 3_150,
                waterRemainingMl: 150,
                weightKg: 90.15,
                hasWorkout: false
            ),
            trainingIntegration: .connected,
            trainingDataSource: .appleHealth,
            appleHealthWorkoutCount: 1
        )
        let workout = try XCTUnwrap(goals.last)
        XCTAssertEqual(workout.label, FormaProductCopy.Today.workoutsToday(1))
        XCTAssertTrue(workout.isComplete)
        XCTAssertEqual(workout.tapAction, .openTrainingInsights)
    }

    func testAppleHealthConnectedWithMultipleWorkoutsShowsCountLabel() throws {
        let goals = TodayGoalsBuilder.goals(
            from: TodayDashboardFixtures.dashboardState(
                proteinConsumed: 170,
                proteinTarget: 180,
                proteinRemaining: 10,
                waterConsumedMl: 3_000,
                waterTargetMl: 3_150,
                waterRemainingMl: 150,
                weightKg: 90.15,
                hasWorkout: false
            ),
            trainingIntegration: .connected,
            trainingDataSource: .appleHealth,
            appleHealthWorkoutCount: 2
        )
        let workout = try XCTUnwrap(goals.last)
        XCTAssertEqual(workout.label, FormaProductCopy.Today.workoutsToday(2))
    }

    func testAppleHealthConnectedWithoutWorkoutShowsNeutralStatus() throws {
        let goals = TodayGoalsBuilder.goals(
            from: TodayDashboardFixtures.dashboardState(
                proteinConsumed: 170,
                proteinTarget: 180,
                proteinRemaining: 10,
                waterConsumedMl: 3_000,
                waterTargetMl: 3_150,
                waterRemainingMl: 150,
                weightKg: 90.15,
                hasWorkout: false
            ),
            trainingIntegration: .connected,
            trainingDataSource: .appleHealth,
            appleHealthWorkoutCount: 0
        )
        let workout = try XCTUnwrap(goals.last)
        XCTAssertEqual(workout.label, FormaProductCopy.Today.statusNoAppleHealthWorkoutToday)
        XCTAssertTrue(workout.isComplete)
        XCTAssertTrue(workout.isInformational)
        XCTAssertNil(workout.tapAction)
        XCTAssertFalse(workout.showsChevron)
    }

    func testUnavailableDataSourceHidesTrainingRow() {
        let goals = TodayGoalsBuilder.goals(
            from: TodayDashboardFixtures.dashboardState(
                proteinConsumed: 31,
                proteinTarget: 180,
                proteinRemaining: 149,
                waterConsumedMl: 500,
                waterTargetMl: 3_150,
                waterRemainingMl: 2_650,
                weightKg: nil,
                hasWorkout: false
            ),
            trainingIntegration: .connected,
            trainingDataSource: .unavailable
        )
        XCTAssertEqual(goals.count, 3)
        XCTAssertFalse(goals.contains(where: { $0.kind == .workout }))
    }
}
