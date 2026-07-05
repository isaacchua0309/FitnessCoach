//
//  JourneyWeeklyProgressHeroTests.swift
//  Fitness CoachTests
//
//  Forma — Weekly progress hero card and detail presentation tests.
//

import SwiftUI
import XCTest
@testable import Fitness_Coach

@MainActor
final class JourneyWeeklyProgressHeroTests: XCTestCase {

    private var writesSnapshots: Bool {
        ProcessInfo.processInfo.environment["WEEKLY_PROGRESS_SNAPSHOTS"] == "1"
    }

    // MARK: - Accessibility & states

    func testWeeklyHeroCardUsesAccessibleLabels() {
        let dashboard = JourneyPreviewData.strongMomentum
        let state = UnifiedWeeklyReviewPresentationBuilder.build(dashboard: dashboard)

        XCTAssertFalse(state.confidenceAccessibilityLabel.isEmpty)
        XCTAssertFalse(state.confidenceLabel.isEmpty)
        XCTAssertNotNil(state.primaryCTA)
        XCTAssertFalse(state.primaryCTA?.accessibilityLabel.isEmpty ?? true)

        if let maintenance = state.maintenanceBlock {
            XCTAssertFalse(maintenance.accessibilityLabel.isEmpty)
        }
        if let plan = state.planRecommendationBlock {
            XCTAssertFalse(plan.accessibilityLabel.isEmpty)
        }
        if let weight = state.weightTrendBlock {
            XCTAssertFalse(weight.accessibilityLabel.isEmpty)
        }

        let detail = UnifiedWeeklyReviewPresentationBuilder.buildDetail(dashboard: dashboard)
        XCTAssertFalse(detail.accessibilityLabel.isEmpty)
        XCTAssertTrue(detail.accessibilityLabel.contains(state.confidenceAccessibilityLabel))
    }

    func testWeeklyHeroCardSupportsInsufficientData() {
        let dashboard = JourneyPreviewData.brandNewUser
        let state = UnifiedWeeklyReviewPresentationBuilder.build(dashboard: dashboard)

        XCTAssertTrue(state.isInsufficientData)
        XCTAssertEqual(state.primaryCTA?.kind, .keepLogging)
        XCTAssertEqual(
            state.confidenceLabel,
            FormaProductCopy.WeeklyReviewPresentation.notEnoughDataTitle
        )
        XCTAssertNil(state.maintenanceBlock?.estimatedMaintenanceKcal)
        XCTAssertNil(state.planRecommendationBlock)
    }

    func testWeeklyDetailShowsConfidenceAndCaveats() {
        let dashboard = JourneyPreviewData.strongMomentum
        let detail = UnifiedWeeklyReviewPresentationBuilder.buildDetail(dashboard: dashboard)

        XCTAssertFalse(detail.unified.confidenceLabel.isEmpty)
        XCTAssertFalse(detail.unified.confidenceAccessibilityLabel.isEmpty)
        XCTAssertFalse(detail.verdictTitle.isEmpty)
        XCTAssertFalse(detail.primaryInsight.isEmpty)
        XCTAssertFalse(detail.uncertaintyTitle.isEmpty)

        if !detail.unified.caveats.isEmpty {
            XCTAssertTrue(detail.accessibilityLabel.contains(detail.unified.caveats[0]))
        }
    }

    // MARK: - Lightweight snapshots (opt-in)

    func testSnapshotInsufficientData() throws {
        try writeSnapshotIfEnabled(
            name: "weekly_progress_insufficient_data",
            dashboard: JourneyPreviewData.brandNewUser
        )
    }

    func testSnapshotOnTrackMediumConfidence() throws {
        try writeSnapshotIfEnabled(
            name: "weekly_progress_on_track_medium",
            dashboard: JourneyPreviewData.strongMomentum
        )
    }

