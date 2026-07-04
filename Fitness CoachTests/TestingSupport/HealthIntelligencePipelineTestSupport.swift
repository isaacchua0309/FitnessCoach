//
//  HealthIntelligencePipelineTestSupport.swift
//  Fitness CoachTests
//
//  Forma — Fakes and harness for end-to-end Health Intelligence pipeline tests.
//

import XCTest
@testable import Fitness_Coach

struct HealthIntelligencePipelineResult: Equatable, Sendable {
    let snapshot: HealthIntelligenceSnapshot
    let trainingLoad: TrainingLoadSummary
}

final class HealthIntelligencePipelineTestHarness {

    let calendar: Calendar
    let repository: PipelineMockRepository
    let nutritionProvider: PipelineMockNutritionProvider
    let weightProvider: PipelineMockWeightProvider
    let userPlanProvider: PipelineMockUserPlanProvider
    private let trainingLoadEngine: TrainingLoadEngine
    private let contextBuilder: HealthIntelligenceContextBuilder
    private let engine: HealthIntelligenceEngine

    init(
        calendar: Calendar = HealthIntelligencePipelineFixtures.makeCalendar(),
        clockDay: Date = HealthIntelligencePipelineFixtures.day(2026, 7, 8, hour: 14),
        dependencies: HealthIntelligenceEngineDependencies = .production()
    ) {
        self.calendar = calendar
        self.repository = PipelineMockRepository(calendar: calendar)
        self.nutritionProvider = PipelineMockNutritionProvider()
        self.weightProvider = PipelineMockWeightProvider()
        self.userPlanProvider = PipelineMockUserPlanProvider()
        self.trainingLoadEngine = TrainingLoadEngine()

        self.contextBuilder = HealthIntelligenceContextBuilder(
            repository: repository,
            nutritionProvider: nutritionProvider,
            weightProvider: weightProvider,
            userPlanProvider: userPlanProvider,
            clock: FixedPipelineClock(nowValue: clockDay, calendarValue: calendar)
        )
        self.engine = HealthIntelligenceEngine(
            contextBuilder: contextBuilder,
            dependencies: dependencies
        )
    }

    func run(
        for day: Date,
        mode: HealthIntelligenceComposeMode = .today
    ) async -> HealthIntelligencePipelineResult {
        let context = await engineContext(for: day)
        let trainingLoad = (try? trainingLoadEngine.evaluate(context.trainingLoadInput)) ?? .unknown
        let snapshot = await engine.composeSnapshot(for: day, calendar: calendar, mode: mode)
        return HealthIntelligencePipelineResult(snapshot: snapshot, trainingLoad: trainingLoad)
    }

    func snapshotOnly(
        for day: Date,
        mode: HealthIntelligenceComposeMode = .today
    ) async -> HealthIntelligenceSnapshot {
        await engine.composeSnapshot(for: day, calendar: calendar, mode: mode)
    }

    private func engineContext(for day: Date) async -> HealthIntelligenceContext {
        await contextBuilder.buildContext(for: day, calendar: calendar)
    }
}

enum HealthIntelligencePipelineFixtures {

    static func makeCalendar() -> Calendar {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(secondsFromGMT: 0) ?? .gmt
        return calendar
    }

    static func day(
        _ year: Int,
        _ month: Int,
        _ day: Int,
        hour: Int = 0,
        calendar: Calendar = makeCalendar()
    ) -> Date {
        calendar.date(from: DateComponents(year: year, month: month, day: day, hour: hour))!
    }

    static func connectedAvailability(cachedDays: Int = 28) -> HealthDataAvailability {
        HealthDataAvailability(
            isHealthDataAvailable: true,
            permissionStatus: .uniform(.available, isHealthDataAvailable: true),
            cachedDayCount: cachedDays
        )
    }

    static func unavailableAvailability() -> HealthDataAvailability {
        HealthDataAvailability(
            isHealthDataAvailable: false,
            permissionStatus: .unavailable(),
            cachedDayCount: 0
        )
    }

