//
//  PlanHealthIntelligencePresentationBuilderTests.swift
//  Fitness CoachTests
//

import XCTest
@testable import Fitness_Coach

final class PlanHealthIntelligencePresentationBuilderTests: XCTestCase {

    private var calendar: Calendar {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(secondsFromGMT: 0) ?? .gmt
        return calendar
    }

    private var referenceDay: Date {
        calendar.startOfDay(
            for: calendar.date(from: DateComponents(year: 2026, month: 7, day: 8))!
        )
    }

    // MARK: - Required scenarios

    func testStrongConfidenceBuildsStrongDataQualityAndReasons() {
        let section = PlanHealthIntelligencePresentationBuilder.buildSection(
            input: makeStrongInput(),
            calendar: calendar
        )

        XCTAssertEqual(section.confidenceCard.phase, .loaded)
        XCTAssertEqual(section.confidenceCard.confidenceLabel, FormaProductCopy.PlanHealthIntelligencePresentation.confidenceHigh)
        XCTAssertEqual(section.confidenceCard.scorePercent, 82)
        XCTAssertFalse(section.confidenceCard.reasons.isEmpty)
        XCTAssertTrue(section.confidenceCard.reasons.contains(FormaProductCopy.PlanHealthIntelligencePresentation.reasonWorkoutsSyncing))
        XCTAssertEqual(section.dataQuality.qualityLevel, .strong)
        XCTAssertEqual(section.dataQuality.qualityLabel, FormaProductCopy.PlanHealthIntelligencePresentation.dataQualityStrongLabel)
        XCTAssertEqual(section.assumptions.items.count, 6)
        XCTAssertTrue(section.missingDataActions.isEmpty)
        XCTAssertTrue(section.dataQuality.signals.contains { $0.kind == .appleHealthWorkouts && $0.status == .available })
        XCTAssertTrue(section.dataQuality.signals.contains { $0.kind == .heartMetrics && $0.status == .available })
        XCTAssertFalse(heartMetricsExposeRawValues(section))
    }

    func testModerateConfidenceBuildsModerateDataQuality() {
        let section = PlanHealthIntelligencePresentationBuilder.buildSection(
            input: makeModerateInput(),
            calendar: calendar
        )

        XCTAssertEqual(section.confidenceCard.confidenceLabel, FormaProductCopy.PlanHealthIntelligencePresentation.confidenceModerate)
        XCTAssertEqual(section.dataQuality.qualityLevel, .moderate)
        XCTAssertEqual(section.dataQuality.qualityLabel, FormaProductCopy.PlanHealthIntelligencePresentation.dataQualityModerateLabel)
        XCTAssertTrue(section.confidenceCard.reasons.contains(FormaProductCopy.PlanHealthIntelligencePresentation.reasonStepsConsistent))
        XCTAssertTrue(section.assumptions.items.contains { $0.id == "calorie-target" && !$0.isLimited })
        XCTAssertFalse(section.missingDataActions.contains { $0.id == "connect-health" })
    }

    func testLimitedDataShowsLimitedQualityAndImprovementHints() {
        let section = PlanHealthIntelligencePresentationBuilder.buildSection(
            input: makeLimitedInput(),
            calendar: calendar
        )

        XCTAssertEqual(section.confidenceCard.confidenceLabel, FormaProductCopy.PlanHealthIntelligencePresentation.confidenceLow)
        XCTAssertEqual(section.dataQuality.qualityLevel, .limited)
        XCTAssertTrue(section.confidenceCard.reasons.contains(FormaProductCopy.PlanHealthIntelligencePresentation.improveLogNutrition))
        XCTAssertTrue(section.confidenceCard.reasons.contains(FormaProductCopy.PlanHealthIntelligencePresentation.improveLogWeight))
        XCTAssertTrue(section.missingDataActions.contains { $0.id == "weight" })
        XCTAssertTrue(section.missingDataActions.contains { $0.id == "nutrition" })
        XCTAssertTrue(section.assumptions.items.contains { $0.isLimited })
    }

