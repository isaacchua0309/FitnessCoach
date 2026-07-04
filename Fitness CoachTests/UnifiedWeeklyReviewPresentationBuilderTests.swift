//
//  UnifiedWeeklyReviewPresentationBuilderTests.swift
//  Fitness CoachTests
//

import XCTest
@testable import Fitness_Coach

final class UnifiedWeeklyReviewPresentationBuilderTests: XCTestCase {

    func testStrongMomentumDashboardBuildsCanonicalWeeklyReview() {
        let dashboard = JourneyPreviewData.strongMomentum

        let state = UnifiedWeeklyReviewPresentationBuilder.build(
            dashboard: dashboard,
            healthIntelligence: nil
        )

        XCTAssertEqual(state.id, dashboard.weeklyProgressSummary.id)
        XCTAssertFalse(state.headline.isEmpty)
        XCTAssertFalse(state.summary.isEmpty)
        XCTAssertFalse(state.dateRangeText.isEmpty)
        XCTAssertFalse(state.habitRows.isEmpty)
        XCTAssertTrue(state.isReady)
        XCTAssertNotNil(state.primaryCTA)
    }

    func testBrandNewUserShowsInsufficientDataWithoutFakeMaintenanceKcal() {
        let dashboard = JourneyPreviewData.brandNewUser

        let state = UnifiedWeeklyReviewPresentationBuilder.build(dashboard: dashboard)

        XCTAssertTrue(state.isInsufficientData)
        XCTAssertNil(state.maintenanceBlock?.estimatedMaintenanceKcal)
        XCTAssertNotEqual(state.maintenanceBlock?.showsLearnedEstimate, true)
        XCTAssertEqual(state.primaryCTA?.kind, .keepLogging)
        XCTAssertNil(state.planRecommendationBlock)
    }

    func testHealthIntelligenceDetailAddsSupplementalInsightsWithoutReplacingCore() {
        let dashboard = JourneyPreviewData.strongMomentum
        let review = makeHealthReview()
        let detail = WeeklyReviewPresentationBuilder.buildDetail(from: review)
        let card = WeeklyReviewPresentationBuilder.buildCard(from: review)
        let healthSection = JourneyHealthIntelligenceSectionState(
            weeklyReviewCard: card,
            weeklyReviewDetail: detail,
            recoveryTimeline: .loading,
            workoutHistory: .loading,
            milestones: .loading,
            progress: .loading,
            connectHealthCTA: nil,
            isLoading: false,
            errorMessage: nil,
            fallbackMessage: nil,
            staleDataLabel: nil,
            partialSignalsNote: nil,
            uiState: nil
        )

        let state = UnifiedWeeklyReviewPresentationBuilder.build(
            dashboard: dashboard,
            healthIntelligence: healthSection
        )

        XCTAssertEqual(state.headline, dashboard.weeklyProgressSummary.headline)
        XCTAssertFalse(state.healthInsights.isEmpty)
        XCTAssertTrue(state.healthInsights.contains { $0.kind == .win })
        XCTAssertTrue(state.healthInsights.contains { $0.kind == .focus })
    }

    func testJourneyWeeklyHabitInputBuildsWithoutHealthIntelligence() {
        let dashboard = JourneyPreviewData.strongMomentum

        let state = UnifiedWeeklyReviewPresentationBuilder.build(
            UnifiedWeeklyReviewInput(
                summary: dashboard.weeklyProgressSummary,
                weeklyHabit: dashboard.weeklyHabit
            )
        )

        XCTAssertEqual(state.habitRows.count, dashboard.weeklyHabit.habits.count)
        XCTAssertTrue(state.healthInsights.isEmpty)
        XCTAssertTrue(state.isReady)
    }

