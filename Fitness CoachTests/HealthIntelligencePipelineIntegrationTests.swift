//
//  HealthIntelligencePipelineIntegrationTests.swift
//  Fitness CoachTests
//
//  Forma — End-to-end integration tests for Phase 6–10 Health Intelligence pipeline.
//

import XCTest
@testable import Fitness_Coach

final class HealthIntelligencePipelineIntegrationTests: XCTestCase {

    private var calendar: Calendar!
    private var day: Date!

    override func setUp() {
        super.setUp()
        calendar = HealthIntelligencePipelineFixtures.makeCalendar()
        day = HealthIntelligencePipelineFixtures.day(2026, 7, 8, hour: 14)
    }

    // MARK: - 1. No health permission / no health data

    func testNoHealthPermissionProducesDisconnectedSnapshot() async {
        let harness = HealthIntelligencePipelineTestHarness(calendar: calendar, clockDay: day)
        harness.repository.availability = HealthIntelligencePipelineFixtures.unavailableAvailability()

        let result = await harness.run(for: day)

        XCTAssertEqual(result.snapshot.recovery.status, .unknown)
        XCTAssertNil(result.snapshot.workout)
        XCTAssertEqual(result.snapshot.activity, .empty)
        XCTAssertEqual(result.snapshot.planConfidence, .unknown)
        XCTAssertEqual(result.snapshot.nextBestAction.reason, .connectHealth)
        XCTAssertEqual(result.trainingLoad.status, .unknown)
    }

    // MARK: - 2. Steps only

    func testStepsOnlyScenario() async {
        let harness = HealthIntelligencePipelineTestHarness(calendar: calendar, clockDay: day)
        harness.repository.availability = HealthIntelligencePipelineFixtures.stepsOnlyAvailability()
        harness.repository.dailyMetricsByDay[calendar.startOfDay(for: day)] = HealthIntelligencePipelineFixtures.metrics(
            day: day,
            steps: 11_500
        )

        let result = await harness.run(for: day)

        XCTAssertEqual(result.snapshot.activity.steps, 11_500)
        XCTAssertNil(result.snapshot.activity.activeEnergyKcal)
        XCTAssertNil(result.snapshot.workout)
        XCTAssertEqual(result.snapshot.recovery.status, .unknown)
        XCTAssertTrue(result.snapshot.recovery.missingSignals.contains(.sleep))
    }

    // MARK: - 3. Workouts only

    func testWorkoutsOnlyScenario() async {
        let harness = HealthIntelligencePipelineTestHarness(calendar: calendar, clockDay: day)
        harness.repository.availability = HealthIntelligencePipelineFixtures.workoutsOnlyAvailability()
        harness.repository.workouts = [
            HealthIntelligencePipelineFixtures.makeWorkout(
                on: day,
                duration: 40,
                category: .cycling,
                calendar: calendar
            )
        ]

        let result = await harness.run(for: day)

        XCTAssertNil(result.snapshot.activity.steps)
        XCTAssertTrue(result.snapshot.workout?.hasWorkout == true)
        XCTAssertEqual(result.snapshot.workout?.primaryWorkoutType, .cycling)
        XCTAssertEqual(result.snapshot.recovery.status, .unknown)
    }

    // MARK: - 4. Strength workout today

    func testStrengthWorkoutTodayScenario() async {
        let harness = makeConnectedHarness()
        harness.repository.workouts = [
            HealthIntelligencePipelineFixtures.makeWorkout(
                on: day,
                duration: 50,
                category: .strength,
                label: "Strength training",
                energy: 320,
                calendar: calendar
            )
        ]
        harness.nutritionProvider.todayLog = HealthIntelligencePipelineFixtures.makeDailyLog(
            on: day,
            calories: 1_400,
            protein: 95,
            calendar: calendar
        )

        let result = await harness.run(for: day)

        XCTAssertEqual(result.snapshot.workout?.primaryWorkoutType, .strength)
        XCTAssertEqual(result.snapshot.workout?.title, "Strength training")
        XCTAssertGreaterThan(result.snapshot.workout?.totalDurationMinutes ?? 0, 0)
        XCTAssertGreaterThan(result.trainingLoad.todayLoad, 0)
    }

