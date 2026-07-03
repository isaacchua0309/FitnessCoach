//
//  AdaptiveNutritionEngineTests.swift
//  Fitness CoachTests
//

import XCTest
@testable import Fitness_Coach

final class AdaptiveNutritionEngineTests: XCTestCase {

    private var engine: AdaptiveNutritionEngine!
    private var targetDate: Date!

    override func setUp() {
        super.setUp()
        engine = AdaptiveNutritionEngine()
        targetDate = Date(timeIntervalSince1970: 1_787_107_200)
    }

    func testNoWorkoutStaysOnPlan() {
        let summary = evaluate(
            workout: .noWorkout,
            progress: defaultProgress
        )

        XCTAssertFalse(summary.shouldChangeTarget)
        XCTAssertEqual(summary.suggestedCalorieAdjustment, 0)
        XCTAssertNil(summary.proteinRecommendationGrams)
        XCTAssertEqual(summary.calorieAdvice, "Stay on your usual plan today.")
        XCTAssertEqual(summary.waterIncreaseMl, 0)
        XCTAssertTrue(summary.missingSignals.contains(.workout))
    }

    func testHighDemandWorkoutRecommendsProteinGuidance() {
        let summary = evaluate(
            workout: workoutSummary(demand: .high, hydrationMl: 800),
            progress: defaultProgress
        )

        XCTAssertEqual(summary.proteinRecommendationGrams, 38)
        XCTAssertGreaterThanOrEqual(summary.proteinRecommendationGrams ?? 0, 30)
        XCTAssertLessThanOrEqual(summary.proteinRecommendationGrams ?? 0, 45)
        XCTAssertEqual(summary.waterIncreaseMl, 800)
        XCTAssertGreaterThanOrEqual(summary.suggestedWaterRemainingMl ?? 0, 800)
    }

    func testModerateDemandWorkoutRecommendsModerateProteinGuidance() {
        let summary = evaluate(
            workout: workoutSummary(demand: .moderate, hydrationMl: 500),
            progress: defaultProgress
        )

        XCTAssertEqual(summary.proteinRecommendationGrams, 28)
        XCTAssertGreaterThanOrEqual(summary.proteinRecommendationGrams ?? 0, 20)
        XCTAssertLessThanOrEqual(summary.proteinRecommendationGrams ?? 0, 35)
        XCTAssertEqual(summary.waterIncreaseMl, 500)
    }

    func testLowRecoveryProtectsProteinAndAvoidsRestriction() {
        let summary = evaluate(
            workout: workoutSummary(demand: .moderate, hydrationMl: 500),
            recovery: recovery(status: .low, score: 48),
            progress: defaultProgress
        )

        XCTAssertGreaterThanOrEqual(summary.proteinRecommendationGrams ?? 0, 20)
        XCTAssertTrue(summary.calorieAdvice.contains("steady"))
        XCTAssertTrue(summary.adjustmentReason.contains("consistency"))
    }

    func testOverreachingTrainingLoadEmphasizesHydrationAndProtein() {
        let summary = evaluate(
            workout: workoutSummary(demand: .moderate, hydrationMl: 250),
            trainingLoad: overreachingTrainingLoad,
            progress: defaultProgress
        )

        XCTAssertGreaterThanOrEqual(summary.proteinRecommendationGrams ?? 0, 20)
        XCTAssertGreaterThanOrEqual(summary.waterIncreaseMl, 500)
        XCTAssertTrue(summary.adjustmentReason.contains("elevated"))
        XCTAssertEqual(summary.priority, 3)
    }

    func testMissingNutritionProgressLowersConfidence() {
        let summary = evaluate(
            workout: workoutSummary(demand: .high, hydrationMl: 800),
            progress: .unavailable,
            plan: .unavailable
        )

        XCTAssertEqual(summary.confidence, .low)
        XCTAssertTrue(summary.missingSignals.contains(.nutritionProgress))
        XCTAssertTrue(summary.missingSignals.contains(.userPlan))
    }

    func testAlreadyHitProteinShiftsAdviceToMaintenance() {
        let progress = AdaptiveNutritionProgress(
            proteinConsumedGrams: 176,
            proteinTargetGrams: 180,
            proteinRemainingGrams: 4,
            caloriesConsumed: 1_400,
            calorieTarget: 2_200,
            calorieRemaining: 800,
            waterConsumedMl: 1_500,
            waterTargetMl: 2_500,
            waterRemainingMl: 1_000
        )

        let summary = evaluate(
            workout: workoutSummary(demand: .high, hydrationMl: 800),
            progress: progress
        )

        XCTAssertTrue(summary.calorieAdvice.contains("Protein is in a good place"))
        XCTAssertEqual(summary.suggestedProteinRemaining, 4)
    }

