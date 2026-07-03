//
//  TrainingLoadEngineTests.swift
//  Fitness CoachTests
//

import XCTest
@testable import Fitness_Coach

final class TrainingLoadEngineTests: XCTestCase {

    private var calendar: Calendar!
    private var engine: TrainingLoadEngine!
    private var targetDate: Date!

    override func setUp() {
        super.setUp()
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(secondsFromGMT: 0) ?? .gmt
        self.calendar = calendar
        self.engine = TrainingLoadEngine()
        self.targetDate = makeDate(2026, 7, 8)
    }

    func testNoWorkoutsReturnsUnknownWithLowConfidence() {
        let summary = evaluate(
            today: [],
            last7: [],
            last28: [],
            baseline: nil
        )

        XCTAssertEqual(summary.status, .unknown)
        XCTAssertEqual(summary.todayLoad, 0)
        XCTAssertEqual(summary.sevenDayLoad, 0)
        XCTAssertNil(summary.loadRatio)
        XCTAssertEqual(summary.confidence, .low)
        XCTAssertTrue(summary.missingSignals.contains(.workoutHistory))
        XCTAssertTrue(summary.missingSignals.contains(.baseline))
    }

    func testSingleWorkoutIsInsufficientHistoryForKnownStatus() {
        let workout = makeWorkout(
            category: .running,
            duration: 40,
            energy: 320,
            dayOffset: 0
        )

        let summary = evaluate(
            today: [workout],
            last7: [workout],
            last28: [workout],
            baseline: nil
        )

        XCTAssertEqual(summary.status, .unknown)
        XCTAssertGreaterThan(summary.todayLoad, 0)
        XCTAssertEqual(summary.workoutDays7d, 1)
        XCTAssertEqual(summary.confidence, .low)
    }

    func testNormalTrainingWeekProducesNormalStatus() {
        let workouts = (0..<4).map { offset in
            makeWorkout(
                category: .running,
                duration: 45,
                energy: 360,
                dayOffset: -offset
            )
        }
        let history = (0..<8).map { offset in
            makeWorkout(
                category: .running,
                duration: 45,
                energy: 360,
                dayOffset: -offset
            )
        }

        let expectedSevenDay = TrainingLoadScorer.totalLoad(for: workouts)
        let summary = evaluate(
            today: [workouts[0]],
            last7: workouts,
            last28: history,
            baseline: expectedSevenDay
        )

        XCTAssertEqual(summary.status, .normal)
        XCTAssertEqual(summary.sevenDayLoad, expectedSevenDay, accuracy: 0.01)
        XCTAssertEqual(summary.loadRatio ?? 0, 1.0, accuracy: 0.05)
        XCTAssertTrue(summary.confidence == .moderate || summary.confidence == .high)
    }

    func testHighLoadWeekProducesHighStatus() {
        let heavy = makeWorkout(category: .hiit, duration: 50, energy: 500, dayOffset: 0)
        let workouts7 = (0..<4).map { _ in heavy }
        let workouts28 = (0..<6).map { offset in
            makeWorkout(category: .running, duration: 45, energy: 360, dayOffset: -offset)
        } + workouts7

        let sevenDayLoad = TrainingLoadScorer.totalLoad(for: workouts7)
        let baseline = sevenDayLoad / 1.5

        let summary = evaluate(
            today: [heavy],
            last7: workouts7,
            last28: workouts28,
            baseline: baseline
        )

        XCTAssertEqual(summary.status, .high)
        XCTAssertGreaterThan(summary.loadRatio ?? 0, 1.31)
        XCTAssertLessThanOrEqual(summary.loadRatio ?? 0, 1.70)
    }

    func testOverreachingWeekProducesOverreachingStatus() {
        let heavy = makeWorkout(category: .hiit, duration: 60, energy: 600, dayOffset: 0)
        let workouts7 = (0..<5).map { _ in heavy }
        let workouts28 = (0..<8).map { offset in
            makeWorkout(category: .strength, duration: 40, energy: 280, dayOffset: -offset - 1)
        } + workouts7

        let sevenDayLoad = TrainingLoadScorer.totalLoad(for: workouts7)
        let baseline = sevenDayLoad / 2.0

        let summary = evaluate(
            today: [heavy],
            last7: workouts7,
            last28: workouts28,
            baseline: baseline
        )

        XCTAssertEqual(summary.status, .overreaching)
        XCTAssertGreaterThan(summary.loadRatio ?? 0, 1.70)
    }

