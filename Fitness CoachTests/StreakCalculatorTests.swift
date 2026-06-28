//
//  StreakCalculatorTests.swift
//  Fitness CoachTests
//

import XCTest
@testable import Fitness_Coach

final class StreakCalculatorTests: XCTestCase {

    private var calendar: Calendar = {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(secondsFromGMT: 0)!
        return calendar
    }()

    private let asOf = Date(timeIntervalSince1970: 1_700_086_400) // 2023-11-15 00:00:00 UTC

    func testEmptyLogsReturnZeroStreaks() {
        let summary = StreakCalculator.calculate(
            logs: [],
            workoutDates: [],
            asOf: asOf,
            calendar: calendar
        )

        XCTAssertEqual(summary.loggingStreak, 0)
        XCTAssertEqual(StreakCalculator.longestLoggingStreak(in: [], calendar: calendar), 0)
    }

    func testTodayLoggedBuildsConsecutiveStreak() {
        let logs = [
            makeLog(daysAgo: 0, calories: 500),
            makeLog(daysAgo: 1, calories: 500),
            makeLog(daysAgo: 2, calories: 500)
        ]

        let summary = StreakCalculator.calculate(
            logs: logs,
            workoutDates: [],
            asOf: asOf,
            calendar: calendar
        )

        XCTAssertEqual(summary.loggingStreak, 3)
    }

    func testYesterdayLoggedButNotTodayBreaksStreak() {
        let logs = [
            makeLog(daysAgo: 1, calories: 500),
            makeLog(daysAgo: 2, calories: 500)
        ]

        let summary = StreakCalculator.calculate(
            logs: logs,
            workoutDates: [],
            asOf: asOf,
            calendar: calendar
        )

        XCTAssertEqual(summary.loggingStreak, 0)
        XCTAssertEqual(
            StreakCalculator.loggingStreakEndingYesterday(
                logs: logs,
                asOf: asOf,
                calendar: calendar
            ),
            2
        )
    }

    func testMissingDayBreaksLongestStreakCalculation() {
        let logs = [
            makeLog(daysAgo: 6, calories: 400),
            makeLog(daysAgo: 5, calories: 400),
            makeLog(daysAgo: 3, calories: 400),
            makeLog(daysAgo: 2, calories: 400),
            makeLog(daysAgo: 1, calories: 400),
            makeLog(daysAgo: 0, calories: 400)
        ]

        XCTAssertEqual(StreakCalculator.longestLoggingStreak(in: logs, calendar: calendar), 4)
    }

    func testLongestLoggingStreakAcrossHistory() {
        let logs = (0..<5).map { makeLog(daysAgo: $0, calories: 500) }

        XCTAssertEqual(StreakCalculator.longestLoggingStreak(in: logs, calendar: calendar), 5)
    }

    func testTimezoneBoundaryUsesCalendarStartOfDay() {
        var localCalendar = Calendar(identifier: .gregorian)
        localCalendar.timeZone = TimeZone(secondsFromGMT: -28_800)! // UTC-8

        let evening = localCalendar.date(
            bySettingHour: 23,
            minute: 30,
            second: 0,
            of: asOf
        )!
        let log = DailyLog(
            id: UUID(),
            date: evening,
            weightKg: nil,
            targets: ProfileTestFixtures.sampleTargets,
            totals: MacroTotals(calories: 600, protein: 40, carbs: 50, fat: 20, fiber: nil, sodium: nil),
            waterConsumedMl: 0,
            steps: nil,
            workoutCaloriesBurned: 0,
            dailyReviewId: nil,
            createdAt: evening,
            updatedAt: evening
        )

        XCTAssertTrue(StreakCalculator.isLogged(on: evening, in: [log], calendar: localCalendar))
    }

    func testTrainingStreakWeeksCountsConsecutiveWeeks() {
        let workoutDay = calendar.startOfDay(for: asOf)
        let previousWeek = calendar.date(byAdding: .weekOfYear, value: -1, to: workoutDay)!
        let workoutDates: Set<Date> = [workoutDay, previousWeek]

        let weeks = StreakCalculator.trainingStreakWeeks(
            workoutDates: workoutDates,
            asOf: asOf,
            calendar: calendar
        )

        XCTAssertGreaterThanOrEqual(weeks, 2)
    }

    // MARK: - Helpers

    private func makeLog(daysAgo: Int, calories: Int) -> DailyLog {
        let date = calendar.date(byAdding: .day, value: -daysAgo, to: asOf)!
        return DailyLog(
            id: UUID(),
            date: date,
            weightKg: nil,
            targets: ProfileTestFixtures.sampleTargets,
            totals: MacroTotals(
                calories: calories,
                protein: 120,
                carbs: 100,
                fat: 40,
                fiber: nil,
                sodium: nil
            ),
            waterConsumedMl: 0,
            steps: nil,
            workoutCaloriesBurned: 0,
            dailyReviewId: nil,
            createdAt: date,
            updatedAt: date
        )
    }
}
