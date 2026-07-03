//
//  HealthIntelligenceUIStateTests.swift
//  Fitness CoachTests
//

import XCTest
@testable import Fitness_Coach

final class HealthIntelligenceUIStateTests: XCTestCase {

    private var calendar: Calendar {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(secondsFromGMT: 0)!
        return calendar
    }

    private var now: Date {
        calendar.date(from: DateComponents(year: 2026, month: 7, day: 3, hour: 12))!
    }

    func testAllStateKindsHaveCopyAndFallbackReason() {
        for kind in HealthIntelligenceUIStateKind.allCases {
            let state = HealthIntelligenceUIStateMapper.resolve(
                HealthIntelligenceUIContext(kind: kind, now: now)
            )

            if kind == .ready {
                XCTAssertEqual(state.title, "")
                XCTAssertEqual(state.fallbackReason, .none)
                XCTAssertTrue(state.canShowInsight)
            } else {
                XCTAssertFalse(state.title.isEmpty, "Missing title for \(kind)")
                XCTAssertFalse(state.message.isEmpty, "Missing message for \(kind)")
                XCTAssertNotEqual(state.fallbackReason, .none, "Missing fallback for \(kind)")
            }
        }
    }

    func testLoadingState() {
        let state = resolve(HealthIntelligenceUIContext(isLoading: true))

        assertState(state, kind: .loading, severity: .info, canShowInsight: false, reason: .loading)
        XCTAssertNil(state.primaryActionTitle)
        XCTAssertEqual(state.primaryAction, .none)
    }

    func testLoadingStateWhenSyncing() {
        let state = resolve(HealthIntelligenceUIContext(syncPhase: .syncing))

        assertState(state, kind: .loading, severity: .info, canShowInsight: false, reason: .loading)
    }

    func testReadyState() {
        let state = resolve(
            HealthIntelligenceUIContext(
                availability: readableAvailability,
                snapshot: readySnapshot,
                isAppleHealthConnected: true,
                cachedDayCount: 7
            )
        )

        assertState(state, kind: .ready, severity: .info, canShowInsight: true, reason: .none)
        XCTAssertNil(state.confidenceLabel)
        XCTAssertTrue(state.missingInsightKinds.isEmpty)
    }

    func testNoHealthPermissionState() {
        let state = resolve(
            HealthIntelligenceUIContext(
                availability: deniedAvailability,
                snapshot: connectHealthSnapshot
            )
        )

        assertState(
            state,
            kind: .noHealthPermission,
            severity: .error,
            canShowInsight: false,
            reason: .permissionsRequired
        )
        XCTAssertEqual(state.primaryAction, .connectAppleHealth)
    }

    func testPartialPermissionState() {
        let state = resolve(
            HealthIntelligenceUIContext(
                availability: partialAvailability,
                snapshot: sparseSnapshot,
                isAppleHealthConnected: true,
                cachedDayCount: 3
            )
        )

        assertState(
            state,
            kind: .partialPermission,
            severity: .warning,
            canShowInsight: true,
            reason: .partialPermissions
        )
        XCTAssertEqual(state.primaryAction, .manageHealthPermissions)
        XCTAssertEqual(state.confidenceLabel, FormaProductCopy.HealthIntelligence.partialDataLabel)
    }

    func testHealthKitUnavailableState() {
        let state = resolve(
            HealthIntelligenceUIContext(
                availability: HealthDataAvailability(
                    isHealthDataAvailable: false,
                    permissionStatus: .unavailable(),
                    cachedDayCount: 0
                )
            )
        )

        assertState(
            state,
            kind: .healthKitUnavailable,
            severity: .error,
            canShowInsight: false,
            reason: .healthKitUnavailable
        )
    }

