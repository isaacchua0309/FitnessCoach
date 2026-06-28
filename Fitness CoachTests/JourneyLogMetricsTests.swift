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

    func testBestProteinDaysInRollingWeekFindsPeakWindow() {
        let calendar = Calendar.current
        let start = calendar.startOfDay(for: Date())
        let logs = (0..<7).map { offset -> DailyLog in
            let date = calendar.date(byAdding: .day, value: offset, to: start)!
            return makeLog(
                date: date,
                protein: offset < 5 ? 140 : 50,
                target: 150
            )
        }

        XCTAssertEqual(
            JourneyLogMetrics.bestProteinDaysInRollingWeek(logs: logs, calendar: calendar),
            5
        )
    }

    private func makeLog(
        date: Date = Date(),
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