    func testDisconnectedPlanShowsDegradedConfidenceAndCoreSignals() {
        let section = PlanHealthIntelligencePresentationBuilder.buildSection(
            input: PlanHealthIntelligenceBuildInput(
                planConfidence: .unknown,
                baselineContext: .empty(for: referenceDay),
                recovery: .unknown,
                userPlan: UserPlanContext(calorieTarget: 2_100, proteinTargetGrams: 150),
                healthConnection: .disconnected,
                hasNutritionLogging: false,
                hasRecentWeightLog: false
            ),
            calendar: calendar
        )

        XCTAssertEqual(section.confidenceCard.phase, .loaded)
        XCTAssertEqual(section.confidenceCard.confidenceLabel, FormaProductCopy.PlanHealthIntelligencePresentation.confidenceUnknown)
        XCTAssertEqual(section.dataQuality.qualityLevel, .limited)
        XCTAssertEqual(section.coreSignals.count, 5)
        XCTAssertTrue(section.assumptions.items.contains { $0.isLimited })
        XCTAssertTrue(section.missingDataActions.contains { $0.id == "connect-health" })
        XCTAssertEqual(
            section.missingDataActions.first(where: { $0.id == "connect-health" })?.title,
            FormaProductCopy.PlanHealthIntelligencePresentation.actionConnectHealthTitle
        )
        XCTAssertTrue(section.dataQuality.signals.contains { $0.kind == .appleHealthWorkouts && $0.status == .missing })
    }

    func testMissingSleepAndHRVShowsPartialHeartAndSleepActions() {
        let section = PlanHealthIntelligencePresentationBuilder.buildSection(
            input: makeMissingSleepHRVInput(),
            calendar: calendar
        )

        XCTAssertTrue(section.dataQuality.signals.contains { $0.kind == .sleep && $0.status != .available })
        XCTAssertTrue(section.dataQuality.signals.contains { $0.kind == .heartMetrics && $0.status != .available })
        XCTAssertTrue(section.missingDataActions.contains { $0.id == "sleep" })
        XCTAssertTrue(section.missingDataActions.contains { $0.id == "heart-metrics" })
        XCTAssertFalse(heartMetricsExposeRawValues(section))
        XCTAssertFalse(combinedSignalValues(section).contains("ms"))
        XCTAssertFalse(combinedSignalValues(section).contains("bpm"))
    }

    func testMissingNutritionAndWeightShowsLoggingActions() {
        let section = PlanHealthIntelligencePresentationBuilder.buildSection(
            input: PlanHealthIntelligenceBuildInput(
                planConfidence: PlanHealthConfidence(score: 0.55, label: "Moderate"),
                baselineContext: makeStrongBaseline(),
                recovery: makeRecovery(score: 70, status: .moderate),
                userPlan: connectedPlan(),
                healthConnection: .connected,
                hasNutritionLogging: false,
                hasRecentWeightLog: false
            ),
            calendar: calendar
        )

        XCTAssertTrue(section.dataQuality.signals.contains { $0.kind == .weight && $0.status == .missing })
        XCTAssertTrue(section.dataQuality.signals.contains { $0.kind == .nutritionLogs && $0.status == .missing })
        XCTAssertTrue(section.missingDataActions.contains { $0.id == "weight" })
        XCTAssertTrue(section.missingDataActions.contains { $0.id == "nutrition" })
    }

    // MARK: - Supporting coverage

    func testBuildInputFromSnapshotMapsPlanConfidenceAndConnection() {
        let snapshot = HealthIntelligenceSnapshot(
            date: referenceDay,
            recovery: makeRecovery(score: 68, status: .moderate),
            workout: nil,
            activity: ActivitySummary(steps: 8_000, activeEnergyKcal: 400, exerciseMinutes: 35),
            nutritionAdjustment: .none,
            weeklyReview: nil,
            planConfidence: PlanHealthConfidence(score: 0.75, label: "Moderate"),
            nextBestAction: .none
        )

        let availability = HealthDataAvailability(
            isHealthDataAvailable: true,
            permissionStatus: .uniform(.available, isHealthDataAvailable: true),
            cachedDayCount: 14
        )

        let input = PlanHealthIntelligenceBuildInput.from(
            snapshot: snapshot,
            baselineContext: makeStrongBaseline(),
            userPlan: connectedPlan(),
            healthAvailability: availability,
            hasNutritionLogging: true,
            hasRecentWeightLog: true
        )

        XCTAssertEqual(input.planConfidence.label, "Moderate")
        XCTAssertEqual(input.recovery?.score, 68)
        XCTAssertEqual(input.healthConnection, .connected)
    }