    func testWeightTrendBlockReflectsSummarySpikeState() {
        let dashboard = JourneyPreviewData.strongMomentum
        var summary = dashboard.weeklyProgressSummary
        summary = WeeklyProgressSummary(
            id: summary.id,
            startDate: summary.startDate,
            endDate: summary.endDate,
            generatedAt: summary.generatedAt,
            confidence: summary.confidence,
            verdict: .noisyButLikelyOkay,
            nextAction: .holdSteady,
            maintenanceEstimate: summary.maintenanceEstimate,
            foodLoggedDays: summary.foodLoggedDays,
            totalDays: summary.totalDays,
            averageDailyCalories: summary.averageDailyCalories,
            averageDailyProteinGrams: summary.averageDailyProteinGrams,
            proteinHitDays: summary.proteinHitDays,
            calorieTargetHitDays: summary.calorieTargetHitDays,
            waterTargetHitDays: summary.waterTargetHitDays,
            trainingDays: summary.trainingDays,
            startingWeightKg: 80,
            endingWeightKg: 79.2,
            weightChangeKg: -0.8,
            weeklyWeightChangeKg: -0.8,
            hasSuddenSpike: true,
            headline: summary.headline,
            summary: summary.summary,
            primaryInsight: summary.primaryInsight,
            nextActionTitle: summary.nextActionTitle,
            nextActionSubtitle: summary.nextActionSubtitle,
            caveats: summary.caveats
        )

        let state = UnifiedWeeklyReviewPresentationBuilder.build(
            UnifiedWeeklyReviewInput(summary: summary)
        )

        XCTAssertNotNil(state.weightTrendBlock)
        XCTAssertTrue(state.weightTrendBlock?.hasSuddenSpike == true)
        XCTAssertNotNil(state.weightTrendBlock?.spikeShortBody)
        XCTAssertEqual(
            state.weightTrendBlock?.spikeShortBody,
            FormaProductCopy.WeightSpikeEducation.shortBody
        )
        XCTAssertEqual(
            state.weightTrendBlock?.spikeDetailBody,
            FormaProductCopy.WeightSpikeEducation.detailBody
        )
    }

    func testBuildDetailIncludesCanonicalSections() {
        let dashboard = JourneyPreviewData.strongMomentum
        let detail = UnifiedWeeklyReviewPresentationBuilder.buildDetail(dashboard: dashboard)

        XCTAssertFalse(detail.unified.headline.isEmpty)
        XCTAssertFalse(detail.verdictTitle.isEmpty)
        XCTAssertTrue(detail.consistency.hasContent)
        XCTAssertFalse(detail.generatedAtLabel.isEmpty)
        XCTAssertFalse(detail.nextWeekFocus.isEmpty)
        XCTAssertFalse(detail.accessibilityLabel.isEmpty)
    }

    func testBuildDetailIncludesDailyReviewsCountWhenPresent() {
        let dashboard = JourneyPreviewData.strongMomentum
        let detail = UnifiedWeeklyReviewPresentationBuilder.buildDetail(
            UnifiedWeeklyReviewInput(
                summary: dashboard.weeklyProgressSummary,
                dailyReviewsThisWeekCount: 4
            )
        )

        XCTAssertEqual(
            detail.consistency.dailyReviewsLabel,
            FormaProductCopy.WeeklyReviewPresentation.dailyReviewsValue(4)
        )
    }

    func testBuildIncludesFreshnessWhenProvided() {
        let dashboard = JourneyPreviewData.strongMomentum
        let freshnessInput = WeeklyProgressFreshnessInput(
            isRestoringAccount: false,
            isCrossDeviceRefreshing: false,
            pendingUploadCount: 1,
            lastRefreshAt: nil,
            recentlyRestoredAt: nil,
            now: Date()
        )

        let state = UnifiedWeeklyReviewPresentationBuilder.build(
            dashboard: dashboard,
            freshnessInput: freshnessInput
        )

        XCTAssertEqual(
            state.freshness?.cardMessage,
            FormaProductCopy.WeeklyReviewPresentation.Freshness.syncingChanges
        )
        XCTAssertEqual(
            UnifiedWeeklyReviewPresentationBuilder.buildDetail(
                dashboard: dashboard,
                freshnessInput: freshnessInput
            ).freshness?.detailMessage,
            FormaProductCopy.WeeklyReviewPresentation.Freshness.reviewMayUpdate
        )
    }

