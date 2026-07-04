//
//  HealthSampleNormalizerTests.swift
//  Fitness CoachTests
//

import XCTest
@testable import Fitness_Coach

final class HealthSampleNormalizerTests: XCTestCase {

    private let normalizer = HealthSampleNormalizer()
    private var calendar: Calendar!

    override func setUp() {
        super.setUp()
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(secondsFromGMT: 0) ?? .gmt
        self.calendar = calendar
    }

    // MARK: - Daily metrics

    func testNormalizeDailyMetricsUsesSafeDefaultsForMissingValues() {
        let day = makeDate(2026, 7, 3)
        let raw = HealthDailyMetrics(date: day, steps: nil, activeEnergyKcal: nil, exerciseMinutes: nil)

        let metrics = normalizer.normalizeDailyMetrics(raw, calendar: calendar)

        XCTAssertEqual(metrics.date, day)
        XCTAssertEqual(metrics.steps, 0)
        XCTAssertEqual(metrics.activeEnergyKcal, 0)
        XCTAssertEqual(metrics.exerciseMinutes, 0)
    }

    func testNormalizeDailyMetricsPreservesProvidedValues() {
        let day = makeDate(2026, 7, 3)
        let raw = HealthDailyMetrics(date: day, steps: 8_432, activeEnergyKcal: 515.4, exerciseMinutes: 42)

        let metrics = normalizer.normalizeDailyMetrics(raw, calendar: calendar)

        XCTAssertEqual(metrics.steps, 8_432)
        XCTAssertEqual(metrics.activeEnergyKcal, 515.4)
        XCTAssertEqual(metrics.exerciseMinutes, 42)
    }

    // MARK: - Workout categories

    func testWorkoutCategoryMapping() {
        XCTAssertEqual(HealthWorkoutCategoryMapping.category(for: "Strength training"), .strength)
        XCTAssertEqual(HealthWorkoutCategoryMapping.category(for: "Running"), .running)
        XCTAssertEqual(HealthWorkoutCategoryMapping.category(for: "Walking"), .walking)
        XCTAssertEqual(HealthWorkoutCategoryMapping.category(for: "Cycling"), .cycling)
        XCTAssertEqual(HealthWorkoutCategoryMapping.category(for: "Swimming"), .swimming)
        XCTAssertEqual(HealthWorkoutCategoryMapping.category(for: "Yoga"), .yoga)
        XCTAssertEqual(HealthWorkoutCategoryMapping.category(for: "HIIT"), .hiit)
        XCTAssertEqual(HealthWorkoutCategoryMapping.category(for: "Mixed cardio"), .other)
    }

    func testNormalizeWorkoutMapsCategoryEnergyAndStableID() {
        let start = makeDate(2026, 7, 3, hour: 8)
        let end = makeDate(2026, 7, 3, hour: 9)
        let raw = HealthFetchedWorkout(
            id: UUID(),
            activityTypeName: "Running",
            startDate: start,
            endDate: end,
            durationMinutes: 60,
            activeCaloriesKcal: 420,
            sourceName: "Apple Watch"
        )

        let workout = normalizer.normalizeWorkout(raw)
        let duplicate = normalizer.normalizeWorkout(raw)

        XCTAssertEqual(workout.category, .running)
        XCTAssertEqual(workout.activeEnergyKcal, 420)
        XCTAssertEqual(workout.durationMinutes, 60)
        XCTAssertEqual(workout.sourceName, "Apple Watch")
        XCTAssertEqual(workout.id, duplicate.id)
    }

    func testNormalizeWorkoutsDeduplicatesByStableID() {
        let start = makeDate(2026, 7, 3, hour: 8)
        let end = makeDate(2026, 7, 3, hour: 9)
        let lowEnergy = HealthFetchedWorkout(
            id: UUID(),
            activityTypeName: "Running",
            startDate: start,
            endDate: end,
            durationMinutes: 60,
            activeCaloriesKcal: 300,
            sourceName: "Apple Watch"
        )
        let highEnergy = HealthFetchedWorkout(
            id: UUID(),
            activityTypeName: "Running",
            startDate: start,
            endDate: end,
            durationMinutes: 60,
            activeCaloriesKcal: 450,
            sourceName: "Apple Watch"
        )

        let workouts = normalizer.normalizeWorkouts([lowEnergy, highEnergy])

        XCTAssertEqual(workouts.count, 1)
        XCTAssertEqual(workouts.first?.activeEnergyKcal, 450)
    }