    func testPartialPermissionsShowPartialActionAndExplanation() {
        let section = PlanHealthIntelligencePresentationBuilder.buildSection(
            input: makeModerateInput(),
            calendar: calendar
        )

        XCTAssertTrue(section.missingDataActions.contains { $0.id == "partial-permissions" })
        XCTAssertFalse(section.missingDataActions.contains { $0.id == "sleep" })
        XCTAssertFalse(section.missingDataActions.contains { $0.id == "heart-metrics" })
        XCTAssertEqual(
            section.dataQuality.explanation,
            FormaProductCopy.PlanHealthIntelligencePresentation.dataQualitySummaryPartial
        )
    }

    func testPartialPermissionsSuppressesGranularSleepAndHeartActions() {
        let section = PlanHealthIntelligencePresentationBuilder.buildSection(
            input: PlanHealthIntelligenceBuildInput(
                planConfidence: PlanHealthConfidence(score: 0.52, label: "Moderate"),
                baselineContext: makeSparseBaseline(),
                recovery: .unknown,
                userPlan: connectedPlan(),
                healthConnection: .partial,
                hasNutritionLogging: false,
                hasRecentWeightLog: false
            ),
            calendar: calendar
        )

        XCTAssertTrue(section.missingDataActions.contains { $0.id == "partial-permissions" })
        XCTAssertFalse(section.missingDataActions.contains { $0.id == "sleep" })
        XCTAssertFalse(section.missingDataActions.contains { $0.id == "heart-metrics" })
    }

    func testCodableRoundTripForSectionState() throws {
        let section = PlanHealthIntelligencePresentationBuilder.buildSection(
            input: makeStrongInput(),
            calendar: calendar
        )

        let data = try JSONEncoder().encode(section)
        let decoded = try JSONDecoder().decode(PlanHealthIntelligenceSectionState.self, from: data)

        XCTAssertEqual(decoded, section)
    }

    // MARK: - Core delegation parity

    func testSectionFallbackMessageUsesPlanPresentationPolicy() {
        let section = PlanHealthIntelligencePresentationBuilder.buildSection(
            input: PlanHealthIntelligenceBuildInput(
                planConfidence: .unknown,
                baselineContext: .empty(for: referenceDay),
                recovery: .unknown,
                userPlan: connectedPlan(),
                healthConnection: .disconnected,
                hasNutritionLogging: false,
                hasRecentWeightLog: false
            ),
            calendar: calendar
        )

        guard let uiState = section.uiState else {
            XCTFail("Expected uiState")
            return
        }

        XCTAssertEqual(
            section.fallbackMessage,
            HealthIntelligencePresentationCore.fallbackMessage(for: uiState, surface: .plan)
        )
    }

    func testStaleDataLabelUsesPlanPresentationPolicy() {
        let uiState = HealthIntelligenceUIState(
            kind: .staleData,
            title: "Stale",
            message: "Cached data may be outdated.",
            primaryActionTitle: nil,
            secondaryActionTitle: nil,
            primaryAction: .none,
            secondaryAction: .none,
            severity: .warning,
            canShowInsight: true,
            confidenceLabel: nil,
            missingSignals: [],
            fallbackReason: .staleLocalCache
        )

        XCTAssertEqual(
            HealthIntelligencePresentationCore.staleDataLabel(for: uiState, surface: .plan),
            FormaProductCopy.Today.HealthIntelligence.staleDataLabel
        )
    }