    func testBuildDetailMergesHealthIntelligenceFocusItems() {
        let dashboard = JourneyPreviewData.strongMomentum
        let review = makeHealthReview()
        let healthDetail = WeeklyReviewPresentationBuilder.buildDetail(from: review)
        let healthSection = JourneyHealthIntelligenceSectionState(
            weeklyReviewCard: WeeklyReviewPresentationBuilder.buildCard(from: review),
            weeklyReviewDetail: healthDetail,
            recoveryTimeline: .loading,
            workoutHistory: .loading,
            milestones: .loading,
            progress: .loading,
            connectHealthCTA: nil,
            isLoading: false,
            errorMessage: nil,
            fallbackMessage: nil,
            staleDataLabel: nil,
            partialSignalsNote: nil,
            uiState: nil
        )

        let detail = UnifiedWeeklyReviewPresentationBuilder.buildDetail(
            dashboard: dashboard,
            healthIntelligence: healthSection
        )

        XCTAssertGreaterThanOrEqual(detail.nextWeekFocus.count, 1)
        XCTAssertFalse(detail.unified.healthInsights.isEmpty)
    }

    func testSparseDashboardDetailStaysInsufficientWithoutFakeMaintenance() {
        let detail = UnifiedWeeklyReviewPresentationBuilder.buildDetail(
            dashboard: JourneyPreviewData.sparseData
        )

        XCTAssertTrue(detail.unified.isInsufficientData)
        XCTAssertNil(detail.unified.maintenanceBlock?.estimatedMaintenanceKcal)
        XCTAssertNil(detail.staticTDEEComparison)
    }

    // MARK: - Named presentation contract tests

    func testUnifiedBuilderShowsInsufficientDataState() {
        let state = UnifiedWeeklyReviewPresentationBuilder.build(
            dashboard: JourneyPreviewData.brandNewUser
        )

        XCTAssertTrue(state.isInsufficientData)
        XCTAssertEqual(state.primaryCTA?.kind, .keepLogging)
        XCTAssertNil(state.planRecommendationBlock)
        XCTAssertNil(state.maintenanceBlock?.estimatedMaintenanceKcal)
    }

    func testUnifiedBuilderShowsMaintenanceWhenEligible() {
        let dashboard = JourneyPreviewData.strongMomentum
        let state = UnifiedWeeklyReviewPresentationBuilder.build(dashboard: dashboard)

        XCTAssertNotNil(state.maintenanceBlock)
        XCTAssertTrue(state.maintenanceBlock?.showsLearnedEstimate == true)
        XCTAssertNotNil(state.maintenanceBlock?.estimatedMaintenanceKcal)
        XCTAssertFalse(state.maintenanceBlock?.accessibilityLabel.isEmpty ?? true)
    }

    func testUnifiedBuilderHidesMaintenanceWhenLowConfidence() {
        let dashboard = JourneyPreviewData.strongMomentum
        let lowConfidenceSummary = UnifiedWeeklyReviewTestFixtures.summary(
            base: dashboard.weeklyProgressSummary,
            confidence: .low,
            maintenanceEstimate: UnifiedWeeklyReviewTestFixtures.lowConfidenceMaintenanceEstimate(
                from: dashboard.weeklyProgressSummary.maintenanceEstimate
            )
        )

        let state = UnifiedWeeklyReviewPresentationBuilder.build(
            UnifiedWeeklyReviewInput(
                summary: lowConfidenceSummary,
                weeklyHabit: dashboard.weeklyHabit
            )
        )

        XCTAssertFalse(state.maintenanceBlock?.showsLearnedEstimate ?? true)
        XCTAssertNil(state.maintenanceBlock?.estimatedMaintenanceKcal)
    }

    func testUnifiedBuilderShowsPlanRecommendationWhenEligible() {
        let dashboard = JourneyPreviewData.strongMomentum
        let state = UnifiedWeeklyReviewPresentationBuilder.build(
            dashboard: dashboard,
            profile: PlanMissionControlFixtures.loseProfile
        )

        XCTAssertNotNil(state.planRecommendationBlock)
        XCTAssertFalse(state.planRecommendationBlock?.title.isEmpty ?? true)
        XCTAssertFalse(state.planRecommendationBlock?.accessibilityLabel.isEmpty ?? true)
    }

