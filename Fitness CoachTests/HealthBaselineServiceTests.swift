//
//  HealthBaselineServiceTests.swift
//  Fitness CoachTests
//

import XCTest
@testable import Fitness_Coach

final class HealthBaselineServiceTests: XCTestCase {

    private var calendar: Calendar!
    private var repository: MockBaselineRepository!
    private var service: HealthBaselineService!

    override func setUp() {
        super.setUp()
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(secondsFromGMT: 0) ?? .gmt
        self.calendar = calendar
        self.repository = MockBaselineRepository(calendar: calendar)
        self.service = HealthBaselineService(repository: repository)
    }

    func testBuildContextWithFullDataPopulatesAllBaselines() async {
        let target = makeDate(2026, 7, 8)
        repository.availability = .allSignalsAvailable
        repository.metrics = metricsRange(endingBefore: target, days: 28, steps: 8_000, energy: 400)
        repository.workouts = workouts(onDays: [1, 3, 5], endingBefore: target, duration: 45, energy: 300)
        repository.sleepRecords = sleepNights(
            endingBefore: target,
            nights: 20,
            asleepMinutes: 420
        )
        repository.heartMetrics = heartSamples(
            endingBefore: target,
            days: 20,
            restingHR: 58,
            hrv: 45
        )

        let context = await service.buildContext(for: target, calendar: calendar)

        XCTAssertEqual(context.targetDate, calendar.startOfDay(for: target))
        assertEqual(context.averageSteps7d, 8_000, accuracy: 0.01)
        assertEqual(context.averageSteps28d, 8_000, accuracy: 0.01)
        assertEqual(context.averageActiveEnergy7d, 400, accuracy: 0.01)
        assertEqual(context.averageActiveEnergy28d, 400, accuracy: 0.01)
        assertEqual(context.averageSleepDuration7d, 420, accuracy: 0.01)
        assertEqual(context.averageSleepDuration28d, 420, accuracy: 0.01)
        assertEqual(context.averageRestingHeartRate28d, 58, accuracy: 0.01)
        assertEqual(context.averageHRV28d, 45, accuracy: 0.01)
        XCTAssertNotNil(context.averageWorkoutLoad28d)
        XCTAssertEqual(context.workoutDays7d, 3)
        XCTAssertEqual(context.workoutDays28d, 3)
        XCTAssertTrue(context.availableSignals.contains(.steps))
        XCTAssertTrue(context.availableSignals.contains(.activeEnergy))
        XCTAssertTrue(context.availableSignals.contains(.sleep))
        XCTAssertTrue(context.availableSignals.contains(.restingHeartRate))
        XCTAssertTrue(context.availableSignals.contains(.hrv))
        XCTAssertTrue(context.availableSignals.contains(.workoutLoad))
        XCTAssertTrue(context.missingSignals.isEmpty)
    }

    func testBuildContextStepsOnlyExposesStepBaselines() async {
        let target = makeDate(2026, 7, 8)
        repository.availability = .stepsOnly
        repository.metrics = metricsRange(endingBefore: target, days: 28, steps: 10_000, energy: 500)

        let context = await service.buildContext(for: target, calendar: calendar)

        assertEqual(context.averageSteps7d, 10_000, accuracy: 0.01)
        assertEqual(context.averageSteps28d, 10_000, accuracy: 0.01)
        XCTAssertNil(context.averageActiveEnergy7d)
        XCTAssertNil(context.averageActiveEnergy28d)
        XCTAssertNil(context.averageSleepDuration7d)
        XCTAssertNil(context.averageSleepDuration28d)
        XCTAssertNil(context.averageRestingHeartRate28d)
        XCTAssertNil(context.averageHRV28d)
        XCTAssertNil(context.averageWorkoutLoad28d)
        XCTAssertNil(context.workoutDays7d)
        XCTAssertNil(context.workoutDays28d)
        XCTAssertEqual(context.availableSignals, [.steps])
        XCTAssertTrue(context.missingSignals.contains(.activeEnergy))
        XCTAssertTrue(context.missingSignals.contains(.sleep))
        XCTAssertTrue(context.missingSignals.contains(.restingHeartRate))
        XCTAssertTrue(context.missingSignals.contains(.hrv))
        XCTAssertTrue(context.missingSignals.contains(.workoutLoad))
    }