    func testNoWorkoutHistoryState() {
        let state = resolve(
            HealthIntelligenceUIContext(
                availability: readableAvailability,
                snapshot: activityOnlySnapshot,
                baseline: baselineWithoutWorkouts,
                isAppleHealthConnected: true,
                cachedDayCount: 10
            )
        )

        assertState(
            state,
            kind: .noWorkoutHistory,
            severity: .warning,
            canShowInsight: true,
            reason: .noWorkoutHistory
        )
        XCTAssertEqual(state.primaryAction, .openPlan)
        XCTAssertTrue(state.missingInsightKinds.contains(.workouts))
    }

    func testNoSleepDataState() {
        let state = resolve(
            HealthIntelligenceUIContext(
                availability: readableAvailability,
                snapshot: missingSleepSnapshot,
                baseline: baselineMissingSleep,
                isAppleHealthConnected: true,
                cachedDayCount: 14
            )
        )

        assertState(
            state,
            kind: .noSleepData,
            severity: .warning,
            canShowInsight: true,
            reason: .missingSleepData
        )
        XCTAssertTrue(state.missingInsightKinds.contains(.sleep))
    }

    func testNoHeartDataState() {
        let state = resolve(
            HealthIntelligenceUIContext(
                availability: readableAvailability,
                snapshot: missingHeartSnapshot,
                baseline: baselineMissingHeart,
                isAppleHealthConnected: true,
                cachedDayCount: 14
            )
        )

        assertState(
            state,
            kind: .noHeartData,
            severity: .warning,
            canShowInsight: true,
            reason: .missingHeartMetrics
        )
        XCTAssertTrue(
            state.missingInsightKinds.contains(.restingHeartRate)
                || state.missingInsightKinds.contains(.hrv)
        )
    }

    func testNotEnoughBaselineState() {
        let state = resolve(
            HealthIntelligenceUIContext(
                availability: readableAvailability,
                snapshot: emptySnapshot,
                baseline: .empty(for: now),
                isAppleHealthConnected: true,
                cachedDayCount: 2
            )
        )

        assertState(
            state,
            kind: .notEnoughBaseline,
            severity: .warning,
            canShowInsight: false,
            reason: .insufficientBaselineHistory
        )
        XCTAssertEqual(state.primaryAction, .continueLogging)
    }

    func testSyncFailedState() {
        let state = resolve(
            HealthIntelligenceUIContext(
                explicitErrorMessage: "Network unavailable",
                syncPhase: .failed
            )
        )

        assertState(
            state,
            kind: .syncFailed,
            severity: .error,
            canShowInsight: false,
            reason: .syncFailed
        )
        XCTAssertEqual(state.primaryAction, .retrySync)
        XCTAssertTrue(state.message.contains("Network unavailable"))
    }

    func testStaleDataState() {
        let staleSync = now.addingTimeInterval(-(25 * 60 * 60))
        let state = resolve(
            HealthIntelligenceUIContext(
                availability: readableAvailability,
                snapshot: activityOnlySnapshot,
                isAppleHealthConnected: true,
                cachedDayCount: 5,
                lastSuccessfulLocalSyncAt: staleSync
            )
        )

        assertState(
            state,
            kind: .staleData,
            severity: .warning,
            canShowInsight: true,
            reason: .staleLocalCache
        )
        XCTAssertEqual(state.primaryAction, .refreshHealthData)
    }

    func testRemoteSyncDisabledState() {
        let state = resolve(
            HealthIntelligenceUIContext(
                availability: readableAvailability,
                snapshot: emptySnapshot,
                isAppleHealthConnected: true,
                cachedDayCount: 0,
                isRemoteSyncCapabilityEnabled: true,
                isRemoteSyncUserEnabled: false,
                remoteSyncConsentDecision: .optedOut
            )
        )

        assertState(
            state,
            kind: .remoteSyncDisabled,
            severity: .info,
            canShowInsight: false,
            reason: .remoteSyncOptedOut
        )
        XCTAssertEqual(state.primaryAction, .manageHealthDataSync)
        XCTAssertTrue(state.missingInsightKinds.contains(.remoteSync))
    }