    func testUnifiedBuilderShowsWeightSpikeCopyWhenDetected() {
        let dashboard = JourneyPreviewData.strongMomentum
        let summary = UnifiedWeeklyReviewTestFixtures.summary(
            base: dashboard.weeklyProgressSummary,
            verdict: .noisyButLikelyOkay,
            hasSuddenSpike: true
        )

        let state = UnifiedWeeklyReviewPresentationBuilder.build(
            UnifiedWeeklyReviewInput(summary: summary)
        )

        XCTAssertEqual(state.weightTrendBlock?.spikeShortBody, FormaProductCopy.WeightSpikeEducation.shortBody)
        XCTAssertEqual(state.weightTrendBlock?.spikeDetailBody, FormaProductCopy.WeightSpikeEducation.detailBody)
        XCTAssertTrue(state.weightTrendBlock?.hasSuddenSpike == true)
    }

    func testUnifiedBuilderWorksWithoutHealthIntelligence() {
        let dashboard = JourneyPreviewData.strongMomentum
        let state = UnifiedWeeklyReviewPresentationBuilder.build(dashboard: dashboard)

        XCTAssertTrue(state.healthInsights.isEmpty)
        XCTAssertTrue(state.isReady)
        XCTAssertFalse(state.headline.isEmpty)
    }

    func testUnifiedBuilderIncludesHealthInsightsWhenAvailable() {
        let dashboard = JourneyPreviewData.strongMomentum
        let healthSection = UnifiedWeeklyReviewTestFixtures.makeHealthIntelligenceSection()

        let state = UnifiedWeeklyReviewPresentationBuilder.build(
            dashboard: dashboard,
            healthIntelligence: healthSection
        )

        XCTAssertFalse(state.healthInsights.isEmpty)
        XCTAssertTrue(state.healthInsights.contains { $0.kind == .win })
        XCTAssertEqual(state.headline, dashboard.weeklyProgressSummary.headline)
    }

    func testUnifiedBuilderDoesNotDuplicateHabitRows() {
        let dashboard = JourneyPreviewData.strongMomentum
        let state = UnifiedWeeklyReviewPresentationBuilder.build(dashboard: dashboard)

        let ids = state.habitRows.map(\.id)
        XCTAssertEqual(Set(ids).count, ids.count)
        XCTAssertEqual(state.habitRows.count, dashboard.weeklyHabit.habits.count)

        let habitTitles = Set(state.habitRows.map(\.title))
        let insightMessages = state.healthInsights.map(\.message)
        for title in habitTitles {
            XCTAssertFalse(
                insightMessages.contains { $0.localizedCaseInsensitiveContains(title) },
                "Health insight duplicated habit row title: \(title)"
            )
        }
    }

    // MARK: - Fixtures

    private func makeHealthReview() -> WeeklyHealthReview {
        let calendar = Calendar(identifier: .gregorian)
        let weekStart = calendar.startOfDay(
            for: calendar.date(from: DateComponents(year: 2026, month: 6, day: 27))!
        )
        let weekEnd = calendar.startOfDay(
            for: calendar.date(from: DateComponents(year: 2026, month: 7, day: 3))!
        )

        return WeeklyHealthReview(
            weekStartDate: weekStart,
            weekEndDate: weekEnd,
            title: "Solid training week",
            summary: "You logged workouts on four days and kept protein steady.",
            stats: WeeklyStats(
                totalWorkouts: 4,
                totalWorkoutMinutes: 180,
                totalActiveCalories: 900,
                averageSteps: 8_500,
                totalSteps: 59_500,
                proteinHitDays: 5,
                calorieTargetHitDays: 4,
                waterHitDays: 4,
                averageRecoveryScore: 72,
                lowRecoveryDays: 1,
                weightChangeKg: -0.4,
                loggingConsistencyDays: 6
            ),
            wins: ["4 workouts logged", "Protein on track most days"],
            risks: ["One low-recovery day after a hard session"],
            nextWeekFocus: ["Keep protein steady", "Add one easy recovery walk"],
            confidence: .moderate,
            missingSignals: [],
            generatedAt: weekEnd
        )
    }
}