    // MARK: - 5. Long run today

    func testLongRunTodayScenario() async {
        let harness = makeConnectedHarness()
        harness.repository.workouts = [
            HealthIntelligencePipelineFixtures.makeWorkout(
                on: day,
                duration: 90,
                category: .running,
                label: "Long run",
                energy: 780,
                hour: 6,
                calendar: calendar
            )
        ]
        harness.nutritionProvider.todayLog = HealthIntelligencePipelineFixtures.makeDailyLog(
            on: day,
            calories: 1_600,
            protein: 110,
            calendar: calendar
        )

        let result = await harness.run(for: day)

        XCTAssertEqual(result.snapshot.workout?.primaryWorkoutType, .running)
        XCTAssertGreaterThanOrEqual(result.snapshot.workout?.totalDurationMinutes ?? 0, 90)
        XCTAssertTrue(
            result.snapshot.workout?.demand == .high || result.snapshot.workout?.demand == .moderate
        )
    }

    // MARK: - 6. High training load week

    func testHighTrainingLoadWeekScenario() async {
        let harness = makeConnectedHarness()
        HealthIntelligencePipelineFixtures.seedDailyMetrics(
            into: harness.repository,
            endingOn: day,
            days: 28,
            calendar: calendar
        )
        HealthIntelligencePipelineFixtures.seedHighLoadHistory(
            into: harness.repository,
            endingOn: day,
            calendar: calendar
        )

        let result = await harness.run(for: day)

        XCTAssertEqual(result.trainingLoad.status, .high)
        XCTAssertGreaterThan(result.trainingLoad.loadRatio ?? 0, 1.30)
        HealthIntelligencePipelineAssertions.assertTrainingLoadConfidenceNotHighWhenSignalsMissing(
            result.trainingLoad
        )
    }

    // MARK: - 7. Overreaching week

    func testOverreachingWeekScenario() async {
        let harness = makeConnectedHarness()
        HealthIntelligencePipelineFixtures.seedDailyMetrics(
            into: harness.repository,
            endingOn: day,
            days: 28,
            calendar: calendar
        )
        HealthIntelligencePipelineFixtures.seedOverreachingHistory(
            into: harness.repository,
            endingOn: day,
            calendar: calendar
        )

        let result = await harness.run(for: day)

        XCTAssertEqual(result.trainingLoad.status, .overreaching)
        XCTAssertGreaterThan(result.trainingLoad.loadRatio ?? 0, 1.70)
    }

    // MARK: - 8. Low recovery from poor sleep + high RHR + low HRV

    func testLowRecoveryFromSleepHeartSignalsScenario() async {
        let harness = makeConnectedHarness()
        HealthIntelligencePipelineFixtures.seedDailyMetrics(
            into: harness.repository,
            endingOn: day,
            days: 28,
            calendar: calendar
        )
        HealthIntelligencePipelineFixtures.seedHeartBaselines(
            into: harness.repository,
            endingOn: day,
            restingHR: 58,
            hrv: 55,
            calendar: calendar
        )
        harness.repository.sleepRecords = [
            HealthIntelligencePipelineFixtures.makeSleep(
                endingOn: day,
                asleepMinutes: 300,
                calendar: calendar
            )
        ]
        harness.repository.heartMetrics.append(
            HealthIntelligencePipelineFixtures.makeHeartMetric(
                on: day,
                kind: .restingHeartRate,
                value: 72
            )
        )
        harness.repository.heartMetrics.append(
            HealthIntelligencePipelineFixtures.makeHeartMetric(
                on: day,
                kind: .heartRateVariabilitySDNN,
                value: 40
            )
        )

        let result = await harness.run(for: day)

        XCTAssertEqual(result.snapshot.recovery.status, .low)
        XCTAssertLessThan(result.snapshot.recovery.score ?? 100, 55)
        XCTAssertTrue(
            result.snapshot.recovery.contributingFactors.contains {
                $0.signal == .sleep && $0.impact == .negative
            }
        )
        HealthIntelligencePipelineAssertions.assertConfidenceNotOverstated(
            confidence: result.snapshot.recovery.confidence,
            missingSignals: result.snapshot.recovery.missingSignals
        )
    }

