//
//  TodayAppleHealthSuggestedNextStepTests.swift
//  Fitness CoachTests
//
//  Regression coverage for Apple Health Suggested Next Step on Today.
//  Connection state must not be inferred from missing HealthKit samples.
//

import XCTest
@testable import Fitness_Coach

final class TodayAppleHealthSuggestedNextStepTests: XCTestCase {

    private var referenceDay: Date {
        HealthIntelligencePipelineFixtures.day(2026, 7, 3)
    }

    // MARK: - 1. User never connected Apple Health

    func testNeverConnectedShowsConnectAppleHealth() {
        let statusInput = makeStatusInput(
            integration: .notConnected,
            permission: .uniform(.notDetermined, isHealthDataAvailable: true),
            snapshot: nil,
            connectionRecord: .empty
        )
        let status = HealthIntegrationStatusResolver.resolve(statusInput)

        XCTAssertEqual(status, .notRequested)
        XCTAssertFalse(statusInput.connectionRecord.hasCompletedAppleHealthConnectionFlow)

        let nextStep = resolveNextStep(statusInput: statusInput, status: status)
        XCTAssertEqual(nextStep.title, "Connect Apple Health")
        XCTAssertEqual(nextStep.destination, .connectHealth)

        let section = buildSection(
            snapshot: nil,
            trainingIntegrationState: .notConnected,
            connectionRecord: .empty,
            availability: notRequestedAvailability
        )
        XCTAssertTrue(section.nextBestAction.isVisible)
        XCTAssertEqual(section.nextBestAction.title, "Connect Apple Health")
        XCTAssertEqual(section.nextBestAction.destination, .connectHealth)
    }

    // MARK: - 2. Connected but no samples today

    func testConnectedNoSamplesDoesNotShowConnectAppleHealth() {
        let snapshot = connectedNoDataSnapshot
        let statusInput = makeStatusInput(
            integration: .connected,
            permission: readablePermission,
            snapshot: snapshot,
            connectionRecord: completedConnectionRecord
        )
        let status = HealthIntegrationStatusResolver.resolve(statusInput)
        let signals = HealthIntegrationStatusResolver.resolveSignalAvailability(from: statusInput)

        XCTAssertEqual(status, .connectedNoData)
        XCTAssertTrue(signals.missingSignals.contains(.sleep))
        XCTAssertTrue(signals.missingSignals.contains(.hrv))
        XCTAssertTrue(signals.missingSignals.contains(.workouts))
        XCTAssertTrue(signals.missingSignals.contains(.steps))

        let nextStep = resolveNextStep(statusInput: statusInput, status: status)
        XCTAssertNotEqual(nextStep.title, "Connect Apple Health")
        XCTAssertEqual(
            nextStep.title,
            FormaProductCopy.HealthIntelligence.Integration.connectedNoData.title
        )
        XCTAssertEqual(nextStep.destination, .refreshHealthData)

        let section = buildSection(
            snapshot: snapshot,
            trainingIntegrationState: .connected,
            connectionRecord: completedConnectionRecord,
            availability: readableAvailability
        )
        XCTAssertNotEqual(section.nextBestAction.title, "Connect Apple Health")
        XCTAssertTrue(
            section.nextBestAction.title == FormaProductCopy.HealthIntelligence.Integration.connectedNoData.title
                || section.nextBestAction.title == "Log your first meal"
        )
    }

    // MARK: - 3. Connected with partial data