    func testBuildContextWorkoutsOnlyExposesWorkoutBaselines() async {
        let target = makeDate(2026, 7, 8)
        repository.availability = .workoutsOnly
        repository.metrics = metricsRange(endingBefore: target, days: 28, steps: 0, energy: 0)
        repository.workouts = workouts(onDays: [0, 2, 4, 6], endingBefore: target, duration: 60, energy: 400)

        let context = await service.buildContext(for: target, calendar: calendar)

        XCTAssertNil(context.averageSteps7d)
        XCTAssertNil(context.averageSteps28d)
        XCTAssertNil(context.averageActiveEnergy7d)
        XCTAssertNil(context.averageActiveEnergy28d)
        XCTAssertEqual(context.workoutDays7d, 4)
        XCTAssertEqual(context.workoutDays28d, 4)
        XCTAssertNotNil(context.averageWorkoutLoad28d)
        XCTAssertGreaterThan(context.averageWorkoutLoad28d ?? 0, 0)
        XCTAssertEqual(context.availableSignals, [.workoutLoad])
        XCTAssertTrue(context.missingSignals.contains(.steps))
        XCTAssertTrue(context.missingSignals.contains(.activeEnergy))
    }

    func testBuildContextWithoutSleepOrHRVLeavesThoseBaselinesNil() async {
        let target = makeDate(2026, 7, 8)
        repository.availability = .activityWithoutRecoverySignals
        repository.metrics = metricsRange(endingBefore: target, days: 28, steps: 7_500, energy: 350)
        repository.workouts = workouts(onDays: [1], endingBefore: target, duration: 30, energy: 200)

        let context = await service.buildContext(for: target, calendar: calendar)

        XCTAssertNotNil(context.averageSteps28d)
        XCTAssertNil(context.averageSleepDuration7d)
        XCTAssertNil(context.averageSleepDuration28d)
        XCTAssertNil(context.averageRestingHeartRate28d)
        XCTAssertNil(context.averageHRV28d)
        XCTAssertTrue(context.missingSignals.contains(.sleep))
        XCTAssertTrue(context.missingSignals.contains(.restingHeartRate))
        XCTAssertTrue(context.missingSignals.contains(.hrv))
    }

    func testBuildContextWithLessThanSevenDaysLeavesSevenDayBaselinesNil() async {
        let target = makeDate(2026, 7, 8)
        repository.availability = .allSignalsAvailable
        repository.metrics = metricsRange(endingBefore: target, days: 5, steps: 6_000, energy: 300)
        repository.workouts = workouts(onDays: [0, 2], endingBefore: target, duration: 40, energy: 250)
        repository.sleepRecords = sleepNights(endingBefore: target, nights: 4, asleepMinutes: 390)

        let context = await service.buildContext(for: target, calendar: calendar)

        XCTAssertNil(context.averageSteps7d)
        XCTAssertNil(context.averageSteps28d)
        XCTAssertNil(context.averageActiveEnergy7d)
        XCTAssertNil(context.averageActiveEnergy28d)
        XCTAssertNil(context.averageSleepDuration7d)
        XCTAssertNil(context.averageSleepDuration28d)
        XCTAssertNil(context.workoutDays7d)
        XCTAssertNil(context.workoutDays28d)
        XCTAssertNil(context.averageWorkoutLoad28d)
    }

    func testBuildContextWithLessThanTwentyEightDaysLeavesTwentyEightDayBaselinesNil() async {
        let target = makeDate(2026, 7, 8)
        repository.availability = .allSignalsAvailable
        repository.metrics = metricsRange(endingBefore: target, days: 20, steps: 9_000, energy: 420)
        repository.workouts = workouts(onDays: [1, 4, 8], endingBefore: target, duration: 50, energy: 320)
        repository.sleepRecords = sleepNights(endingBefore: target, nights: 16, asleepMinutes: 410)
        repository.heartMetrics = heartSamples(
            endingBefore: target,
            days: 16,
            restingHR: 60,
            hrv: 42
        )

        let context = await service.buildContext(for: target, calendar: calendar)

        assertEqual(context.averageSteps7d, 9_000, accuracy: 0.01)
        XCTAssertNil(context.averageSteps28d)
        assertEqual(context.averageActiveEnergy7d, 420, accuracy: 0.01)
        XCTAssertNil(context.averageActiveEnergy28d)
        XCTAssertNotNil(context.averageSleepDuration7d)
        XCTAssertNil(context.averageSleepDuration28d)
        XCTAssertNil(context.averageRestingHeartRate28d)
        XCTAssertNil(context.averageHRV28d)
        XCTAssertEqual(context.workoutDays7d, 2)
        XCTAssertNil(context.workoutDays28d)
        XCTAssertNil(context.averageWorkoutLoad28d)
    }

    func testLookbackWindowExcludesTargetDate() {
        let target = makeDate(2026, 7, 8)
        let window = HealthBaselineService.lookbackWindow(
            endingBefore: calendar.startOfDay(for: target),
            days: 7,
            calendar: calendar
        )

        XCTAssertEqual(window?.start, makeDate(2026, 7, 1))
        XCTAssertEqual(window?.end, makeDate(2026, 7, 7))
    }