    // MARK: - 9. Nutrition behind after workout

    func testNutritionBehindAfterWorkoutScenario() async {
        let harness = makeConnectedHarness()
        harness.repository.workouts = [
            HealthIntelligencePipelineFixtures.makeWorkout(
                on: day,
                duration: 55,
                category: .strength,
                energy: 420,
                calendar: calendar
            )
        ]
        harness.nutritionProvider.todayLog = HealthIntelligencePipelineFixtures.makeDailyLog(
            on: day,
            calories: 900,
            protein: 45,
            waterMl: 2_000,
            calendar: calendar
        )

        let result = await harness.run(for: day)

        XCTAssertTrue(result.snapshot.workout?.hasWorkout == true)
        XCTAssertEqual(result.snapshot.workout?.demand, .high)
        XCTAssertGreaterThanOrEqual(result.snapshot.nutritionAdjustment.priority, 2)
        XCTAssertNotNil(result.snapshot.nutritionAdjustment.proteinRecommendationGrams)
        XCTAssertEqual(result.snapshot.nextBestAction.reason, .postWorkoutRecovery)
        XCTAssertEqual(result.snapshot.nextBestAction.priority, 1)
        XCTAssertEqual(result.snapshot.nextBestAction.destination, .logMeal)
    }

    // MARK: - 10. Hydration behind after workout

    func testHydrationBehindAfterWorkoutScenario() async {
        let harness = makeConnectedHarness()
        harness.repository.workouts = [
            HealthIntelligencePipelineFixtures.makeWorkout(
                on: day,
                duration: 50,
                category: .running,
                energy: 500,
                calendar: calendar
            )
        ]
        harness.nutritionProvider.todayLog = HealthIntelligencePipelineFixtures.makeDailyLog(
            on: day,
            calories: 1_500,
            protein: 140,
            waterMl: 800,
            calendar: calendar
        )

        let result = await harness.run(for: day)

        XCTAssertGreaterThan(result.snapshot.nutritionAdjustment.waterIncreaseMl, 0)
        XCTAssertEqual(result.snapshot.nextBestAction.reason, .hydration)
        XCTAssertEqual(result.snapshot.nextBestAction.priority, 2)
        XCTAssertEqual(result.snapshot.nextBestAction.destination, .addWater)
    }

    // MARK: - 11. Weekly review strong week

    func testWeeklyReviewStrongWeekScenario() async {
        let harness = makeConnectedHarness()
        HealthIntelligencePipelineFixtures.seedDailyMetrics(
            into: harness.repository,
            endingOn: day,
            days: 7,
            steps: 8_000,
            calendar: calendar
        )
        HealthIntelligencePipelineFixtures.seedNutritionWeek(
            into: harness.nutritionProvider,
            endingOn: day,
            calories: 2_000,
            protein: 145,
            calendar: calendar
        )
        harness.repository.workouts = (0..<4).compactMap { offset in
            calendar.date(byAdding: .day, value: -offset * 2, to: day).map {
                HealthIntelligencePipelineFixtures.makeWorkout(
                    on: $0,
                    duration: 45,
                    energy: 380,
                    calendar: calendar
                )
            }
        }
        harness.weightProvider.entries = [
            WeightEntry(id: UUID(), date: HealthIntelligencePipelineFixtures.day(2026, 7, 2), weightKg: 80, note: nil, createdAt: day),
            WeightEntry(id: UUID(), date: day, weightKg: 79.7, note: nil, createdAt: day)
        ]
        harness.weightProvider.hasRecentWeight = true

        let result = await harness.run(for: day, mode: .weeklyReview)

        XCTAssertNotNil(result.snapshot.weeklyReview)
        XCTAssertEqual(result.snapshot.weeklyReview?.confidence, .high)
        XCTAssertFalse(result.snapshot.weeklyReview?.wins.isEmpty == true)
        HealthIntelligencePipelineAssertions.assertWeeklyFocusWithinLimit(result.snapshot.weeklyReview)
        XCTAssertTrue(result.snapshot.weeklyReview?.missingSignals.isEmpty == true)
    }