    static func stepsOnlyAvailability() -> HealthDataAvailability {
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
            cachedDayCount: 7
        )
    }

    static func workoutsOnlyAvailability() -> HealthDataAvailability {
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

    static func metrics(
        day: Date,
        steps: Int = 8_000,
        activeEnergyKcal: Double = 400,
        exerciseMinutes: Double = 35
    ) -> DailyHealthMetrics {
        DailyHealthMetrics(
            date: day,
            steps: steps,
            activeEnergyKcal: activeEnergyKcal,
            exerciseMinutes: exerciseMinutes
        )
    }

    static func makeWorkout(
        on day: Date,
        duration: Int,
        category: FormaWorkoutCategory = .running,
        label: String? = nil,
        energy: Double = 360,
        hour: Int = 7,
        calendar: Calendar = makeCalendar(),
        id: UUID = UUID()
    ) -> NormalizedWorkout {
        let start = calendar.date(
            bySettingHour: hour,
            minute: 0,
            second: 0,
            of: calendar.startOfDay(for: day)
        ) ?? day
        let end = calendar.date(byAdding: .minute, value: duration, to: start) ?? start
        return NormalizedWorkout(
            id: id,
            category: category,
            activityLabel: label ?? category.rawValue,
            startDate: start,
            endDate: end,
            durationMinutes: duration,
            activeEnergyKcal: energy,
            sourceName: "Pipeline Test"
        )
    }

    static func makeDailyLog(
        on day: Date,
        calories: Int,
        protein: Double,
        waterMl: Int = 1_800,
        calendar: Calendar = makeCalendar(),
        id: UUID = UUID()
    ) -> DailyLog {
        DailyLog(
            id: id,
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
            waterConsumedMl: waterMl,
            steps: nil,
            workoutCaloriesBurned: 0,
            dailyReviewId: nil,
            createdAt: day,
            updatedAt: day
        )
    }

    static func makeSleep(
        endingOn wakeDay: Date,
        asleepMinutes: Double,
        calendar: Calendar = makeCalendar()
    ) -> NormalizedSleepRecord {
        let wake = calendar.startOfDay(for: wakeDay)
        let start = calendar.date(byAdding: .minute, value: -Int(asleepMinutes), to: wake) ?? wake
        return NormalizedSleepRecord(
            id: UUID(),
            startDate: start,
            endDate: wake,
            asleepMinutes: asleepMinutes,
            inBedMinutes: asleepMinutes + 30
        )
    }

    static func makeHeartMetric(
        on day: Date,
        kind: HealthHeartMetricKind,
        value: Double
    ) -> NormalizedHeartMetric {
        NormalizedHeartMetric(
            id: UUID(),
            kind: kind,
            date: day,
            value: value,
            unitSymbol: kind == .restingHeartRate ? "count/min" : "ms"
        )
    }

    static func seedDailyMetrics(
        into repository: PipelineMockRepository,
        endingOn day: Date,
        days: Int,
        steps: Int = 7_000,
        calendar: Calendar = makeCalendar()
    ) {
        for offset in 0..<days {
            guard let date = calendar.date(byAdding: .day, value: -offset, to: day) else { continue }
            repository.dailyMetricsByDay[calendar.startOfDay(for: date)] = metrics(day: date, steps: steps)
        }
    }

    static func seedNutritionWeek(
        into provider: PipelineMockNutritionProvider,
        endingOn day: Date,
        calories: Int = 1_800,
        protein: Double = 130,
        calendar: Calendar = makeCalendar()
    ) {
        for offset in 0..<7 {
            guard let date = calendar.date(byAdding: .day, value: -offset, to: day) else { continue }
            provider.logsByDay[calendar.startOfDay(for: date)] = makeDailyLog(
                on: date,
                calories: calories,
                protein: protein,
                calendar: calendar
            )
        }
    }

    static func seedHeartBaselines(
        into repository: PipelineMockRepository,
        endingOn day: Date,
        restingHR: Double = 58,
        hrv: Double = 55,
        calendar: Calendar = makeCalendar()
    ) {
        for offset in 0..<28 {
            guard let date = calendar.date(byAdding: .day, value: -offset, to: day) else { continue }
            repository.heartMetrics.append(
                makeHeartMetric(on: date, kind: .restingHeartRate, value: restingHR)
            )
            repository.heartMetrics.append(
                makeHeartMetric(on: date, kind: .heartRateVariabilitySDNN, value: hrv)
            )
        }
    }

    static func seedModerateTrainingHistory(
        into repository: PipelineMockRepository,
        endingOn day: Date,
        calendar: Calendar = makeCalendar()
    ) -> [NormalizedWorkout] {
        var workouts: [NormalizedWorkout] = []
        for offset in 0..<8 {
            guard let date = calendar.date(byAdding: .day, value: -offset, to: day) else { continue }
            workouts.append(makeWorkout(on: date, duration: 45, energy: 360, calendar: calendar))
        }
        repository.workouts = workouts
        return workouts
    }

  static func seedHighLoadHistory(
        into repository: PipelineMockRepository,
        endingOn day: Date,
        calendar: Calendar = makeCalendar()
    ) {
        var workouts = seedLightTrainingBaselineHistory(endingOn: day, calendar: calendar)
        workouts.append(
            makeWorkout(
                on: day,
                duration: 50,
                category: .hiit,
                energy: 500,
                calendar: calendar
            )
        )
        repository.workouts = workouts
    }

    static func seedOverreachingHistory(
        into repository: PipelineMockRepository,
        endingOn day: Date,
        calendar: Calendar = makeCalendar()
    ) {
        var workouts = seedLightTrainingBaselineHistory(endingOn: day, calendar: calendar)
        for offset in 0...1 {
            guard let date = calendar.date(byAdding: .day, value: -offset, to: day) else { continue }
            workouts.append(
                makeWorkout(
                    on: date,
                    duration: 60,
                    category: .hiit,
                    energy: 600,
                    calendar: calendar
                )
            )
        }
        repository.workouts = workouts
    }

    /// Sparse baseline training used to keep load-ratio scenarios in the `.high` / `.overreaching` bands.
    private static func seedLightTrainingBaselineHistory(
        endingOn day: Date,
        calendar: Calendar = makeCalendar()
    ) -> [NormalizedWorkout] {
        var workouts: [NormalizedWorkout] = []
        for offset in stride(from: 28, through: 8, by: -4) {
            guard let date = calendar.date(byAdding: .day, value: -offset, to: day) else { continue }
            workouts.append(
                makeWorkout(
                    on: date,
                    duration: 40,
                    category: .running,
                    energy: 300,
                    calendar: calendar
                )
            )
        }
        return workouts
    }

    static func defaultPlan() -> HealthIntelligenceUserPlanSnapshot {
        HealthIntelligenceUserPlanSnapshot(
            goal: .maintain,
            calorieTarget: 2_200,
            proteinTargetGrams: 150,
            waterTargetMl: 2_500
        )
    }
}

