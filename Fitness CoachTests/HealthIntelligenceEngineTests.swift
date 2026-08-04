//
//  HealthIntelligenceEngineTests.swift
//  Fitness CoachTests
//

import XCTest
@testable import Fitness_Coach

final class HealthIntelligenceEngineTests: XCTestCase {

    private var calendar: Calendar!
    private var repository: MockIntelligenceRepository!
    private var nutritionProvider: MockEngineNutritionProvider!
    private var engine: HealthIntelligenceEngine!

    override func setUp() {
        super.setUp()
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(secondsFromGMT: 0) ?? .gmt
        self.calendar = calendar
        self.repository = MockIntelligenceRepository(calendar: calendar)
        self.nutritionProvider = MockEngineNutritionProvider()
        let contextBuilder = HealthIntelligenceContextBuilder(
            repository: repository,
            nutritionProvider: nutritionProvider,
            weightProvider: EmptyHealthIntelligenceWeightProvider(),
            userPlanProvider: MockEngineUserPlanProvider(),
            clock: FixedEngineClock(
                now: makeDate(2026, 7, 3, hour: 12),
                calendar: calendar
            )
        )
        self.engine = HealthIntelligenceEngine(
            contextBuilder: contextBuilder,
            dependencies: .production()
        )
    }

    func testAllDataAvailableProducesEngineSummaries() async {
        let day = makeDate(2026, 7, 3)
        seedConnectedDay(day)
        nutritionProvider.todayLog = makeDailyLog(on: day, calories: 1_500, protein: 120)
        repository.workouts = [makeWorkout(on: day, duration: 45, label: "Strength training", category: .strength)]
        repository.sleepRecords = [
            NormalizedSleepRecord(
                id: UUID(),
                startDate: makeDate(2026, 7, 2, hour: 23),
                endDate: makeDate(2026, 7, 3, hour: 7),
                asleepMinutes: 480,
                inBedMinutes: 510
            )
        ]

        let snapshot = await engine.composeSnapshot(for: day, calendar: calendar)

        XCTAssertTrue(snapshot.workout?.hasWorkout == true)
        XCTAssertNotNil(snapshot.recovery.score)
        XCTAssertEqual(snapshot.activity.steps, 8_000)
        XCTAssertFalse(snapshot.nutritionAdjustment.shouldChangeTarget)
        XCTAssertNotEqual(snapshot.nextBestAction.id, "")
    }

    func testHealthKitUnavailableDegradesSafely() async {
        repository.availability = .unavailableSnapshot
        let day = makeDate(2026, 7, 3)

        let snapshot = await engine.composeSnapshot(for: day, calendar: calendar)

        XCTAssertEqual(snapshot.recovery.status, .unknown)
        XCTAssertNil(snapshot.workout)
        XCTAssertEqual(snapshot.activity, .empty)
        XCTAssertNil(snapshot.weeklyReview)
        XCTAssertEqual(snapshot.planConfidence, .unknown)
        XCTAssertEqual(snapshot.nextBestAction.reason, .connectHealth)
    }

    func testStepsAndWorkoutsOnlyStillCompose() async {
        let day = makeDate(2026, 7, 3)
        repository.availability = HealthDataAvailability(
            isHealthDataAvailable: true,
            permissionStatus: HealthPermissionStatus(
                isHealthDataAvailable: true,
                signalAccess: [
                    .stepCount: .available,
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
            cachedDayCount: 1
        )
        repository.dailyMetricsByDay[day] = DailyHealthMetrics(
            date: day,
            steps: 12_345,
            activeEnergyKcal: 500,
            exerciseMinutes: 40
        )
        repository.workouts = [
            makeWorkout(
                on: day,
                duration: 30,
                label: "Running",
                category: .running
            )
        ]

        let snapshot = await engine.composeSnapshot(for: day, calendar: calendar)

        XCTAssertEqual(snapshot.activity.steps, 12_345)
        XCTAssertNil(snapshot.activity.activeEnergyKcal)
        XCTAssertTrue(snapshot.workout?.hasWorkout == true)
        XCTAssertEqual(snapshot.recovery.status, .unknown)
    }

    func testMissingNutritionProviderLeavesNutritionUnavailable() async {
        let day = makeDate(2026, 7, 3)
        seedConnectedDay(day)

        let snapshot = await engine.composeSnapshot(for: day, calendar: calendar)

        XCTAssertTrue(snapshot.nutritionAdjustment.missingSignals.contains(.nutritionProgress))
        XCTAssertFalse(snapshot.nutritionAdjustment.shouldChangeTarget)
    }

    func testWorkoutTodayIncludedInSnapshot() async {
        let day = makeDate(2026, 7, 3)
        seedConnectedDay(day)
        repository.workouts = [
            makeWorkout(on: day, duration: 55, label: "Running", category: .running, hour: 7),
            makeWorkout(on: day, duration: 30, label: "Walking", category: .walking, hour: 18)
        ]

        let snapshot = await engine.composeSnapshot(for: day, calendar: calendar)

        XCTAssertEqual(snapshot.workout?.workoutCount, 2)
        XCTAssertEqual(snapshot.workout?.title, "Running + 1 more")
        XCTAssertEqual(snapshot.workout?.totalDurationMinutes, 85)
    }

    func testLowRecoveryWhenSleepIsPoor() async {
        let day = makeDate(2026, 7, 3)
        repository.availability = HealthDataAvailability(
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
                    .sleepAnalysis: .available,
                    .bodyMass: .denied
                ],
                resolvedAt: Date()
            ),
            cachedDayCount: 28
        )
        repository.dailyMetricsByDay[day] = DailyHealthMetrics(
            date: day,
            steps: 8_000,
            activeEnergyKcal: 400,
            exerciseMinutes: 35
        )
        repository.sleepRecords = [
            NormalizedSleepRecord(
                id: UUID(),
                startDate: makeDate(2026, 7, 2, hour: 23),
                endDate: makeDate(2026, 7, 3, hour: 5),
                asleepMinutes: 300,
                inBedMinutes: 360
            )
        ]

        let snapshot = await engine.composeSnapshot(for: day, calendar: calendar)

        XCTAssertLessThan(snapshot.recovery.score ?? 100, 70)
    }