    func testMissingIntensityLowersConfidenceAndRecordsMissingSignals() {
        let workouts = (0..<4).map { offset in
            makeWorkout(
                category: .running,
                duration: 45,
                energy: 0,
                dayOffset: -offset
            )
        }

        let summary = evaluate(
            today: [workouts[0]],
            last7: workouts,
            last28: workouts,
            baseline: 300
        )

        XCTAssertTrue(summary.missingSignals.contains(.calories))
        XCTAssertTrue(summary.missingSignals.contains(.intensityData))
        XCTAssertEqual(summary.confidence, .low)
        XCTAssertEqual(TrainingLoadScorer.inferredIntensity(for: workouts[0]), .unknown)
    }

    func testOutlierDurationIsCapped() {
        let outlier = makeWorkout(
            category: .running,
            duration: 400,
            energy: 2_000,
            dayOffset: 0
        )

        let capped = TrainingLoadScorer.workoutLoad(for: outlier)
        let uncapped = Double(outlier.durationMinutes) * 2.0 * 1.3

        XCTAssertEqual(capped, TrainingLoadPolicy.maxSingleWorkoutLoad)
        XCTAssertGreaterThan(uncapped, TrainingLoadPolicy.maxSingleWorkoutLoad)
    }

    func testLoadRatioWithoutBaselineUsesTwentyEightDayAverageWeeklyLoad() {
        let lightHistorical = makeWorkout(category: .walking, duration: 30, energy: 120, dayOffset: -10)
        let history = (0..<6).map { offset in
            makeWorkout(category: .walking, duration: 30, energy: 120, dayOffset: -offset - 1)
        } + [lightHistorical]
        let recentHeavy = (0..<3).map { offset in
            makeWorkout(category: .hiit, duration: 50, energy: 500, dayOffset: -offset)
        }

        let twentyEightTotal = TrainingLoadScorer.totalLoad(for: history + recentHeavy)
        let expectedWeekly = twentyEightTotal / TrainingLoadPolicy.weeksIn28DayWindow
        let sevenDayLoad = TrainingLoadScorer.totalLoad(for: recentHeavy)

        let summary = evaluate(
            today: [recentHeavy[0]],
            last7: recentHeavy,
            last28: history + recentHeavy,
            baseline: nil
        )

        XCTAssertTrue(summary.missingSignals.contains(.baseline))
        XCTAssertNotNil(summary.loadRatio)
        XCTAssertEqual(summary.twentyEightDayAverageWeeklyLoad, expectedWeekly, accuracy: 0.01)
        XCTAssertEqual(summary.loadRatio ?? 0, sevenDayLoad / expectedWeekly, accuracy: 0.05)
        XCTAssertNotEqual(summary.status, .unknown)
    }

    func testExplanationStaysShort() {
        let workouts = (0..<4).map { offset in
            makeWorkout(category: .cycling, duration: 50, energy: 400, dayOffset: -offset)
        }
        let summary = evaluate(
            today: [workouts[0]],
            last7: workouts,
            last28: workouts,
            baseline: TrainingLoadScorer.totalLoad(for: workouts)
        )

        XCTAssertLessThanOrEqual(summary.explanation.count, 120)
        XCTAssertFalse(summary.explanation.contains("\n"))
    }

    // MARK: - Helpers

    private func evaluate(
        today: [NormalizedWorkout],
        last7: [NormalizedWorkout],
        last28: [NormalizedWorkout],
        baseline: Double?
    ) -> TrainingLoadSummary {
        engine.evaluate(
            TrainingLoadEngineInput(
                targetDate: targetDate,
                workoutsToday: today,
                workoutsLast7Days: last7,
                workoutsLast28Days: last28,
                baselineAverageWeeklyLoad: baseline,
                calendar: calendar
            )
        )
    }

    private func makeDate(_ year: Int, _ month: Int, _ day: Int) -> Date {
        calendar.date(from: DateComponents(year: year, month: month, day: day))!
    }

    private func makeWorkout(
        category: FormaWorkoutCategory,
        duration: Int,
        energy: Double,
        dayOffset: Int
    ) -> NormalizedWorkout {
        let day = calendar.date(byAdding: .day, value: dayOffset, to: targetDate)!
        let start = calendar.date(byAdding: .hour, value: 8, to: calendar.startOfDay(for: day))!
        let end = calendar.date(byAdding: .minute, value: duration, to: start)!
        return NormalizedWorkout(
            id: UUID(),
            category: category,
            activityLabel: category.rawValue,
            startDate: start,
            endDate: end,
            durationMinutes: duration,
            activeEnergyKcal: energy,
            sourceName: nil
        )
    }
}

private extension FormaWorkoutCategory {
    var typeMultiplier: Double {
        switch self {
        case .walking: 0.75
        case .yoga: 0.8
        case .strength: 1.2
        case .hiit: 1.4
        case .running: 1.3
        case .cycling: 1.1
        case .swimming: 1.2
        case .other: 1.0
        }
    }
}