    // MARK: - 12. Weekly review sparse data

    func testWeeklyReviewSparseDataScenario() async {
        let harness = makeConnectedHarness()
        HealthIntelligencePipelineFixtures.seedDailyMetrics(
            into: harness.repository,
            endingOn: day,
            days: 7,
            steps: 5_500,
            calendar: calendar
        )

        let result = await harness.run(for: day, mode: .weeklyReview)

        XCTAssertNotNil(result.snapshot.weeklyReview)
        XCTAssertEqual(result.snapshot.weeklyReview?.confidence, .low)
        XCTAssertTrue(result.snapshot.weeklyReview?.missingSignals.contains(.nutrition) == true)
        XCTAssertTrue(result.snapshot.weeklyReview?.missingSignals.contains(.weight) == true)
        HealthIntelligencePipelineAssertions.assertWeeklyFocusWithinLimit(result.snapshot.weeklyReview)
    }

    // MARK: - 13. Missing nutrition provider should not crash

    func testMissingNutritionProviderDoesNotCrash() async {
        let harness = HealthIntelligencePipelineTestHarness(calendar: calendar, clockDay: day)
        harness.repository.availability = HealthIntelligencePipelineFixtures.connectedAvailability()
        harness.repository.dailyMetricsByDay[calendar.startOfDay(for: day)] = HealthIntelligencePipelineFixtures.metrics(day: day)
        harness.nutritionProvider.todayLog = nil
        harness.nutritionProvider.logsByDay = [:]
        harness.userPlanProvider.plan = HealthIntelligencePipelineFixtures.defaultPlan()

        let result = await harness.run(for: day)

        XCTAssertTrue(result.snapshot.nutritionAdjustment.missingSignals.contains(.nutritionProgress))
        XCTAssertFalse(result.snapshot.nutritionAdjustment.shouldChangeTarget)
        XCTAssertNotEqual(result.snapshot.nextBestAction.id, "")
    }

    // MARK: - 14. Missing weight data should reduce confidence

    func testMissingWeightDataReducesWeeklyReviewConfidence() async {
        let withWeight = await weeklyReviewConfidence(includeWeight: true)
        let withoutWeight = await weeklyReviewConfidence(includeWeight: false)

        XCTAssertEqual(withWeight, .high)
        XCTAssertEqual(withoutWeight, .moderate)
    }

    // MARK: - 15. Snapshot composition should be deterministic

    func testSnapshotCompositionIsDeterministicForSameInputs() async {
        let harness = makeConnectedHarness()
        HealthIntelligencePipelineFixtures.seedDailyMetrics(
            into: harness.repository,
            endingOn: day,
            days: 14,
            calendar: calendar
        )
        harness.repository.workouts = [
            HealthIntelligencePipelineFixtures.makeWorkout(
                on: day,
                duration: 45,
                category: .strength,
                energy: 320,
                calendar: calendar,
                id: UUID(uuidString: "00000000-0000-0000-0000-0000000000BB")!
            )
        ]
        harness.nutritionProvider.todayLog = HealthIntelligencePipelineFixtures.makeDailyLog(
            on: day,
            calories: 1_500,
            protein: 120,
            calendar: calendar,
            id: UUID(uuidString: "00000000-0000-0000-0000-0000000000CC")!
        )

        let first = await harness.run(for: day)
        let second = await harness.run(for: day)

        XCTAssertEqual(first.snapshot, second.snapshot)
        XCTAssertEqual(first.trainingLoad, second.trainingLoad)
    }