    func testWeeklyReviewAvailableInWeeklyReviewMode() async {
        let day = makeDate(2026, 7, 7)
        repository.availability = .connectedSnapshot
        for offset in 0..<7 {
            let date = calendar.date(byAdding: .day, value: -offset, to: day)!
            repository.dailyMetricsByDay[date] = DailyHealthMetrics(
                date: date,
                steps: 6_000,
                activeEnergyKcal: 350,
                exerciseMinutes: 35
            )
            nutritionProvider.logsByDay[calendar.startOfDay(for: date)] = makeDailyLog(
                on: date,
                calories: 1_800,
                protein: 130
            )
        }

        let snapshot = await engine.composeSnapshot(
            for: day,
            calendar: calendar,
            mode: .weeklyReview
        )

        XCTAssertNotNil(snapshot.weeklyReview)
        XCTAssertFalse(snapshot.weeklyReview?.title.isEmpty == true)
    }

    func testTodayModeSkipsWeeklyReviewOnNonWeekEnd() async {
        let day = makeDate(2026, 7, 7)
        repository.availability = .connectedSnapshot
        for offset in 0..<7 {
            let date = calendar.date(byAdding: .day, value: -offset, to: day)!
            repository.dailyMetricsByDay[date] = DailyHealthMetrics(
                date: date,
                steps: 6_000,
                activeEnergyKcal: 350,
                exerciseMinutes: 35
            )
        }

        let snapshot = await engine.composeSnapshot(for: day, calendar: calendar, mode: .today)

        XCTAssertNil(snapshot.weeklyReview)
    }

    func testPreviewModeSkipsWeeklyReview() async {
        let day = makeDate(2026, 7, 11)
        seedWeek(of: day)

        let snapshot = await engine.composeSnapshot(for: day, calendar: calendar, mode: .preview)

        XCTAssertNil(snapshot.weeklyReview)
        XCTAssertNotNil(snapshot.recovery)
    }

    func testTrainingLoadFailureDegradesWithoutCrashing() async {
        let day = makeDate(2026, 7, 3)
        seedConnectedDay(day)
        let failingDependencies = HealthIntelligenceEngineDependencies(
            trainingLoad: FailingTrainingLoadProvider(),
            workout: WorkoutIntelligenceEngine(),
            recovery: FailingRecoveryProvider(),
            adaptiveNutrition: AdaptiveNutritionEngine(),
            nextBestAction: HealthNextBestActionEngine(),
            weeklyReview: WeeklyReviewEngine()
        )
        let failingEngine = HealthIntelligenceEngine(
            contextBuilder: HealthIntelligenceContextBuilder(repository: repository),
            dependencies: failingDependencies
        )

        let snapshot = await failingEngine.composeSnapshot(for: day, calendar: calendar)

        XCTAssertEqual(snapshot.activity.steps, 8_000)
        XCTAssertEqual(snapshot.recovery.status, .unknown)
        XCTAssertTrue(snapshot.workout?.hasWorkout != true)
    }

    func testComposeSnapshotIsDeterministicForSameInputs() async {
        let day = makeDate(2026, 7, 3)
        seedConnectedDay(day)
        repository.workouts = [
            makeWorkout(
                on: day,
                duration: 45,
                label: "Strength training",
                category: .strength,
                hour: 12,
                id: UUID(uuidString: "00000000-0000-0000-0000-0000000000AA")!
            )
        ]

        let first = await engine.composeSnapshot(for: day, calendar: calendar)
        let second = await engine.composeSnapshot(for: day, calendar: calendar)

        XCTAssertEqual(first, second)
    }

