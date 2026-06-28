//
//  JourneyConsistencyCalendarTests.swift
//  Fitness CoachTests
//
//  Forma — Journey consistency / momentum display rules.
//

import XCTest
@testable import Fitness_Coach

final class JourneyConsistencyCalendarTests: XCTestCase {

    func testZeroLoggedDaysShowsMomentumEmpty() {
        let calendar = makeCalendar(totalLoggedDays: 0, monthCompleted: 0)

        XCTAssertEqual(calendar.displayMode, .momentumEmpty)
    }

    func testOneOrTwoLoggedDaysShowsSummaryWithoutFullCalendar() {
        XCTAssertEqual(makeCalendar(totalLoggedDays: 1, monthCompleted: 1).displayMode, .consistencySummary)
        XCTAssertEqual(makeCalendar(totalLoggedDays: 2, monthCompleted: 2).displayMode, .consistencySummary)
    }

    func testThreeOrMoreLoggedDaysShowsFullCalendar() {
        XCTAssertEqual(makeCalendar(totalLoggedDays: 3, monthCompleted: 3).displayMode, .fullCalendar)
        XCTAssertEqual(makeCalendar(totalLoggedDays: 10, monthCompleted: 5).displayMode, .fullCalendar)
    }

    func testConsistencyCalendarBuilderCountsTotalLoggedDays() {
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: Date())
        let yesterday = calendar.date(byAdding: .day, value: -1, to: today)!

        let logs = [
            makeLog(on: today, calories: 500),
            makeLog(on: yesterday, waterMl: 1_000)
        ]

        let result = JourneyDashboardBuilder.consistencyCalendar(
            logs: logs,
            healthWorkoutDayStarts: [],
            weights: [],
            month: today,
            calendar: calendar
        )

        XCTAssertEqual(result.totalLoggedDays, 2)
        XCTAssertEqual(result.displayMode, .consistencySummary)
    }

    private func makeCalendar(totalLoggedDays: Int, monthCompleted: Int) -> JourneyConsistencyCalendar {
        JourneyConsistencyCalendar(
            monthTitle: "June 2026",
            weekdaySymbols: Calendar.current.shortWeekdaySymbols,
            days: [],
            completedCount: monthCompleted,
            totalLoggedDays: totalLoggedDays
        )
    }

    private func makeLog(on date: Date, calories: Int = 0, waterMl: Int = 0) -> DailyLog {
        DailyLog(
            id: UUID(),
            date: date,
            weightKg: nil,
            targets: UserTargets(
                calorieTarget: 2_000,
                proteinTarget: 150,
                carbTarget: 200,
                fatTarget: 60,
                waterTargetMl: 2_500,
                expectedWeeklyWeightLossKg: 0.5,
                aggressiveness: .moderate
            ),
            totals: MacroTotals(
                calories: calories,
                protein: 0,
                carbs: 0,
                fat: 0,
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
}
