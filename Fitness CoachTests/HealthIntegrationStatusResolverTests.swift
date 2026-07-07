//
//  HealthIntegrationStatusResolverTests.swift
//  Fitness CoachTests
//

import XCTest
@testable import Fitness_Coach

final class HealthIntegrationStatusResolverTests: XCTestCase {

    private var referenceDay: Date {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(secondsFromGMT: 0)!
        return calendar.startOfDay(for: calendar.date(from: DateComponents(year: 2026, month: 7, day: 3))!)
    }

    func testConnectedWithMissingRecoveryDataIsConnectedNoData() {
        let status = HealthIntegrationStatusResolver.resolve(
            makeInput(
                integration: .connected,
                permission: .uniform(.available, isHealthDataAvailable: true),
                snapshot: missingRecoverySnapshot,
                connectionRecord: completedConnectionRecord
            )
        )

        XCTAssertEqual(status, .connectedNoData)
        XCTAssertFalse(status.requiresInitialConnection(hasPriorConnectionEvidence: true))
    }

    func testConnectedWithActivityAndPartialRecoveryIsConnectedReady() {
        let status = HealthIntegrationStatusResolver.resolve(
            makeInput(
                integration: .connected,
                permission: .uniform(.available, isHealthDataAvailable: true),
                snapshot: readyActivitySnapshot,
                connectionRecord: completedConnectionRecord
            )
        )

        XCTAssertEqual(status, .connectedReady)
    }

    func testNotRequestedWhenNeverConnected() {
        let status = HealthIntegrationStatusResolver.resolve(
            makeInput(
                integration: .notConnected,
                permission: .uniform(.notDetermined, isHealthDataAvailable: true),
                snapshot: nil,
                connectionRecord: .empty
            )
        )

        XCTAssertEqual(status, .notRequested)
        XCTAssertTrue(status.requiresInitialConnection(hasPriorConnectionEvidence: false))
    }

    func testCompletedFlowWithoutReadableSignalsIsConnectedNoDataNotNotRequested() {
        let status = HealthIntegrationStatusResolver.resolve(
            makeInput(
                integration: .notConnected,
                permission: .uniform(.notDetermined, isHealthDataAvailable: true),
                snapshot: missingRecoverySnapshot,
                connectionRecord: completedConnectionRecord
            )
        )

        XCTAssertEqual(status, .connectedNoData)
        XCTAssertFalse(status.requiresInitialConnection(hasPriorConnectionEvidence: true))
    }

    func testTodayNextStepDoesNotShowConnectWhenConnectedAndMissingRecovery() {
        let statusInput = makeInput(
            integration: .connected,
            permission: .uniform(.available, isHealthDataAvailable: true),
            snapshot: missingRecoverySnapshot,
            connectionRecord: completedConnectionRecord
        )
        let status = HealthIntegrationStatusResolver.resolve(statusInput)
        let signals = HealthIntegrationStatusResolver.resolveSignalAvailability(from: statusInput)

        let nextStep = TodayHealthIntegrationNextStepResolver.resolve(
            integrationStatus: status,
            signalAvailability: signals,
            behavioralAction: .none,
            hasPriorConnectionEvidence: statusInput.hasPriorConnectionEvidence
        )

        XCTAssertEqual(nextStep.title, FormaProductCopy.HealthIntelligence.Integration.connectedNoData.title)
        XCTAssertNotEqual(nextStep.title, "Connect Apple Health")
        XCTAssertEqual(nextStep.destination, .refreshHealthData)
    }

    func testTodayNextStepShowsConnectOnlyWhenNotRequested() {
        let statusInput = makeInput(
            integration: .notConnected,
            permission: .uniform(.notDetermined, isHealthDataAvailable: true),
            snapshot: nil,
            connectionRecord: .empty
        )
        let status = HealthIntegrationStatusResolver.resolve(statusInput)
        let signals = HealthIntegrationStatusResolver.resolveSignalAvailability(from: statusInput)

        let nextStep = TodayHealthIntegrationNextStepResolver.resolve(
            integrationStatus: status,
            signalAvailability: signals,
            behavioralAction: .none,
            hasPriorConnectionEvidence: statusInput.hasPriorConnectionEvidence
        )

        XCTAssertEqual(nextStep.title, "Connect Apple Health")
        XCTAssertEqual(nextStep.destination, .connectHealth)
    }