    func testComposeSnapshotWeeklyReviewNilWhenLessThanSevenDaysOfData() async {
        let day = makeDate(2026, 7, 7)
        repository.availability = .connectedSnapshot
        repository.weekMetrics = (0..<5).map { offset in
            let date = calendar.date(byAdding: .day, value: -offset, to: day)!
            return DailyHealthMetrics(date: date, steps: 5_000, activeEnergyKcal: 300, exerciseMinutes: 30)
        }

        let snapshot = await engine.composeSnapshot(for: day, calendar: calendar, mode: .weeklyReview)

        XCTAssertNil(snapshot.weeklyReview)
        XCTAssertEqual(snapshot.planConfidence.label, "Limited")
    }

    func testComposeSnapshotImprovesPlanConfidenceWithSevenDaysOfData() async {
        let day = makeDate(2026, 7, 11)
        seedWeek(of: day)

        let snapshot = await engine.composeSnapshot(for: day, calendar: calendar, mode: .weeklyReview)

        XCTAssertNotNil(snapshot.weeklyReview)
        XCTAssertEqual(snapshot.planConfidence.label, "Moderate")
        XCTAssertEqual(snapshot.planConfidence.score, 0.75)
    }

    // MARK: - Helpers

    private func seedConnectedDay(_ day: Date) {
        repository.availability = .connectedSnapshot
        repository.dailyMetricsByDay[day] = DailyHealthMetrics(
            date: day,
            steps: 8_000,
            activeEnergyKcal: 400,
            exerciseMinutes: 35
        )
    }

    private func seedWeek(of day: Date) {
        repository.availability = .connectedSnapshot
        for offset in 0..<7 {
            let date = calendar.date(byAdding: .day, value: -offset, to: day)!
            repository.dailyMetricsByDay[date] = DailyHealthMetrics(
                date: date,
                steps: 6_000,
                activeEnergyKcal: 350,
                exerciseMinutes: 35
            )
            nutritionProvider.logsByDay[calendar.startOfDay(for: date)] = makeDailyLog(
                on: date,
                calories: 1_800,
                protein: 130
            )
        }
    }

    private func makeDate(
        _ year: Int,
        _ month: Int,
        _ day: Int,
        hour: Int = 0
    ) -> Date {
        calendar.date(from: DateComponents(year: year, month: month, day: day, hour: hour))!
    }

    private func makeWorkout(
        on day: Date,
        duration: Int,
        label: String,
        category: FormaWorkoutCategory,
        hour: Int = 8,
        id: UUID = UUID()
    ) -> NormalizedWorkout {
        let start = makeDate(
            calendar.component(.year, from: day),
            calendar.component(.month, from: day),
            calendar.component(.day, from: day),
            hour: hour
        )
        return NormalizedWorkout(
            id: id,
            category: category,
            activityLabel: label,
            startDate: start,
            endDate: calendar.date(byAdding: .minute, value: duration, to: start) ?? start,
            durationMinutes: duration,
            activeEnergyKcal: 300,
            sourceName: "Apple Watch"
        )
    }

    private func makeDailyLog(on day: Date, calories: Int, protein: Double) -> DailyLog {
        DailyLog(
            id: UUID(),
            date: calendar.startOfDay(for: day),
            weightKg: nil,
            targets: UserTargets(
                calorieTarget: 2_200,
                proteinTarget: 150,
                carbTarget: 200,
                fatTarget: 70,
                waterTargetMl: 2_500,
                expectedWeeklyWeightLossKg: nil,
                aggressiveness: .moderate
            ),
            totals: MacroTotals(
                calories: calories,
                protein: protein,
                carbs: 150,
                fat: 50,
                fiber: 10,
                sodium: 1_500
            ),
            waterConsumedMl: 1_800,
            steps: nil,
            workoutCaloriesBurned: 0,
            dailyReviewId: nil,
            createdAt: day,
            updatedAt: day
        )
    }
}

// MARK: - Mocks

private struct FailingTrainingLoadProvider: TrainingLoadProviding {
    func evaluate(_ input: TrainingLoadEngineInput) throws -> TrainingLoadSummary {
        throw HealthIntelligenceEngineEvaluationError.simulatedFailure(.trainingLoad)
    }
}

private struct FailingRecoveryProvider: RecoveryEngineProviding {
    func evaluate(_ input: RecoveryEngineInput) throws -> RecoverySummary {
        throw HealthIntelligenceEngineEvaluationError.simulatedFailure(.recovery)
    }
}

private final class MockIntelligenceRepository: HealthDataRepositorying, @unchecked Sendable {

