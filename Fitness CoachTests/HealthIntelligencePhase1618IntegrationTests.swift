//
//  HealthIntelligencePhase1618IntegrationTests.swift
//  Fitness CoachTests
//
//  Phase 16–18 — UI state boundaries, surface fallbacks, and Coach context semantics.
//

import XCTest
@testable import Fitness_Coach

final class HealthIntelligencePhase1618IntegrationTests: XCTestCase {

    private var calendar: Calendar {
        HealthIntelligencePhase1618TestSupport.makeCalendar()
    }

    private var now: Date {
        HealthIntelligencePhase1618TestSupport.referenceNow(calendar: calendar)
    }

    private var referenceDay: Date {
        HealthIntelligencePhase1618TestSupport.referenceDay(calendar: calendar)
    }

    // MARK: - 1. Remote sync payload contract

    func testSyncEnvelopeRoundTripPreservesSchemaVersion() throws {
        let envelope = HealthSummarySyncEnvelope(
            id: "2026-07-03",
            userId: "user-123",
            localDate: "2026-07-03",
            timezone: "UTC",
            generatedAt: now,
            source: .appleHealth,
            confidence: .moderate,
            missingSignals: []
        )

        let decoded = try HealthSummaryRemoteSyncTestSupport.roundTrip(envelope)
        XCTAssertEqual(decoded.schemaVersion, HealthSummarySyncSchemaVersion.current)
        XCTAssertEqual(decoded, envelope)
    }

    func testDailyPayloadCarriesCurrentSchemaVersion() {
        let day = referenceDay
        let metrics = DailyHealthMetrics(date: day, steps: 8_000, activeEnergyKcal: 400, exerciseMinutes: 35)
        let context = HealthIntelligencePhase1618TestSupport.makeMappingContext(calendar: calendar)

        let payload = HealthDailySummarySyncPayload.make(from: metrics, dayWorkouts: [], context: context)

        XCTAssertEqual(payload.schemaVersion, HealthSummarySyncSchemaVersion.current)
        XCTAssertEqual(payload.id, "2026-07-03")
    }

    // MARK: - 4. HealthIntelligenceUIState boundaries

    func testStaleBoundaryExactlyTwentyFourHoursIsNotStale() {
        let syncAt = now.addingTimeInterval(-HealthIntelligenceUIStatePolicy.defaultStaleInterval)
        let state = resolveUIState(
            snapshot: HealthIntelligencePhase1618TestSupport.activitySnapshot(on: referenceDay),
            lastSuccessfulLocalSyncAt: syncAt
        )

        XCTAssertNotEqual(state.kind, .staleData)
    }

    func testStaleBoundaryJustPastTwentyFourHoursMarksStale() {
        let syncAt = now.addingTimeInterval(-(HealthIntelligenceUIStatePolicy.defaultStaleInterval + 1))
        let state = resolveUIState(
            snapshot: HealthIntelligencePhase1618TestSupport.activitySnapshot(on: referenceDay),
            lastSuccessfulLocalSyncAt: syncAt
        )

        XCTAssertEqual(state.kind, .staleData)
        XCTAssertEqual(state.fallbackReason, .staleLocalCache)
        XCTAssertTrue(state.canShowInsight)
    }

    func testBaselineBoundarySixDaysIsNotEnough() {
        let state = resolveUIState(
            snapshot: HealthIntelligencePhase1618TestSupport.sparseSnapshot(on: referenceDay),
            cachedDayCount: HealthIntelligenceUIStatePolicy.minimumBaselineDays - 1,
            baseline: .empty(for: referenceDay)
        )

        XCTAssertEqual(state.kind, .notEnoughBaseline)
        XCTAssertEqual(state.fallbackReason, .insufficientBaselineHistory)
    }

    func testBaselineBoundarySevenDaysSkipsNotEnoughBaseline() {
        let baseline = HealthIntelligencePhase1618TestSupport.baselineWithoutWorkouts(on: referenceDay)
        let state = resolveUIState(
            snapshot: HealthIntelligencePhase1618TestSupport.activitySnapshot(on: referenceDay),
            cachedDayCount: HealthIntelligenceUIStatePolicy.minimumBaselineDays,
            baseline: baseline
        )

        XCTAssertEqual(state.kind, .noWorkoutHistory)
    }

