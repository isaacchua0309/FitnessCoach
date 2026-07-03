//
//  CoachHealthIntelligenceContextBuilderTests.swift
//  Fitness CoachTests
//

import XCTest
@testable import Fitness_Coach

final class CoachHealthIntelligenceContextBuilderTests: XCTestCase {

    private var referenceDay: Date {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(secondsFromGMT: 0) ?? .gmt
        return calendar.startOfDay(
            for: calendar.date(from: DateComponents(year: 2026, month: 7, day: 3))!
        )
    }

    func testRecoveryLimitedWordingWhenSleepAndHeartSignalsMissing() {
        let recovery = RecoverySummary(
            score: nil,
            status: .unknown,
            title: "Recovery unclear",
            explanation: "Sleep and HRV are missing.",
            recommendedTraining: "Use how you feel today.",
            recommendedNutrition: "Stay on your usual plan.",
            confidence: .low,
            contributingFactors: [
                RecoveryContributingFactor(
                    signal: .hrv,
                    impact: .negative,
                    detail: "HRV was below your recent baseline."
                )
            ],
            missingSignals: [.sleep, .hrv]
        )

        let explanation = CoachHealthIntelligenceContextBuilder.coachSafeRecoveryExplanation(from: recovery)

        XCTAssertEqual(
            explanation,
            "Recovery estimate is limited because sleep and heart signals are missing."
        )
    }

    func testRecoveryDoesNotUseContributingFactorMetricLanguage() {
        let recovery = RecoverySummary(
            score: 55,
            status: .low,
            title: "Recovery is low",
            explanation: "HRV was below your recent baseline and sleep was short.",
            recommendedTraining: "Keep today lighter.",
            recommendedNutrition: "Fuel steadily.",
            confidence: .moderate,
            contributingFactors: [
                RecoveryContributingFactor(
                    signal: .hrv,
                    impact: .negative,
                    detail: "HRV 42ms below baseline 58ms"
                )
            ],
            missingSignals: []
        )

        let explanation = CoachHealthIntelligenceContextBuilder.coachSafeRecoveryExplanation(from: recovery)

        XCTAssertFalse(explanation.lowercased().contains("hrv"))
        XCTAssertFalse(explanation.contains("baseline"))
        XCTAssertTrue(explanation.contains("Recovery is low."))
    }

    func testWorkoutSummaryUsesCoachSafeTextWithoutInventingData() {
        let summary = CoachHealthIntelligenceContextBuilder.coachSafeWorkoutSummary(
            from: WorkoutSummary(
                hasWorkout: true,
                primaryWorkoutType: .strength,
                title: "Strength training",
                workoutCount: 1,
                totalDurationMinutes: 50,
                totalActiveCalories: 320,
                intensity: .moderate,
                demand: .high,
                latestWorkoutStart: referenceDay,
                latestWorkoutEnd: referenceDay,
                nutritionAdvice: "Aim for 30–40g protein in your next meal.",
                hydrationAdviceMl: 700,
                explanation: "Strength training added meaningful load today.",
                confidence: .high,
                sourceSummary: "Based on synced workouts. Calorie figures are estimates."
            )
        )

        XCTAssertEqual(
            summary,
            "A strength training workout was logged today. Duration: 50 minutes. Training demand looks high. Aim for 30–40g protein in your next meal."
        )
        XCTAssertFalse(summary?.contains("estimates") ?? true)
    }

    func testWorkoutSummaryNilWhenNoWorkout() {
        XCTAssertNil(CoachHealthIntelligenceContextBuilder.coachSafeWorkoutSummary(from: nil))
        XCTAssertNil(
            CoachHealthIntelligenceContextBuilder.coachSafeWorkoutSummary(
                from: WorkoutSummary.noWorkout
            )
        )
    }

    func testNutritionAdviceUnavailableWhenConfidenceLowAndSignalsMissing() {
        let advice = CoachHealthIntelligenceContextBuilder.coachSafeNutritionAdvice(
            from: AdaptiveNutritionSummary.none
        )

        XCTAssertNil(advice)
    }

    func testTrainingLoadUsesConservativeStatusAndSafeExplanation() {
        let status = CoachHealthIntelligenceContextBuilder.coachSafeTrainingLoadStatus(
            from: TrainingLoadSummary(
                status: .normal,
                todayLoad: 58,
                sevenDayLoad: 245,
                twentyEightDayAverageWeeklyLoad: 220,
                loadRatio: 1.11,
                workoutDays7d: 3,
                workoutDays28d: 11,
                explanation: "Training load is in a normal range for your recent history.",
                confidence: .moderate,
                missingSignals: []
            )
        )

        XCTAssertEqual(
            status,
            "normal — Training load is in a normal range for your recent history."
        )
    }

    func testTrainingLoadUnknownDoesNotInventExplanation() {
        let status = CoachHealthIntelligenceContextBuilder.coachSafeTrainingLoadStatus(from: .unknown)
        XCTAssertEqual(status, "unknown")
    }

    func testNextBestActionReasonHumanized() {
        let reason = CoachHealthIntelligenceContextBuilder.coachSafeNextBestActionReason(
            from: NextBestAction(
                id: "mock",
                title: "Log protein",
                message: "Protein gap after training.",
                ctaTitle: "Log meal",
                destination: .logMeal,
                priority: 2,
                reason: .postWorkoutRecovery,
                createdAt: referenceDay,
                expiresAt: nil
            )
        )

        XCTAssertEqual(reason, "post workout recovery")
    }

    func testMissingSignalsOnlyUsesSnapshotReportedSignals() {
        let recovery = RecoverySummary(
            score: 72,
            status: .moderate,
            title: "Moderate recovery",
            explanation: "Recovery looks acceptable today.",
            recommendedTraining: "Train based on how you feel.",
            recommendedNutrition: "Stay on your usual plan.",
            confidence: .moderate,
            contributingFactors: [],
            missingSignals: [.workouts, .trainingLoad]
        )

        let labels = CoachHealthIntelligenceContextBuilder.plainLanguageMissingSignals(
            recovery: recovery,
            nutrition: .none,
            trainingLoad: .unknown
        )

        XCTAssertTrue(labels.contains("workouts"))
        XCTAssertTrue(labels.contains("training load"))
        XCTAssertFalse(labels.contains("workout logged today"))
    }

    func testMissingSignalsOmitsRedundantHeartSleepLabelsWhenLimitedRecoveryWordingUsed() {
        let recovery = RecoverySummary(
            score: nil,
            status: .unknown,
            title: "Recovery unclear",
            explanation: "Sleep and HRV are missing.",
            recommendedTraining: "Use how you feel today.",
            recommendedNutrition: "Stay on your usual plan.",
            confidence: .low,
            contributingFactors: [],
            missingSignals: [.sleep, .hrv]
        )

        let labels = CoachHealthIntelligenceContextBuilder.plainLanguageMissingSignals(
            recovery: recovery,
            nutrition: .none,
            trainingLoad: .unknown
        )

        XCTAssertFalse(labels.contains("sleep"))
        XCTAssertFalse(labels.contains("HRV"))
    }
}