    func testBuildSectionUsesSectionLoaderCoreClassificationForStaleLabel() {
        let now = Date()
        let planInput = PlanHealthIntelligenceBuildInput(
            planConfidence: PlanHealthConfidence(score: 0.62, label: "Moderate"),
            baselineContext: HealthIntelligencePresentationCharacterizationFixtures.strongPlanBaseline(),
            recovery: HealthIntelligencePresentationCharacterizationFixtures.planRecovery(),
            userPlan: HealthIntelligencePresentationCharacterizationFixtures.connectedPlan(),
            healthConnection: .connected,
            healthAvailability: HealthIntelligencePresentationCharacterizationFixtures.connectedAvailability,
            hasNutritionLogging: true,
            hasRecentWeightLog: true,
            cachedDayCount: 10,
            lastSuccessfulLocalSyncAt: HealthIntelligencePresentationCharacterizationFixtures.staleLastSyncAt(from: now)
        )
        let section = PlanHealthIntelligencePresentationBuilder.buildSection(
            input: planInput,
            calendar: calendar
        )

        guard let uiState = section.uiState else {
            XCTFail("Expected uiState")
            return
        }

        XCTAssertEqual(section.uiState?.kind, .staleData)
        XCTAssertEqual(
            section.staleDataLabel,
            HealthIntelligencePresentationCore.staleDataLabel(for: uiState, surface: .plan)
        )
    }

    func testMissingDataActionAccessibilityUsesSharedJoinedLabel() {
        let action = PlanHealthIntelligencePresentationBuilder.missingDataActions(
            from: PlanHealthIntelligenceBuildInput(
                planConfidence: .unknown,
                baselineContext: .empty(for: referenceDay),
                recovery: .unknown,
                userPlan: connectedPlan(),
                healthConnection: .disconnected,
                hasNutritionLogging: false,
                hasRecentWeightLog: false
            )
        ).first { $0.id == "connect-health" }

        XCTAssertEqual(
            action?.accessibilityLabel,
            HealthIntelligencePresentationAccessibility.joinedLabel(
                parts: [
                    FormaProductCopy.PlanHealthIntelligencePresentation.actionConnectHealthTitle,
                    FormaProductCopy.PlanHealthIntelligencePresentation.actionConnectHealthMessage
                ]
            )
        )
    }

    // MARK: - Fixtures

    private func makeStrongInput() -> PlanHealthIntelligenceBuildInput {
        PlanHealthIntelligenceBuildInput(
            planConfidence: PlanHealthConfidence(score: 0.82, label: "High"),
            baselineContext: makeStrongBaseline(),
            recovery: makeRecovery(score: 74, status: .moderate),
            userPlan: connectedPlan(),
            healthConnection: .connected,
            hasNutritionLogging: true,
            hasRecentWeightLog: true
        )
    }

    private func makeModerateInput() -> PlanHealthIntelligenceBuildInput {
        PlanHealthIntelligenceBuildInput(
            planConfidence: PlanHealthConfidence(score: 0.58, label: "Moderate"),
            baselineContext: makeModerateBaseline(),
            recovery: makeRecovery(score: 62, status: .moderate),
            userPlan: connectedPlan(),
            healthConnection: .partial,
            hasNutritionLogging: false,
            hasRecentWeightLog: false
        )
    }

    private func makeLimitedInput() -> PlanHealthIntelligenceBuildInput {
        PlanHealthIntelligenceBuildInput(
            planConfidence: PlanHealthConfidence(score: 0.35, label: "Limited"),
            baselineContext: makeSparseBaseline(),
            recovery: .unknown,
            userPlan: connectedPlan(),
            healthConnection: .partial,
            hasNutritionLogging: false,
            hasRecentWeightLog: false
        )
    }

    private func makeMissingSleepHRVInput() -> PlanHealthIntelligenceBuildInput {
        PlanHealthIntelligenceBuildInput(
            planConfidence: PlanHealthConfidence(score: 0.52, label: "Moderate"),
            baselineContext: makeSparseBaseline(),
            recovery: .unknown,
            userPlan: connectedPlan(),
            healthConnection: .connected,
            hasNutritionLogging: true,
            hasRecentWeightLog: true
        )
    }

