//
//  RecoveryEngineTests.swift
//  Fitness CoachTests
//

import XCTest
@testable import Fitness_Coach

final class RecoveryEngineTests: XCTestCase {

    private var calendar: Calendar!
    private var engine: RecoveryEngine!
    private var targetDate: Date!

    override func setUp() {
        super.setUp()
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(secondsFromGMT: 0) ?? .gmt
        self.calendar = calendar
        self.engine = RecoveryEngine()
        self.targetDate = makeDate(2026, 7, 8)
    }

    func testNoDataReturnsUnknownStatus() {
        let summary = evaluate()

        XCTAssertEqual(summary.status, .unknown)
        XCTAssertNil(summary.score)
        XCTAssertEqual(summary.confidence, .unknown)
    }

    func testStepsAndWorkoutsOnlyReturnsLimitedEstimate() {
        let summary = evaluate(
            todayMetrics: metrics(steps: 4_000),
            yesterdayMetrics: metrics(steps: 9_000, energy: 500),
            workoutsLast7Days: [makeWorkout(dayOffset: -1, duration: 40)],
            trainingLoad: TrainingLoadSummary(
                status: .normal,
                todayLoad: 50,
                sevenDayLoad: 200,
                twentyEightDayAverageWeeklyLoad: 180,
                loadRatio: 1.1,
                workoutDays7d: 1,
                workoutDays28d: 4,
                explanation: "Load is in line with your recent training pattern.",
                confidence: .moderate,
                missingSignals: []
            ),
            baseline: baseline(steps7d: 6_000, energy7d: 350)
        )

        XCTAssertNil(summary.score)
        XCTAssertEqual(summary.confidence, .low)
        XCTAssertTrue(summary.missingSignals.contains(.sleep))
        XCTAssertTrue(summary.explanation.contains("limited recovery estimate"))
    }

    func testGoodSleepAndNormalHRVProducesReadyScore() {
        let summary = evaluate(
            sleepRecords: [sleepRecord(wakeDayOffset: 0, asleepMinutes: 500)],
            heartMetrics: [
                heartMetric(dayOffset: 0, kind: .restingHeartRate, value: 58),
                heartMetric(dayOffset: 0, kind: .heartRateVariabilitySDNN, value: 56)
            ],
            trainingLoad: normalTrainingLoad,
            baseline: baseline(
                sleep28d: 450,
                restingHR28d: 58,
                hrv28d: 50
            )
        )

        XCTAssertGreaterThanOrEqual(summary.score ?? 0, 75)
        XCTAssertEqual(summary.status, .ready)
        XCTAssertEqual(summary.confidence, .high)
    }

    func testPoorSleepReducesScore() {
        let summary = evaluate(
            sleepRecords: [sleepRecord(wakeDayOffset: 0, asleepMinutes: 300)],
            baseline: baseline(sleep28d: 450)
        )

        XCTAssertLessThan(summary.score ?? 100, 70)
        XCTAssertTrue(
            summary.contributingFactors.contains {
                $0.signal == .sleep && $0.impact == .negative
            }
        )
    }

    func testHighRestingHeartRateReducesScore() {
        let summary = evaluate(
            heartMetrics: [heartMetric(dayOffset: 0, kind: .restingHeartRate, value: 70)],
            baseline: baseline(restingHR28d: 58)
        )

        XCTAssertLessThan(summary.score ?? 100, 70)
        XCTAssertTrue(
            summary.contributingFactors.contains {
                $0.signal == .restingHeartRate && $0.impact == .negative
            }
        )
    }

    func testLowHRVReducesScore() {
        let summary = evaluate(
            heartMetrics: [heartMetric(dayOffset: 0, kind: .heartRateVariabilitySDNN, value: 35)],
            baseline: baseline(hrv28d: 50)
        )

        XCTAssertLessThan(summary.score ?? 100, 70)
        XCTAssertTrue(
            summary.contributingFactors.contains {
                $0.signal == .hrv && $0.impact == .negative
            }
        )
    }