    // MARK: - Helpers

    private func assertEqual(_ value: Double?, _ expected: Double, accuracy: Double, file: StaticString = #filePath, line: UInt = #line) {
        guard let value else {
            XCTFail("Expected \(expected) but value was nil", file: file, line: line)
            return
        }
        XCTAssertEqual(value, expected, accuracy: accuracy, file: file, line: line)
    }

    // MARK: - Date helpers

    private func makeDate(_ year: Int, _ month: Int, _ day: Int) -> Date {
        calendar.date(from: DateComponents(year: year, month: month, day: day))!
    }

    private func metricsRange(
        endingBefore target: Date,
        days: Int,
        steps: Int,
        energy: Double
    ) -> [DailyHealthMetrics] {
        guard let window = HealthBaselineService.lookbackWindow(
            endingBefore: calendar.startOfDay(for: target),
            days: days,
            calendar: calendar
        ) else {
            return []
        }

        return HealthBaselineService.days(in: window, calendar: calendar).map { day in
            DailyHealthMetrics(
                date: day,
                steps: steps,
                activeEnergyKcal: energy,
                exerciseMinutes: 30
            )
        }
    }

    private func workouts(
        onDays offsets: [Int],
        endingBefore target: Date,
        duration: Int,
        energy: Double
    ) -> [NormalizedWorkout] {
        guard let window7 = HealthBaselineService.lookbackWindow(
            endingBefore: calendar.startOfDay(for: target),
            days: 7,
            calendar: calendar
        ) else {
            return []
        }

        let days = HealthBaselineService.days(in: window7, calendar: calendar)
        return offsets.compactMap { offset in
            guard offset < days.count else { return nil }
            let day = days[offset]
            let start = calendar.date(byAdding: .hour, value: 7, to: day)!
            let end = calendar.date(byAdding: .minute, value: duration, to: start)!
            return NormalizedWorkout(
                id: UUID(),
                category: .running,
                activityLabel: "Running",
                startDate: start,
                endDate: end,
                durationMinutes: duration,
                activeEnergyKcal: energy,
                sourceName: nil
            )
        }
    }

    private func sleepNights(
        endingBefore target: Date,
        nights: Int,
        asleepMinutes: Double
    ) -> [NormalizedSleepRecord] {
        guard let window = HealthBaselineService.lookbackWindow(
            endingBefore: calendar.startOfDay(for: target),
            days: 28,
            calendar: calendar
        ) else {
            return []
        }

        let days = HealthBaselineService.days(in: window, calendar: calendar).suffix(nights)
        return days.map { wakeDay in
            let start = calendar.date(byAdding: .hour, value: -8, to: wakeDay)!
            NormalizedSleepRecord(
                id: UUID(),
                startDate: start,
                endDate: wakeDay,
                asleepMinutes: asleepMinutes,
                inBedMinutes: asleepMinutes + 30
            )
        }
    }

    private func heartSamples(
        endingBefore target: Date,
        days: Int,
        restingHR: Double,
        hrv: Double
    ) -> [NormalizedHeartMetric] {
        guard let window = HealthBaselineService.lookbackWindow(
            endingBefore: calendar.startOfDay(for: target),
            days: 28,
            calendar: calendar
        ) else {
            return []
        }

        let sampleDays = HealthBaselineService.days(in: window, calendar: calendar).suffix(days)
        return sampleDays.flatMap { day -> [NormalizedHeartMetric] in
            [
                NormalizedHeartMetric(
                    id: UUID(),
                    kind: .restingHeartRate,
                    date: day,
                    value: restingHR,
                    unitSymbol: "count/min"
                ),
                NormalizedHeartMetric(
                    id: UUID(),
                    kind: .heartRateVariabilitySDNN,
                    date: day,
                    value: hrv,
                    unitSymbol: "ms"
                )
            ]
        }
    }
}

// MARK: - Mock repository

private final class MockBaselineRepository: HealthDataRepositorying, @unchecked Sendable {

    let calendar: Calendar
    var availability: HealthDataAvailability = .allSignalsAvailable
    var metrics: [DailyHealthMetrics] = []
    var workouts: [NormalizedWorkout] = []
    var sleepRecords: [NormalizedSleepRecord] = []
    var heartMetrics: [NormalizedHeartMetric] = []

    init(calendar: Calendar) {
        self.calendar = calendar
    }

    func normalizedSamples(for date: Date, calendar: Calendar) async throws -> [HealthNormalizedSample] {
        []
    }

    func getDailyMetrics(for date: Date, calendar: Calendar) async -> DailyHealthMetrics {
        let day = calendar.startOfDay(for: date)
        return metrics.first { calendar.isDate($0.date, inSameDayAs: day) }
            ?? .empty(for: day)
    }