enum HealthIntelligencePipelineAssertions {

    static func assertWeeklyFocusWithinLimit(_ review: WeeklyHealthReview?) {
        XCTAssertLessThanOrEqual(review?.nextWeekFocus.count ?? 0, 3)
    }

    static func assertConfidenceNotOverstated(
        confidence: RecoveryConfidence,
        missingSignals: Set<RecoveryMissingSignal>
    ) {
        if !missingSignals.isEmpty {
            XCTAssertNotEqual(confidence, .high)
        }
    }

    static func assertTrainingLoadConfidenceNotHighWhenSignalsMissing(
        _ summary: TrainingLoadSummary
    ) {
        if summary.missingSignals.contains(.workoutHistory)
            || summary.missingSignals.contains(.baseline) {
            XCTAssertNotEqual(summary.confidence, .high)
        }
    }
}

// MARK: - Mocks

final class PipelineMockRepository: HealthDataRepositorying, @unchecked Sendable {
    let calendar: Calendar
    var availability: HealthDataAvailability = HealthIntelligencePipelineFixtures.connectedAvailability()
    var dailyMetricsByDay: [Date: DailyHealthMetrics] = [:]
    var workouts: [NormalizedWorkout] = []
    var sleepRecords: [NormalizedSleepRecord] = []
    var heartMetrics: [NormalizedHeartMetric] = []
    var bodyMassRecords: [NormalizedBodyMass] = []
    var normalizedSamplesError: Error?
    var shouldFailDailyMetricsRange = false

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
        if shouldFailDailyMetricsRange {
            return []
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

    func getWorkouts(from startDate: Date, to endDate: Date, calendar: Calendar) async -> [NormalizedWorkout] {
        let rangeStart = calendar.startOfDay(for: startDate)
        let rangeEnd = calendar.startOfDay(for: endDate)
        return workouts.filter {
            let day = calendar.startOfDay(for: $0.startDate)
            return day >= rangeStart && day <= rangeEnd
        }
    }

    func getRecentSleep(days: Int, calendar: Calendar) async -> [NormalizedSleepRecord] { sleepRecords }

    func getSleepRecords(from startDate: Date, to endDate: Date, calendar: Calendar) async -> [NormalizedSleepRecord] {
        sleepRecords
    }

    func getRecentHeartMetrics(days: Int, calendar: Calendar) async -> [NormalizedHeartMetric] { heartMetrics }

    func getHeartMetrics(from startDate: Date, to endDate: Date, calendar: Calendar) async -> [NormalizedHeartMetric] {
        heartMetrics
    }

    func getBodyMassHistory(days: Int, calendar: Calendar) async -> [NormalizedBodyMass] { bodyMassRecords }

    func getHealthDataAvailability() async -> HealthDataAvailability { availability }

    func refreshHealthData(days: Int, endingOn date: Date, calendar: Calendar) async -> HealthRefreshResult {
        HealthRefreshResult(daysRefreshed: days, refreshedAt: Date())
    }
}

final class PipelineMockNutritionProvider: HealthIntelligenceNutritionProviding, @unchecked Sendable {
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

final class PipelineMockWeightProvider: HealthIntelligenceWeightProviding, @unchecked Sendable {
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

final class PipelineMockUserPlanProvider: HealthIntelligenceUserPlanProviding, @unchecked Sendable {
    var plan: HealthIntelligenceUserPlanSnapshot? = HealthIntelligencePipelineFixtures.defaultPlan()

    func userPlan(referenceDate: Date) async -> HealthIntelligenceUserPlanSnapshot? {
        plan
    }
}

struct FixedPipelineClock: HealthIntelligenceClockProviding {
    let nowValue: Date
    let calendarValue: Calendar

    func now() -> Date { nowValue }

    func calendar() -> Calendar { calendarValue }
}

struct PipelineFailingTrainingLoadProvider: TrainingLoadProviding {
    func evaluate(_ input: TrainingLoadEngineInput) throws -> TrainingLoadSummary {
        throw HealthIntelligenceEngineEvaluationError.simulatedFailure(.trainingLoad)
    }
}

struct PipelineFailingRecoveryProvider: RecoveryEngineProviding {
    func evaluate(_ input: RecoveryEngineInput) throws -> RecoverySummary {
        throw HealthIntelligenceEngineEvaluationError.simulatedFailure(.recovery)
    }
}