    func testUnknownStateWhenSnapshotMissing() {
        let state = resolve(
            HealthIntelligenceUIContext(
                availability: readableAvailability,
                snapshot: nil,
                isAppleHealthConnected: true,
                cachedDayCount: 3
            )
        )

        assertState(
            state,
            kind: .unknown,
            severity: .warning,
            canShowInsight: false,
            reason: .unknown
        )
        XCTAssertEqual(state.secondaryAction, .askCoach)
    }

    func testReadyIncludesLimitedEstimateConfidenceLabel() {
        let state = resolve(
            HealthIntelligenceUIContext(
                availability: readableAvailability,
                snapshot: limitedRecoverySnapshot,
                isAppleHealthConnected: true,
                cachedDayCount: 5
            )
        )

        XCTAssertEqual(state.kind, .ready)
        XCTAssertTrue(state.canShowInsight)
        XCTAssertEqual(state.confidenceLabel, FormaProductCopy.HealthIntelligence.limitedEstimateLabel)
    }

    func testPresentationContextBridgeProducesSameLoadingState() {
        let uiContext = HealthIntelligenceUIContext.from(
            presentationContext: HealthIntelligencePresentationContext(isLoading: true),
            surface: .today,
            now: now
        )

        XCTAssertEqual(HealthIntelligenceUIState.resolve(from: uiContext).kind, .loading)
    }

    func testInsightAvailabilityMarksRemoteSyncMissingWhenOptedOut() {
        let missing = HealthInsightAvailabilityResolver.missing(
            from: HealthIntelligenceUIContext(
                isRemoteSyncCapabilityEnabled: true,
                isRemoteSyncUserEnabled: false
            )
        )

        XCTAssertTrue(missing.contains(where: { $0.kind == .remoteSync }))
    }

    // MARK: - Helpers

    private func resolve(_ context: HealthIntelligenceUIContext) -> HealthIntelligenceUIState {
        var context = context
        context.now = now
        return HealthIntelligenceUIStateMapper.resolve(context)
    }

