//
//  TodayMomentumSectionTests.swift
//  Fitness CoachTests
//

import XCTest
@testable import Fitness_Coach

final class TodayMomentumSectionTests: XCTestCase {

    private var calendar: Calendar = {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(secondsFromGMT: 0)!
        return calendar
    }()

    private let asOf = Date(timeIntervalSince1970: 1_700_086_400) // 2023-11-15 00:00:00 UTC

    func testActiveStreakShowsLoggingAndOptionalStreaks() {
        let display = TodayMomentumSectionFormatting.displayModel(
            for: TodayMomentumState(
                streaks: StreakSummary(
                    loggingStreak: 21,
                    proteinStreak: 5,
                    hydrationStreak: 3,
                    workoutStreak: 2
                ),
                weekLoggedDays: 5
            )
        )

        XCTAssertEqual(display.loggingStreakLine, "Logging streak: 21 days")
        XCTAssertEqual(display.weekProgressLine, "This week: 5 of 7 days logged")
        XCTAssertEqual(display.optionalStreakLines, [
            "Protein streak: 5 days",
            "Water streak: 3 days"
        ])
        XCTAssertFalse(display.accessibilitySummary.contains("broken"))
    }

    func testBrokenStreakUsesNeutralStartCopy() {
        let display = TodayMomentumSectionFormatting.displayModel(
            for: TodayMomentumState(
                streaks: StreakSummary(
                    loggingStreak: 0,
                    proteinStreak: 0,
                    hydrationStreak: 0,
                    workoutStreak: 0
                ),
                weekLoggedDays: 2
            )
        )

        XCTAssertEqual(
            display.loggingStreakLine,
            FormaProductCopy.Today.Momentum.startStreakToday
        )
        XCTAssertEqual(display.weekProgressLine, "This week: 2 of 7 days logged")
        XCTAssertTrue(display.optionalStreakLines.isEmpty)
        XCTAssertFalse(display.loggingStreakLine.localizedCaseInsensitiveContains("lost"))
        XCTAssertFalse(display.loggingStreakLine.localizedCaseInsensitiveContains("broken"))
    }

    func testNewUserShowsStartStreakAndZeroWeekProgress() {
        let display = TodayMomentumSectionFormatting.displayModel(
            for: TodayMomentumState(
                streaks: StreakSummary(
                    loggingStreak: 0,
                    proteinStreak: 0,
                    hydrationStreak: 0,
                    workoutStreak: 0
                ),
                weekLoggedDays: 0
            )
        )

        XCTAssertEqual(
            display.loggingStreakLine,
            FormaProductCopy.Today.Momentum.startStreakToday
        )
        XCTAssertEqual(display.weekProgressLine, "This week: 0 of 7 days logged")
    }

    func testWeekProgressCountsRollingSevenDayWindow() {
        let logs = [
            makeLog(daysAgo: 0, calories: 500),
            makeLog(daysAgo: 1, calories: 500),
            makeLog(daysAgo: 2, calories: 500),
            makeLog(daysAgo: 3, calories: 500),
            makeLog(daysAgo: 4, calories: 500),
            makeLog(daysAgo: 6, calories: 500)
        ]

        let loggedDays = StreakCalculator.loggedDaysInRollingWindow(
            logs: logs,
            windowDays: 7,
            asOf: asOf,
            calendar: calendar
        )

        XCTAssertEqual(loggedDays, 5)

        let display = TodayMomentumSectionFormatting.displayModel(
            for: TodayMomentumState(
                streaks: StreakSummary(
                    loggingStreak: 1,
                    proteinStreak: 0,
                    hydrationStreak: 0,
                    workoutStreak: 0
                ),
                weekLoggedDays: loggedDays
            )
        )

        XCTAssertEqual(display.weekProgressLine, "This week: 5 of 7 days logged")
    }

    func testYesterdayLoggedButNotTodayShowsNeutralStartCopy() {
        let logs = [
            makeLog(daysAgo: 1, calories: 500),
            makeLog(daysAgo: 2, calories: 500)
        ]

        let streaks = StreakCalculator.calculate(
            logs: logs,
            workoutDates: [],
            asOf: asOf,
            calendar: calendar
        )

        XCTAssertEqual(streaks.loggingStreak, 0)

        let display = TodayMomentumSectionFormatting.displayModel(
            for: TodayMomentumState(
                streaks: streaks,
                weekLoggedDays: StreakCalculator.loggedDaysInRollingWindow(
                    logs: logs,
                    asOf: asOf,
                    calendar: calendar
                )
            )
        )

        XCTAssertEqual(
            display.loggingStreakLine,
            FormaProductCopy.Today.Momentum.startStreakToday
        )
    }

    private func makeLog(daysAgo: Int, calories: Int) -> DailyLog {
        let date = calendar.date(byAdding: .day, value: -daysAgo, to: asOf)!
        return DailyLog(
            id: UUID(),
            date: date,
            weightKg: nil,
            targets: ProfileTestFixtures.sampleTargets,
            totals: MacroTotals(
                calories: calories,
                protein: 0,
                carbs: 0,
                fat: 0,
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
