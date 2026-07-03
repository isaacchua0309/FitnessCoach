//
//  CoachHealthIntelligenceContextTests.swift
//  Fitness CoachTests
//

import XCTest
@testable import Fitness_Coach

final class CoachHealthIntelligenceContextTests: XCTestCase {

    private var calendar: Calendar {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(secondsFromGMT: 0) ?? .gmt
        return calendar
    }

    private var referenceDay: Date {
        calendar.startOfDay(
            for: calendar.date(from: DateComponents(year: 2026, month: 7, day: 3))!
        )
    }

    func testWorkoutDayContextMapsSummaryFields() {
        let context = CoachHealthIntelligenceContextBuilder.build(
            from: workoutDaySnapshot,
            trainingLoad: .mockNormal
        )

        XCTAssertEqual(context.recoveryStatus, RecoveryStatus.moderate.rawValue)
        XCTAssertEqual(context.recoveryConfidence, "moderate")
        XCTAssertTrue(context.workoutCompletedToday)
        XCTAssertTrue(context.workoutSummaryText?.contains("strength training") ?? false)
        XCTAssertEqual(context.workoutDemand, WorkoutDemand.high.rawValue)
        XCTAssertEqual(context.totalWorkoutMinutesToday, 50)
        XCTAssertEqual(context.totalActiveCaloriesToday, 320)
        XCTAssertEqual(context.stepsToday, 9_120)
        XCTAssertEqual(context.proteinRecommendation, 35)
        XCTAssertEqual(context.hydrationRecommendationMl, 350)
        XCTAssertTrue(context.trainingLoadStatus.hasPrefix("normal"))
        XCTAssertEqual(context.nextBestActionTitle, "Log protein")
        XCTAssertEqual(context.nextBestActionReason, "post workout recovery")
    }

    func testNoHealthDataContextUsesUnknownStatesAndMissingSignals() {
        let context = CoachHealthIntelligenceContextBuilder.build(
            from: noHealthDataSnapshot
        )

        XCTAssertEqual(context.recoveryStatus, RecoveryStatus.unknown.rawValue)
        XCTAssertFalse(context.workoutCompletedToday)
        XCTAssertNil(context.stepsToday)
        XCTAssertNil(context.proteinRecommendation)
        XCTAssertEqual(context.nextBestActionTitle, "Connect Apple Health")
        XCTAssertTrue(context.missingSignals.contains("sleep"))
        XCTAssertTrue(context.missingSignals.contains("HRV"))
        XCTAssertEqual(context.healthDataConfidenceLabel, "Limited estimate")
        XCTAssertTrue(
            context.recoveryExplanation.contains(
                "Recovery estimate is limited because sleep and heart signals are missing."
            )
        )
    }

    func testLowRecoveryContext() {
        let context = CoachHealthIntelligenceContextBuilder.build(
            from: lowRecoverySnapshot,
            trainingLoad: TrainingLoadSummary(
                status: .high,
                todayLoad: 72,
                sevenDayLoad: 280,
                twentyEightDayAverageWeeklyLoad: 220,
                loadRatio: 1.27,
                workoutDays7d: 4,
                workoutDays28d: 12,
                explanation: "Recent load is elevated.",
                confidence: .moderate,
                missingSignals: []
            )
        )

        XCTAssertEqual(context.recoveryStatus, RecoveryStatus.low.rawValue)
        XCTAssertEqual(context.recoveryScore, 48)
        XCTAssertEqual(context.recoveryConfidence, "moderate")
        XCTAssertTrue(context.trainingLoadStatus.hasPrefix("high"))
        XCTAssertEqual(context.nextBestActionTitle, "Prioritize recovery")
        XCTAssertEqual(context.nextBestActionReason, "low recovery")
        XCTAssertTrue(context.recoveryExplanation.contains("Recovery is low."))
    }