    func getDailyMetrics(
        from startDate: Date,
        to endDate: Date,
        calendar: Calendar
    ) async -> [DailyHealthMetrics] {
        let start = calendar.startOfDay(for: startDate)
        let end = calendar.startOfDay(for: endDate)
        return metrics
            .filter { metric in
                let day = calendar.startOfDay(for: metric.date)
                return day >= start && day <= end
            }
            .sorted { $0.date < $1.date }
    }

    func getRecentWorkouts(days: Int, calendar: Calendar) async -> [NormalizedWorkout] {
        workouts
    }

    func getWorkouts(from startDate: Date, to endDate: Date, calendar: Calendar) async -> [NormalizedWorkout] {
        let start = calendar.startOfDay(for: startDate)
        let end = calendar.startOfDay(for: endDate)
        return workouts.filter { workout in
            let day = calendar.startOfDay(for: workout.startDate)
            return day >= start && day <= end
        }
    }

    func getRecentSleep(days: Int, calendar: Calendar) async -> [NormalizedSleepRecord] {
        sleepRecords
    }

    func getSleepRecords(
        from startDate: Date,
        to endDate: Date,
        calendar: Calendar
    ) async -> [NormalizedSleepRecord] {
        let start = calendar.startOfDay(for: startDate)
        let end = calendar.startOfDay(for: endDate)
        return sleepRecords.filter { record in
            let wakeDay = calendar.startOfDay(for: record.endDate)
            return wakeDay >= start && wakeDay <= end
        }
    }

    func getRecentHeartMetrics(days: Int, calendar: Calendar) async -> [NormalizedHeartMetric] {
        heartMetrics
    }

    func getHeartMetrics(
        from startDate: Date,
        to endDate: Date,
        calendar: Calendar
    ) async -> [NormalizedHeartMetric] {
        let start = calendar.startOfDay(for: startDate)
        let end = calendar.startOfDay(for: endDate)
        return heartMetrics.filter { metric in
            let day = calendar.startOfDay(for: metric.date)
            return day >= start && day <= end
        }
    }

    func getBodyMassHistory(days: Int, calendar: Calendar) async -> [NormalizedBodyMass] {
        []
    }

    func getHealthDataAvailability() async -> HealthDataAvailability {
        availability
    }

    func refreshHealthData(days: Int, endingOn date: Date, calendar: Calendar) async -> HealthRefreshResult {
        HealthRefreshResult(daysRefreshed: days, refreshedAt: Date())
    }
}

private extension HealthDataAvailability {
    static var allSignalsAvailable: HealthDataAvailability {
        HealthDataAvailability(
            isHealthDataAvailable: true,
            permissionStatus: .uniform(.available, isHealthDataAvailable: true),
            cachedDayCount: 28
        )
    }

    static var stepsOnly: HealthDataAvailability {
        HealthDataAvailability(
            isHealthDataAvailable: true,
            permissionStatus: HealthPermissionStatus(
                isHealthDataAvailable: true,
                signalAccess: [
                    .stepCount: .available,
                    .activeEnergyBurned: .denied,
                    .appleExerciseTime: .denied,
                    .workout: .denied,
                    .restingHeartRate: .denied,
                    .heartRateVariabilitySDNN: .denied,
                    .sleepAnalysis: .denied,
                    .bodyMass: .denied
                ],
                resolvedAt: Date()
            ),
            cachedDayCount: 28
        )
    }

    static var workoutsOnly: HealthDataAvailability {
        HealthDataAvailability(
            isHealthDataAvailable: true,
            permissionStatus: HealthPermissionStatus(
                isHealthDataAvailable: true,
                signalAccess: [
                    .stepCount: .denied,
                    .activeEnergyBurned: .denied,
                    .appleExerciseTime: .denied,
                    .workout: .available,
                    .restingHeartRate: .denied,
                    .heartRateVariabilitySDNN: .denied,
                    .sleepAnalysis: .denied,
                    .bodyMass: .denied
                ],
                resolvedAt: Date()
            ),
            cachedDayCount: 28
        )
    }

    static var activityWithoutRecoverySignals: HealthDataAvailability {
        HealthDataAvailability(
            isHealthDataAvailable: true,
            permissionStatus: HealthPermissionStatus(
                isHealthDataAvailable: true,
                signalAccess: [
                    .stepCount: .available,
                    .activeEnergyBurned: .available,
                    .appleExerciseTime: .available,
                    .workout: .available,
                    .restingHeartRate: .denied,
                    .heartRateVariabilitySDNN: .denied,
                    .sleepAnalysis: .denied,
                    .bodyMass: .available
                ],
                resolvedAt: Date()
            ),
            cachedDayCount: 28
        )
    }
}