    let calendar: Calendar
    var availability: HealthDataAvailability = .connectedSnapshot
    var dailyMetricsByDay: [Date: DailyHealthMetrics] = [:]
    var workouts: [NormalizedWorkout] = []
    var weekMetrics: [DailyHealthMetrics] = []
    var sleepRecords: [NormalizedSleepRecord] = []

    init(calendar: Calendar) {
        self.calendar = calendar
    }

    func normalizedSamples(for date: Date, calendar: Calendar) async throws -> [HealthNormalizedSample] {
        []
    }

    func getDailyMetrics(for date: Date, calendar: Calendar) async -> DailyHealthMetrics {
        let day = calendar.startOfDay(for: date)
        return dailyMetricsByDay[day] ?? .empty(for: day)
    }

    func getDailyMetrics(
        from startDate: Date,
        to endDate: Date,
        calendar: Calendar
    ) async -> [DailyHealthMetrics] {
        if !weekMetrics.isEmpty {
            return weekMetrics.sorted { $0.date < $1.date }
        }

        let rangeStart = calendar.startOfDay(for: startDate)
        let rangeEnd = calendar.startOfDay(for: endDate)
        var metrics: [DailyHealthMetrics] = []
        var cursor = rangeStart
        while cursor <= rangeEnd {
            let day = calendar.startOfDay(for: cursor)
            metrics.append(dailyMetricsByDay[day] ?? .empty(for: day))
            guard let next = calendar.date(byAdding: .day, value: 1, to: cursor) else { break }
            cursor = next
        }
        return metrics
    }

    func getRecentWorkouts(days: Int, calendar: Calendar) async -> [NormalizedWorkout] { workouts }

    func getWorkouts(from startDate: Date, to endDate: Date, calendar: Calendar) async -> [NormalizedWorkout] { workouts }

    func getRecentSleep(days: Int, calendar: Calendar) async -> [NormalizedSleepRecord] { sleepRecords }

    func getSleepRecords(from startDate: Date, to endDate: Date, calendar: Calendar) async -> [NormalizedSleepRecord] {
        sleepRecords
    }

    func getRecentHeartMetrics(days: Int, calendar: Calendar) async -> [NormalizedHeartMetric] { [] }

    func getHeartMetrics(from startDate: Date, to endDate: Date, calendar: Calendar) async -> [NormalizedHeartMetric] {
        []
    }

    func getBodyMassHistory(days: Int, calendar: Calendar) async -> [NormalizedBodyMass] { [] }

    func getHealthDataAvailability() async -> HealthDataAvailability { availability }

    func refreshHealthData(days: Int, endingOn date: Date, calendar: Calendar) async -> HealthRefreshResult {
        HealthRefreshResult(daysRefreshed: days, refreshedAt: Date())
    }
}

private final class MockEngineNutritionProvider: HealthIntelligenceNutritionProviding, @unchecked Sendable {
    var todayLog: DailyLog?
    var logsByDay: [Date: DailyLog] = [:]

    func dailyLog(for date: Date, calendar: Calendar) async -> DailyLog? {
        todayLog ?? logsByDay[calendar.startOfDay(for: date)]
    }

    func dailyLogs(from startDate: Date, to endDate: Date, calendar: Calendar) async -> [DailyLog] {
        let start = calendar.startOfDay(for: startDate)
        let end = calendar.startOfDay(for: endDate)
        return logsByDay
            .filter { $0.key >= start && $0.key <= end }
            .map(\.value)
            .sorted { $0.date < $1.date }
    }
}

private final class MockEngineUserPlanProvider: HealthIntelligenceUserPlanProviding, @unchecked Sendable {
    func userPlan(referenceDate: Date) async -> HealthIntelligenceUserPlanSnapshot? {
        HealthIntelligenceUserPlanSnapshot(
            goal: .maintain,
            calorieTarget: 2_200,
            proteinTargetGrams: 150,
            waterTargetMl: 2_500
        )
    }
}

private struct FixedEngineClock: HealthIntelligenceClockProviding {
    let nowValue: Date
    let calendarValue: Calendar

    init(now: Date, calendar: Calendar) {
        self.nowValue = now
        self.calendarValue = calendar
    }

    func now() -> Date { nowValue }

    func calendar() -> Calendar { calendarValue }
}

private extension HealthDataAvailability {
    static var unavailableSnapshot: HealthDataAvailability {
        HealthDataAvailability(
            isHealthDataAvailable: false,
            permissionStatus: .unavailable(),
            cachedDayCount: 0
        )
    }

    static var connectedSnapshot: HealthDataAvailability {
        HealthDataAvailability(
            isHealthDataAvailable: true,
            permissionStatus: .uniform(.available, isHealthDataAvailable: true),
            cachedDayCount: 28
        )
    }
}