    private func connectedPlan() -> UserPlanContext {
        UserPlanContext(
            calorieTarget: 2_200,
            proteinTargetGrams: 165,
            isAppleHealthConnected: true
        )
    }

    private func makeStrongBaseline() -> HealthBaselineContext {
        HealthBaselineContext(
            targetDate: referenceDay,
            averageSteps7d: 8_450,
            averageSteps28d: 7_900,
            averageActiveEnergy7d: 420,
            averageActiveEnergy28d: 390,
            averageSleepDuration7d: 426,
            averageSleepDuration28d: 408,
            averageRestingHeartRate28d: 58,
            averageHRV28d: 52,
            averageWorkoutLoad28d: 180,
            workoutDays7d: 4,
            workoutDays28d: 12,
            availableSignals: [.steps, .activeEnergy, .sleep, .restingHeartRate, .hrv, .workoutLoad],
            missingSignals: []
        )
    }

    private func makeModerateBaseline() -> HealthBaselineContext {
        HealthBaselineContext(
            targetDate: referenceDay,
            averageSteps7d: 7_200,
            averageSteps28d: 6_800,
            averageActiveEnergy7d: 360,
            averageActiveEnergy28d: nil,
            averageSleepDuration7d: 390,
            averageSleepDuration28d: nil,
            averageRestingHeartRate28d: nil,
            averageHRV28d: nil,
            averageWorkoutLoad28d: 120,
            workoutDays7d: 3,
            workoutDays28d: 9,
            availableSignals: [.steps, .activeEnergy, .sleep, .workoutLoad],
            missingSignals: [.hrv, .restingHeartRate]
        )
    }

    private func makeSparseBaseline() -> HealthBaselineContext {
        HealthBaselineContext(
            targetDate: referenceDay,
            averageSteps7d: 5_200,
            averageSteps28d: nil,
            averageActiveEnergy7d: nil,
            averageActiveEnergy28d: nil,
            averageSleepDuration7d: nil,
            averageSleepDuration28d: nil,
            averageRestingHeartRate28d: nil,
            averageHRV28d: nil,
            averageWorkoutLoad28d: nil,
            workoutDays7d: 1,
            workoutDays28d: 2,
            availableSignals: [.steps, .workoutLoad],
            missingSignals: [.sleep, .hrv, .restingHeartRate, .activeEnergy]
        )
    }

    private func makeRecovery(score: Int, status: RecoveryStatus) -> RecoverySummary {
        RecoverySummary(
            score: score,
            status: status,
            title: "Recovery",
            explanation: "Explanation",
            recommendedTraining: "Train based on feel.",
            recommendedNutrition: "Stay on plan.",
            confidence: .moderate,
            contributingFactors: [],
            missingSignals: []
        )
    }

    private func heartMetricsExposeRawValues(_ section: PlanHealthIntelligenceSectionState) -> Bool {
        guard let heart = section.dataQuality.signals.first(where: { $0.kind == .heartMetrics }) else {
            return false
        }
        let value = heart.value.lowercased()
        return value.contains("ms") || value.contains("bpm") || value.contains("58") || value.contains("52")
    }

    private func combinedSignalValues(_ section: PlanHealthIntelligenceSectionState) -> String {
        section.dataQuality.signals.map(\.value).joined(separator: " ").lowercased()
    }

    // MARK: - Characterization fixtures A–E

    func testCharacterizationFixtureA_FullyReady_ShowsHighConfidenceAndStrongDataQuality() {
        let section = HealthIntelligencePresentationCharacterizationFixtures.buildPlanSection(for: .fullyReady)

        XCTAssertFalse(section.isLoading)
        XCTAssertEqual(section.confidenceCard.phase, .loaded)
        XCTAssertEqual(
            section.confidenceCard.confidenceLabel,
            FormaProductCopy.PlanHealthIntelligencePresentation.confidenceHigh
        )
        XCTAssertEqual(section.confidenceCard.scorePercent, 82)
        XCTAssertEqual(section.dataQuality.qualityLevel, .strong)
        XCTAssertEqual(
            section.dataQuality.qualityLabel,
            FormaProductCopy.PlanHealthIntelligencePresentation.dataQualityStrongLabel
        )
        XCTAssertTrue(section.missingDataActions.isEmpty)
        XCTAssertNil(section.fallbackMessage)
        XCTAssertNil(section.staleDataLabel)
        XCTAssertFalse(section.accessibilityLabel.isEmpty)
        XCTAssertEqual(section.uiState?.kind, .ready)
    }

