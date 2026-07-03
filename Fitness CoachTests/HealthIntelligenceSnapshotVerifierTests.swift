//
//  HealthIntelligenceSnapshotVerifierTests.swift
//  Fitness CoachTests
//

import XCTest
@testable import Fitness_Coach

final class HealthIntelligenceSnapshotVerifierTests: XCTestCase {

    func testBuildReportSummarizesSnapshotWithoutSensitiveDetail() {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(secondsFromGMT: 0) ?? .gmt
        let day = calendar.date(from: DateComponents(year: 2026, month: 7, day: 3))!

        let snapshot = HealthIntelligenceSnapshot(
            date: day,
            recovery: RecoverySummary(
                score: 72,
                status: .moderate,
                title: "Moderate recovery",
                explanation: "Sleep was shorter than usual.",
                recommendedTraining: "Train steady.",
                recommendedNutrition: "Eat steadily.",
                confidence: .moderate,
                contributingFactors: [
                    RecoveryContributingFactor(
                        signal: .hrv,
                        impact: .negative,
                        detail: "HRV 42ms vs baseline 55ms"
                    )
                ],
                missingSignals: []
            ),
            workout: WorkoutSummary(
                hasWorkout: true,
                primaryWorkoutType: .running,
                title: "Running",
                workoutCount: 1,
                totalDurationMinutes: 45,
                totalActiveCalories: 400,
                intensity: .moderate,
                demand: .moderate,
                latestWorkoutStart: day,
                latestWorkoutEnd: day,
                nutritionAdvice: "Protein soon.",
                hydrationAdviceMl: 500,
                explanation: "Running added volume.",
                confidence: .high,
                sourceSummary: "Synced workouts."
            ),
            activity: ActivitySummary(steps: 8_000, activeEnergyKcal: 400, exerciseMinutes: 40),
            nutritionAdjustment: AdaptiveNutritionSummary(
                proteinRecommendationGrams: 30,
                suggestedProteinRemaining: 20,
                waterIncreaseMl: 250,
                suggestedWaterRemainingMl: 500,
                calorieAdvice: "Stay steady.",
                shouldChangeTarget: false,
                suggestedCalorieAdjustment: 0,
                adjustmentReason: "",
                priority: 4,
                confidence: .moderate,
                missingSignals: []
            ),
            weeklyReview: nil,
            planConfidence: PlanHealthConfidence(score: 0.75, label: "Moderate"),
            nextBestAction: NextBestAction(
                id: "hydrate",
                title: "Drink water",
                message: "You are behind on water.",
                ctaTitle: "Add water",
                destination: .addWater,
                priority: 3,
                reason: .hydration,
                createdAt: day,
                expiresAt: nil
            )
        )

        let trainingLoad = TrainingLoadSummary(
            status: .normal,
            todayLoad: 55,
            sevenDayLoad: 220,
            twentyEightDayAverageWeeklyLoad: 200,
            loadRatio: 1.1,
            workoutDays7d: 3,
            workoutDays28d: 10,
            explanation: "Training load is in range.",
            confidence: .moderate,
            missingSignals: []
        )

        let report = HealthIntelligenceSnapshotVerifier.buildReport(
            snapshot: snapshot,
            trainingLoad: trainingLoad,
            calendar: calendar
        )

        XCTAssertEqual(report.dayKey, "2026-07-03")
        XCTAssertEqual(report.recoveryStatus, "moderate")
        XCTAssertEqual(report.recoveryScore, "72")
        XCTAssertEqual(report.recoveryFactorSummary, ["hrv:negative"])
        XCTAssertFalse(report.recoveryFactorSummary.joined().contains("42"))
        XCTAssertEqual(report.workoutSummary, "Running (1 workouts, 45m)")
        XCTAssertEqual(report.trainingLoadStatus, "normal")
        XCTAssertEqual(report.adaptiveNutritionPriority, 4)
        XCTAssertEqual(report.nextBestActionReason, "hydration")
        XCTAssertFalse(report.weeklyReviewAvailable)
        XCTAssertEqual(report.planConfidenceLabel, "Moderate")
    }

    #if DEBUG
    func testAppContainerVerifyTodaySnapshotProducesReport() async throws {
        let container = try AppContainer(inMemory: true)
        let report = await container.verifyTodayHealthIntelligenceSnapshot()
        XCTAssertFalse(report.dayKey.isEmpty)
        XCTAssertFalse(report.recoveryStatus.isEmpty)
        XCTAssertFalse(report.nextBestActionTitle.isEmpty)
    }
    #endif
}
