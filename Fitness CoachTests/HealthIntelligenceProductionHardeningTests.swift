//
//  HealthIntelligenceProductionHardeningTests.swift
//  Fitness CoachTests
//
//  Forma — Production hardening checks for Phase 6–10 Health Intelligence.
//

import XCTest
@testable import Fitness_Coach

final class HealthIntelligenceProductionHardeningTests: XCTestCase {

    private var calendar: Calendar!

    override func setUp() {
        super.setUp()
        calendar = HealthIntelligencePipelineFixtures.makeCalendar()
    }

    func testWeeklyReviewWinsUseStableOrdering() throws {
        let engine = WeeklyReviewEngine()
        let weekStart = HealthIntelligencePipelineFixtures.day(2026, 7, 1)
        let weekEnd = HealthIntelligencePipelineFixtures.day(2026, 7, 7)
        let input = WeeklyReviewEngineInput(
            weekStartDate: weekStart,
            weekEndDate: weekEnd,
            dailyMetrics: (0..<7).map { offset in
                let date = calendar.date(byAdding: .day, value: offset, to: weekStart)!
                return HealthIntelligencePipelineFixtures.metrics(day: date, steps: 8_500)
            },
            workouts: (0..<4).map { offset in
                HealthIntelligencePipelineFixtures.makeWorkout(
                    on: calendar.date(byAdding: .day, value: offset * 2, to: weekStart)!,
                    duration: 45,
                    calendar: calendar
                )
            },
            recoverySummaries: (0..<7).map { offset in
                DailyRecoverySummary(
                    date: calendar.date(byAdding: .day, value: offset, to: weekStart)!,
                    summary: RecoverySummary(
                        score: 80,
                        status: .ready,
                        title: "Ready",
                        explanation: "Stable",
                        recommendedTraining: "Train",
                        recommendedNutrition: "Fuel",
                        confidence: .high,
                        contributingFactors: [],
                        missingSignals: []
                    )
                )
            },
            nutritionDailySummaries: (0..<7).map { offset in
                let date = calendar.date(byAdding: .day, value: offset, to: weekStart)!
                let log = HealthIntelligencePipelineFixtures.makeDailyLog(
                    on: date,
                    calories: 2_000,
                    protein: 145,
                    calendar: calendar
                )
                return WeeklyNutritionDailySummary(
                    date: log.date,
                    caloriesConsumed: log.totals.calories,
                    calorieTarget: log.targets.calorieTarget,
                    proteinConsumedGrams: log.totals.protein,
                    proteinTargetGrams: log.targets.proteinTarget,
                    waterConsumedMl: log.waterConsumedMl,
                    waterTargetMl: log.targets.waterTargetMl,
                    didLogFood: true
                )
            },
            weightRecords: [
                NormalizedBodyMass(
                    id: UUID(),
                    date: weekStart,
                    valueKg: 80
                ),
                NormalizedBodyMass(
                    id: UUID(),
                    date: weekEnd,
                    valueKg: 79.7
                )
            ],
            userPlan: WeeklyReviewUserPlan(
                goal: .loseFat,
                calorieTarget: 2_200,
                proteinTargetGrams: 150,
                waterTargetMl: 2_500
            ),
            calendar: calendar,
            generatedAt: weekEnd
        )

        let first = try XCTUnwrap(try engine.evaluate(input))
        let second = try XCTUnwrap(try engine.evaluate(input))

        XCTAssertEqual(first.wins, second.wins)
        XCTAssertLessThanOrEqual(first.nextWeekFocus.count, 3)
        XCTAssertEqual(first.nextWeekFocus, second.nextWeekFocus)
    }

    func testNextBestActionDoesNotNagForWeightEarlyInDay() {
        let engine = HealthNextBestActionEngine()
        let day = HealthIntelligencePipelineFixtures.day(2026, 7, 8, hour: 9)
        let input = NextBestActionEngineInput(
            targetDate: calendar.startOfDay(for: day),
            timeOfDay: day,
            nutritionProgress: AdaptiveNutritionProgress(
                proteinConsumedGrams: 80,
                proteinTargetGrams: 150,
                proteinRemainingGrams: 70,
                caloriesConsumed: 900,
                calorieTarget: 2_200,
                calorieRemaining: 1_300,
                waterConsumedMl: 2_000,
                waterTargetMl: 2_500,
                waterRemainingMl: 500
            ),
            userPlan: AdaptiveNutritionUserPlan(
                calorieTarget: 2_200,
                proteinTargetGrams: 150,
                waterTargetMl: 2_500
            ),
            recoverySummary: RecoverySummary(
                score: 75,
                status: .ready,
                title: "Ready",
                explanation: "Ready",
                recommendedTraining: "Train",
                recommendedNutrition: "Fuel",
                confidence: .high,
                contributingFactors: [],
                missingSignals: []
            ),
            workoutSummary: .noWorkout,
            activitySummary: ActivitySummary(steps: 6_000, activeEnergyKcal: 250, exerciseMinutes: 30),
            adaptiveNutritionSummary: .none,
            trainingLoadSummary: .unknown,
            hasLoggedWeightRecently: false,
            calendar: calendar
        )

        let action = try! engine.evaluate(input)

        XCTAssertNotEqual(action.reason, .missingWeight)
    }

    func testTrainingLoadCapsExtremeRatios() throws {
        let engine = TrainingLoadEngine()
        let day = HealthIntelligencePipelineFixtures.day(2026, 7, 8)
        let heavy = HealthIntelligencePipelineFixtures.makeWorkout(
            on: day,
            duration: 90,
            category: .hiit,
            energy: 900,
            calendar: calendar
        )
        let workouts = Array(repeating: heavy, count: 7)
        let input = TrainingLoadEngineInput(
            targetDate: day,
            workoutsToday: [heavy],
            workoutsLast7Days: workouts,
            workoutsLast28Days: workouts,
            baselineAverageWeeklyLoad: 10,
            calendar: calendar
        )

        let summary = try engine.evaluate(input)

        XCTAssertEqual(summary.status, .overreaching)
        XCTAssertLessThanOrEqual(summary.loadRatio ?? 0, TrainingLoadPolicy.maximumLoadRatio)
    }

    func testPartialAuthorizationStillComposesActivity() async {
        let harness = HealthIntelligencePipelineTestHarness(calendar: calendar)
        harness.repository.availability = HealthIntelligencePipelineFixtures.stepsOnlyAvailability()
        harness.repository.dailyMetricsByDay[
            calendar.startOfDay(for: HealthIntelligencePipelineFixtures.day(2026, 7, 8))
        ] = HealthIntelligencePipelineFixtures.metrics(
            day: HealthIntelligencePipelineFixtures.day(2026, 7, 8),
            steps: 9_200
        )

        let result = await harness.run(for: HealthIntelligencePipelineFixtures.day(2026, 7, 8))

        XCTAssertEqual(result.snapshot.activity.steps, 9_200)
        XCTAssertNil(result.snapshot.activity.activeEnergyKcal)
        XCTAssertNotEqual(result.snapshot.nextBestAction.id, "")
    }
}