    func testConnectedPartialDataDoesNotRecommendAppleHealthSetup() {
        let snapshot = partialDataSnapshot
        let statusInput = makeStatusInput(
            integration: .connected,
            permission: readablePermission,
            snapshot: snapshot,
            connectionRecord: completedConnectionRecord,
            cachedDayCount: 0,
            baseline: baselineWithStepsOnly
        )
        let status = HealthIntegrationStatusResolver.resolve(statusInput)
        let signals = HealthIntegrationStatusResolver.resolveSignalAvailability(from: statusInput)

        XCTAssertEqual(status, .connectedPartial)
        XCTAssertTrue(signals.stepsAvailable)
        XCTAssertFalse(signals.sleepAvailable)
        XCTAssertFalse(signals.hrvAvailable)

        let nextStep = resolveNextStep(statusInput: statusInput, status: status)
        XCTAssertNotEqual(nextStep.title, "Connect Apple Health")
        XCTAssertEqual(
            nextStep.title,
            FormaProductCopy.HealthIntelligence.Integration.connectedPartial.title
        )
        XCTAssertTrue(nextStep.title.lowercased().contains("limited"))

        let section = buildSection(
            snapshot: snapshot,
            trainingIntegrationState: .connected,
            connectionRecord: completedConnectionRecord,
            availability: readableAvailability(cachedDayCount: 0),
            baseline: baselineWithStepsOnly,
            cachedDayCount: 0
        )
        XCTAssertNotEqual(section.nextBestAction.title, "Connect Apple Health")
        XCTAssertEqual(
            section.nextBestAction.title,
            FormaProductCopy.HealthIntelligence.Integration.connectedPartial.title
        )
        XCTAssertTrue(
            section.recoveryCard.confidenceNote?.lowercased().contains("limited") == true
                || section.recoveryCard.subtitle?.lowercased().contains("limited") == true
        )
    }

    // MARK: - 4. Connected and data available

    func testConnectedReadyHidesAppleHealthSetupCard() {
        let snapshot = readyDataSnapshot
        let statusInput = makeStatusInput(
            integration: .connected,
            permission: readablePermission,
            snapshot: snapshot,
            connectionRecord: completedConnectionRecord
        )
        let status = HealthIntegrationStatusResolver.resolve(statusInput)

        XCTAssertEqual(status, .connectedReady)

        let nextStep = resolveNextStep(
            statusInput: statusInput,
            status: status,
            behavioralAction: stayOnPlanAction
        )
        XCTAssertNotEqual(nextStep.title, "Connect Apple Health")
        XCTAssertNotEqual(nextStep.title, FormaProductCopy.HealthIntelligence.Integration.connectedNoData.title)
        XCTAssertFalse(nextStep.isVisible)

        let section = buildSection(
            snapshot: snapshot,
            trainingIntegrationState: .connected,
            connectionRecord: completedConnectionRecord,
            availability: readableAvailability
        )
        XCTAssertNotEqual(section.nextBestAction.title, "Connect Apple Health")
        XCTAssertFalse(section.nextBestAction.isVisible)
    }

    // MARK: - 5. Empty nutrition day and Apple Health connected

    func testEmptyNutritionDayPrioritizesLoggingOverConnectAppleHealth() {
        let snapshot = connectedNoDataSnapshot
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
        let snapshotWithMealAction = HealthIntelligenceSnapshot(
            date: snapshot.date,
            recovery: snapshot.recovery,
            workout: snapshot.workout,
            activity: snapshot.activity,
            nutritionAdjustment: snapshot.nutritionAdjustment,
            weeklyReview: snapshot.weeklyReview,
            planConfidence: snapshot.planConfidence,
            nextBestAction: mealAction
        )

        let statusInput = makeStatusInput(
            integration: .connected,
            permission: readablePermission,
            snapshot: snapshotWithMealAction,
            connectionRecord: completedConnectionRecord
        )
        let status = HealthIntegrationStatusResolver.resolve(statusInput)
        XCTAssertEqual(status, .connectedNoData)

        let nextStep = resolveNextStep(
            statusInput: statusInput,
            status: status,
            behavioralAction: mealAction
        )
        XCTAssertEqual(nextStep.title, "Log your first meal")
        XCTAssertNotEqual(nextStep.title, "Connect Apple Health")
        XCTAssertEqual(nextStep.destination, .logMeal)

        let section = buildSection(
            snapshot: snapshotWithMealAction,
            nutritionProgress: emptyNutritionProgress,
            trainingIntegrationState: .connected,
            connectionRecord: completedConnectionRecord,
            availability: readableAvailability
        )
        XCTAssertNotEqual(section.nextBestAction.title, "Connect Apple Health")
        XCTAssertTrue(
            section.nextBestAction.title == "Log your first meal"
                || section.nextBestAction.ctaTitle == "Add water"
        )
    }

