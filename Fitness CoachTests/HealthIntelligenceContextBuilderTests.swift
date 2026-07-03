//
//  HealthIntelligenceContextBuilderTests.swift
//  Fitness CoachTests
//

import XCTest
@testable import Fitness_Coach

final class HealthIntelligenceContextBuilderTests: XCTestCase {

    private var calendar: Calendar!
    private var repository: MockContextRepository!
    private var nutritionProvider: MockNutritionProvider!
    private var weightProvider: MockWeightProvider!
    private var userPlanProvider: MockUserPlanProvider!
    private var clock: FixedContextClock!
    private var builder: HealthIntelligenceContextBuilder!

    override func setUp() {
        super.setUp()
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(secondsFromGMT: 0) ?? .gmt
        self.calendar = calendar
        self.repository = MockContextRepository(calendar: calendar)
        self.nutritionProvider = MockNutritionProvider()
        self.weightProvider = MockWeightProvider()
        self.userPlanProvider = MockUserPlanProvider()
        self.clock = FixedContextClock(
            now: makeDate(2026, 7, 8, hour: 14),
            calendar: calendar
        )
        self.builder = HealthIntelligenceContextBuilder(
            repository: repository,
            nutritionProvider: nutritionProvider,
            weightProvider: weightProvider,
            userPlanProvider: userPlanProvider,
            clock: clock
        )
    }

    func testBuildsTrainingLoadAndWorkoutInputsFromSharedFetch() async {
        let day = makeDate(2026, 7, 8)
        repository.dailyMetricsByDay[day] = metrics(day: day, steps: 8_000)
        repository.workouts = [
            makeWorkout(on: day, duration: 45),
            makeWorkout(on: makeDate(2026, 7, 7), duration: 30)
        ]

        let context = await builder.buildContext(for: day, calendar: calendar)

        XCTAssertEqual(context.trainingLoadInput.workoutsToday.count, 1)
        XCTAssertEqual(context.trainingLoadInput.workoutsLast7Days.count, 2)
        XCTAssertEqual(context.workoutIntelligenceInput.workoutsToday.count, 1)
        XCTAssertTrue(context.summaries.workout.hasWorkout)
        XCTAssertEqual(repository.getDailyMetricsCallCount, 1)
        XCTAssertEqual(repository.getWorkoutsCallCount, 1)
    }

    func testBuildsAdaptiveNutritionAndNextBestActionInputs() async {
        let day = makeDate(2026, 7, 8)
        repository.dailyMetricsByDay[day] = metrics(day: day, steps: 6_000)
        nutritionProvider.todayLog = makeDailyLog(on: day, calories: 1_200, protein: 90)
        userPlanProvider.plan = HealthIntelligenceUserPlanSnapshot(
            goal: .loseFat,
            calorieTarget: 2_200,
            proteinTargetGrams: 150,
            waterTargetMl: 2_500
        )
        weightProvider.hasRecentWeight = true

        let context = await builder.buildContext(for: day, calendar: calendar)

        XCTAssertEqual(context.adaptiveNutritionInput.nutritionProgress.caloriesConsumed, 1_200)
        XCTAssertEqual(context.nextBestActionInput.nutritionProgress.proteinConsumedGrams, 90)
        XCTAssertTrue(context.nextBestActionInput.hasLoggedWeightRecently)
        XCTAssertFalse(context.dataGaps.contains(.nutritionUnavailable))
        XCTAssertFalse(context.dataGaps.contains(.userPlanUnavailable))
    }

    func testMissingNutritionAndPlanProduceDataGaps() async {
        let day = makeDate(2026, 7, 8)
        repository.dailyMetricsByDay[day] = metrics(day: day, steps: 4_000)

        let context = await builder.buildContext(for: day, calendar: calendar)

        XCTAssertTrue(context.dataGaps.contains(.nutritionUnavailable))
        XCTAssertTrue(context.dataGaps.contains(.userPlanUnavailable))
        XCTAssertTrue(context.dataGaps.contains(.weightUnavailable))
        XCTAssertEqual(context.adaptiveNutritionInput.nutritionProgress, .unavailable)
    }

    func testWeeklyReviewInputBuiltWhenSevenActiveDaysExist() async {
        let day = makeDate(2026, 7, 8)
        for offset in 0..<7 {
            let date = calendar.date(byAdding: .day, value: -offset, to: day)!
            repository.dailyMetricsByDay[date] = metrics(day: date, steps: 7_000)
            nutritionProvider.logsByDay[calendar.startOfDay(for: date)] = makeDailyLog(
                on: date,
                calories: 1_800,
                protein: 130
            )
        }
        userPlanProvider.plan = HealthIntelligenceUserPlanSnapshot(
            goal: .maintain,
            calorieTarget: 2_200,
            proteinTargetGrams: 150,
            waterTargetMl: 2_500
        )
        weightProvider.entries = [
            WeightEntry(
                id: UUID(),
                date: makeDate(2026, 7, 2),
                weightKg: 80,
                note: nil,
                createdAt: makeDate(2026, 7, 2)
            ),
            WeightEntry(
                id: UUID(),
                date: day,
                weightKg: 79.8,
                note: nil,
                createdAt: day
            )
        ]

        let context = await builder.buildContext(for: day, calendar: calendar)

        XCTAssertNotNil(context.weeklyReviewInput)
        XCTAssertEqual(context.weeklyReviewInput?.nutritionDailySummaries.count, 7)
        XCTAssertEqual(context.weeklyReviewInput?.weightRecords.count, 2)
        XCTAssertEqual(context.metricsLast7Days.count, 7)
    }