    private func assertState(
        _ state: HealthIntelligenceUIState,
        kind: HealthIntelligenceUIStateKind,
        severity: HealthIntelligenceUISeverity,
        canShowInsight: Bool,
        reason: HealthFallbackReason,
        file: StaticString = #filePath,
        line: UInt = #line
    ) {
        XCTAssertEqual(state.kind, kind, file: file, line: line)
        XCTAssertEqual(state.severity, severity, file: file, line: line)
        XCTAssertEqual(state.canShowInsight, canShowInsight, file: file, line: line)
        XCTAssertEqual(state.fallbackReason, reason, file: file, line: line)
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
            cachedDayCount: 3
        )
    }

    private var connectHealthSnapshot: HealthIntelligenceSnapshot {
        HealthIntelligenceSnapshot(
            date: now,
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
                createdAt: now,
                expiresAt: nil
            )
        )
    }

    private var emptySnapshot: HealthIntelligenceSnapshot {
        HealthIntelligenceSnapshot(
            date: now,
            recovery: .unknown,
            workout: nil,
            activity: .empty,
            nutritionAdjustment: .none,
            weeklyReview: nil,
            planConfidence: .unknown,
            nextBestAction: NextBestAction(
                id: "",
                title: "",
                message: "",
                ctaTitle: "",
                destination: .none,
                priority: 0,
                reason: .none,
                createdAt: now,
                expiresAt: nil
            )
        )
    }

    private var activityOnlySnapshot: HealthIntelligenceSnapshot {
        HealthIntelligenceSnapshot(
            date: now,
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
            nextBestAction: NextBestAction(
                id: "log-meal",
                title: "Log meal",
                message: "Keep logging",
                ctaTitle: "Log",
                destination: .logMeal,
                priority: 2,
                reason: .nutritionGap,
                createdAt: now,
                expiresAt: nil
            )
        )
    }

    private var sparseSnapshot: HealthIntelligenceSnapshot {
        HealthIntelligenceSnapshot(
            date: now,
            recovery: RecoverySummary(
                score: nil,
                status: .unknown,
                title: "Recovery forming",
                explanation: "Limited signals",
                recommendedTraining: "",
                recommendedNutrition: "",
                confidence: .low,
                contributingFactors: [],
                missingSignals: [.sleep, .hrv]
            ),
            workout: nil,
            activity: ActivitySummary(steps: 4_500, activeEnergyKcal: nil, exerciseMinutes: nil),
            nutritionAdjustment: .none,
            weeklyReview: nil,
            planConfidence: .unknown,
            nextBestAction: NextBestAction(
                id: "log-meal",
                title: "Log meal",
                message: "Keep logging",
                ctaTitle: "Log",
                destination: .logMeal,
                priority: 2,
                reason: .nutritionGap,
                createdAt: now,
                expiresAt: nil
            )
        )
    }

    private var limitedRecoverySnapshot: HealthIntelligenceSnapshot {
        HealthIntelligenceSnapshot(
            date: now,
            recovery: RecoverySummary(
                score: 55,
                status: .moderate,
                title: "Moderate recovery",
                explanation: "Limited estimate",
                recommendedTraining: "Steady pacing",
                recommendedNutrition: "Prioritize protein",
                confidence: .low,
                contributingFactors: [],
                missingSignals: [.sleep]
            ),
            workout: nil,
            activity: ActivitySummary(steps: 8_000, activeEnergyKcal: 400, exerciseMinutes: 35),
            nutritionAdjustment: .none,
            weeklyReview: nil,
            planConfidence: PlanHealthConfidence(score: 0.5, label: "Moderate"),
            nextBestAction: NextBestAction(
                id: "log-water",
                title: "Add water",
                message: "Hydrate",
                ctaTitle: "Add",
                destination: .addWater,
                priority: 2,
                reason: .hydrationGap,
                createdAt: now,
                expiresAt: nil
            )
        )
    }

    private var readySnapshot: HealthIntelligenceSnapshot {
        HealthIntelligenceSnapshot(
            date: now,
            recovery: RecoverySummary(
                score: 82,
                status: .ready,
                title: "Ready",
                explanation: "Recovery looks supportive",
                recommendedTraining: "Train as planned",
                recommendedNutrition: "Keep protein on track",
                confidence: .high,
                contributingFactors: [],
                missingSignals: []
            ),
            workout: WorkoutSummary(
                hasWorkout: true,
                primaryWorkoutType: .strength,
                title: "Strength",
                workoutCount: 1,
                totalDurationMinutes: 45,
                totalActiveCalories: 300,
                intensity: .moderate,
                demand: .moderate,
                latestWorkoutStart: now,
                latestWorkoutEnd: now,
                nutritionAdvice: "Refuel with protein",
                hydrationAdviceMl: 500,
                explanation: "Synced workout",
                confidence: .high,
                sourceSummary: "Apple Health"
            ),
            activity: ActivitySummary(steps: 9_000, activeEnergyKcal: 550, exerciseMinutes: 50),
            nutritionAdjustment: .none,
            weeklyReview: nil,
            planConfidence: PlanHealthConfidence(score: 0.82, label: "Strong"),
            nextBestAction: NextBestAction(
                id: "log-protein",
                title: "Log protein",
                message: "Finish protein target",
                ctaTitle: "Log meal",
                destination: .logMeal,
                priority: 2,
                reason: .postWorkoutRecovery,
                createdAt: now,
                expiresAt: nil
            )
        )
    }

    private var missingSleepSnapshot: HealthIntelligenceSnapshot {
        HealthIntelligenceSnapshot(
            date: now,
            recovery: RecoverySummary(
                score: 58,
                status: .moderate,
                title: "Moderate",
                explanation: "Sleep missing",
                recommendedTraining: "Steady",
                recommendedNutrition: "Protein",
                confidence: .moderate,
                contributingFactors: [],
                missingSignals: [.sleep]
            ),
            workout: .noWorkout,
            activity: ActivitySummary(steps: 7_000, activeEnergyKcal: 350, exerciseMinutes: 25),
            nutritionAdjustment: .none,
            weeklyReview: nil,
            planConfidence: PlanHealthConfidence(score: 0.5, label: "Moderate"),
            nextBestAction: NextBestAction(
                id: "log-meal",
                title: "Log meal",
                message: "Keep logging",
                ctaTitle: "Log",
                destination: .logMeal,
                priority: 2,
                reason: .nutritionGap,
                createdAt: now,
                expiresAt: nil
            )
        )
    }

    private var missingHeartSnapshot: HealthIntelligenceSnapshot {
        HealthIntelligenceSnapshot(
            date: now,
            recovery: RecoverySummary(
                score: 58,
                status: .moderate,
                title: "Moderate",
                explanation: "Heart missing",
                recommendedTraining: "Steady",
                recommendedNutrition: "Protein",
                confidence: .moderate,
                contributingFactors: [],
                missingSignals: [.restingHeartRate, .hrv]
            ),
            workout: .noWorkout,
            activity: ActivitySummary(steps: 7_000, activeEnergyKcal: 350, exerciseMinutes: 25),
            nutritionAdjustment: .none,
            weeklyReview: nil,
            planConfidence: PlanHealthConfidence(score: 0.5, label: "Moderate"),
            nextBestAction: NextBestAction(
                id: "log-meal",
                title: "Log meal",
                message: "Keep logging",
                ctaTitle: "Log",
                destination: .logMeal,
                priority: 2,
                reason: .nutritionGap,
                createdAt: now,
                expiresAt: nil
            )
        )
    }

    private var baselineWithoutWorkouts: HealthBaselineContext {
        HealthBaselineContext(
            targetDate: now,
            averageSteps7d: 8_000,
            averageSteps28d: 7_500,
            averageActiveEnergy7d: 400,
            averageActiveEnergy28d: 380,
            averageSleepDuration7d: 7.5,
            averageSleepDuration28d: 7.2,
            averageRestingHeartRate28d: 58,
            averageHRV28d: 45,
            averageWorkoutLoad28d: nil,
            workoutDays7d: 0,
            workoutDays28d: 0,
            availableSignals: [.steps, .activeEnergy, .sleep, .restingHeartRate, .hrv],
            missingSignals: [.workoutLoad]
        )
    }

    private var baselineMissingSleep: HealthBaselineContext {
        HealthBaselineContext(
            targetDate: now,
            averageSteps7d: 8_000,
            averageSteps28d: 7_500,
            averageActiveEnergy7d: 400,
            averageActiveEnergy28d: 380,
            averageSleepDuration7d: nil,
            averageSleepDuration28d: nil,
            averageRestingHeartRate28d: 58,
            averageHRV28d: 45,
            averageWorkoutLoad28d: 120,
            workoutDays7d: 2,
            workoutDays28d: 8,
            availableSignals: [.steps, .activeEnergy, .restingHeartRate, .hrv, .workoutLoad],
            missingSignals: [.sleep]
        )
    }

    private var baselineMissingHeart: HealthBaselineContext {
        HealthBaselineContext(
            targetDate: now,
            averageSteps7d: 8_000,
            averageSteps28d: 7_500,
            averageActiveEnergy7d: 400,
            averageActiveEnergy28d: 380,
            averageSleepDuration7d: 7.5,
            averageSleepDuration28d: 7.2,
            averageRestingHeartRate28d: nil,
            averageHRV28d: nil,
            averageWorkoutLoad28d: 120,
            workoutDays7d: 2,
            workoutDays28d: 8,
            availableSignals: [.steps, .activeEnergy, .sleep, .workoutLoad],
            missingSignals: [.restingHeartRate, .hrv]
        )
    }
}

