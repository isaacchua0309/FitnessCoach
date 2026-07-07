//
//  HealthIntelligencePresentationStateMapperTests.swift
//  Fitness CoachTests
//

import XCTest
@testable import Fitness_Coach

final class HealthIntelligencePresentationStateMapperTests: XCTestCase {

    func testLoadingStateWhenExplicitlyLoading() {
        let lifecycle = HealthIntelligencePresentationStateMapper.resolve(
            HealthIntelligencePresentationContext(isLoading: true)
        )

        XCTAssertEqual(lifecycle, .loading)
    }

    func testLoadingStateWhenSyncing() {
        let lifecycle = HealthIntelligencePresentationStateMapper.resolve(
            HealthIntelligencePresentationContext(syncPhase: .syncing)
        )

        XCTAssertEqual(lifecycle, .loading)
    }

    func testSyncFailedStateWhenExplicitErrorProvided() {
        let lifecycle = HealthIntelligencePresentationStateMapper.resolve(
            HealthIntelligencePresentationContext(explicitErrorMessage: "Network unavailable")
        )

        XCTAssertEqual(lifecycle, .syncFailed)
    }

    func testSyncFailedStateWhenSyncPhaseFailed() {
        let lifecycle = HealthIntelligencePresentationStateMapper.resolve(
            HealthIntelligencePresentationContext(syncPhase: .failed)
        )

        XCTAssertEqual(lifecycle, .syncFailed)
    }

    func testUnavailableOnDeviceWhenHealthDataNotAvailable() {
        let lifecycle = HealthIntelligencePresentationStateMapper.resolve(
            HealthIntelligencePresentationContext(
                availability: HealthDataAvailability(
                    isHealthDataAvailable: false,
                    permissionStatus: .unavailable(),
                    cachedDayCount: 0
                )
            )
        )

        XCTAssertEqual(lifecycle, .unavailableOnDevice)
    }

    func testNoHealthPermissionWhenConnectHealthActionPresent() {
        let lifecycle = HealthIntelligencePresentationStateMapper.resolve(
            HealthIntelligencePresentationContext(
                snapshot: connectHealthSnapshot
            )
        )

        XCTAssertEqual(lifecycle, .noHealthPermission)
    }

    func testNoHealthPermissionWhenSnapshotMissingAndNoReadableSignals() {
        let lifecycle = HealthIntelligencePresentationStateMapper.resolve(
            HealthIntelligencePresentationContext(
                availability: HealthDataAvailability(
                    isHealthDataAvailable: true,
                    permissionStatus: .uniform(.denied, isHealthDataAvailable: true),
                    cachedDayCount: 0
                )
            )
        )

        XCTAssertEqual(lifecycle, .noHealthPermission)
    }

    func testPartialHealthPermissionWhenSomeSignalsAvailable() {
        var access: [HealthSignalKind: HealthSignalAccess] = [:]
        for signal in HealthSignalKind.allCases {
            access[signal] = signal == .stepCount ? .available : .denied
        }

        let lifecycle = HealthIntelligencePresentationStateMapper.resolve(
            HealthIntelligencePresentationContext(
                availability: HealthDataAvailability(
                    isHealthDataAvailable: true,
                    permissionStatus: HealthPermissionStatus(
                        isHealthDataAvailable: true,
                        signalAccess: access,
                        resolvedAt: Date()
                    ),
                    cachedDayCount: 3
                ),
                snapshot: sparseSnapshot,
                isAppleHealthConnected: true
            )
        )

        XCTAssertEqual(lifecycle, HealthIntelligencePresentationLifecycle.partialHealthPermission)
    }

    func testNoHealthDataYetWhenConnectedWithoutCachedDaysOrSignals() {
        let lifecycle = HealthIntelligencePresentationStateMapper.resolve(
            HealthIntelligencePresentationContext(
                availability: readableAvailability,
                snapshot: emptySnapshot,
                isAppleHealthConnected: true,
                cachedDayCount: 0
            )
        )

        XCTAssertEqual(lifecycle, HealthIntelligencePresentationLifecycle.noHealthDataYet)
    }

    func testLimitedEstimateWhenRecoveryConfidenceIsLowButSignalsExist() {
        let lifecycle = HealthIntelligencePresentationStateMapper.resolve(
            HealthIntelligencePresentationContext(
                availability: readableAvailability,
                snapshot: limitedRecoverySnapshot,
                isAppleHealthConnected: true,
                cachedDayCount: 5
            )
        )

        XCTAssertEqual(lifecycle, .limitedEstimate)
    }

    func testReadyWhenWorkoutAndRecoverySignalsPresent() {
        let lifecycle = HealthIntelligencePresentationStateMapper.resolve(
            HealthIntelligencePresentationContext(
                availability: readableAvailability,
                snapshot: readySnapshot,
                isAppleHealthConnected: true,
                cachedDayCount: 7
            )
        )

        XCTAssertEqual(lifecycle, .ready)
    }