    // MARK: - Unit normalization

    func testQuantityNormalizationConvertsUnits() {
        XCTAssertEqual(
            HealthQuantityNormalization.kilocalories(value: 1_500, unitSymbol: "cal"),
            1.5,
            accuracy: 0.001
        )
        XCTAssertEqual(
            HealthQuantityNormalization.minutes(value: 120, unitSymbol: "s"),
            2,
            accuracy: 0.001
        )
        XCTAssertEqual(
            HealthQuantityNormalization.kilograms(value: 1_500, unitSymbol: "g"),
            1.5,
            accuracy: 0.001
        )
        XCTAssertEqual(
            HealthQuantityNormalization.beatsPerMinute(value: 1, unitSymbol: "hz"),
            60,
            accuracy: 0.001
        )
        XCTAssertEqual(
            HealthQuantityNormalization.milliseconds(value: 2, unitSymbol: "s"),
            2_000,
            accuracy: 0.001
        )
    }

    // MARK: - Heart metrics

    func testNormalizeHeartMetricNormalizesUnits() {
        let date = makeDate(2026, 7, 3, hour: 7)
        let resting = HealthHeartMetric(
            id: UUID(),
            kind: .restingHeartRate,
            date: date,
            value: 58,
            unitSymbol: "bpm"
        )
        let hrv = HealthHeartMetric(
            id: UUID(),
            kind: .heartRateVariabilitySDNN,
            date: date,
            value: 42,
            unitSymbol: "ms"
        )

        let normalizedResting = normalizer.normalizeHeartMetric(resting)
        let normalizedHRV = normalizer.normalizeHeartMetric(hrv)

        XCTAssertEqual(normalizedResting.unitSymbol, HealthUnitSymbol.beatsPerMinute)
        XCTAssertEqual(normalizedResting.value, 58)
        XCTAssertEqual(normalizedHRV.unitSymbol, HealthUnitSymbol.milliseconds)
        XCTAssertEqual(normalizedHRV.value, 42)
    }

    // MARK: - Sleep

    func testNormalizeSleepRecordConvertsDurationToMinutes() {
        let start = makeDate(2026, 7, 3, hour: 23)
        let end = makeDate(2026, 7, 4, hour: 7)
        let raw = HealthSleepRecord(
            id: UUID(),
            startDate: start,
            endDate: end,
            asleepDuration: 6 * 3_600,
            inBedDuration: 7 * 3_600
        )

        let sleep = normalizer.normalizeSleepRecord(raw)

        XCTAssertEqual(sleep.asleepMinutes, 360, accuracy: 0.01)
        XCTAssertEqual(sleep.inBedMinutes ?? 0, 420, accuracy: 0.01)
    }

    // MARK: - Day bundle

    func testNormalizeDayBundleTransformsAllSignals() {
        let day = makeDate(2026, 7, 3)
        let input = HealthRawDayInput(
            dailyMetrics: HealthDailyMetrics(date: day, steps: 10_000, activeEnergyKcal: 600, exerciseMinutes: 45),
            workouts: [
                HealthFetchedWorkout(
                    id: UUID(),
                    activityTypeName: "HIIT",
                    startDate: makeDate(2026, 7, 3, hour: 18),
                    endDate: makeDate(2026, 7, 3, hour: 18, minute: 30),
                    durationMinutes: 30,
                    activeCaloriesKcal: 250,
                    sourceName: "Apple Watch"
                )
            ],
            sleepRecords: [],
            heartMetrics: [],
            bodyMassRecords: [
                HealthBodyMassRecord(id: UUID(), date: day, valueKg: 72.4)
            ]
        )

        let bundle = normalizer.normalize(day: input, calendar: calendar)

        XCTAssertEqual(bundle.dailyMetrics.steps, 10_000)
        XCTAssertEqual(bundle.workouts.count, 1)
        XCTAssertEqual(bundle.workouts.first?.category, .hiit)
        XCTAssertEqual(bundle.bodyMassRecords.first?.valueKg ?? 0, 72.4, accuracy: 0.001)
    }

