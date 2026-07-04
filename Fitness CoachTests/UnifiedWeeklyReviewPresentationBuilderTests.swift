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
        XCTAssertNotNil(state.weightTrendBlock?.spikeWarning)
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
