//
//  WorkoutIntelligenceEngineTests.swift
//  Fitness CoachTests
//

import XCTest
@testable import Fitness_Coach

final class WorkoutIntelligenceEngineTests: XCTestCase {

    private var calendar: Calendar!
    private var engine: WorkoutIntelligenceEngine!
    private var targetDate: Date!

    override func setUp() {
        super.setUp()
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(secondsFromGMT: 0) ?? .gmt
        self.calendar = calendar
        self.engine = WorkoutIntelligenceEngine()
        self.targetDate = makeDate(2026, 7, 8)
    }

    func testNoWorkoutReturnsRestDaySummaryWithoutFakeCalories() {
        let summary = evaluate(today: [])

        XCTAssertFalse(summary.hasWorkout)
        XCTAssertNil(summary.totalActiveCalories)
        XCTAssertEqual(summary.demand, .low)
        XCTAssertEqual(summary.hydrationAdviceMl, 0)
        XCTAssertEqual(summary.confidence, .low)
    }

    func testStrengthWorkoutSeventyMinutesIsHighDemand() {
        let workout = makeWorkout(
            category: .strength,
            label: "Strength training",
            duration: 70,
            energy: 420,
            startHour: 18
        )

        let summary = evaluate(today: [workout])

        XCTAssertTrue(summary.hasWorkout)
        XCTAssertEqual(summary.totalDurationMinutes, 70)
        XCTAssertEqual(summary.demand, .high)
        XCTAssertEqual(summary.primaryWorkoutType, .strength)
        XCTAssertGreaterThanOrEqual(summary.hydrationAdviceMl, 700)
        XCTAssertTrue(summary.nutritionAdvice.contains("30–45g protein"))
    }

    func testWalkingTwentyMinutesIsLowDemand() {
        let workout = makeWorkout(
            category: .walking,
            label: "Walking",
            duration: 20,
            energy: 80,
            startHour: 9
        )

        let summary = evaluate(today: [workout])

        XCTAssertEqual(summary.demand, .low)
        XCTAssertEqual(summary.intensity, .low)
        XCTAssertEqual(summary.hydrationAdviceMl, 250)
        XCTAssertEqual(summary.nutritionAdvice, "Stay on your usual plan today.")
    }

    func testHighCalorieRunningWorkoutIsHighIntensity() {
        let workout = makeWorkout(
            category: .running,
            label: "Running",
            duration: 50,
            energy: 500,
            startHour: 7
        )

        let summary = evaluate(today: [workout])

        XCTAssertEqual(summary.intensity, .high)
        XCTAssertEqual(summary.totalActiveCalories, 500)
        XCTAssertTrue(summary.demand == .moderate || summary.demand == .high)
    }

    func testMultipleWorkoutsSummarizeTotalsAndPickHighestLoadPrimary() {
        let running = makeWorkout(
            category: .running,
            label: "Running",
            duration: 55,
            energy: 450,
            startHour: 7
        )
        let walking = makeWorkout(
            category: .walking,
            label: "Walking",
            duration: 25,
            energy: 100,
            startHour: 18
        )

        let summary = evaluate(today: [walking, running])

        XCTAssertEqual(summary.workoutCount, 2)
        XCTAssertEqual(summary.totalDurationMinutes, 80)
        XCTAssertEqual(summary.totalActiveCalories, 550)
        XCTAssertEqual(summary.primaryWorkoutType, .running)
        XCTAssertEqual(summary.title, "Running + 1 more")
    }

    func testMissingCaloriesOmitsTotalCaloriesAndLowersConfidence() {
        let workout = makeWorkout(
            category: .cycling,
            label: "Cycling",
            duration: 40,
            energy: 0,
            startHour: 12
        )

        let summary = evaluate(today: [workout])

        XCTAssertNil(summary.totalActiveCalories)
        XCTAssertEqual(summary.confidence, .moderate)
        XCTAssertTrue(summary.sourceSummary.contains("estimates"))
    }

    func testWorkoutCrossingMidnightIsAttributedToStartDay() {
        let dayStart = calendar.startOfDay(for: targetDate)
        let start = calendar.date(byAdding: .hour, value: 23, to: dayStart)!
        let end = calendar.date(byAdding: .hour, value: 1, to: start)!
        let workout = NormalizedWorkout(
            id: UUID(),
            category: .running,
            activityLabel: "Late run",
            startDate: start,
            endDate: end,
            durationMinutes: 60,
            activeEnergyKcal: 520,
            sourceName: "Apple Watch"
        )

        let onStartDay = WorkoutIntelligenceEngine.workoutsOnTargetDay(
            [workout],
            targetDay: dayStart,
            calendar: calendar
        )
        XCTAssertEqual(onStartDay.count, 1)

        let nextDay = calendar.date(byAdding: .day, value: 1, to: dayStart)!
        let onNextDay = WorkoutIntelligenceEngine.workoutsOnTargetDay(
            [workout],
            targetDay: nextDay,
            calendar: calendar
        )
        XCTAssertEqual(onNextDay.count, 1)

        let summary = evaluate(today: [workout])
        XCTAssertTrue(summary.hasWorkout)
        XCTAssertEqual(summary.totalDurationMinutes, 60)
    }

    func testConfidenceScoring() {
        let complete = makeWorkout(category: .running, label: "Run", duration: 30, energy: 300, startHour: 8)
        let partial = makeWorkout(category: .yoga, label: "Yoga", duration: 30, energy: 0, startHour: 9)
        let incomplete = NormalizedWorkout(
            id: UUID(),
            category: .other,
            activityLabel: "",
            startDate: makeDateTime(hour: 10),
            endDate: makeDateTime(hour: 10),
            durationMinutes: 0,
            activeEnergyKcal: 0,
            sourceName: nil
        )

        XCTAssertEqual(evaluate(today: [complete]).confidence, .high)
        XCTAssertEqual(evaluate(today: [partial]).confidence, .moderate)
        XCTAssertEqual(evaluate(today: [incomplete]).confidence, .low)
    }

    // MARK: - Helpers

    private func evaluate(
        today: [NormalizedWorkout],
        trainingLoad: TrainingLoadSummary = .unknown
    ) -> WorkoutSummary {
        try! engine.evaluate(
            WorkoutIntelligenceInput(
                targetDate: targetDate,
                workoutsToday: today,
                recentWorkouts: today,
                trainingLoadSummary: trainingLoad,
                baselineContext: .empty(for: targetDate),
                calendar: calendar
            )
        )
    }

    private func makeDate(_ year: Int, _ month: Int, _ day: Int) -> Date {
        calendar.date(from: DateComponents(year: year, month: month, day: day))!
    }

    private func makeDateTime(hour: Int, minute: Int = 0) -> Date {
        calendar.date(
            bySettingHour: hour,
            minute: minute,
            second: 0,
            of: targetDate
        )!
    }

    private func makeWorkout(
        category: FormaWorkoutCategory,
        label: String,
        duration: Int,
        energy: Double,
        startHour: Int
    ) -> NormalizedWorkout {
        let start = makeDateTime(hour: startHour)
        let end = calendar.date(byAdding: .minute, value: duration, to: start)!
        return NormalizedWorkout(
            id: UUID(),
            category: category,
            activityLabel: label,
            startDate: start,
            endDate: end,
            durationMinutes: duration,
            activeEnergyKcal: energy,
            sourceName: "Apple Watch"
        )
    }
}