    func testEmptyNutritionDayCanPrioritizeAddWaterOverConnectAppleHealth() {
        let waterAction = NextBestAction(
            id: "hydration",
            title: "Drink more water",
            message: "Hydration will help you feel better through the rest of today.",
            ctaTitle: "Add water",
            destination: .addWater,
            priority: 2,
            reason: .hydration,
            createdAt: referenceDay,
            expiresAt: nil
        )
        let snapshot = HealthIntelligenceSnapshot(
            date: referenceDay,
            recovery: .unknown,
            workout: nil,
            activity: .empty,
            nutritionAdjustment: .none,
            weeklyReview: nil,
            planConfidence: .unknown,
            nextBestAction: waterAction
        )

        let statusInput = makeStatusInput(
            integration: .connected,
            permission: readablePermission,
            snapshot: snapshot,
            connectionRecord: completedConnectionRecord
        )
        let status = HealthIntegrationStatusResolver.resolve(statusInput)
        XCTAssertEqual(status, .connectedNoData)

        let nextStep = resolveNextStep(
            statusInput: statusInput,
            status: status,
            behavioralAction: waterAction
        )
        XCTAssertEqual(nextStep.ctaTitle, "Add water")
        XCTAssertNotEqual(nextStep.title, "Connect Apple Health")
        XCTAssertEqual(nextStep.destination, .addWater)
    }

    // MARK: - 6. Permission denied

    func testPermissionDeniedShowsPermissionsRecoveryWithoutConnectedCopy() {
        let statusInput = makeStatusInput(
            integration: .denied,
            permission: deniedPermission,
            snapshot: nil,
            connectionRecord: .empty
        )
        let status = HealthIntegrationStatusResolver.resolve(statusInput)

        XCTAssertEqual(status, .permissionDenied)

        let nextStep = resolveNextStep(statusInput: statusInput, status: status)
        XCTAssertNotEqual(nextStep.title, FormaProductCopy.HealthIntelligence.Integration.connectedNoData.title)
        XCTAssertNotEqual(nextStep.message, FormaProductCopy.HealthIntelligence.Integration.connectedNoData.message)
        XCTAssertEqual(
            nextStep.ctaTitle,
            FormaProductCopy.HealthIntelligence.PartialHealthPermission.actionTitle
        )
        XCTAssertEqual(nextStep.destination, .connectHealth)
        XCTAssertTrue(
            nextStep.message.lowercased().contains("settings")
                || nextStep.ctaTitle?.lowercased().contains("permission") == true
        )

        let section = buildSection(
            snapshot: nil,
            trainingIntegrationState: .denied,
            connectionRecord: .empty,
            availability: deniedAvailability
        )
        XCTAssertNotEqual(section.nextBestAction.title, "Apple Health connected")
        XCTAssertTrue(section.nextBestAction.isVisible)
        XCTAssertEqual(
            section.nextBestAction.ctaTitle,
            FormaProductCopy.HealthIntelligence.PartialHealthPermission.actionTitle
        )
    }

    // MARK: - 7. Regression — missing data must not imply connect

    func testTodayRecommendationSourcesDoNotInferConnectFromMissingDataSignals() {
        let repositoryRoot = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
            .deletingLastPathComponent()

        let relativePaths = [
            "Fitness Coach/Application/StateBuilders/Today/TodayHealthIntegrationNextStepResolver.swift",
            "Fitness Coach/Application/StateBuilders/Today/TodayHealthIntelligencePresentationBuilder.swift",
            "Fitness Coach/Features/Today/Model/TodayHealthIntelligencePresentationState.swift",
            "Fitness Coach/Health/UIState/HealthIntelligenceUIState.swift"
        ]

        var violations: [String] = []
        for relativePath in relativePaths {
            let fileURL = repositoryRoot.appendingPathComponent(relativePath)
            guard let source = try? String(contentsOf: fileURL, encoding: .utf8) else {
                XCTFail("Missing Today recommendation source: \(relativePath)")
                continue
            }
            violations.append(
                contentsOf: Self.missingDataConnectViolations(in: source, fileName: relativePath)
            )
        }

        if violations.isEmpty { return }

        XCTFail(
            """
            Found \(violations.count) Today recommendation regression(s) where missing data implies connect:

            \(violations.joined(separator: "\n"))
            """
        )
    }

