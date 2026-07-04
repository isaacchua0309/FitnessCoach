//
//  JourneyWeeklyPatternBuilderTests.swift
//  Fitness CoachTests
//

import XCTest
@testable import Fitness_Coach

final class JourneyWeeklyPatternBuilderTests: XCTestCase {

    private let calendar: Calendar = {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(secondsFromGMT: 0)!
        return calendar
    }()

    private let asOf = ProfileTestFixtures.referenceDate

    func testWeeklyCountsAreCorrect() {
        let weekLogs = (0..<5).map { offset in
            makeLog(
                daysAgo: offset,
                calories: 1_800,
                protein: offset < 3 ? 140 : 80,
                waterMl: offset < 2 ? 2_500 : 400
            )
        }
        let weights = [
            makeWeight(daysAgo: 4, kg: 90),
            makeWeight(daysAgo: 1, kg: 89.5)
        ]

        let state = build(
            weekLogs: weekLogs,
            weekWeights: weights,
            maturityLogs: weekLogs,
            allWeights: weights,
            streaks: makeStreaks(logging: 3, protein: 2, water: 0)
        )

        XCTAssertTrue(state.showsHabitRows)
        XCTAssertEqual(habit(id: "food", in: state)?.weeklyCountLabel, "5 / 7 days")
        XCTAssertEqual(habit(id: "protein", in: state)?.weeklyCountLabel, "3 / 7 days")
        XCTAssertEqual(habit(id: "water", in: state)?.weeklyCountLabel, "2 / 7 days")
        XCTAssertEqual(habit(id: "weight", in: state)?.weeklyCountLabel, "2 / 7 days")
    }

    func testStreakCalculationUsesCurrentStreaks() {
        let weekLogs = (0..<3).map { offset in
            makeLog(daysAgo: offset, calories: 1_800, protein: 140, waterMl: 2_500)
        }

        let state = build(
            weekLogs: weekLogs,
            maturityLogs: weekLogs,
            streaks: makeStreaks(logging: 3, protein: 2, water: 1)
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
            makeLog(daysAgo: offset, calories: 1_800, protein: 80, waterMl: 400)
        }

        let state = build(
            weekLogs: weekLogs,
            maturityLogs: weekLogs,
            streaks: makeStreaks(logging: 0, protein: 0, water: 0)
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
            makeLog(daysAgo: 2, calories: 1_800, protein: 140, waterMl: 2_500),
            makeLog(daysAgo: 0, calories: 1_800, protein: 140, waterMl: 2_500)
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
        let resolvedStreaks = streaks ?? makeStreaks(logging: 0, protein: 0, water: 0)
        let review = JourneyWeeklyReviewState(
            foodLoggedDays: JourneyLogMetrics.uniqueFoodLoggedDays(in: weekLogs, calendar: calendar),
            foodLoggedDaysTotal: 7,
            proteinGoalDays: JourneyLogMetrics.uniqueProteinGoalDays(in: weekLogs, calendar: calendar),
            proteinGoalDaysTotal: 7,
            waterGoalDays: JourneyLogMetrics.uniqueWaterGoalDays(in: weekLogs, calendar: calendar),
            waterGoalDaysTotal: 7,
            trainingDays: 0,
            expectedTrainingDays: 4,
            training: training,
            weightDeltaThisWeekKg: nil,
            calorieAdherenceDays: JourneyLogMetrics.uniqueCalorieAdherenceDays(in: weekLogs, calendar: calendar),
            calorieAdherenceDaysTotal: 7,
            weekSummaryCopy: "",
            rows: [],
            weekOverWeekDetail: nil
        )

        let streakSummary = StreakCalculator.calculate(
            logs: maturityLogs,
            workoutDates: [],
            asOf: asOf,
            calendar: calendar
        )

        return JourneyWeeklyPatternBuilder.build(
            JourneyWeeklyPatternBuilder.Input(
                weekLogs: weekLogs,
                weekWeights: weekWeights,
                maturityLogs: maturityLogs,
                allWeights: allWeights,
                healthWorkoutDayStarts: [],
                weeklyTraining: training,
                expectedTrainingDays: 4,
                streaks: resolvedStreaks,
                streakSummary: streakSummary,
                weeklyReview: review,
                asOf: asOf,
                calendar: calendar
            )
        )
    }

    private func habit(id: String, in state: JourneyWeeklyHabitState) -> JourneyWeeklyHabitRowState? {
        state.habits.first { $0.id == id }
    }

    private func makeStreaks(logging: Int, protein: Int, water: Int) -> JourneyStreakState {
        JourneyStreakState(
            currentLoggingStreakDays: logging,
            longestLoggingStreakDays: logging,
            currentProteinStreakDays: protein,
            currentWaterStreakDays: water,
            currentTrainingStreakWeeks: nil,
            isTodayLogged: logging > 0,
            heroStreakChip: .hidden,
            weeklyConsistencyHeadline: "",
            weeklyConsistencyDetail: nil,
            keepStreakAliveCopy: nil
        )
    }

    private func makeLog(
        daysAgo: Int,
        calories: Int,
        protein: Double,
        waterMl: Int
    ) -> DailyLog {
        let date = calendar.date(byAdding: .day, value: -daysAgo, to: asOf)!
        return DailyLog(
            id: UUID(),
            date: date,
            weightKg: nil,
            targets: ProfileTestFixtures.sampleTargets,
            totals: MacroTotals(
                calories: calories,
                protein: protein,
                carbs: 120,
                fat: 50,
                fiber: nil,
                sodium: nil
            ),
            waterConsumedMl: waterMl,
            steps: nil,
            workoutCaloriesBurned: 0,
            dailyReviewId: nil,
            createdAt: date,
            updatedAt: date
        )
    }

    private func makeWeight(daysAgo: Int, kg: Double) -> WeightEntry {
        let date = calendar.date(byAdding: .day, value: -daysAgo, to: asOf)!
        return WeightEntry(
            id: UUID(),
            date: date,
            weightKg: kg,
            note: nil,
            createdAt: date
        )
    }
}