    func testVeryLowCaloriesAfterWorkoutAdvisesAgainstUnderEating() {
        let progress = AdaptiveNutritionProgress(
            proteinConsumedGrams: 40,
            proteinTargetGrams: 180,
            proteinRemainingGrams: 140,
            caloriesConsumed: 500,
            calorieTarget: 2_200,
            calorieRemaining: 1_700,
            waterConsumedMl: 600,
            waterTargetMl: 2_500,
            waterRemainingMl: 1_900
        )

        let summary = evaluate(
            workout: workoutSummary(demand: .high, hydrationMl: 800),
            progress: progress
        )

        XCTAssertTrue(summary.calorieAdvice.contains("not under-fueling"))
        XCTAssertEqual(summary.priority, 2)
    }

    func testHydrationRecommendationStaysWithinHighDemandBounds() {
        let summary = evaluate(
            workout: workoutSummary(demand: .high, hydrationMl: 900, duration: 90),
            progress: defaultProgress
        )

        XCTAssertGreaterThanOrEqual(summary.waterIncreaseMl, 700)
        XCTAssertLessThanOrEqual(summary.waterIncreaseMl, 900)
    }

    // MARK: - Helpers

    private var defaultProgress: AdaptiveNutritionProgress {
        AdaptiveNutritionProgress(
            proteinConsumedGrams: 60,
            proteinTargetGrams: 180,
            proteinRemainingGrams: 120,
            caloriesConsumed: 900,
            calorieTarget: 2_200,
            calorieRemaining: 1_300,
            waterConsumedMl: 800,
            waterTargetMl: 2_500,
            waterRemainingMl: 1_700
        )
    }

    private var defaultPlan: AdaptiveNutritionUserPlan {
        AdaptiveNutritionUserPlan(
            calorieTarget: 2_200,
            proteinTargetGrams: 180,
            waterTargetMl: 2_500
        )
    }

    private var overreachingTrainingLoad: TrainingLoadSummary {
        TrainingLoadSummary(
            status: .overreaching,
            todayLoad: 120,
            sevenDayLoad: 700,
            twentyEightDayAverageWeeklyLoad: 280,
            loadRatio: 2.0,
            workoutDays7d: 5,
            workoutDays28d: 12,
            explanation: "Load is well above your baseline.",
            confidence: .high,
            missingSignals: []
        )
    }

    private func evaluate(
        workout: WorkoutSummary,
        recovery: RecoverySummary = RecoverySummary(
            score: 78,
            status: .ready,
            title: "Ready for training",
            explanation: "Recovery signals look supportive.",
            recommendedTraining: "Your usual training plan looks reasonable today.",
            recommendedNutrition: "Stick with your normal protein and hydration rhythm.",
            confidence: .high,
            contributingFactors: [],
            missingSignals: []
        ),
        trainingLoad: TrainingLoadSummary = .unknown,
        progress: AdaptiveNutritionProgress? = nil,
        plan: AdaptiveNutritionUserPlan? = nil
    ) -> AdaptiveNutritionSummary {
        try! engine.evaluate(
            AdaptiveNutritionEngineInput(
                targetDate: targetDate,
                nutritionProgress: progress ?? defaultProgress,
                userPlan: plan ?? defaultPlan,
                workoutSummary: workout,
                recoverySummary: recovery,
                activitySummary: ActivitySummary(steps: 8_000, activeEnergyKcal: 400, exerciseMinutes: 40),
                trainingLoadSummary: trainingLoad,
                baselineContext: .empty(for: targetDate),
                calendar: .current
            )
        )
    }

    private func workoutSummary(
        demand: WorkoutDemand,
        hydrationMl: Int,
        duration: Int = 60,
        calories: Int? = 450
    ) -> WorkoutSummary {
        WorkoutSummary(
            hasWorkout: true,
            primaryWorkoutType: .running,
            title: "Running",
            workoutCount: 1,
            totalDurationMinutes: duration,
            totalActiveCalories: calories,
            intensity: demand == .high ? .high : .moderate,
            demand: demand,
            latestWorkoutStart: targetDate,
            latestWorkoutEnd: targetDate,
            nutritionAdvice: "Aim for protein in your next meal.",
            hydrationAdviceMl: hydrationMl,
            explanation: "Running added training volume today.",
            confidence: calories == nil ? .moderate : .high,
            sourceSummary: "Based on synced workouts."
        )
    }

    private func recovery(status: RecoveryStatus, score: Int) -> RecoverySummary {
        RecoverySummary(
            score: score,
            status: status,
            title: "Recovery",
            explanation: "Recovery context.",
            recommendedTraining: "Train steady.",
            recommendedNutrition: "Eat steadily.",
            confidence: .moderate,
            contributingFactors: [],
            missingSignals: []
        )
    }
}