    func testRegressionGuardDetectsForbiddenMissingDataConnectPattern() {
        let sample = """
        if missingSignals.contains(.sleep) {
            return connectHealthAction()
        }
        """
        let violations = Self.missingDataConnectViolations(
            in: sample,
            fileName: "Sample.swift"
        )
        XCTAssertEqual(violations.count, 1)
        XCTAssertTrue(violations[0].contains("missingSignals"))
    }

    // MARK: - Regression scanner

    private static func missingDataConnectViolations(in source: String, fileName: String) -> [String] {
        let connectMarkers = [
            "connecthealth",
            "connect apple health",
            "connect-health",
            ".connecthealth"
        ]
        let missingDataMarkers = [
            "stepsunavailable",
            "sleepunavailable",
            "missingsignals"
        ]

        return source
            .components(separatedBy: .newlines)
            .enumerated()
            .compactMap { index, line -> String? in
                let trimmed = line.trimmingCharacters(in: .whitespaces)
                if trimmed.hasPrefix("//") { return nil }

                let lowered = line.lowercased()
                let impliesConnect = connectMarkers.contains { lowered.contains($0) }
                guard impliesConnect else { return nil }

                if let marker = missingDataMarkers.first(where: { lowered.contains($0) }) {
                    return "\(fileName):\(index + 1) — \(marker) must not imply connect"
                }
                return nil
            }
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

    private var readablePermission: HealthPermissionStatus {
        .uniform(.available, isHealthDataAvailable: true)
    }

    private var deniedPermission: HealthPermissionStatus {
        .uniform(.denied, isHealthDataAvailable: true)
    }

    private var notRequestedAvailability: HealthDataAvailability {
        HealthDataAvailability(
            isHealthDataAvailable: true,
            permissionStatus: .uniform(.notDetermined, isHealthDataAvailable: true),
            cachedDayCount: 0
        )
    }

    private var readableAvailability: HealthDataAvailability {
        readableAvailability(cachedDayCount: 3)
    }

    private func readableAvailability(cachedDayCount: Int) -> HealthDataAvailability {
        HealthDataAvailability(
            isHealthDataAvailable: true,
            permissionStatus: readablePermission,
            cachedDayCount: cachedDayCount
        )
    }

    private var deniedAvailability: HealthDataAvailability {
        HealthDataAvailability(
            isHealthDataAvailable: true,
            permissionStatus: deniedPermission,
            cachedDayCount: 0
        )
    }

    private var emptyNutritionProgress: TodayHealthIntelligenceNutritionProgress {
        TodayHealthIntelligenceNutritionProgress(
            calorieRemaining: 2_000,
            proteinRemainingGrams: 150,
            waterRemainingMl: 2_500,
            hasCalorieTarget: true,
            hasProteinTarget: true,
            hasWaterTarget: true
        )
    }

    private var stayOnPlanAction: NextBestAction {
        NextBestAction(
            id: "stay-on-plan",
            title: "Stay on plan",
            message: "Recovery looks good. Keep following your usual plan today.",
            ctaTitle: "",
            destination: .none,
            priority: 7,
            reason: .stayOnPlan,
            createdAt: referenceDay,
            expiresAt: nil
        )
    }

    private var connectedNoDataSnapshot: HealthIntelligenceSnapshot {
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
            nextBestAction: legacyConnectHealthAction
        )
    }