    func testNoSleepDataStateWhenSleepPermittedButMissing() {
        let state = resolveUIState(
            snapshot: HealthIntelligenceSnapshot(
                date: referenceDay,
                recovery: RecoverySummary(
                    score: 58,
                    status: .moderate,
                    title: "Moderate",
                    explanation: "Sleep missing.",
                    recommendedTraining: "Steady.",
                    recommendedNutrition: "Protein.",
                    confidence: .moderate,
                    contributingFactors: [],
                    missingSignals: [.sleep]
                ),
                workout: .noWorkout,
                activity: ActivitySummary(steps: 7_000, activeEnergyKcal: 350, exerciseMinutes: 25),
                nutritionAdjustment: .none,
                weeklyReview: nil,
                planConfidence: PlanHealthConfidence(score: 0.5, label: "Moderate"),
                nextBestAction: .none
            ),
            baseline: HealthIntelligencePhase1618TestSupport.baselineMissingSleepAndHeart(on: referenceDay)
        )

        XCTAssertEqual(state.kind, .noSleepData)
        XCTAssertTrue(state.missingInsightKinds.contains(.sleep))
    }

    func testNoHeartDataStateWhenHeartPermittedButMissing() {
        let state = resolveUIState(
            snapshot: HealthIntelligenceSnapshot(
                date: referenceDay,
                recovery: RecoverySummary(
                    score: 58,
                    status: .moderate,
                    title: "Moderate",
                    explanation: "Heart missing.",
                    recommendedTraining: "Steady.",
                    recommendedNutrition: "Protein.",
                    confidence: .moderate,
                    contributingFactors: [],
                    missingSignals: [.restingHeartRate, .hrv]
                ),
                workout: .noWorkout,
                activity: ActivitySummary(steps: 7_000, activeEnergyKcal: 350, exerciseMinutes: 25),
                nutritionAdjustment: .none,
                weeklyReview: nil,
                planConfidence: PlanHealthConfidence(score: 0.5, label: "Moderate"),
                nextBestAction: .none
            ),
            baseline: HealthIntelligencePhase1618TestSupport.baselineMissingSleepAndHeart(on: referenceDay)
        )

        XCTAssertEqual(state.kind, .noHeartData)
        XCTAssertTrue(
            state.missingInsightKinds.contains(.restingHeartRate)
                || state.missingInsightKinds.contains(.hrv)
        )
    }

    func testSyncFailedStateBlocksInsightEvenWithCachedSnapshot() {
        let state = resolveUIState(
            snapshot: HealthIntelligencePhase1618TestSupport.activitySnapshot(on: referenceDay),
            syncPhase: .failed,
            explicitErrorMessage: "Network unavailable"
        )

        XCTAssertEqual(state.kind, .syncFailed)
        XCTAssertFalse(state.canShowInsight)
        XCTAssertEqual(state.fallbackReason, .syncFailed)
        XCTAssertEqual(state.primaryAction, .retrySync)
    }

    func testReadyStateWhenSignalsSupportInsight() {
        let state = resolveUIState(
            snapshot: HealthIntelligenceSnapshot(
                date: referenceDay,
                recovery: RecoverySummary(
                    score: 82,
                    status: .ready,
                    title: "Ready",
                    explanation: "Supportive recovery.",
                    recommendedTraining: "Train as planned.",
                    recommendedNutrition: "Keep protein on track.",
                    confidence: .high,
                    contributingFactors: [],
                    missingSignals: []
                ),
                workout: .noWorkout,
                activity: ActivitySummary(steps: 9_000, activeEnergyKcal: 550, exerciseMinutes: 50),
                nutritionAdjustment: .none,
                weeklyReview: nil,
                planConfidence: PlanHealthConfidence(score: 0.82, label: "Strong"),
                nextBestAction: .none
            )
        )

        XCTAssertEqual(state.kind, .ready)
        XCTAssertTrue(state.canShowInsight)
        XCTAssertEqual(state.fallbackReason, .none)
    }

    // MARK: - 5. Today fallback mapping