    func testOverreachingTrainingLoadReducesScore() {
        let summary = evaluate(
            workoutsLast7Days: [makeWorkout(dayOffset: -1, duration: 60)],
            trainingLoad: TrainingLoadSummary(
                status: .overreaching,
                todayLoad: 120,
                sevenDayLoad: 700,
                twentyEightDayAverageWeeklyLoad: 300,
                loadRatio: 2.0,
                workoutDays7d: 5,
                workoutDays28d: 12,
                explanation: "Load is well above your baseline.",
                confidence: .high,
                missingSignals: []
            )
        )

        XCTAssertLessThanOrEqual(summary.score ?? 100, 60)
        XCTAssertTrue(
            summary.contributingFactors.contains {
                $0.signal == .trainingLoad && $0.impact == .negative
            }
        )
    }

    func testMultipleNegativeSignalsProduceLowStatus() {
        let summary = evaluate(
            sleepRecords: [sleepRecord(wakeDayOffset: 0, asleepMinutes: 310)],
            heartMetrics: [
                heartMetric(dayOffset: 0, kind: .restingHeartRate, value: 72),
                heartMetric(dayOffset: 0, kind: .heartRateVariabilitySDNN, value: 34)
            ],
            workoutsLast7Days: workouts(onDays: [-1, -2, -3, -4]),
            trainingLoad: TrainingLoadSummary(
                status: .overreaching,
                todayLoad: 100,
                sevenDayLoad: 650,
                twentyEightDayAverageWeeklyLoad: 280,
                loadRatio: 2.1,
                workoutDays7d: 4,
                workoutDays28d: 10,
                explanation: "Load is well above your baseline.",
                confidence: .high,
                missingSignals: []
            ),
            baseline: baseline(sleep28d: 450, restingHR28d: 58, hrv28d: 50)
        )

        XCTAssertEqual(summary.status, .low)
        XCTAssertLessThan(summary.score ?? 100, 55)
    }

    func testHighConfidenceRequiresThreeReliableSignals() {
        let high = evaluate(
            sleepRecords: [sleepRecord(wakeDayOffset: 0, asleepMinutes: 470)],
            heartMetrics: [
                heartMetric(dayOffset: 0, kind: .restingHeartRate, value: 57),
                heartMetric(dayOffset: 0, kind: .heartRateVariabilitySDNN, value: 52)
            ],
            workoutsLast7Days: [makeWorkout(dayOffset: -1, duration: 45)],
            trainingLoad: normalTrainingLoad,
            baseline: baseline(sleep28d: 450, restingHR28d: 58, hrv28d: 50)
        )

        let low = evaluate(
            sleepRecords: [sleepRecord(wakeDayOffset: 0, asleepMinutes: 470)],
            baseline: baseline(sleep28d: 450)
        )

        XCTAssertEqual(high.confidence, .high)
        XCTAssertEqual(low.confidence, .low)
    }

    func testScoreIsQuantizedToNearestFive() {
        let summary = evaluate(
            sleepRecords: [sleepRecord(wakeDayOffset: 0, asleepMinutes: 300)],
            baseline: baseline(sleep28d: 450)
        )

        XCTAssertEqual(summary.score, 55)
    }

    func testPartialMissingSignalsAreTracked() {
        let summary = evaluate(
            heartMetrics: [heartMetric(dayOffset: 0, kind: .restingHeartRate, value: 59)],
            baseline: baseline(restingHR28d: 58)
        )

        XCTAssertTrue(summary.missingSignals.contains(.sleep))
        XCTAssertTrue(summary.missingSignals.contains(.hrv))
        XCTAssertEqual(summary.confidence, .low)
    }

    // MARK: - Helpers

    private var normalTrainingLoad: TrainingLoadSummary {
        TrainingLoadSummary(
            status: .normal,
            todayLoad: 60,
            sevenDayLoad: 240,
            twentyEightDayAverageWeeklyLoad: 220,
            loadRatio: 1.0,
            workoutDays7d: 3,
            workoutDays28d: 8,
            explanation: "Load is in line with your recent training pattern.",
            confidence: .high,
            missingSignals: []
        )
    }

