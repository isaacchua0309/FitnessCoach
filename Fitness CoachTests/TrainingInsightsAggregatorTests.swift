//
//  TrainingInsightsAggregatorTests.swift
//  Fitness CoachTests
//

import XCTest
@testable import Fitness_Coach

final class TrainingInsightsAggregatorTests: XCTestCase {

    private var calendar: Calendar!
    private var referenceNow: Date!

    override func setUp() {
        super.setUp()
        var gregorian = Calendar(identifier: .gregorian)
        gregorian.timeZone = TimeZone(secondsFromGMT: 0)!
        calendar = gregorian

        var components = DateComponents()
        components.year = 2026
        components.month = 6
        components.day = 27
        components.hour = 12
        referenceNow = calendar.date(from: components)!
    }

    func testWeeklySummaryAggregatesCountDurationAndCalories() {
        let workouts = [
            makeWorkout(daysAgo: 1, minutes: 45, calories: 320, name: "Strength training"),
            makeWorkout(daysAgo: 4, minutes: 50, calories: 300, name: "Running")
        ]

        let summary = TrainingInsightsAggregator.summary(
            workouts: workouts,
            asOf: referenceNow,
            calendar: calendar
        )

        XCTAssertEqual(summary.weekly.workoutCount, 2)
        XCTAssertEqual(summary.weekly.workoutDays, 2)
        XCTAssertEqual(summary.weekly.totalDurationMinutes, 95)
        XCTAssertEqual(summary.weekly.activeCalories, 620)
        XCTAssertEqual(summary.weekly.workoutTypes.count, 2)
    }

    func testConsistencyCountsUniqueWorkoutDays() {
        let workouts = [
            makeWorkout(daysAgo: 1, minutes: 45, calories: 320, name: "Strength training"),
            makeWorkout(daysAgo: 1, minutes: 20, calories: 100, name: "Walking"),
            makeWorkout(daysAgo: 10, minutes: 40, calories: 280, name: "Strength training")
        ]

        let summary = TrainingInsightsAggregator.summary(
            workouts: workouts,
            asOf: referenceNow,
            calendar: calendar
        )

        XCTAssertEqual(summary.consistency.workoutDays7, 1)
        XCTAssertEqual(summary.consistency.workoutDays14, 2)
        XCTAssertEqual(summary.consistency.workoutDays28, 2)
    }

    func testRecentWorkoutSelectsLatestStartDate() {
        let older = makeWorkout(daysAgo: 5, minutes: 30, calories: 200, name: "Running")
        let newer = makeWorkout(daysAgo: 1, minutes: 45, calories: 320, name: "Strength training")

        let summary = TrainingInsightsAggregator.summary(
            workouts: [older, newer],
            asOf: referenceNow,
            calendar: calendar
        )

        XCTAssertEqual(summary.recentWorkout?.activityName, "Strength training")
        XCTAssertEqual(summary.recentWorkout?.durationMinutes, 45)
    }

    func testCoachNoteForTwoWeeklyWorkouts() {
        let note = TrainingInsightsCoachNoteBuilder.note(weeklyWorkoutCount: 2)
        XCTAssertEqual(
            note,
            "You trained twice this week. Keep your next session simple and recover well."
        )
    }

    func testCoachNoteWhenNoWeeklyWorkouts() {
        let note = TrainingInsightsCoachNoteBuilder.note(weeklyWorkoutCount: 0)
        XCTAssertEqual(
            note,
            "No workouts found yet. Once Apple Fitness records one, Forma will reflect it here."
        )
    }

    func testConsistencyNoteWhenRegularTraining() {
        let consistency = TrainingInsightsConsistencySummary(
            workoutDays7: 2,
            workoutDays14: 4,
            workoutDays28: 6,
            workoutDaysThisMonth: 5
        )
        let note = TrainingInsightsConsistencyNoteBuilder.note(for: consistency)
        XCTAssertEqual(note, "You have been training regularly over the last two weeks.")
    }

    func testWorkoutTypeCountsGroupsDuplicates() {
        let workouts = [
            makeWorkout(daysAgo: 1, minutes: 45, calories: 320, name: "Strength training"),
            makeWorkout(daysAgo: 3, minutes: 40, calories: 300, name: "Strength training"),
            makeWorkout(daysAgo: 5, minutes: 30, calories: 200, name: "Running")
        ]

        let weekly = TrainingInsightsAggregator.weeklySummary(from: workouts)
        let strength = weekly.workoutTypes.first { $0.name == "Strength training" }
        XCTAssertEqual(strength?.count, 2)
    }

    func testFormatterRecentWorkoutLine() {
        let workout = makeWorkout(daysAgo: 1, minutes: 45, calories: 320, name: "Strength training")
        XCTAssertEqual(
            TrainingInsightsFormatter.recentWorkoutLine(workout),
            "Strength training · 45 min"
        )
    }

    func testInsightsModelShowsEmptyWhenNoWorkouts() async {
        let reader = MockHealthKitWorkoutReader(workouts: [])
        let model = await MainActor.run {
            TrainingInsightsModel(
                workoutReader: reader,
                dateProvider: FixedTestDateProvider(now: referenceNow),
                calendar: calendar
            )
        }

        await model.refresh()

        let state = await MainActor.run { model.viewState }
        if case .empty = state {
            XCTAssertEqual(reader.fetchCallCount, 1)
        } else {
            XCTFail("Expected empty state, got \(state)")
        }
    }

    // MARK: - Helpers

    private func makeWorkout(
        daysAgo: Int,
        minutes: Int,
        calories: Int,
        name: String
    ) -> HealthWorkoutRecord {
        let start = calendar.date(byAdding: .day, value: -daysAgo, to: referenceNow)!
        let end = calendar.date(byAdding: .minute, value: minutes, to: start)!
        return HealthWorkoutRecord(
            id: UUID(),
            activityName: name,
            startDate: start,
            endDate: end,
            durationMinutes: minutes,
            activeCalories: calories
        )
    }
}

private struct FixedTestDateProvider: DateProviding {
    let now: Date

    func startOfDay(for date: Date) -> Date {
        Calendar.current.startOfDay(for: date)
    }
}