    func testMissingSleepAndHRVListsExplicitMissingSignals() {
        let snapshot = HealthIntelligenceSnapshot(
            date: referenceDay,
            recovery: RecoverySummary(
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
                        impact: .limited,
                        detail: "HRV 42ms below baseline 58ms"
                    )
                ],
                missingSignals: [.sleep, .hrv]
            ),
            workout: nil,
            activity: ActivitySummary(steps: 4_000, activeEnergyKcal: 220, exerciseMinutes: 20),
            nutritionAdjustment: .none,
            weeklyReview: nil,
            planConfidence: .unknown,
            nextBestAction: .none
        )

        let context = CoachHealthIntelligenceContextBuilder.build(from: snapshot)
        let prompt = context.toPromptContext(calendar: calendar)

        XCTAssertTrue(context.missingSignals.contains("sleep"))
        XCTAssertTrue(context.missingSignals.contains("HRV"))
        XCTAssertNil(context.recoveryScore)
        XCTAssertTrue(
            context.recoveryExplanation.contains(
                "Recovery estimate is limited because sleep and heart signals are missing."
            )
        )
        XCTAssertFalse(prompt.contains("42ms"))
        XCTAssertFalse(prompt.contains("58ms"))
        XCTAssertFalse(prompt.contains("bpm"))
    }

    func testPromptSummaryDoesNotIncludeRawHeartMetrics() {
        let context = CoachHealthIntelligenceContextBuilder.build(
            from: workoutDaySnapshot,
            trainingLoad: .mockNormal
        )

        let prompt = context.toPromptContext(calendar: calendar)

        XCTAssertTrue(prompt.contains("Health intelligence for 2026-07-03"))
        XCTAssertTrue(prompt.contains("Recovery: moderate"))
        XCTAssertTrue(prompt.contains("Workout: completed"))
        XCTAssertTrue(prompt.contains("9,120 steps"))
        XCTAssertFalse(prompt.lowercased().contains("hrv"))
        XCTAssertFalse(prompt.lowercased().contains("resting heart"))
        XCTAssertFalse(prompt.contains("ms"))
        XCTAssertFalse(prompt.contains("bpm"))
    }

    func testLowConfidenceRecoveryScoreOmittedFromPrompt() {
        let snapshot = HealthIntelligenceSnapshot(
            date: referenceDay,
            recovery: RecoverySummary(
                score: 72,
                status: .ready,
                title: "Ready to train",
                explanation: "Limited signals.",
                recommendedTraining: "Train as planned.",
                recommendedNutrition: "Stay on plan.",
                confidence: .low,
                contributingFactors: [],
                missingSignals: [.hrv]
            ),
            workout: nil,
            activity: .empty,
            nutritionAdjustment: .none,
            weeklyReview: nil,
            planConfidence: .unknown,
            nextBestAction: .none
        )

        let prompt = CoachHealthIntelligenceContextBuilder.build(from: snapshot)
            .toPromptContext(calendar: calendar)

        XCTAssertFalse(prompt.contains("Estimated recovery score"))
        XCTAssertFalse(prompt.contains("72"))
    }

    func testCodableRoundTrip() throws {
        let context = CoachHealthIntelligenceContextBuilder.build(
            from: workoutDaySnapshot,
            trainingLoad: .mockNormal
        )

        let data = try JSONEncoder().encode(context)
        let decoded = try JSONDecoder().decode(CoachHealthIntelligenceContext.self, from: data)

        XCTAssertEqual(decoded, context)
    }

    // MARK: - Fixtures

    private var workoutDaySnapshot: HealthIntelligenceSnapshot {
        HealthIntelligenceSnapshot(
            date: referenceDay,
            recovery: RecoverySummary(
                score: 74,
                status: .moderate,
                title: "Moderate recovery",
                explanation: "Recovery is acceptable after recent training.",
                recommendedTraining: "You can train, but avoid stacking intensity tonight.",
                recommendedNutrition: "Prioritize protein and hydration after your workout.",
                confidence: .moderate,
                contributingFactors: [],
                missingSignals: []
            ),
            workout: WorkoutSummary(
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
                sourceSummary: "Synced workout."
            ),
            activity: ActivitySummary(steps: 9_120, activeEnergyKcal: 560, exerciseMinutes: 52),
            nutritionAdjustment: AdaptiveNutritionSummary(
                proteinRecommendationGrams: 35,
                suggestedProteinRemaining: 28,
                waterIncreaseMl: 350,
                suggestedWaterRemainingMl: 900,
                calorieAdvice: "Keep calories steady and prioritize protein after training.",
                shouldChangeTarget: false,
                suggestedCalorieAdjustment: 0,
                adjustmentReason: "",
                priority: 6,
                confidence: .high,
                missingSignals: []
            ),
            weeklyReview: nil,
            planConfidence: PlanHealthConfidence(score: 0.78, label: "Moderate"),
            nextBestAction: NextBestAction(
                id: "log-protein",
                title: "Log protein",
                message: "You still have meaningful protein left after today's workout.",
                ctaTitle: "Log meal",
                destination: .logMeal,
                priority: 2,
                reason: .postWorkoutRecovery,
                createdAt: referenceDay,
                expiresAt: nil
            )
        )
    }

    private var lowRecoverySnapshot: HealthIntelligenceSnapshot {
        HealthIntelligenceSnapshot(
            date: referenceDay,
            recovery: RecoverySummary(
                score: 48,
                status: .low,
                title: "Recovery is low",
                explanation: "Sleep was short and recent training load is elevated.",
                recommendedTraining: "Keep today lighter and avoid stacking hard sessions.",
                recommendedNutrition: "Prioritize protein, hydration, and steady fueling today.",
                confidence: .moderate,
                contributingFactors: [],
                missingSignals: []
            ),
            workout: nil,
            activity: ActivitySummary(steps: 5_600, activeEnergyKcal: 290, exerciseMinutes: 22),
            nutritionAdjustment: .none,
            weeklyReview: nil,
            planConfidence: PlanHealthConfidence(score: 0.62, label: "Moderate"),
            nextBestAction: NextBestAction(
                id: "recover",
                title: "Prioritize recovery",
                message: "Recovery is low today. Keep movement light and fuel steadily.",
                ctaTitle: "View recovery",
                destination: .viewRecovery,
                priority: 2,
                reason: .lowRecovery,
                createdAt: referenceDay,
                expiresAt: nil
            )
        )
    }

    private var noHealthDataSnapshot: HealthIntelligenceSnapshot {
        HealthIntelligenceSnapshot(
            date: referenceDay,
            recovery: .unknown,
            workout: nil,
            activity: .empty,
            nutritionAdjustment: .none,
            weeklyReview: nil,
            planConfidence: .unknown,
            nextBestAction: NextBestAction(
                id: "connect-health",
                title: "Connect Apple Health",
                message: "Enable Apple Health to unlock recovery and activity insights.",
                ctaTitle: "",
                destination: .none,
                priority: 1,
                reason: .connectHealth,
                createdAt: referenceDay,
                expiresAt: nil
            )
        )
    }
}

private extension TrainingLoadSummary {
    static var mockNormal: TrainingLoadSummary {
        TrainingLoadSummary(
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
    }
}
