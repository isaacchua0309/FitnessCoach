//
//  JourneyWeeklyPatternBuilderTests.swift
//  Fitness CoachTests
//

import XCTest
@testable import Fitness_Coach

final class JourneyWeeklyPatternBuilderTests: XCTestCase {

    private let calendar = WeeklyProgressFixtures.calendar
    private let asOf = WeeklyProgressFixtures.asOf

    func testWeeklyCountsAreCorrect() {
        let weekLogs = (0..<5).map { offset in
            WeeklyProgressFixtures.makeLog(
                daysAgo: offset,
                calories: 1_800,
                protein: offset < 3 ? 140 : 80,
                waterMl: offset < 2 ? 2_500 : 400
            )
        }
        let weights = [
            WeeklyProgressFixtures.makeWeight(daysAgo: 4, kg: 90),
            WeeklyProgressFixtures.makeWeight(daysAgo: 1, kg: 89.5)
        ]

        let state = build(
            weekLogs: weekLogs,
            weekWeights: weights,
            maturityLogs: weekLogs,
            allWeights: weights,
            streaks: WeeklyProgressFixtures.makeStreaks(logging: 3, protein: 2, water: 0)
        )

        XCTAssertTrue(state.showsHabitRows)
        XCTAssertEqual(habit(id: "food", in: state)?.weeklyCountLabel, "5 / 7 days")
        XCTAssertEqual(habit(id: "protein", in: state)?.weeklyCountLabel, "3 / 7 days")
        XCTAssertEqual(habit(id: "water", in: state)?.weeklyCountLabel, "2 / 7 days")
        XCTAssertEqual(habit(id: "weight", in: state)?.weeklyCountLabel, "2 / 7 days")
    }

    func testStreakCalculationUsesCurrentStreaks() {
        let weekLogs = (0..<3).map { offset in
            WeeklyProgressFixtures.makeLog(daysAgo: offset, calories: 1_800, protein: 140, waterMl: 2_500)
        }

        let state = build(
            weekLogs: weekLogs,
            maturityLogs: weekLogs,
            streaks: WeeklyProgressFixtures.makeStreaks(logging: 3, protein: 2, water: 1)
        )

        XCTAssertEqual(
            habit(id: "food", in: state)?.streakLabel,
            FormaProductCopy.Journey.WeeklyReview.streakLabel(days: 3)
        )
        XCTAssertEqual(
            habit(id: "protein", in: state)?.streakLabel,
            FormaProductCopy.Journey.WeeklyReview.streakLabel(days: 2)
        )
        XCTAssertNil(habit(id: "water", in: state)?.streakLabel)
        XCTAssertNil(habit(id: "food", in: state)?.supportiveCopy)
        XCTAssertNil(habit(id: "protein", in: state)?.supportiveCopy)
    }

    func testSupportiveCopyAppearsWhenUseful() {
        let weekLogs = (0..<2).map { offset in
            WeeklyProgressFixtures.makeLog(daysAgo: offset, calories: 1_800, protein: 80, waterMl: 400)
        }

        let state = build(
            weekLogs: weekLogs,
            maturityLogs: weekLogs,
            streaks: WeeklyProgressFixtures.makeStreaks(logging: 0, protein: 0, water: 0)
        )

        XCTAssertEqual(
            habit(id: "food", in: state)?.supportiveCopy,
            FormaProductCopy.Journey.WeeklyReview.oneMoreDayMomentum
        )
    }

    func testEmptyStateAppearsForNoActivity() {
        let state = build(weekLogs: [], maturityLogs: [])

        XCTAssertFalse(state.showsHabitRows)
        XCTAssertTrue(state.habits.isEmpty)
        XCTAssertEqual(
            state.emptyMessage,
            FormaProductCopy.Journey.WeeklyReview.emptyState
        )
    }

    func testSevenDayVisualMatchesLoggedDays() {
        let weekLogs = [
            WeeklyProgressFixtures.makeLog(daysAgo: 2, calories: 1_800, protein: 140, waterMl: 2_500),
            WeeklyProgressFixtures.makeLog(daysAgo: 0, calories: 1_800, protein: 140, waterMl: 2_500)
        ]

        let state = build(weekLogs: weekLogs, maturityLogs: weekLogs)

        XCTAssertEqual(habit(id: "food", in: state)?.dayCells, [false, false, false, false, true, false, true])
    }

    func testBrandNewUserPreviewShowsWeeklyEmptyState() {
        let dashboard = JourneyPreviewData.brandNewUser

        XCTAssertFalse(dashboard.weeklyHabit.showsHabitRows)
        XCTAssertEqual(
            dashboard.weeklyHabit.emptyMessage,
            FormaProductCopy.Journey.WeeklyReview.emptyState
        )
    }

    func testTodayGoalsBuilderUnchangedByJourneyWeeklyRedesign() {
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
    }

    // MARK: - Helpers

    private func build(
        weekLogs: [DailyLog],
        weekWeights: [WeightEntry] = [],
        maturityLogs: [DailyLog],
        allWeights: [WeightEntry] = [],
        streaks: JourneyStreakState? = nil,
        training: JourneyWeeklyTrainingStatus = .connectedEmpty
    ) -> JourneyWeeklyHabitState {
        WeeklyProgressFixtures.buildWeeklyHabit(
            weekLogs: weekLogs,
            weekWeights: weekWeights,
            maturityLogs: maturityLogs,
            allWeights: allWeights,
            streaks: streaks,
            training: training,
            asOf: asOf
        )
    }

    private func habit(id: String, in state: JourneyWeeklyHabitState) -> JourneyWeeklyHabitRowState? {
        state.habits.first { $0.id == id }
    }
}