    func testTodayNilSnapshotUsesUnknownUIStateAndFallback() {
        let section = TodayHealthIntelligencePresentationBuilder.buildSection(
            snapshot: nil,
            isUIEnabled: true,
            availability: HealthIntelligencePhase1618TestSupport.availability(.full, cachedDayCount: 3),
            isAppleHealthConnected: true,
            cachedDayCount: 3
        )

        XCTAssertNotNil(section)
        XCTAssertEqual(section?.uiState?.kind, .unknown)
        XCTAssertNotNil(section?.fallbackMessage)
        XCTAssertEqual(section?.recoveryCard.phase, .unknown)
        XCTAssertNil(section?.workoutCard)
    }

    func testTodayRecoveryUnknownMapsUnknownPhase() {
        let snapshot = HealthIntelligenceSnapshot(
            date: referenceDay,
            recovery: .unknown,
            workout: nil,
            activity: ActivitySummary(steps: 4_000, activeEnergyKcal: 220, exerciseMinutes: 20),
            nutritionAdjustment: .none,
            weeklyReview: nil,
            planConfidence: .unknown,
            nextBestAction: .none
        )

        let section = buildTodaySection(snapshot: snapshot)

        XCTAssertEqual(section.recoveryCard.phase, .unknown)
    }

    func testTodayStaleDataUsesStaleLabelFromLastSuccessfulSync() {
        let anchor = Date()
        let staleSync = anchor.addingTimeInterval(-(25 * 60 * 60))
        let section = TodayHealthIntelligencePresentationBuilder.buildSection(
            snapshot: HealthIntelligencePhase1618TestSupport.activitySnapshot(on: referenceDay),
            isUIEnabled: true,
            availability: HealthIntelligencePhase1618TestSupport.availability(.full, cachedDayCount: 5),
            isAppleHealthConnected: true,
            cachedDayCount: 5,
            lastSuccessfulLocalSyncAt: staleSync
        )!

        XCTAssertEqual(section.uiState?.kind, .staleData)
        XCTAssertEqual(
            section.staleDataLabel,
            FormaProductCopy.Today.HealthIntelligence.staleDataLabel
        )
        XCTAssertEqual(section.recoveryCard.phase, .moderate)
    }

    func testTodaySyncFailedStillSurfacesCachedRecoveryCard() {
        let section = TodayHealthIntelligencePresentationBuilder.buildSection(
            snapshot: HealthIntelligencePhase1618TestSupport.activitySnapshot(on: referenceDay),
            isUIEnabled: true,
            availability: HealthIntelligencePhase1618TestSupport.availability(.full, cachedDayCount: 7),
            isAppleHealthConnected: true,
            cachedDayCount: 7,
            errorMessage: "Network unavailable",
            syncPhase: .failed
        )!

        XCTAssertEqual(section.uiState?.kind, .syncFailed)
        XCTAssertEqual(section.recoveryCard.phase, .moderate)
        XCTAssertEqual(section.recoveryCard.title, "Moderate recovery")
    }

    func testTodayLowConfidenceRecoveryUsesLimitedEstimatePhase() {
        let section = buildTodaySection(
            snapshot: HealthIntelligencePhase1618TestSupport.limitedRecoverySnapshot(on: referenceDay)
        )

        XCTAssertEqual(section.recoveryCard.phase, .limitedEstimate)
        XCTAssertEqual(
            section.recoveryCard.confidenceNote,
            FormaProductCopy.Today.HealthIntelligence.limitedEstimate
        )
    }

    func testTodayNoWorkoutDataOmitsWorkoutCard() {
        let section = buildTodaySection(
            snapshot: HealthIntelligencePhase1618TestSupport.activitySnapshot(on: referenceDay)
        )

        XCTAssertNil(section.workoutCard)
    }

    // MARK: - 6. Coach context fallback

    func testCoachContextNoHealthDataIsUnavailable() {
        let input = HealthIntelligencePhase1618TestSupport.coachResolverInput(
            snapshot: HealthIntelligencePhase1618TestSupport.connectHealthSnapshot(on: referenceDay),
            preset: .denied,
            awarenessAvailable: false,
            now: now,
            calendar: calendar
        )

        XCTAssertEqual(CoachHealthContextStatusResolver.resolveStatus(from: input), .unavailable)
        XCTAssertTrue(CoachHealthContextStatusResolver.missingSignalLabels(from: input).contains("Apple Health connection"))
    }