    // MARK: - 16. Cache/repository partial failure should degrade gracefully

    func testPartialRepositoryAndEngineFailureDegradesGracefully() async {
        let harness = HealthIntelligencePipelineTestHarness(
            calendar: calendar,
            clockDay: day,
            dependencies: HealthIntelligenceEngineDependencies(
                trainingLoad: PipelineFailingTrainingLoadProvider(),
                workout: WorkoutIntelligenceEngine(),
                recovery: PipelineFailingRecoveryProvider(),
                adaptiveNutrition: AdaptiveNutritionEngine(),
                nextBestAction: HealthNextBestActionEngine(),
                weeklyReview: WeeklyReviewEngine()
            )
        )
        harness.repository.availability = HealthIntelligencePipelineFixtures.connectedAvailability()
        harness.repository.dailyMetricsByDay[calendar.startOfDay(for: day)] = HealthIntelligencePipelineFixtures.metrics(
            day: day,
            steps: 9_000
        )
        harness.repository.normalizedSamplesError = HealthDataRepositoryError.unavailable
        harness.repository.shouldFailDailyMetricsRange = false
        harness.nutritionProvider.todayLog = HealthIntelligencePipelineFixtures.makeDailyLog(
            on: day,
            calories: 1_400,
            protein: 110,
            calendar: calendar
        )

        let result = await harness.run(for: day)

        XCTAssertEqual(result.snapshot.activity.steps, 9_000)
        XCTAssertEqual(result.trainingLoad.status, .unknown)
        XCTAssertEqual(result.snapshot.recovery.status, .unknown)
        XCTAssertFalse(result.snapshot.nutritionAdjustment.shouldChangeTarget)
    }

    // MARK: - Helpers

    private func makeConnectedHarness() -> HealthIntelligencePipelineTestHarness {
        let harness = HealthIntelligencePipelineTestHarness(calendar: calendar, clockDay: day)
        harness.repository.availability = HealthIntelligencePipelineFixtures.connectedAvailability()
        harness.repository.dailyMetricsByDay[calendar.startOfDay(for: day)] = HealthIntelligencePipelineFixtures.metrics(
            day: day
        )
        harness.userPlanProvider.plan = HealthIntelligencePipelineFixtures.defaultPlan()
        return harness
    }

    private func weeklyReviewConfidence(includeWeight: Bool) async -> WeeklyReviewConfidence? {
        let harness = makeConnectedHarness()
        HealthIntelligencePipelineFixtures.seedDailyMetrics(
            into: harness.repository,
            endingOn: day,
            days: 7,
            calendar: calendar
        )
        HealthIntelligencePipelineFixtures.seedNutritionWeek(
            into: harness.nutritionProvider,
            endingOn: day,
            calendar: calendar
        )
        harness.repository.workouts = [
            HealthIntelligencePipelineFixtures.makeWorkout(on: day, duration: 45, calendar: calendar)
        ]
        if includeWeight {
            harness.weightProvider.entries = [
                WeightEntry(id: UUID(), date: HealthIntelligencePipelineFixtures.day(2026, 7, 2), weightKg: 80, note: nil, createdAt: day),
                WeightEntry(id: UUID(), date: day, weightKg: 79.8, note: nil, createdAt: day)
            ]
            harness.weightProvider.hasRecentWeight = true
        } else {
            harness.weightProvider.entries = []
            harness.weightProvider.hasRecentWeight = false
        }

        let result = await harness.run(for: day, mode: .weeklyReview)
        return result.snapshot.weeklyReview?.confidence
    }
}
