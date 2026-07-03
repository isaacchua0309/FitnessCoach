//
//  CoachHealthContextStatusTests.swift
//  Fitness CoachTests
//

import XCTest
@testable import Fitness_Coach

final class CoachHealthContextStatusTests: XCTestCase {

    private var calendar: Calendar {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(secondsFromGMT: 0)!
        return calendar
    }

    private var now: Date {
        calendar.date(from: DateComponents(year: 2026, month: 7, day: 3, hour: 12))!
    }

    private var referenceDay: Date {
        calendar.startOfDay(for: now)
    }

    func testNoHealthPermissionContextIsUnavailable() {
        let context = buildContext(
            snapshot: connectHealthSnapshot,
            availability: deniedAvailability,
            awarenessAvailable: false
        )

        XCTAssertEqual(context.healthContextStatus, .unavailable)
        XCTAssertTrue(context.availableSignals.isEmpty)
        XCTAssertTrue(context.missingSignals.contains("Apple Health connection"))
        XCTAssertTrue(context.toPromptContext(calendar: calendar).contains("Workout data: unavailable."))
        XCTAssertTrue(context.toPromptContext(calendar: calendar).contains("Steps data: unavailable."))
        XCTAssertTrue(context.toPromptContext(calendar: calendar).contains(CoachHealthContextInstruction.doNotAssumeMissingData))
    }

    func testPartialPermissionContextIsPartialWithLimitedConfidence() {
        let context = buildContext(
            snapshot: sparseSnapshot,
            availability: partialAvailability,
            awarenessAvailable: true
        )

        XCTAssertEqual(context.healthContextStatus, .partial)
        XCTAssertTrue(context.availableSignals.contains("steps"))
        XCTAssertTrue(context.missingSignals.contains("sleep") || context.missingSignals.contains("HRV"))
        XCTAssertEqual(context.healthDataConfidenceLabel, FormaProductCopy.HealthIntelligence.partialDataLabel)
    }

    func testWorkoutsOnlyContextDoesNotClaimSteps() {
        let context = buildContext(
            snapshot: workoutsOnlySnapshot,
            availability: workoutsOnlyAvailability,
            awarenessAvailable: true
        )

        XCTAssertTrue(context.availableSignals.contains("workouts"))
        XCTAssertFalse(context.availableSignals.contains("steps"))
        XCTAssertTrue(context.workoutCompletedToday)
        XCTAssertNil(context.stepsToday)

        let prompt = context.toPromptContext(calendar: calendar)
        XCTAssertTrue(prompt.contains("Workout: completed"))
        XCTAssertTrue(prompt.contains("Steps data: unavailable."))
        XCTAssertFalse(prompt.contains("none logged today"))
    }

    func testStepsOnlyContextDoesNotClaimWorkout() {
        let context = buildContext(
            snapshot: stepsOnlySnapshot,
            availability: stepsOnlyAvailability,
            awarenessAvailable: true
        )

        XCTAssertTrue(context.availableSignals.contains("steps"))
        XCTAssertFalse(context.availableSignals.contains("workouts"))
        XCTAssertFalse(context.workoutCompletedToday)
        XCTAssertEqual(context.stepsToday, 8_000)

        let prompt = context.toPromptContext(calendar: calendar)
        XCTAssertTrue(prompt.contains("8,000 steps"))
        XCTAssertTrue(prompt.contains("Workout data: unavailable."))
        XCTAssertFalse(prompt.lowercased().contains("did not work out"))
    }

    func testStaleHealthDataContextStatusIsStale() {
        let staleSync = now.addingTimeInterval(-(25 * 60 * 60))
        let context = buildContext(
            snapshot: activitySnapshot,
            availability: readableAvailability,
            lastHealthSyncAt: staleSync,
            awarenessAvailable: true
        )

        XCTAssertEqual(context.healthContextStatus, .stale)
        XCTAssertEqual(context.lastHealthSyncAt, staleSync)
        XCTAssertEqual(context.healthDataConfidenceLabel, "Stale estimate")

        let prompt = context.toPromptContext(calendar: calendar)
        XCTAssertTrue(prompt.contains("Health context status: stale."))
        XCTAssertTrue(prompt.contains("Last health sync:"))
    }

    func testLowRecoveryConfidenceUsesLimitedEstimateLabel() {
        let context = buildContext(
            snapshot: limitedRecoverySnapshot,
            availability: readableAvailability,
            awarenessAvailable: true
        )

        XCTAssertEqual(context.recoveryConfidence, "limited")
        XCTAssertNil(context.recoveryScore)
        XCTAssertEqual(context.healthDataConfidenceLabel, FormaProductCopy.HealthIntelligence.limitedEstimateLabel)

        let prompt = context.toPromptContext(calendar: calendar)
        XCTAssertFalse(prompt.contains("Estimated recovery score"))
        XCTAssertTrue(prompt.contains("limited confidence"))
    }