// MARK: - Test helper context factory

private extension HealthIntelligenceUIContext {
    init(kind: HealthIntelligenceUIStateKind, now: Date) {
        switch kind {
        case .loading:
            self.init(isLoading: true, now: now)
        case .ready:
            self.init(
                availability: HealthDataAvailability(
                    isHealthDataAvailable: true,
                    permissionStatus: .uniform(.available, isHealthDataAvailable: true),
                    cachedDayCount: 7
                ),
                snapshot: HealthIntelligenceSnapshot(
                    date: now,
                    recovery: RecoverySummary(
                        score: 80,
                        status: .ready,
                        title: "Ready",
                        explanation: "Good",
                        recommendedTraining: "Train",
                        recommendedNutrition: "Eat",
                        confidence: .high,
                        contributingFactors: [],
                        missingSignals: []
                    ),
                    workout: .noWorkout,
                    activity: ActivitySummary(steps: 8_000, activeEnergyKcal: 400, exerciseMinutes: 30),
                    nutritionAdjustment: .none,
                    weeklyReview: nil,
                    planConfidence: PlanHealthConfidence(score: 0.8, label: "Strong"),
                    nextBestAction: NextBestAction(
                        id: "nba",
                        title: "Log",
                        message: "Log",
                        ctaTitle: "Log",
                        destination: .logMeal,
                        priority: 1,
                        reason: .none,
                        createdAt: now,
                        expiresAt: nil
                    )
                ),
                isAppleHealthConnected: true,
                cachedDayCount: 7,
                now: now
            )
        case .noHealthPermission:
            self.init(
                availability: HealthDataAvailability(
                    isHealthDataAvailable: true,
                    permissionStatus: .uniform(.denied, isHealthDataAvailable: true),
                    cachedDayCount: 0
                ),
                now: now
            )
        case .partialPermission:
            var access: [HealthSignalKind: HealthSignalAccess] = [:]
            for signal in HealthSignalKind.allCases {
                access[signal] = signal == .stepCount ? .available : .denied
            }
            self.init(
                availability: HealthDataAvailability(
                    isHealthDataAvailable: true,
                    permissionStatus: HealthPermissionStatus(
                        isHealthDataAvailable: true,
                        signalAccess: access,
                        resolvedAt: now
                    ),
                    cachedDayCount: 3
                ),
                snapshot: HealthIntelligenceSnapshot(
                    date: now,
                    recovery: .unknown,
                    workout: nil,
                    activity: ActivitySummary(steps: 4_000, activeEnergyKcal: nil, exerciseMinutes: nil),
                    nutritionAdjustment: .none,
                    weeklyReview: nil,
                    planConfidence: .unknown,
                    nextBestAction: NextBestAction(
                        id: "nba",
                        title: "",
                        message: "",
                        ctaTitle: "",
                        destination: .none,
                        priority: 0,
                        reason: .none,
                        createdAt: now,
                        expiresAt: nil
                    )
                ),
                isAppleHealthConnected: true,
                cachedDayCount: 3,
                now: now
            )
        case .healthKitUnavailable:
            self.init(
                availability: HealthDataAvailability(
                    isHealthDataAvailable: false,
                    permissionStatus: .unavailable(),
                    cachedDayCount: 0
                ),
                now: now
            )
        case .noWorkoutHistory:
            self.init(
                availability: HealthDataAvailability(
                    isHealthDataAvailable: true,
                    permissionStatus: .uniform(.available, isHealthDataAvailable: true),
                    cachedDayCount: 10
                ),
                snapshot: HealthIntelligenceSnapshot(
                    date: now,
                    recovery: RecoverySummary(
                        score: 60,
                        status: .moderate,
                        title: "Moderate",
                        explanation: "Activity",
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
                    nextBestAction: NextBestAction(
                        id: "nba",
                        title: "Log",
                        message: "Log",
                        ctaTitle: "Log",
                        destination: .logMeal,
                        priority: 1,
                        reason: .none,
                        createdAt: now,
                        expiresAt: nil
                    )
                ),
                baseline: HealthBaselineContext(
                    targetDate: now,
                    averageSteps7d: 8_000,
                    averageSteps28d: 7_500,
                    averageActiveEnergy7d: 400,
                    averageActiveEnergy28d: 380,
                    averageSleepDuration7d: 7.5,
                    averageSleepDuration28d: 7.2,
                    averageRestingHeartRate28d: 58,
                    averageHRV28d: 45,
                    averageWorkoutLoad28d: nil,
                    workoutDays7d: 0,
                    workoutDays28d: 0,
                    availableSignals: [.steps],
                    missingSignals: [.workoutLoad]
                ),
                isAppleHealthConnected: true,
                cachedDayCount: 10,
                now: now
            )
        case .noSleepData:
            self.init(
                availability: HealthDataAvailability(
                    isHealthDataAvailable: true,
                    permissionStatus: .uniform(.available, isHealthDataAvailable: true),
                    cachedDayCount: 14
                ),
                snapshot: HealthIntelligenceSnapshot(
                    date: now,
                    recovery: RecoverySummary(
                        score: 58,
                        status: .moderate,
                        title: "Moderate",
                        explanation: "Sleep missing",
                        recommendedTraining: "Steady",
                        recommendedNutrition: "Protein",
                        confidence: .moderate,
                        contributingFactors: [],
                        missingSignals: [.sleep]
                    ),
                    workout: .noWorkout,
                    activity: ActivitySummary(steps: 7_000, activeEnergyKcal: 350, exerciseMinutes: 25),
                    nutritionAdjustment: .none,
                    weeklyReview: nil,
                    planConfidence: PlanHealthConfidence(score: 0.5, label: "Moderate"),
                    nextBestAction: NextBestAction(
                        id: "nba",
                        title: "Log",
                        message: "Log",
                        ctaTitle: "Log",
                        destination: .logMeal,
                        priority: 1,
                        reason: .none,
                        createdAt: now,
                        expiresAt: nil
                    )
                ),
                baseline: HealthBaselineContext(
                    targetDate: now,
                    averageSteps7d: 8_000,
                    averageSteps28d: 7_500,
                    averageActiveEnergy7d: 400,
                    averageActiveEnergy28d: 380,
                    averageSleepDuration7d: nil,
                    averageSleepDuration28d: nil,
                    averageRestingHeartRate28d: 58,
                    averageHRV28d: 45,
                    averageWorkoutLoad28d: 120,
                    workoutDays7d: 2,
                    workoutDays28d: 8,
                    availableSignals: [.steps],
                    missingSignals: [.sleep]
                ),
                isAppleHealthConnected: true,
                cachedDayCount: 14,
                now: now
            )
        case .noHeartData:
            self.init(
                availability: HealthDataAvailability(
                    isHealthDataAvailable: true,
                    permissionStatus: .uniform(.available, isHealthDataAvailable: true),
                    cachedDayCount: 14
                ),
                snapshot: HealthIntelligenceSnapshot(
                    date: now,
                    recovery: RecoverySummary(
                        score: 58,
                        status: .moderate,
                        title: "Moderate",
                        explanation: "Heart missing",
                        recommendedTraining: "Steady",
                        recommendedNutrition: "Protein",
                        confidence: .moderate,
                        contributingFactors: [],
                        missingSignals: [.restingHeartRate, .hrv]
                    ),
                    workout: .noWorkout,
                    activity: ActivitySummary(steps: 7_000, activeEnergyKcal: 350, exerciseMinutes: 25),
                    nutritionAdjustment: .none,
                    weeklyReview: nil,
                    planConfidence: PlanHealthConfidence(score: 0.5, label: "Moderate"),
                    nextBestAction: NextBestAction(
                        id: "nba",
                        title: "Log",
                        message: "Log",
                        ctaTitle: "Log",
                        destination: .logMeal,
                        priority: 1,
                        reason: .none,
                        createdAt: now,
                        expiresAt: nil
                    )
                ),
                baseline: HealthBaselineContext(
                    targetDate: now,
                    averageSteps7d: 8_000,
                    averageSteps28d: 7_500,
                    averageActiveEnergy7d: 400,
                    averageActiveEnergy28d: 380,
                    averageSleepDuration7d: 7.5,
                    averageSleepDuration28d: 7.2,
                    averageRestingHeartRate28d: nil,
                    averageHRV28d: nil,
                    averageWorkoutLoad28d: 120,
                    workoutDays7d: 2,
                    workoutDays28d: 8,
                    availableSignals: [.steps],
                    missingSignals: [.restingHeartRate, .hrv]
                ),
                isAppleHealthConnected: true,
                cachedDayCount: 14,
                now: now
            )
        case .notEnoughBaseline:
            self.init(
                availability: HealthDataAvailability(
                    isHealthDataAvailable: true,
                    permissionStatus: .uniform(.available, isHealthDataAvailable: true),
                    cachedDayCount: 2
                ),
                snapshot: HealthIntelligenceSnapshot(
                    date: now,
                    recovery: .unknown,
                    workout: nil,
                    activity: .empty,
                    nutritionAdjustment: .none,
                    weeklyReview: nil,
                    planConfidence: .unknown,
                    nextBestAction: NextBestAction(
                        id: "",
                        title: "",
                        message: "",
                        ctaTitle: "",
                        destination: .none,
                        priority: 0,
                        reason: .none,
                        createdAt: now,
                        expiresAt: nil
                    )
                ),
                baseline: .empty(for: now),
                isAppleHealthConnected: true,
                cachedDayCount: 2,
                now: now
            )
        case .syncFailed:
            self.init(explicitErrorMessage: "Failed", syncPhase: .failed, now: now)
        case .staleData:
            self.init(
                availability: HealthDataAvailability(
                    isHealthDataAvailable: true,
                    permissionStatus: .uniform(.available, isHealthDataAvailable: true),
                    cachedDayCount: 5
                ),
                snapshot: HealthIntelligenceSnapshot(
                    date: now,
                    recovery: RecoverySummary(
                        score: 60,
                        status: .moderate,
                        title: "Moderate",
                        explanation: "Activity",
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
                    nextBestAction: NextBestAction(
                        id: "nba",
                        title: "Log",
                        message: "Log",
                        ctaTitle: "Log",
                        destination: .logMeal,
                        priority: 1,
                        reason: .none,
                        createdAt: now,
                        expiresAt: nil
                    )
                ),
                lastSuccessfulLocalSyncAt: now.addingTimeInterval(-48 * 60 * 60),
                isAppleHealthConnected: true,
                cachedDayCount: 5,
                now: now
            )
        case .remoteSyncDisabled:
            self.init(
                availability: HealthDataAvailability(
                    isHealthDataAvailable: true,
                    permissionStatus: .uniform(.available, isHealthDataAvailable: true),
                    cachedDayCount: 0
                ),
                snapshot: HealthIntelligenceSnapshot(
                    date: now,
                    recovery: .unknown,
                    workout: nil,
                    activity: .empty,
                    nutritionAdjustment: .none,
                    weeklyReview: nil,
                    planConfidence: .unknown,
                    nextBestAction: NextBestAction(
                        id: "",
                        title: "",
                        message: "",
                        ctaTitle: "",
                        destination: .none,
                        priority: 0,
                        reason: .none,
                        createdAt: now,
                        expiresAt: nil
                    )
                ),
                isAppleHealthConnected: true,
                cachedDayCount: 0,
                isRemoteSyncCapabilityEnabled: true,
                isRemoteSyncUserEnabled: false,
                remoteSyncConsentDecision: .optedOut,
                now: now
            )
        case .unknown:
            self.init(
                availability: HealthDataAvailability(
                    isHealthDataAvailable: true,
                    permissionStatus: .uniform(.available, isHealthDataAvailable: true),
                    cachedDayCount: 3
                ),
                snapshot: nil,
                isAppleHealthConnected: true,
                cachedDayCount: 3,
                now: now
            )
        }
    }
}