    func testMealLoggingBeatsConnectedNoDataCard() {
        let statusInput = makeInput(
            integration: .connected,
            permission: .uniform(.available, isHealthDataAvailable: true),
            snapshot: missingRecoverySnapshot,
            connectionRecord: completedConnectionRecord
        )
        let status = HealthIntegrationStatusResolver.resolve(statusInput)
        let signals = HealthIntegrationStatusResolver.resolveSignalAvailability(from: statusInput)
        let mealAction = NextBestAction(
            id: "log-first-meal",
            title: "Log your first meal",
            message: "A quick meal log keeps today on track.",
            ctaTitle: "Log meal",
            destination: .logMeal,
            priority: 4,
            reason: .noMealLogged,
            createdAt: referenceDay,
            expiresAt: nil
        )

        let nextStep = TodayHealthIntegrationNextStepResolver.resolve(
            integrationStatus: status,
            signalAvailability: signals,
            behavioralAction: mealAction,
            hasPriorConnectionEvidence: statusInput.hasPriorConnectionEvidence
        )

        XCTAssertEqual(nextStep.title, "Log your first meal")
        XCTAssertEqual(nextStep.destination, .logMeal)
    }

    // MARK: - Fixtures

    private var completedConnectionRecord: HealthIntegrationConnectionRecord {
        HealthIntegrationConnectionRecord(
            hasCompletedAppleHealthConnectionFlow: true,
            lastHealthPermissionRequestAt: referenceDay,
            lastSuccessfulHealthReadAt: referenceDay,
            lastHealthSyncAttemptAt: referenceDay
        )
    }

    private var missingRecoverySnapshot: HealthIntelligenceSnapshot {
        HealthIntelligenceSnapshot(
            date: referenceDay,
            recovery: RecoverySummary(
                score: nil,
                status: .unknown,
                title: "Recovery unclear",
                explanation: "Sleep and heart signals are not available yet.",
                recommendedTraining: "Use how you feel before adding intensity today.",
                recommendedNutrition: "Stay on your usual plan until more data arrives.",
                confidence: .low,
                contributingFactors: [],
                missingSignals: [.sleep, .hrv, .restingHeartRate]
            ),
            workout: nil,
            activity: .empty,
            nutritionAdjustment: .none,
            weeklyReview: nil,
            planConfidence: .unknown,
            nextBestAction: NextBestAction(
                id: "connect-health",
                title: "Connect Apple Health",
                message: "Enable activity reads to improve plan confidence.",
                ctaTitle: "",
                destination: .none,
                priority: 1,
                reason: .connectHealth,
                createdAt: referenceDay,
                expiresAt: nil
            )
        )
    }

    private var readyActivitySnapshot: HealthIntelligenceSnapshot {
        HealthIntelligenceSnapshot(
            date: referenceDay,
            recovery: RecoverySummary(
                score: 80,
                status: .ready,
                title: "Ready to train",
                explanation: "Signals look supportive.",
                recommendedTraining: "Train as planned.",
                recommendedNutrition: "Stay on plan.",
                confidence: .high,
                contributingFactors: [],
                missingSignals: []
            ),
            workout: nil,
            activity: ActivitySummary(steps: 8_000, activeEnergyKcal: 400, exerciseMinutes: 30),
            nutritionAdjustment: .none,
            weeklyReview: nil,
            planConfidence: PlanHealthConfidence(score: 0.8, label: "Strong"),
            nextBestAction: .none
        )
    }

    private func makeInput(
        integration: TrainingIntegrationState,
        permission: HealthPermissionStatus,
        snapshot: HealthIntelligenceSnapshot?,
        connectionRecord: HealthIntegrationConnectionRecord
    ) -> HealthIntegrationStatusInput {
        HealthIntegrationStatusInput(
            isHealthDataAvailable: permission.isHealthDataAvailable,
            permissionStatus: permission,
            trainingIntegrationState: integration,
            connectionRecord: connectionRecord,
            snapshot: snapshot,
            baseline: nil,
            cachedDayCount: snapshot == nil ? 0 : 3
        )
    }
}