    func testUnavailableSnapshotStillIncludesInstructionAndStatus() async {
        let provider = MockCoachHealthIntelligenceSnapshotService()
        provider.snapshot = nil

        let activity = await CoachAIActivityContextResolver.resolve(
            date: referenceDay,
            snapshotProvider: provider,
            healthActivityQuery: emptyHealthActivityQuery,
            loadHealthIntelligence: { true },
            calendar: calendar
        )

        XCTAssertNotNil(activity.healthIntelligence)
        XCTAssertEqual(activity.healthIntelligence?.healthContextStatus, .unavailable)
        XCTAssertFalse(activity.healthIntelligenceAwarenessAvailable)
    }

    func testConnectHealthSnapshotKeepsContextButDisablesAwareness() async {
        let provider = MockCoachHealthIntelligenceSnapshotService()
        provider.snapshot = connectHealthSnapshot

        let activity = await CoachAIActivityContextResolver.resolve(
            date: referenceDay,
            snapshotProvider: provider,
            healthActivityQuery: emptyHealthActivityQuery,
            loadHealthIntelligence: { true },
            resolveInput: CoachAIActivityContextResolver.ResolveInput(
                availability: deniedAvailability
            ),
            calendar: calendar
        )

        XCTAssertNotNil(activity.healthIntelligence)
        XCTAssertFalse(activity.healthIntelligenceAwarenessAvailable)
        XCTAssertEqual(activity.healthIntelligence?.healthContextStatus, .unavailable)
    }

    // MARK: - Helpers

    private func buildContext(
        snapshot: HealthIntelligenceSnapshot,
        availability: HealthDataAvailability?,
        baseline: HealthBaselineContext? = nil,
        lastHealthSyncAt: Date? = nil,
        awarenessAvailable: Bool
    ) -> CoachHealthIntelligenceContext {
        CoachHealthIntelligenceContextBuilder.build(
            from: snapshot,
            input: CoachHealthIntelligenceContextBuilder.BuildInput(
                availability: availability,
                baseline: baseline,
                lastHealthSyncAt: lastHealthSyncAt,
                isAppleHealthConnected: awarenessAvailable,
                awarenessAvailable: awarenessAvailable,
                now: now
            ),
            calendar: calendar
        )
    }

    private var emptyHealthActivityQuery: HealthActivityQueryService {
        HealthActivityQueryService(
            workoutReader: MockHealthKitWorkoutReader(workouts: []),
            stepReader: MockHealthKitStepReader(stepCount: 0),
            repositoryReadRoutingEnabled: false
        )
    }

    // MARK: - Fixtures

    private var readableAvailability: HealthDataAvailability {
        HealthDataAvailability(
            isHealthDataAvailable: true,
            permissionStatus: .uniform(.available, isHealthDataAvailable: true),
            cachedDayCount: 7
        )
    }

    private var deniedAvailability: HealthDataAvailability {
        HealthDataAvailability(
            isHealthDataAvailable: true,
            permissionStatus: .uniform(.denied, isHealthDataAvailable: true),
            cachedDayCount: 0
        )
    }

    private var partialAvailability: HealthDataAvailability {
        var access: [HealthSignalKind: HealthSignalAccess] = [:]
        for signal in HealthSignalKind.allCases {
            access[signal] = signal == .stepCount ? .available : .denied
        }
        return HealthDataAvailability(
            isHealthDataAvailable: true,
            permissionStatus: HealthPermissionStatus(
                isHealthDataAvailable: true,
                signalAccess: access,
                resolvedAt: now
            ),
            cachedDayCount: 5
        )
    }

    private var workoutsOnlyAvailability: HealthDataAvailability {
        var access: [HealthSignalKind: HealthSignalAccess] = [:]
        for signal in HealthSignalKind.allCases {
            access[signal] = signal == .workout ? .available : .denied
        }
        return HealthDataAvailability(
            isHealthDataAvailable: true,
            permissionStatus: HealthPermissionStatus(
                isHealthDataAvailable: true,
                signalAccess: access,
                resolvedAt: now
            ),
            cachedDayCount: 10
        )
    }

    private var stepsOnlyAvailability: HealthDataAvailability {
        var access: [HealthSignalKind: HealthSignalAccess] = [:]
        for signal in HealthSignalKind.allCases {
            access[signal] = signal == .stepCount ? .available : .denied
        }
        return HealthDataAvailability(
            isHealthDataAvailable: true,
            permissionStatus: HealthPermissionStatus(
                isHealthDataAvailable: true,
                signalAccess: access,
                resolvedAt: now
            ),
            cachedDayCount: 7
        )
    }

