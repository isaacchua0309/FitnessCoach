//
//  JourneyStreakBuilderTests.swift
//  Fitness CoachTests
//

import XCTest
@testable import Fitness_Coach

final class JourneyStreakBuilderTests: XCTestCase {

    private var calendar: Calendar = {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(secondsFromGMT: 0)!
        return calendar
    }()

    private let asOf = Date(timeIntervalSince1970: 1_700_086_400)

    func testHeroStreakChipUsesLoggingStreakCopy() {
        let state = build(loggingStreak: 7)

        XCTAssertTrue(state.heroStreakChip.isVisible)
        XCTAssertEqual(state.heroStreakChip.label, "7-day logging streak")
    }

    func testKeepStreakAliveWhenYesterdayLoggedButNotToday() {
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

        let state = JourneyStreakBuilder.build(
            JourneyStreakBuilder.Input(
                streakSummary: summary,
                maturityLogs: logs,
                workoutDates: [],
                isAppleHealthConnected: false,
                asOf: asOf,
                calendar: calendar
            )
        )

        XCTAssertEqual(state.currentLoggingStreakDays, 0)
        XCTAssertEqual(state.keepStreakAliveCopy, "Log today to keep your 2-day streak alive.")
    }

    func testLongestStreakSurfacedInWeeklyConsistency() {
        let logs = (0..<10).map { makeLog(daysAgo: $0, calories: 500) }
        let state = build(logs: logs, loggingStreak: 10, longestLogging: 10)

        XCTAssertEqual(state.longestLoggingStreakDays, 10)
        XCTAssertTrue(state.weeklyConsistencyDetail?.contains("21") == false)
        XCTAssertEqual(state.weeklyConsistencyHeadline, "10-day logging streak")
    }

    func testTrainingStreakWeeksNilWhenAppleHealthDisconnected() {
        let state = build(loggingStreak: 2, isAppleHealthConnected: false)

        XCTAssertNil(state.currentTrainingStreakWeeks)
    }

    func testTrainingStreakWeeksWhenAppleHealthConnected() {
        let workoutDay = calendar.startOfDay(for: asOf)
        let state = build(
            loggingStreak: 1,
            workoutDates: [workoutDay],
            isAppleHealthConnected: true
        )

        XCTAssertEqual(state.currentTrainingStreakWeeks, 1)
    }

    func testBuildingConsistencyCopyWhenNoActiveStreak() {
        let state = build(loggingStreak: 0)

        XCTAssertEqual(
            state.habitInsightStreakCopy,
            FormaProductCopy.Journey.Streaks.buildingConsistency
        )
        XCTAssertFalse(state.heroStreakChip.isVisible)
    }

    // MARK: - Helpers

    private func build(
        logs: [DailyLog] = [],
        loggingStreak: Int = 0,
        longestLogging: Int = 0,
        workoutDates: Set<Date> = [],
        isAppleHealthConnected: Bool = false
    ) -> JourneyStreakState {
        let summary = StreakSummary(
            loggingStreak: loggingStreak,
            proteinStreak: 2,
            hydrationStreak: 1,
            workoutStreak: workoutDates.isEmpty ? 0 : 1
        )
        return JourneyStreakBuilder.build(
            JourneyStreakBuilder.Input(
                streakSummary: summary,
                maturityLogs: logs.isEmpty ? (0..<max(longestLogging, loggingStreak)).map {
                    makeLog(daysAgo: $0, calories: 500)
                } : logs,
                workoutDates: workoutDates,
                isAppleHealthConnected: isAppleHealthConnected,
                asOf: asOf,
                calendar: calendar
            )
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