    func testCoachContextPartialHealthDataIsPartial() {
        let input = HealthIntelligencePhase1618TestSupport.coachResolverInput(
            snapshot: HealthIntelligencePhase1618TestSupport.sparseSnapshot(on: referenceDay),
            preset: .partialStepsOnly,
            now: now,
            calendar: calendar
        )

        XCTAssertEqual(CoachHealthContextStatusResolver.resolveStatus(from: input), .partial)
        XCTAssertTrue(CoachHealthContextStatusResolver.availableSignalLabels(from: input).contains("steps"))
    }

    func testCoachContextMissingWorkoutSignalDoesNotClaimWorkoutCompleted() {
        let context = CoachHealthIntelligenceContextBuilder.build(
            from: HealthIntelligencePhase1618TestSupport.stepsOnlySnapshot(on: referenceDay),
            input: CoachHealthIntelligenceContextBuilder.BuildInput(
                availability: HealthIntelligencePhase1618TestSupport.availability(.partialStepsOnly),
                awarenessAvailable: true,
                now: now
            ),
            calendar: calendar
        )

        XCTAssertFalse(context.workoutCompletedToday)
        XCTAssertFalse(context.availableSignals.contains("workouts"))
    }

    func testCoachContextMissingStepsSignalDoesNotReportStepCount() {
        let context = CoachHealthIntelligenceContextBuilder.build(
            from: HealthIntelligencePhase1618TestSupport.workoutsOnlySnapshot(on: referenceDay),
            input: CoachHealthIntelligenceContextBuilder.BuildInput(
                availability: HealthIntelligencePhase1618TestSupport.availability(.partialWorkoutsOnly),
                awarenessAvailable: true,
                now: now
            ),
            calendar: calendar
        )

        XCTAssertTrue(context.workoutCompletedToday)
        XCTAssertNil(context.stepsToday)
    }

    func testCoachContextStaleSyncMarksStaleStatus() {
        let staleSync = now.addingTimeInterval(-(25 * 60 * 60))
        let input = HealthIntelligencePhase1618TestSupport.coachResolverInput(
            snapshot: HealthIntelligencePhase1618TestSupport.activitySnapshot(on: referenceDay),
            lastHealthSyncAt: staleSync,
            now: now,
            calendar: calendar
        )

        XCTAssertEqual(CoachHealthContextStatusResolver.resolveStatus(from: input), .stale)
    }

    func testCoachContextLowConfidenceRecoveryUsesLimitedLabel() {
        let context = CoachHealthIntelligenceContextBuilder.build(
            from: HealthIntelligencePhase1618TestSupport.limitedRecoverySnapshot(on: referenceDay),
            input: CoachHealthIntelligenceContextBuilder.BuildInput(
                availability: HealthIntelligencePhase1618TestSupport.availability(.full),
                awarenessAvailable: true,
                now: now
            ),
            calendar: calendar
        )

        XCTAssertEqual(context.recoveryConfidence, "limited")
        XCTAssertEqual(
            context.healthDataConfidenceLabel,
            FormaProductCopy.HealthIntelligence.limitedEstimateLabel
        )
    }

    // MARK: - 7. Journey / Plan state builders

    func testJourneyNoDataShowsConnectCTA() {
        let section = JourneyHealthIntelligencePresentationBuilder.buildSection(
            input: JourneyHealthIntelligenceBuildInput(healthConnection: .notConnected),
            calendar: calendar,
            isUIEnabled: true
        )

        XCTAssertNotNil(section?.connectHealthCTA)
        XCTAssertEqual(section?.workoutHistory.emptyKind, .noHealthData)
        XCTAssertEqual(section?.recoveryTimeline.phase, .empty)
    }