    func testNormalizeWorkoutUsesMinimumDurationWhenZero() {
        let start = makeDate(2026, 7, 3, hour: 8)
        let end = makeDate(2026, 7, 3, hour: 8, minute: 5)
        let raw = HealthFetchedWorkout(
            id: UUID(),
            activityTypeName: "Walking",
            startDate: start,
            endDate: end,
            durationMinutes: 0,
            activeCaloriesKcal: nil,
            sourceName: nil
        )

        let workout = normalizer.normalizeWorkout(raw)

        XCTAssertEqual(workout.durationMinutes, 1)
        XCTAssertEqual(workout.activeEnergyKcal, 0)
        XCTAssertEqual(workout.sourceName, nil)
    }

    func testNormalizeBodyMassHandlesMissingUnitConversion() {
        let day = makeDate(2026, 7, 3)
        let record = normalizer.normalizeBodyMassRecord(
            HealthBodyMassRecord(id: UUID(), date: day, valueKg: 72.4)
        )

        XCTAssertEqual(record.valueKg, 72.4, accuracy: 0.001)
    }

    // MARK: - Sample deduplication

    func testDeduplicateSamplesRemovesExactDuplicates() {
        let start = makeDate(2026, 7, 3)
        let end = makeDate(2026, 7, 4)
        let sample = HealthNormalizedSample(
            kind: .stepCount,
            startDate: start,
            endDate: end,
            value: 8_000,
            unitSymbol: HealthUnitSymbol.count
        )

        let deduped = normalizer.deduplicate(samples: [sample, sample])

        XCTAssertEqual(deduped.count, 1)
        XCTAssertEqual(deduped.first?.value, 8_000)
    }

    // MARK: - Helpers

    private func makeDate(
        _ year: Int,
        _ month: Int,
        _ day: Int,
        hour: Int = 0,
        minute: Int = 0
    ) -> Date {
        calendar.date(from: DateComponents(
            calendar: calendar,
            year: year,
            month: month,
            day: day,
            hour: hour,
            minute: minute
        )) ?? Date(timeIntervalSince1970: 0)
    }
}

final class HealthStableIdentifierTests: XCTestCase {

    func testWorkoutStableIDIsDeterministic() {
        let start = Date(timeIntervalSince1970: 1_000)
        let end = Date(timeIntervalSince1970: 2_000)

        let first = HealthStableIdentifier.workoutID(
            sourceName: "Apple Watch",
            startDate: start,
            endDate: end,
            durationMinutes: 30,
            category: .running
        )
        let second = HealthStableIdentifier.workoutID(
            sourceName: "Apple Watch",
            startDate: start,
            endDate: end,
            durationMinutes: 30,
            category: .running
        )
        let different = HealthStableIdentifier.workoutID(
            sourceName: "Apple Watch",
            startDate: start,
            endDate: end,
            durationMinutes: 31,
            category: .running
        )

        XCTAssertEqual(first, second)
        XCTAssertNotEqual(first, different)
    }

    func testWorkoutStableIDChangesWhenSourceChanges() {
        let start = Date(timeIntervalSince1970: 1_000)
        let end = Date(timeIntervalSince1970: 2_000)

        let appleWatch = HealthStableIdentifier.workoutID(
            sourceName: "Apple Watch",
            startDate: start,
            endDate: end,
            durationMinutes: 30,
            category: .running
        )
        let iPhone = HealthStableIdentifier.workoutID(
            sourceName: "iPhone",
            startDate: start,
            endDate: end,
            durationMinutes: 30,
            category: .running
        )

        XCTAssertNotEqual(appleWatch, iPhone)
    }
}