    func testSnapshotWeightSpike() throws {
        let dashboard = JourneyPreviewData.strongMomentum
        let summary = UnifiedWeeklyReviewTestFixtures.summary(
            base: dashboard.weeklyProgressSummary,
            verdict: .noisyButLikelyOkay,
            hasSuddenSpike: true
        )
        let state = UnifiedWeeklyReviewPresentationBuilder.build(
            UnifiedWeeklyReviewInput(summary: summary, weeklyHabit: dashboard.weeklyHabit)
        )

        try writeSnapshotIfEnabled(name: "weekly_progress_weight_spike", state: state, summary: summary)
    }

    func testSnapshotPoorLoggingConsistency() throws {
        let dashboard = JourneyPreviewData.sparseData
        try writeSnapshotIfEnabled(
            name: "weekly_progress_poor_consistency",
            dashboard: dashboard
        )
    }

    func testSnapshotPlanReviewRecommended() throws {
        let dashboard = JourneyPreviewData.strongMomentum
        let base = dashboard.weeklyProgressSummary
        let maintenance = MaintenanceEstimate(
            method: .learnedEnergyBalance,
            confidence: .medium,
            estimatedMaintenanceKcal: 2_500,
            staticTDEEKcal: 2_400,
            averageDailyCalories: 2_100,
            estimatedDailyEnergyBalanceKcal: -250,
            weightChangeKg: -0.8,
            weeklyWeightChangeKg: -1.0,
            trendDirection: .losingFasterThanExpected,
            sufficiency: base.maintenanceEstimate.sufficiency,
            shouldShowWaterWeightDisclaimer: false,
            explanation: base.maintenanceEstimate.explanation,
            caveats: []
        )
        let summary = UnifiedWeeklyReviewTestFixtures.summary(
            base: base,
            verdict: .likelyTooAggressive,
            confidence: .medium,
            maintenanceEstimate: maintenance
        )
        let state = UnifiedWeeklyReviewPresentationBuilder.build(
            UnifiedWeeklyReviewInput(
                summary: summary,
                weeklyHabit: dashboard.weeklyHabit,
                profile: PlanMissionControlFixtures.loseProfile,
                goalDirection: .lose
            )
        )
        XCTAssertNotNil(state.planRecommendationBlock)
        try writeSnapshotIfEnabled(name: "weekly_progress_plan_review", state: state, summary: summary)
    }

    // MARK: - Snapshot helpers

    @MainActor
    private func writeSnapshotIfEnabled(
        name: String,
        dashboard: JourneyDashboardState
    ) throws {
        let state = UnifiedWeeklyReviewPresentationBuilder.build(dashboard: dashboard)
        try writeSnapshotIfEnabled(
            name: name,
            state: state,
            summary: dashboard.weeklyProgressSummary
        )
    }

    @MainActor
    private func writeSnapshotIfEnabled(
        name: String,
        state: UnifiedWeeklyReviewState,
        summary: WeeklyProgressSummary
    ) throws {
        guard writesSnapshots else {
            throw XCTSkip("Set WEEKLY_PROGRESS_SNAPSHOTS=1 to write PNG snapshots.")
        }

        let view = WeeklyProgressHeroSection(
            state: state,
            summary: summary,
            foodLoggedDays: summary.foodLoggedDays,
            totalDays: summary.totalDays
        )
        .padding()
        .frame(width: 375)
        .background(FormaTokens.Color.canvas)
        .formaThemePreview(appearance: .light)

        let renderer = ImageRenderer(content: view)
        renderer.scale = 2
        guard let image = renderer.uiImage else {
            XCTFail("Failed to render weekly progress snapshot")
            return
        }

        let directory = URL(fileURLWithPath: FileManager.default.currentDirectoryPath)
            .appendingPathComponent("screenshots/weekly-progress", isDirectory: true)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        let url = directory.appendingPathComponent("\(name).png")
        guard let data = image.pngData() else {
            XCTFail("Failed to encode PNG")
            return
        }
        try data.write(to: url)
    }
}