    func testCharacterizationFixtureB_HealthKitDisconnected_ShowsConnectHealthActionAndUnknownConfidence() {
        let section = HealthIntelligencePresentationCharacterizationFixtures.buildPlanSection(for: .healthKitDisconnected)

        XCTAssertEqual(section.confidenceCard.phase, .loaded)
        XCTAssertEqual(
            section.confidenceCard.confidenceLabel,
            FormaProductCopy.PlanHealthIntelligencePresentation.confidenceUnknown
        )
        XCTAssertEqual(section.dataQuality.qualityLevel, .limited)
        XCTAssertTrue(section.missingDataActions.contains { $0.id == "connect-health" })
        XCTAssertEqual(
            section.missingDataActions.first(where: { $0.id == "connect-health" })?.title,
            FormaProductCopy.PlanHealthIntelligencePresentation.actionConnectHealthTitle
        )
        XCTAssertNil(section.staleDataLabel)
        XCTAssertFalse(section.accessibilityLabel.isEmpty)
    }

    func testCharacterizationFixtureC_StaleData_ShowsStaleLabelWithModerateConfidence() {
        let section = HealthIntelligencePresentationCharacterizationFixtures.buildPlanSection(for: .staleData)

        XCTAssertEqual(section.uiState?.kind, .staleData)
        XCTAssertEqual(
            section.staleDataLabel,
            FormaProductCopy.Today.HealthIntelligence.staleDataLabel
        )
        XCTAssertEqual(
            section.confidenceCard.confidenceLabel,
            FormaProductCopy.PlanHealthIntelligencePresentation.confidenceModerate
        )
        XCTAssertEqual(section.dataQuality.qualityLevel, .strong)
        XCTAssertNil(section.fallbackMessage)
        XCTAssertFalse(section.accessibilityLabel.isEmpty)
    }

    func testCharacterizationFixtureD_PartialSignals_ShowsPartialPermissionsActionAndSummary() {
        let section = HealthIntelligencePresentationCharacterizationFixtures.buildPlanSection(for: .partialSignals)

        XCTAssertEqual(
            section.confidenceCard.confidenceLabel,
            FormaProductCopy.PlanHealthIntelligencePresentation.confidenceModerate
        )
        XCTAssertEqual(section.dataQuality.qualityLevel, .limited)
        XCTAssertEqual(
            section.dataQuality.explanation,
            FormaProductCopy.PlanHealthIntelligencePresentation.dataQualitySummaryPartial
        )
        XCTAssertTrue(section.missingDataActions.contains { $0.id == "partial-permissions" })
        XCTAssertFalse(section.missingDataActions.contains { $0.id == "sleep" })
        XCTAssertFalse(section.missingDataActions.contains { $0.id == "heart-metrics" })
        XCTAssertNil(section.staleDataLabel)
        XCTAssertFalse(section.accessibilityLabel.isEmpty)
    }

    func testCharacterizationFixtureE_WeeklyReviewUnavailable_KeepsPlanSectionStable() {
        let section = HealthIntelligencePresentationCharacterizationFixtures.buildPlanSection(for: .weeklyReviewUnavailable)

        XCTAssertEqual(section.confidenceCard.phase, .loaded)
        XCTAssertEqual(section.dataQuality.qualityLevel, .strong)
        XCTAssertNil(section.fallbackMessage)
        XCTAssertNil(section.staleDataLabel)
        XCTAssertEqual(section.uiState?.kind, .ready)
        XCTAssertFalse(section.accessibilityLabel.isEmpty)
    }
}