    private var partialDataSnapshot: HealthIntelligenceSnapshot {
        HealthIntelligenceSnapshot(
            date: referenceDay,
            recovery: RecoverySummary(
                score: nil,
                status: .unknown,
                title: "Recovery forming",
                explanation: "Limited signals available today.",
                recommendedTraining: "Use how you feel today.",
                recommendedNutrition: "Keep logging meals and water.",
                confidence: .low,
                contributingFactors: [],
                missingSignals: [.sleep, .hrv]
            ),
            workout: nil,
            activity: .empty,
            nutritionAdjustment: .none,
            weeklyReview: nil,
            planConfidence: .unknown,
            nextBestAction: .none
        )
    }

    private var baselineWithStepsOnly: HealthBaselineContext {
        HealthBaselineContext(
            targetDate: referenceDay,
            averageSteps7d: 8_000,
            averageSteps28d: 7_500,
            averageActiveEnergy7d: nil,
            averageActiveEnergy28d: nil,
            averageSleepDuration7d: nil,
            averageSleepDuration28d: nil,
            averageRestingHeartRate28d: nil,
            averageHRV28d: nil,
            averageWorkoutLoad28d: nil,
            workoutDays7d: 0,
            workoutDays28d: 0,
            availableSignals: [.steps],
            missingSignals: [.sleep, .restingHeartRate, .hrv, .workoutLoad]
        )
    }

    private var readyDataSnapshot: HealthIntelligenceSnapshot {
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
            nextBestAction: stayOnPlanAction
        )
    }

    private var legacyConnectHealthAction: NextBestAction {
        NextBestAction(
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
    }

    // MARK: - Helpers

    private func makeStatusInput(
        integration: TrainingIntegrationState,
        permission: HealthPermissionStatus,
        snapshot: HealthIntelligenceSnapshot?,
        connectionRecord: HealthIntegrationConnectionRecord,
        cachedDayCount: Int? = nil,
        baseline: HealthBaselineContext? = nil
    ) -> HealthIntegrationStatusInput {
        HealthIntegrationStatusInput(
            isHealthDataAvailable: permission.isHealthDataAvailable,
            permissionStatus: permission,
            trainingIntegrationState: integration,
            connectionRecord: connectionRecord,
            snapshot: snapshot,
            baseline: baseline,
            cachedDayCount: cachedDayCount ?? (snapshot == nil ? 0 : 3)
        )
    }

    private func resolveNextStep(
        statusInput: HealthIntegrationStatusInput,
        status: HealthIntegrationStatus,
        behavioralAction: NextBestAction = .none
    ) -> TodayHealthNextBestActionState {
        TodayHealthIntegrationNextStepResolver.resolve(
            integrationStatus: status,
            signalAvailability: HealthIntegrationStatusResolver.resolveSignalAvailability(from: statusInput),
            behavioralAction: behavioralAction,
            hasPriorConnectionEvidence: statusInput.hasPriorConnectionEvidence
        )
    }

    private func buildSection(
        snapshot: HealthIntelligenceSnapshot?,
        nutritionProgress: TodayHealthIntelligenceNutritionProgress = .unavailable,
        trainingIntegrationState: TrainingIntegrationState,
        connectionRecord: HealthIntegrationConnectionRecord,
        availability: HealthDataAvailability,
        baseline: HealthBaselineContext? = nil,
        cachedDayCount: Int? = nil
    ) -> TodayHealthIntelligenceSectionState {
        let resolvedCachedDayCount = cachedDayCount ?? availability.cachedDayCount
        guard let section = TodayHealthIntelligencePresentationBuilder.buildSection(
            snapshot: snapshot,
            nutritionProgress: nutritionProgress,
            isUIEnabled: true,
            availability: availability,
            isAppleHealthConnected: trainingIntegrationState.isConnected,
            trainingIntegrationState: trainingIntegrationState,
            connectionRecord: connectionRecord,
            cachedDayCount: resolvedCachedDayCount,
            baseline: baseline
        ) else {
            XCTFail("Expected section state")
            return TodayHealthIntelligenceSectionState(
                recoveryCard: .loading,
                dailyMission: .loading,
                nextBestAction: .loading,
                workoutCard: nil,
                adaptiveNutritionCard: nil,
                isLoading: false,
                fallbackMessage: nil,
                uiState: nil,
                staleDataLabel: nil
            )
        }
        return section
    }
}
