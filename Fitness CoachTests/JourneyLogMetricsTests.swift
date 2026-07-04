//
//  JourneyLogMetricsTests.swift
//  Fitness CoachTests
//

import XCTest
@testable import Fitness_Coach

final class JourneyLogMetricsTests: XCTestCase {

    func testProteinGoalDaysRequiresNinetyPercentOfTarget() {
        let hit = makeLog(protein: 135, target: 150)
        let miss = makeLog(protein: 100, target: 150)

        XCTAssertEqual(JourneyLogMetrics.proteinGoalDays(in: [hit]), 1)
        XCTAssertEqual(JourneyLogMetrics.proteinGoalDays(in: [miss]), 0)
    }

    func testRollingWeekStartMatchesRollingWeekDayStartsFirstDay() {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(secondsFromGMT: 0) ?? .gmt
        let asOf = calendar.startOfDay(
            for: calendar.date(from: DateComponents(year: 2026, month: 7, day: 4))!
        )

        let weekStart = JourneyLogMetrics.rollingWeekStart(asOf: asOf, calendar: calendar)
        let dayStarts = JourneyLogMetrics.rollingWeekDayStarts(asOf: asOf, calendar: calendar)

        XCTAssertEqual(weekStart, dayStarts.first)
        XCTAssertEqual(dayStarts.count, JourneyLogMetrics.weekDayCount)
        XCTAssertEqual(dayStarts.last, asOf)
    }

    func testInclusiveDaySpanStartCoversRequestedDayCount() {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(secondsFromGMT: 0) ?? .gmt
        let end = calendar.startOfDay(
            for: calendar.date(from: DateComponents(year: 2026, month: 7, day: 10))!
        )

        let start = JourneyLogMetrics.inclusiveDaySpanStart(
            endingOn: end,
            dayCount: 30,
            calendar: calendar
        )
        let dayCount = calendar.dateComponents([.day], from: start, to: end).day! + 1

        XCTAssertEqual(dayCount, 30)
    }

    func testLookbackStartMatchesLegacyWeightWindow() {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(secondsFromGMT: 0) ?? .gmt
        let asOf = calendar.startOfDay(
            for: calendar.date(from: DateComponents(year: 2026, month: 6, day: 28))!
        )
        let legacyStart = calendar.date(byAdding: .day, value: -14, to: asOf)!

        XCTAssertEqual(
            JourneyLogMetrics.lookbackStart(endingOn: asOf, dayCount: 14, calendar: calendar),
            legacyStart
        )
    }

    private func makeLog(
        date: Date = TestDateFixtures.referenceEpoch,
        protein: Double,
        target: Double
    ) -> DailyLog {
        DailyLog(
            id: UUID(),
            date: date,
            weightKg: nil,
            targets: UserTargets(
                calorieTarget: 2_000,
                proteinTarget: target,
                carbTarget: 200,
                fatTarget: 60,
                waterTargetMl: 2_500,
                expectedWeeklyWeightLossKg: 0.5,
                aggressiveness: .moderate
            ),
            totals: MacroTotals(
                calories: 500,
                protein: protein,
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
