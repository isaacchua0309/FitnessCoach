//
//  HealthIntelligenceBaselineTests.swift
//  Fitness CoachTests
//

import XCTest
@testable import Fitness_Coach

final class HealthIntelligenceBaselineTests: XCTestCase {

    private var calendar: Calendar!

    override func setUp() {
        super.setUp()
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(secondsFromGMT: 0) ?? .gmt
        self.calendar = calendar
    }

    func testWorkoutSummaryPicksLongestWorkoutDeterministically() {
        let day = makeDate(2026, 7, 3)
        let workouts = [
            makeWorkout(
                id: "00000000-0000-0000-0000-000000000002",
                label: "Walking",
                duration: 30,
                startHour: 18
            ),
            makeWorkout(
                id: "00000000-0000-0000-0000-000000000001",
                label: "Running",
                duration: 55,
                startHour: 7
            )
        ]

        let summary = HealthIntelligenceBaseline.workoutSummary(
            workouts: workouts,
            on: day,
            calendar: calendar
        )

        XCTAssertEqual(summary?.primaryActivityName, "Running")
        XCTAssertEqual(summary?.primaryDurationMinutes, 55)
    }

    func testPlanConfidenceRequiresSevenDaysForModerateLabel() {
        let availability = HealthDataAvailability(
            isHealthDataAvailable: true,
            permissionStatus: .uniform(.available, isHealthDataAvailable: true),
            cachedDayCount: 7
        )

        let limited = HealthIntelligenceBaseline.planConfidence(
            availability: availability,
            daysWithActivityData: 3
        )
        let moderate = HealthIntelligenceBaseline.planConfidence(
            availability: availability,
            daysWithActivityData: 7
        )

        XCTAssertEqual(limited.label, "Limited")
        XCTAssertEqual(moderate.label, "Moderate")
        XCTAssertGreaterThan(moderate.score, limited.score)
    }

    func testWeeklyReviewRequiresSevenActiveDays() {
        let metrics = (0..<6).map { index in
            DailyHealthMetrics(
                date: makeDate(2026, 7, index + 1),
                steps: 5_000,
                activeEnergyKcal: 300,
                exerciseMinutes: 30
            )
        }

        XCTAssertNil(
            HealthIntelligenceBaseline.weeklyReview(metricsInWeek: metrics, workoutDays: 2)
        )

        let seventh = DailyHealthMetrics(
            date: makeDate(2026, 7, 7),
            steps: 5_000,
            activeEnergyKcal: 300,
            exerciseMinutes: 30
        )

        XCTAssertNotNil(
            HealthIntelligenceBaseline.weeklyReview(
                metricsInWeek: metrics + [seventh],
                workoutDays: 3
            )
        )
    }

    // MARK: - Helpers

    private func makeDate(_ year: Int, _ month: Int, _ day: Int, hour: Int = 0) -> Date {
        calendar.date(from: DateComponents(year: year, month: month, day: day, hour: hour))!
    }

    private func makeWorkout(
        id: String,
        label: String,
        duration: Int,
        startHour: Int
    ) -> NormalizedWorkout {
        let start = makeDate(2026, 7, 3, hour: startHour)
        return NormalizedWorkout(
            id: UUID(uuidString: id)!,
            category: .other,
            activityLabel: label,
            startDate: start,
            endDate: calendar.date(byAdding: .minute, value: duration, to: start) ?? start,
            durationMinutes: duration,
            activeEnergyKcal: 200,
            sourceName: nil
        )
    }
}