    private func evaluate(
        todayMetrics: DailyHealthMetrics = .empty(for: .distantPast),
        yesterdayMetrics: DailyHealthMetrics = .empty(for: .distantPast),
        sleepRecords: [NormalizedSleepRecord] = [],
        heartMetrics: [NormalizedHeartMetric] = [],
        workoutsLast7Days: [NormalizedWorkout] = [],
        workoutsLast28Days: [NormalizedWorkout] = [],
        trainingLoad: TrainingLoadSummary = .unknown,
        baseline: HealthBaselineContext = .empty(for: .distantPast)
    ) -> RecoverySummary {
        let today = metrics(steps: todayMetrics.steps, energy: todayMetrics.activeEnergyKcal, date: targetDate)
        let yesterdayDay = calendar.date(byAdding: .day, value: -1, to: targetDate)!
        let yesterday = metrics(
            steps: yesterdayMetrics.steps,
            energy: yesterdayMetrics.activeEnergyKcal,
            date: yesterdayDay
        )

        return try! engine.evaluate(
            RecoveryEngineInput(
                targetDate: targetDate,
                todayMetrics: today,
                yesterdayMetrics: yesterday,
                sleepRecordsRecent: sleepRecords,
                heartMetricsRecent: heartMetrics,
                workoutsLast7Days: workoutsLast7Days,
                workoutsLast28Days: workoutsLast28Days.isEmpty ? workoutsLast7Days : workoutsLast28Days,
                trainingLoadSummary: trainingLoad,
                baselineContext: baseline,
                calendar: calendar
            )
        )
    }

    private func baseline(
        steps7d: Double? = nil,
        energy7d: Double? = nil,
        sleep28d: Double? = nil,
        restingHR28d: Double? = nil,
        hrv28d: Double? = nil
    ) -> HealthBaselineContext {
        HealthBaselineContext(
            targetDate: targetDate,
            averageSteps7d: steps7d,
            averageSteps28d: nil,
            averageActiveEnergy7d: energy7d,
            averageActiveEnergy28d: nil,
            averageSleepDuration7d: nil,
            averageSleepDuration28d: sleep28d,
            averageRestingHeartRate28d: restingHR28d,
            averageHRV28d: hrv28d,
            averageWorkoutLoad28d: nil,
            workoutDays7d: nil,
            workoutDays28d: nil,
            availableSignals: [],
            missingSignals: []
        )
    }

    private func metrics(
        steps: Int,
        energy: Double = 0,
        date: Date? = nil
    ) -> DailyHealthMetrics {
        DailyHealthMetrics(
            date: date ?? targetDate,
            steps: steps,
            activeEnergyKcal: energy,
            exerciseMinutes: 0
        )
    }

    private func makeDate(_ year: Int, _ month: Int, _ day: Int) -> Date {
        calendar.date(from: DateComponents(year: year, month: month, day: day))!
    }

    private func sleepRecord(wakeDayOffset: Int, asleepMinutes: Double) -> NormalizedSleepRecord {
        let wakeDay = calendar.date(byAdding: .day, value: wakeDayOffset, to: targetDate)!
        let start = calendar.date(byAdding: .hour, value: -8, to: wakeDay)!
        return NormalizedSleepRecord(
            id: UUID(),
            startDate: start,
            endDate: wakeDay,
            asleepMinutes: asleepMinutes,
            inBedMinutes: asleepMinutes + 20
        )
    }

    private func heartMetric(
        dayOffset: Int,
        kind: HealthHeartMetricKind,
        value: Double
    ) -> NormalizedHeartMetric {
        let day = calendar.date(byAdding: .day, value: dayOffset, to: targetDate)!
        return NormalizedHeartMetric(
            id: UUID(),
            kind: kind,
            date: day,
            value: value,
            unitSymbol: kind == .restingHeartRate ? "count/min" : "ms"
        )
    }

    private func makeWorkout(dayOffset: Int, duration: Int) -> NormalizedWorkout {
        let day = calendar.date(byAdding: .day, value: dayOffset, to: targetDate)!
        let start = calendar.date(byAdding: .hour, value: 7, to: day)!
        let end = calendar.date(byAdding: .minute, value: duration, to: start)!
        return NormalizedWorkout(
            id: UUID(),
            category: .running,
            activityLabel: "Running",
            startDate: start,
            endDate: end,
            durationMinutes: duration,
            activeEnergyKcal: 350,
            sourceName: nil
        )
    }

    private func workouts(onDays offsets: [Int]) -> [NormalizedWorkout] {
        offsets.map { makeWorkout(dayOffset: $0, duration: 45) }
    }
}
