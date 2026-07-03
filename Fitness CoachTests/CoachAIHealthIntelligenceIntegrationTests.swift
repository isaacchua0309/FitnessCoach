//
//  CoachAIHealthIntelligenceIntegrationTests.swift
//  Fitness CoachTests
//

import XCTest
@testable import Fitness_Coach

@MainActor
final class CoachAIHealthIntelligenceIntegrationTests: XCTestCase {

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

    func testResolverUsesSnapshotWorkoutSignalsWithoutFallbackQuery() async {
        let snapshotProvider = MockCoachHealthIntelligenceSnapshotService()
        snapshotProvider.snapshot = workoutDaySnapshot

        let activity = await CoachAIActivityContextResolver.resolve(
            date: referenceDay,
            snapshotProvider: snapshotProvider,
            healthActivityQuery: failingHealthActivityQuery,
            loadHealthIntelligence: { true },
            calendar: calendar
        )

        XCTAssertEqual(snapshotProvider.loadCallCount, 1)
        XCTAssertTrue(activity.hasWorkoutToday)
        XCTAssertEqual(activity.workoutsToday, 1)
        XCTAssertEqual(activity.stepsOverride, 9_120)
        XCTAssertTrue(activity.healthIntelligenceAwarenessAvailable)
        XCTAssertNotNil(activity.healthIntelligence)
        XCTAssertEqual(activity.healthIntelligence?.nextBestActionTitle, "Log protein")
    }

    func testResolverFallsBackWhenSnapshotUnavailable() async {
        let snapshotProvider = MockCoachHealthIntelligenceSnapshotService()
        snapshotProvider.snapshot = nil

        let query = HealthActivityQueryService(
            workoutReader: MockHealthKitWorkoutReader(workouts: [
                HealthWorkoutRecord(
                    id: UUID(),
                    activityName: "Strength Training",
                    startDate: referenceDay.addingTimeInterval(3_600),
                    endDate: referenceDay.addingTimeInterval(6_600),
                    durationMinutes: 55,
                    activeCalories: 320
                )
            ]),
            stepReader: MockHealthKitStepReader(stepCount: 0),
            repositoryReadRoutingEnabled: false
        )

        let activity = await CoachAIActivityContextResolver.resolve(
            date: referenceDay,
            snapshotProvider: snapshotProvider,
            healthActivityQuery: query,
            loadHealthIntelligence: { true },
            calendar: calendar
        )

        XCTAssertEqual(snapshotProvider.loadCallCount, 1)
        XCTAssertTrue(activity.hasWorkoutToday)
        XCTAssertEqual(activity.workoutsToday, 1)
        XCTAssertNil(activity.healthIntelligence)
        XCTAssertFalse(activity.healthIntelligenceAwarenessAvailable)
    }

    func testResolverSkipsSnapshotWhenHealthIntelligenceDisabled() async {
        let snapshotProvider = MockCoachHealthIntelligenceSnapshotService()
        snapshotProvider.snapshot = workoutDaySnapshot

        let query = HealthActivityQueryService(
            workoutReader: MockHealthKitWorkoutReader(workouts: []),
            stepReader: MockHealthKitStepReader(stepCount: 0),
            repositoryReadRoutingEnabled: false
        )

        let activity = await CoachAIActivityContextResolver.resolve(
            date: referenceDay,
            snapshotProvider: snapshotProvider,
            healthActivityQuery: query,
            loadHealthIntelligence: { false },
            calendar: calendar
        )

        XCTAssertEqual(snapshotProvider.loadCallCount, 0)
        XCTAssertFalse(activity.hasWorkoutToday)
        XCTAssertNil(activity.healthIntelligence)
    }

    func testConnectHealthSnapshotDoesNotClaimHealthAwareness() async {
        let snapshotProvider = MockCoachHealthIntelligenceSnapshotService()
        snapshotProvider.snapshot = HealthIntelligenceSnapshot(
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

        let activity = await CoachAIActivityContextResolver.resolve(
            date: referenceDay,
            snapshotProvider: snapshotProvider,
            healthActivityQuery: failingHealthActivityQuery,
            loadHealthIntelligence: { true },
            calendar: calendar
        )

        XCTAssertFalse(activity.healthIntelligenceAwarenessAvailable)
        XCTAssertNil(activity.healthIntelligence)
    }

    func testCoachContextBuilderIncludesHealthIntelligenceInAIContext() throws {
        let harness = try FitnessActionCenterTestSupport.makeHarness(referenceNow: referenceDay)
        _ = try harness.seedProfile(ownerUID: "coach-hi-user")

        let builder = CoachContextBuilder(
            dailyLogReader: harness.dailyLogService,
            userProfileReader: harness.profileService,
            actionCenter: harness.actionCenter
        )

        let activity = CoachAIActivityContext(
            workoutsToday: 1,
            hasWorkoutToday: true,
            stepsOverride: 9_120,
            healthIntelligence: CoachHealthIntelligenceContextBuilder.build(
                from: workoutDaySnapshot
            ),
            healthIntelligenceAwarenessAvailable: true
        )

        let context = builder.makeContext(recentMessages: [], activity: activity)

        XCTAssertTrue(context.healthIntelligenceAwarenessAvailable)
        XCTAssertEqual(context.todaySummary?.workoutsToday, 0)
        XCTAssertEqual(context.healthIntelligence?.workoutDemand, WorkoutDemand.high.rawValue)
        XCTAssertEqual(context.healthIntelligence?.recoveryStatus, RecoveryStatus.moderate.rawValue)
    }

    func testCoachContextBuilderPreservesLegacyWorkoutsTodayParameter() throws {
        let harness = try FitnessActionCenterTestSupport.makeHarness(referenceNow: referenceDay)
        _ = try harness.seedProfile(ownerUID: "coach-hi-user")

        let builder = CoachContextBuilder(
            dailyLogReader: harness.dailyLogService,
            userProfileReader: harness.profileService,
            actionCenter: harness.actionCenter
        )

        let context = builder.makeContext(
            recentMessages: [],
            activity: CoachAIActivityContext(workoutsToday: 0),
            workoutsToday: 2
        )

        XCTAssertEqual(context.todaySummary?.workoutsToday, 2)
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

    private var failingHealthActivityQuery: HealthActivityQueryService {
        HealthActivityQueryService(
            workoutReader: FailingHealthKitWorkoutReader(),
            stepReader: FailingHealthKitStepReader(),
            repositoryReadRoutingEnabled: false
        )
    }
}

// MARK: - Mocks

private final class MockCoachHealthIntelligenceSnapshotService: HealthIntelligenceSnapshotServing, @unchecked Sendable {
    var snapshot: HealthIntelligenceSnapshot?
    private(set) var loadCallCount = 0

    func refreshTodaySnapshot(calendar: Calendar) async {}

    func loadTodaySnapshot(for date: Date, calendar: Calendar) async -> HealthIntelligenceSnapshot? {
        loadCallCount += 1
        return snapshot
    }
}

private struct FailingHealthKitWorkoutReader: HealthKitWorkoutReading {
    func fetchWorkouts(from startDate: Date, to endDate: Date) async throws -> [HealthWorkoutRecord] {
        XCTFail("HealthActivityQueryService should not be queried when snapshot is available")
        return []
    }
}

private struct FailingHealthKitStepReader: HealthKitStepReading {
    func fetchStepCount(from startDate: Date, to endDate: Date) async throws -> Int {
        XCTFail("HealthActivityQueryService should not be queried when snapshot is available")
        return 0
    }
}