    func testNormalizedSampleFailureRecordsGapWithoutThrowing() async {
        let day = makeDate(2026, 7, 8)
        repository.dailyMetricsByDay[day] = metrics(day: day, steps: 5_000)
        repository.normalizedSamplesError = HealthDataRepositoryError.unavailable

        let context = await builder.buildContext(for: day, calendar: calendar)

        XCTAssertTrue(context.dataGaps.contains(.normalizedSamplesFailed))
        XCTAssertTrue(context.normalizedSamples.isEmpty)
    }

    func testDeterministicForSameInputs() async {
        let day = makeDate(2026, 7, 8)
        repository.dailyMetricsByDay[day] = metrics(day: day, steps: 7_500)
        repository.workouts = [makeWorkout(on: day, duration: 40)]
        nutritionProvider.todayLog = makeDailyLog(on: day, calories: 1_500, protein: 120)
        userPlanProvider.plan = HealthIntelligenceUserPlanSnapshot(
            goal: .maintain,
            calorieTarget: 2_200,
            proteinTargetGrams: 150,
            waterTargetMl: 2_500
        )

        let first = await builder.buildContext(for: day, calendar: calendar)
        let second = await builder.buildContext(for: day, calendar: calendar)

        XCTAssertEqual(first, second)
    }

    // MARK: - Helpers

    private func makeDate(_ year: Int, _ month: Int, _ day: Int, hour: Int = 0) -> Date {
        calendar.date(from: DateComponents(year: year, month: month, day: day, hour: hour))!
    }

    private func metrics(day: Date, steps: Int) -> DailyHealthMetrics {
        DailyHealthMetrics(
            date: day,
            steps: steps,
            activeEnergyKcal: 350,
            exerciseMinutes: 35
        )
    }

    private func makeWorkout(on day: Date, duration: Int) -> NormalizedWorkout {
        let start = calendar.date(byAdding: .hour, value: 8, to: calendar.startOfDay(for: day))!
        return NormalizedWorkout(
            id: UUID(),
            category: .running,
            activityLabel: "Running",
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

private final class MockContextRepository: HealthDataRepositorying, @unchecked Sendable {

    let calendar: Calendar
    var availability: HealthDataAvailability = .connectedSnapshot
    var dailyMetricsByDay: [Date: DailyHealthMetrics] = [:]
    var workouts: [NormalizedWorkout] = []
    var normalizedSamplesError: Error?
    private(set) var getDailyMetricsCallCount = 0
    private(set) var getWorkoutsCallCount = 0

    init(calendar: Calendar) {
        self.calendar = calendar
    }

    func normalizedSamples(for date: Date, calendar: Calendar) async throws -> [HealthNormalizedSample] {
        if let normalizedSamplesError { throw normalizedSamplesError }
        return []
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
        getDailyMetricsCallCount += 1
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

    func getRecentWorkouts(days: Int, calendar: Calendar) async -> [NormalizedWorkout] {
        workouts
    }

    func getWorkouts(from startDate: Date, to endDate: Date) async -> [NormalizedWorkout] {
        getWorkoutsCallCount += 1
        let rangeStart = calendar.startOfDay(for: startDate)
        let rangeEnd = calendar.startOfDay(for: endDate)
        return workouts.filter {
            let day = calendar.startOfDay(for: $0.startDate)
            return day >= rangeStart && day <= rangeEnd
        }
    }

    func getRecentSleep(days: Int, calendar: Calendar) async -> [NormalizedSleepRecord] { [] }

    func getSleepRecords(from startDate: Date, to endDate: Date, calendar: Calendar) async -> [NormalizedSleepRecord] {
        []
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

private final class MockNutritionProvider: HealthIntelligenceNutritionProviding, @unchecked Sendable {
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

private final class MockWeightProvider: HealthIntelligenceWeightProviding, @unchecked Sendable {
    var entries: [WeightEntry] = []
    var hasRecentWeight = false

    func weightEntries(from startDate: Date, to endDate: Date, calendar: Calendar) async -> [WeightEntry] {
        let start = calendar.startOfDay(for: startDate)
        let end = calendar.startOfDay(for: endDate)
        return entries.filter {
            let day = calendar.startOfDay(for: $0.date)
            return day >= start && day <= end
        }
    }

    func hasLoggedWeightRecently(referenceDate: Date, withinDays: Int, calendar: Calendar) async -> Bool {
        hasRecentWeight
    }
}

private final class MockUserPlanProvider: HealthIntelligenceUserPlanProviding, @unchecked Sendable {
    var plan: HealthIntelligenceUserPlanSnapshot?

    func userPlan(referenceDate: Date) async -> HealthIntelligenceUserPlanSnapshot? {
        plan
    }
}

private struct FixedContextClock: HealthIntelligenceClockProviding {
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
    static var connectedSnapshot: HealthDataAvailability {
        HealthDataAvailability(
            isHealthDataAvailable: true,
            permissionStatus: .uniform(.available, isHealthDataAvailable: true),
            cachedDayCount: 28
        )
    }
}