    func testJourneyPartialDataShowsPartialSignalsNote() {
        let section = JourneyHealthIntelligencePresentationBuilder.buildSection(
            input: JourneyHealthIntelligenceBuildInput(
                todaySnapshot: HealthIntelligencePhase1618TestSupport.activitySnapshot(on: referenceDay),
                recoveryDays: [
                    JourneyHealthIntelligenceRecoveryDayInput(
                        date: referenceDay,
                        recovery: HealthIntelligencePhase1618TestSupport.activitySnapshot(on: referenceDay).recovery,
                        steps: 8_000
                    )
                ],
                workoutRecords: [],
                healthConnection: .connected,
                availability: HealthIntelligencePhase1618TestSupport.availability(.partialStepsOnly, cachedDayCount: 5),
                cachedDayCount: 5
            ),
            calendar: calendar,
            isUIEnabled: true
        )

        XCTAssertNotNil(section?.partialSignalsNote)
        XCTAssertEqual(section?.recoveryTimeline.phase, .loaded)
    }

    func testJourneySyncFailedWithoutInsightShowsErrorTimeline() {
        let section = JourneyHealthIntelligencePresentationBuilder.buildSection(
            input: JourneyHealthIntelligenceBuildInput(
                todaySnapshot: HealthIntelligencePhase1618TestSupport.activitySnapshot(on: referenceDay),
                recoveryDays: [
                    JourneyHealthIntelligenceRecoveryDayInput(
                        date: referenceDay,
                        recovery: HealthIntelligencePhase1618TestSupport.activitySnapshot(on: referenceDay).recovery,
                        steps: 8_000
                    )
                ],
                workoutRecords: [],
                healthConnection: .connected,
                cachedDayCount: 7,
                errorMessage: "Network unavailable",
                syncPhase: .failed
            ),
            calendar: calendar,
            isUIEnabled: true
        )

        XCTAssertEqual(section?.uiState?.kind, .syncFailed)
        XCTAssertEqual(section?.recoveryTimeline.phase, .error)
        XCTAssertNotNil(section?.recoveryTimeline.errorMessage)
    }

    func testJourneyMissingWeeklyReviewUsesNotEnoughDataCopy() {
        let presentation = JourneyHealthIntelligencePresentationBuilder.weeklyReviewPresentation(
            from: nil,
            isLoading: false,
            showBuildingWhenMissing: true,
            uiState: HealthIntelligenceUIStateMapper.resolve(
                HealthIntelligencePhase1618TestSupport.uiContext(
                    snapshot: HealthIntelligencePhase1618TestSupport.activitySnapshot(on: referenceDay),
                    cachedDayCount: 3,
                    surface: .journey,
                    now: now,
                    calendar: calendar
                )
            ),
            calendar: calendar
        )

        XCTAssertEqual(presentation.card?.phase, .empty)
        XCTAssertEqual(
            presentation.card?.title,
            FormaProductCopy.WeeklyReviewPresentation.notEnoughDataTitle
        )
    }

    func testPlanNoDataShowsLimitedQualityAndConnectAction() {
        let section = PlanHealthIntelligencePresentationBuilder.buildSection(
            input: PlanHealthIntelligenceBuildInput(
                planConfidence: .unknown,
                baselineContext: .empty(for: referenceDay),
                recovery: .unknown,
                userPlan: UserPlanContext(calorieTarget: 2_100, proteinTargetGrams: 150),
                healthConnection: .disconnected
            ),
            calendar: calendar
        )

        XCTAssertEqual(section.dataQuality.qualityLevel, .limited)
        XCTAssertEqual(section.coreSignals.count, 5)
        XCTAssertTrue(section.missingDataActions.contains { $0.id == "connect-health" })
    }

    func testPlanPartialDataShowsPartialPermissionsAction() {
        let section = PlanHealthIntelligencePresentationBuilder.buildSection(
            input: PlanHealthIntelligenceBuildInput(
                planConfidence: PlanHealthConfidence(score: 0.52, label: "Moderate"),
                baselineContext: HealthIntelligencePhase1618TestSupport.baselineMissingSleepAndHeart(on: referenceDay),
                recovery: .unknown,
                userPlan: UserPlanContext(calorieTarget: 2_200, proteinTargetGrams: 165, isAppleHealthConnected: true),
                healthConnection: .partial,
                healthAvailability: HealthIntelligencePhase1618TestSupport.availability(.partialStepsOnly),
                cachedDayCount: 5
            ),
            calendar: calendar
        )

        XCTAssertTrue(section.missingDataActions.contains { $0.id == "partial-permissions" })
        XCTAssertEqual(section.dataQuality.qualityLevel, .limited)
    }

