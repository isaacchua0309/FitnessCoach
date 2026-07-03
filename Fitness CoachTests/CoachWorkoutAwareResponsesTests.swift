//
//  CoachWorkoutAwareResponsesTests.swift
//  Fitness CoachTests
//

import XCTest
@testable import Fitness_Coach

@MainActor
final class CoachWorkoutAwareResponsesTests: XCTestCase {

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

    func testMealAdviceAfterWorkoutIncludesPostWorkoutProteinGuidance() throws {
        let harness = try FitnessActionCenterTestSupport.makeHarness(referenceNow: referenceDay)
        _ = try harness.seedProfile(ownerUID: "coach-workout-aware")

        let log = try harness.dailyLogService.getTodayLog()
        let health = workoutDayHealthContext

        let message = CoachResponseBuilder.mealAdvice(
            log: log,
            profile: try harness.profileService.getCurrentProfile(),
            hasWorkoutToday: true,
            healthIntelligence: health,
            intent: .nutritionAdvice,
            assistantMessage: nil
        )

        XCTAssertTrue(message.contains("After today's high-demand workout"))
        XCTAssertTrue(message.contains("Aim for about 35g protein"))
        XCTAssertTrue(message.contains("350ml extra water"))
    }

    func testMealAdviceOnLowRecoveryUsesLimitedRecoveryGuidance() throws {
        let harness = try FitnessActionCenterTestSupport.makeHarness(referenceNow: referenceDay)
        _ = try harness.seedProfile(ownerUID: "coach-low-recovery")

        let log = try harness.dailyLogService.getTodayLog()
        let health = lowRecoveryHealthContext

        let message = CoachResponseBuilder.mealAdvice(
            log: log,
            profile: try harness.profileService.getCurrentProfile(),
            hasWorkoutToday: false,
            healthIntelligence: health,
            intent: .mealDecision,
            assistantMessage: nil
        )

        XCTAssertTrue(message.contains("Recovery looks limited today"))
        XCTAssertTrue(message.contains("protein-forward"))
    }

    func testWorkoutAdviceOnLowRecoveryIncludesRecoveryAndTrainingLoadContext() {
        let message = CoachResponseBuilder.workoutAdviceResponse(
            hasWorkoutToday: false,
            healthIntelligence: lowRecoveryHealthContext,
            assistantMessage: nil
        )

        XCTAssertTrue(message.contains("Recovery looks limited today"))
        XCTAssertTrue(message.contains("training load looks elevated"))
    }

    func testMealAdviceWithoutHealthDataUsesStandardFallback() throws {
        let harness = try FitnessActionCenterTestSupport.makeHarness(referenceNow: referenceDay)
        _ = try harness.seedProfile(ownerUID: "coach-no-health")

        let log = try harness.dailyLogService.getTodayLog()
        let nutrition = DailyNutritionSummaryBuilder.build(from: log)

        let message = CoachResponseBuilder.mealAdvice(
            log: log,
            profile: try harness.profileService.getCurrentProfile(),
            hasWorkoutToday: false,
            healthIntelligence: nil,
            intent: .nutritionAdvice,
            assistantMessage: nil
        )

        XCTAssertTrue(message.contains("\(nutrition.remaining.calories) kcal left"))
        XCTAssertFalse(message.contains("Recovery looks limited"))
        XCTAssertFalse(message.contains("After today's"))
    }

    func testMissingSnapshotDoesNotBreakCoachContextPreparation() async throws {
        let harness = try FitnessActionCenterTestSupport.makeHarness(referenceNow: referenceDay)
        _ = try harness.seedProfile(ownerUID: "coach-missing-snapshot")

        let snapshotProvider = MockCoachMissingSnapshotProvider()
        snapshotProvider.snapshot = nil

        let builder = CoachContextPacketV2Builder(
            dailyLogService: harness.dailyLogService,
            userProfileService: harness.profileService,
            healthActivityQuery: harness.healthActivityQuery,
            healthIntelligenceSnapshotProvider: snapshotProvider,
            dateProvider: harness.base.dateProvider,
            calendar: calendar,
            loadHealthIntelligence: { true }
        )

        let packet = await builder.makeContext(recentMessages: [])

        XCTAssertNil(packet.healthIntelligence)
        XCTAssertNotNil(packet.today)
    }

    func testWorkoutAwareHealthIntelligenceAppearsInPromptContext() throws {
        let health = workoutDayHealthContext
        let packet = CoachContextPacketV2TestFixtures.withHealthIntelligence(health)

        let prompt = health.toPromptContext(calendar: calendar)

        XCTAssertNotNil(packet.healthIntelligence)
        XCTAssertEqual(packet.healthIntelligence?.workoutDemand, WorkoutDemand.high.rawValue)
        XCTAssertTrue(prompt.contains("Workout: completed"))
        XCTAssertTrue(prompt.contains("Demand: high"))
        XCTAssertTrue(prompt.contains("Protein recommendation: 35g"))
    }

    func testMealAdviceRemovesRedundantWorkoutQuestionWhenHealthKnowsWorkout() {
        let message = CoachResponseBuilder.mealAdvice(
            log: nil,
            profile: nil,
            hasWorkoutToday: true,
            healthIntelligence: workoutDayHealthContext,
            intent: .nutritionAdvice,
            assistantMessage: "Did you work out today? Try a balanced meal with protein."
        )

        XCTAssertFalse(message.lowercased().contains("did you work out today"))
        XCTAssertTrue(message.contains("balanced meal"))
    }

    func testDailyBriefIncludesConciseHealthInsight() {
        let nutrition = DailyNutritionSummaryBuilder.build(
            from: DailyNutritionSummaryTestFixtures.baselineLog
        )

        let brief = DailyBriefBuilder.todayBrief(
            nutrition: nutrition,
            hasWorkoutToday: true,
            trainingFrequency: 4,
            healthIntelligence: workoutDayHealthContext
        )

        XCTAssertTrue(
            brief.priorities.contains {
                $0.contains("high-demand workout") || $0.contains("protein and hydration")
            }
        )
        XCTAssertTrue(brief.recommendation.contains("protein"))
    }

    // MARK: - Fixtures

    private var workoutDayHealthContext: CoachHealthIntelligenceContext {
        CoachHealthIntelligenceContextBuilder.build(
            from: HealthIntelligenceSnapshot(
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
                nextBestAction: .none
            )
        )
    }

    private var lowRecoveryHealthContext: CoachHealthIntelligenceContext {
        CoachHealthIntelligenceContextBuilder.build(
            from: HealthIntelligenceSnapshot(
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
            ),
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
    }
}

private final class MockCoachMissingSnapshotProvider: HealthIntelligenceSnapshotServing, @unchecked Sendable {
    var snapshot: HealthIntelligenceSnapshot?

    func refreshTodaySnapshot(calendar: Calendar) async {}

    func loadTodaySnapshot(for date: Date, calendar: Calendar) async -> HealthIntelligenceSnapshot? {
        snapshot
    }
}