    private var connectHealthSnapshot: HealthIntelligenceSnapshot {
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
                message: "Enable Apple Health",
                ctaTitle: "Connect",
                destination: .none,
                priority: 1,
                reason: .connectHealth,
                createdAt: referenceDay,
                expiresAt: nil
            )
        )
    }

    private var sparseSnapshot: HealthIntelligenceSnapshot {
        HealthIntelligenceSnapshot(
            date: referenceDay,
            recovery: RecoverySummary(
                score: nil,
                status: .unknown,
                title: "Recovery forming",
                explanation: "Limited signals",
                recommendedTraining: "Use how you feel",
                recommendedNutrition: "Keep logging",
                confidence: .low,
                contributingFactors: [],
                missingSignals: [.sleep, .hrv]
            ),
            workout: nil,
            activity: ActivitySummary(steps: 4_500, activeEnergyKcal: nil, exerciseMinutes: nil),
            nutritionAdjustment: .none,
            weeklyReview: nil,
            planConfidence: .unknown,
            nextBestAction: .none
        )
    }

    private var workoutsOnlySnapshot: HealthIntelligenceSnapshot {
        HealthIntelligenceSnapshot(
            date: referenceDay,
            recovery: RecoverySummary(
                score: 70,
                status: .moderate,
                title: "Moderate",
                explanation: "Workout logged",
                recommendedTraining: "Steady",
                recommendedNutrition: "Protein",
                confidence: .moderate,
                contributingFactors: [],
                missingSignals: [.sleep, .hrv]
            ),
            workout: WorkoutSummary(
                hasWorkout: true,
                primaryWorkoutType: .strength,
                title: "Strength training",
                workoutCount: 1,
                totalDurationMinutes: 45,
                totalActiveCalories: 300,
                intensity: .moderate,
                demand: .moderate,
                latestWorkoutStart: referenceDay,
                latestWorkoutEnd: referenceDay,
                nutritionAdvice: "Refuel with protein",
                hydrationAdviceMl: 500,
                explanation: "Synced workout",
                confidence: .high,
                sourceSummary: "Apple Health"
            ),
            activity: ActivitySummary(steps: nil, activeEnergyKcal: nil, exerciseMinutes: nil),
            nutritionAdjustment: .none,
            weeklyReview: nil,
            planConfidence: PlanHealthConfidence(score: 0.5, label: "Moderate"),
            nextBestAction: .none
        )
    }

    private var stepsOnlySnapshot: HealthIntelligenceSnapshot {
        HealthIntelligenceSnapshot(
            date: referenceDay,
            recovery: RecoverySummary(
                score: 60,
                status: .moderate,
                title: "Moderate",
                explanation: "Activity only",
                recommendedTraining: "Steady",
                recommendedNutrition: "Protein",
                confidence: .moderate,
                contributingFactors: [],
                missingSignals: [.sleep, .hrv]
            ),
            workout: .noWorkout,
            activity: ActivitySummary(steps: 8_000, activeEnergyKcal: 400, exerciseMinutes: 30),
            nutritionAdjustment: .none,
            weeklyReview: nil,
            planConfidence: PlanHealthConfidence(score: 0.5, label: "Moderate"),
            nextBestAction: .none
        )
    }

    private var activitySnapshot: HealthIntelligenceSnapshot {
        HealthIntelligenceSnapshot(
            date: referenceDay,
            recovery: RecoverySummary(
                score: 60,
                status: .moderate,
                title: "Moderate",
                explanation: "Activity available",
                recommendedTraining: "Steady",
                recommendedNutrition: "Protein",
                confidence: .moderate,
                contributingFactors: [],
                missingSignals: []
            ),
            workout: .noWorkout,
            activity: ActivitySummary(steps: 8_000, activeEnergyKcal: 400, exerciseMinutes: 30),
            nutritionAdjustment: .none,
            weeklyReview: nil,
            planConfidence: PlanHealthConfidence(score: 0.5, label: "Moderate"),
            nextBestAction: .none
        )
    }

    private var limitedRecoverySnapshot: HealthIntelligenceSnapshot {
        HealthIntelligenceSnapshot(
            date: referenceDay,
            recovery: RecoverySummary(
                score: 72,
                status: .ready,
                title: "Ready to train",
                explanation: "Limited signals",
                recommendedTraining: "Train as planned",
                recommendedNutrition: "Stay on plan",
                confidence: .low,
                contributingFactors: [],
                missingSignals: [.hrv]
            ),
            workout: nil,
            activity: ActivitySummary(steps: 7_000, activeEnergyKcal: 350, exerciseMinutes: 25),
            nutritionAdjustment: .none,
            weeklyReview: nil,
            planConfidence: .unknown,
            nextBestAction: .none
        )
    }
}