    func testSharedCopyUsesConsistentConnectHealthCTAAcrossSurfaces() {
        for surface in [HealthIntelligenceSurface.today, .journey, .plan, .coach] {
            let message = FormaProductCopy.HealthIntelligence.message(
                for: .noHealthPermission,
                surface: surface
            )

            XCTAssertEqual(message.primaryAction, .connectAppleHealth)
            XCTAssertEqual(
                message.primaryActionTitle,
                FormaProductCopy.HealthIntelligence.NoHealthPermission.actionTitle
            )
            XCTAssertTrue(message.message.contains("Apple Health"))
            XCTAssertTrue(message.reassurance?.contains("logging") == true)
        }
    }

    func testPartialPermissionCopyOffersManagePermissionsCTA() {
        let message = FormaProductCopy.HealthIntelligence.message(
            for: .partialHealthPermission,
            surface: .plan
        )

        XCTAssertEqual(message.primaryAction, .manageHealthPermissions)
        XCTAssertEqual(
            message.primaryActionTitle,
            FormaProductCopy.HealthIntelligence.PartialHealthPermission.actionTitle
        )
    }

    func testLimitedEstimateCopyOffersAskCoachCTA() {
        let message = FormaProductCopy.HealthIntelligence.message(
            for: .limitedEstimate,
            surface: .today
        )

        XCTAssertEqual(message.primaryAction, .askCoach)
        XCTAssertEqual(
            message.primaryActionTitle,
            FormaProductCopy.HealthIntelligence.LimitedEstimate.actionTitle
        )
    }

    func testSyncFailedCopyDoesNotBlockLogging() {
        let message = FormaProductCopy.HealthIntelligence.message(
            for: .syncFailed,
            surface: .journey
        )

        XCTAssertEqual(message.primaryAction, .none)
        XCTAssertTrue(message.reassurance?.contains("logged data is safe") == true)
    }

    func testTodayBuilderUsesSharedNoHealthPermissionFallbackForNilSnapshot() {
        let section = TodayHealthIntelligencePresentationBuilder.buildSection(
            snapshot: nil,
            isUIEnabled: true
        )

        XCTAssertEqual(
            section?.fallbackMessage,
            FormaProductCopy.HealthIntelligence.message(for: .noHealthPermission, surface: .today).bannerMessage
        )
    }

    func testJourneyBuilderMapsNotConnectedInputToConnectHealthSection() {
        let section = JourneyHealthIntelligencePresentationBuilder.buildSection(
            input: JourneyHealthIntelligenceBuildInput(healthConnection: .notConnected),
            isUIEnabled: true
        )

        XCTAssertNotNil(section?.connectHealthCTA)
        XCTAssertEqual(
            section?.connectHealthCTA?.title,
            FormaProductCopy.HealthIntelligence.NoHealthPermission.title
        )
    }

    func testPlanMissingDataActionsUseSharedConnectAndPartialCopy() {
        let section = PlanHealthIntelligencePresentationBuilder.buildSection(
            input: PlanHealthIntelligenceBuildInput(
                healthConnection: .partial,
                hasNutritionLogging: true
            )
        )

        XCTAssertTrue(section.missingDataActions.contains { $0.id == "partial-permissions" })
        XCTAssertEqual(
            section.missingDataActions.first(where: { $0.id == "partial-permissions" })?.title,
            FormaProductCopy.HealthIntelligence.PartialHealthPermission.actionTitle
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

    private var connectHealthSnapshot: HealthIntelligenceSnapshot {
        HealthIntelligenceSnapshot(
            date: Date(),
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
                createdAt: Date(),
                expiresAt: nil
            )
        )
    }

    private var emptySnapshot: HealthIntelligenceSnapshot {
        HealthIntelligenceSnapshot(
            date: Date(),
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
                reason: .stayOnPlan,
                createdAt: Date(),
                expiresAt: nil
            )
        )
    }

    private var sparseSnapshot: HealthIntelligenceSnapshot {
        HealthIntelligenceSnapshot(
            date: Date(),
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
                reason: .noMealLogged,
                createdAt: Date(),
                expiresAt: nil
            )
        )
    }

    private var limitedRecoverySnapshot: HealthIntelligenceSnapshot {
        HealthIntelligenceSnapshot(
            date: Date(),
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
                reason: .hydration,
                createdAt: Date(),
                expiresAt: nil
            )
        )
    }

    private var readySnapshot: HealthIntelligenceSnapshot {
        HealthIntelligenceSnapshot(
            date: Date(),
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
                latestWorkoutStart: Date(),
                latestWorkoutEnd: Date(),
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
                createdAt: Date(),
                expiresAt: nil
            )
        )
    }
}