    func testPlanCachedDataRemainsLoadedDuringSyncFailure() {
        let section = PlanHealthIntelligencePresentationBuilder.buildSection(
            input: PlanHealthIntelligenceBuildInput(
                planConfidence: PlanHealthConfidence(score: 0.75, label: "Moderate"),
                baselineContext: HealthIntelligencePhase1618TestSupport.baselineWithoutWorkouts(on: referenceDay),
                recovery: RecoverySummary(
                    score: 68,
                    status: .moderate,
                    title: "Moderate",
                    explanation: "Cached recovery.",
                    recommendedTraining: "Steady.",
                    recommendedNutrition: "Protein.",
                    confidence: .moderate,
                    contributingFactors: [],
                    missingSignals: []
                ),
                userPlan: UserPlanContext(calorieTarget: 2_200, proteinTargetGrams: 165, isAppleHealthConnected: true),
                healthConnection: .connected,
                healthAvailability: HealthIntelligencePhase1618TestSupport.availability(.full, cachedDayCount: 14),
                cachedDayCount: 14,
                errorMessage: "Network unavailable",
                syncPhase: .failed
            ),
            calendar: calendar
        )

        XCTAssertEqual(section.uiState?.kind, .syncFailed)
        XCTAssertEqual(section.confidenceCard.phase, .loaded)
        XCTAssertFalse(section.coreSignals.isEmpty)
    }

    func testPlanMissingAssumptionsMarkLimitedRows() {
        let section = PlanHealthIntelligencePresentationBuilder.buildSection(
            input: PlanHealthIntelligenceBuildInput(
                planConfidence: PlanHealthConfidence(score: 0.35, label: "Limited"),
                baselineContext: HealthIntelligencePhase1618TestSupport.baselineMissingSleepAndHeart(on: referenceDay),
                recovery: .unknown,
                userPlan: UserPlanContext(calorieTarget: 2_200, proteinTargetGrams: 165, isAppleHealthConnected: true),
                healthConnection: .partial,
                healthAvailability: HealthIntelligencePhase1618TestSupport.availability(.partialStepsOnly),
                cachedDayCount: 3
            ),
            calendar: calendar
        )

        XCTAssertTrue(section.assumptions.items.contains(where: \.isLimited))
        XCTAssertFalse(section.assumptions.items.isEmpty)
    }

    // MARK: - Helpers

    private func resolveUIState(
        snapshot: HealthIntelligenceSnapshot?,
        cachedDayCount: Int = 7,
        baseline: HealthBaselineContext? = nil,
        lastSuccessfulLocalSyncAt: Date? = nil,
        syncPhase: HealthSyncPhase? = nil,
        explicitErrorMessage: String? = nil
    ) -> HealthIntelligenceUIState {
        HealthIntelligenceUIStateMapper.resolve(
            HealthIntelligenceUIContext(
                explicitErrorMessage: explicitErrorMessage,
                syncPhase: syncPhase,
                lastSuccessfulLocalSyncAt: lastSuccessfulLocalSyncAt,
                availability: HealthIntelligencePhase1618TestSupport.availability(.full, cachedDayCount: cachedDayCount),
                snapshot: snapshot,
                baseline: baseline,
                isAppleHealthConnected: true,
                cachedDayCount: cachedDayCount,
                now: now
            )
        )
    }

    private func buildTodaySection(snapshot: HealthIntelligenceSnapshot) -> TodayHealthIntelligenceSectionState {
        guard let section = TodayHealthIntelligencePresentationBuilder.buildSection(
            snapshot: snapshot,
            isUIEnabled: true,
            availability: HealthIntelligencePhase1618TestSupport.availability(.full),
            isAppleHealthConnected: true,
            cachedDayCount: 7
        ) else {
            XCTFail("Expected Today section")
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
