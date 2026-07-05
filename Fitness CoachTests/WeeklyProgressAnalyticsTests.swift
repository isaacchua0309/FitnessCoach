//
//  WeeklyProgressAnalyticsTests.swift
//  Fitness CoachTests
//
//  Forma — Weekly Progress Loop v1 analytics event contracts and privacy.
//

import XCTest
@testable import Fitness_Coach

@MainActor
final class WeeklyProgressAnalyticsTests: XCTestCase {

    private var logger: CapturingWeeklyProgressAnalyticsLogger!
    private var coordinator: WeeklyProgressAnalyticsCoordinator!

    private let strongSummary = JourneyPreviewData.strongMomentum.weeklyProgressSummary
    private let sparseSummary = JourneyPreviewData.brandNewUser.weeklyProgressSummary

    override func setUp() {
        super.setUp()
        logger = CapturingWeeklyProgressAnalyticsLogger()
        coordinator = WeeklyProgressAnalyticsCoordinator(analyticsLogger: logger)
    }

    override func tearDown() {
        coordinator = nil
        logger = nil
        super.tearDown()
    }

    func testWeeklyProgressCardViewedLogged() {
        coordinator.logCardViewed(summary: strongSummary)

        XCTAssertEqual(logger.eventCount(for: .cardViewed), 1)
        XCTAssertEqual(logger.lastEvent, .cardViewed)
        XCTAssertEqual(
            logger.lastProperties(for: .cardViewed)?["surface"],
            WeeklyProgressAnalyticsSurface.journeyCard.rawValue
        )
    }

    func testWeeklyReviewOpenedLogged() {
        coordinator.logReviewOpened(summary: strongSummary)

        XCTAssertTrue(logger.contains(.reviewOpened))
        XCTAssertEqual(
            logger.lastProperties(for: .reviewOpened)?["surface"],
            WeeklyProgressAnalyticsSurface.journeyDetail.rawValue
        )
        XCTAssertEqual(
            logger.lastProperties(for: .reviewOpened)?["entry_point"],
            WeeklyProgressAnalyticsEntryPoint.journeyCard.rawValue
        )
    }

    func testMaintenanceEstimateShownLogged() {
        coordinator.logMaintenanceBlockViewed(
            summary: strongSummary,
            showsLearnedEstimate: true,
            surface: .journeyCard
        )

        XCTAssertTrue(logger.contains(.maintenanceEstimateShown))
        XCTAssertEqual(
            logger.lastProperties(for: .maintenanceEstimateShown)?["has_maintenance_estimate"],
            "true"
        )
    }

    func testMaintenanceEstimateInsufficientDataLogged() {
        coordinator.logMaintenanceBlockViewed(
            summary: sparseSummary,
            showsLearnedEstimate: false,
            surface: .journeyCard
        )

        XCTAssertTrue(logger.contains(.maintenanceEstimateInsufficientData))
        XCTAssertFalse(logger.contains(.maintenanceEstimateShown))
    }

    func testLowConfidenceLoggedWithoutRawValues() {
        let lowConfidenceSummary = UnifiedWeeklyReviewTestFixtures.summary(
            base: strongSummary,
            confidence: .low,
            maintenanceEstimate: UnifiedWeeklyReviewTestFixtures.lowConfidenceMaintenanceEstimate(
                from: strongSummary.maintenanceEstimate
            )
        )

        coordinator.logMaintenanceBlockViewed(
            summary: lowConfidenceSummary,
            showsLearnedEstimate: true,
            surface: .journeyCard
        )

        XCTAssertTrue(logger.contains(.maintenanceConfidenceLow))
        XCTAssertEqual(
            logger.lastProperties(for: .maintenanceConfidenceLow)?["confidence_level"],
            WeeklyProgressConfidenceLevel.low.rawValue
        )

        guard let properties = logger.lastProperties(for: .maintenanceConfidenceLow) else {
            return XCTFail("Expected maintenance_confidence_low properties")
        }
        assertNoRawCaloriesOrWeight(in: properties, summary: lowConfidenceSummary)
    }

    func testPlanRecommendationShownLogged() {
        coordinator.logPlanRecommendationShown(
            summary: strongSummary,
            recommendationKind: .considerSmallIncrease,
            surface: .planDashboard
        )

        XCTAssertTrue(logger.contains(.planRecommendationShown))
        XCTAssertEqual(
            logger.lastProperties(for: .planRecommendationShown)?["recommendation_kind"],
            WeeklyPlanRecommendationKind.considerSmallIncrease.rawValue
        )
        XCTAssertEqual(
            logger.lastProperties(for: .planRecommendationShown)?["surface"],
            WeeklyProgressAnalyticsSurface.planDashboard.rawValue
        )
    }

    func testPlanRecommendationTappedLogged() {
        coordinator.logPlanRecommendationTapped(
            summary: strongSummary,
            recommendationKind: .considerSmallIncrease,
            surface: .journeyDetail,
            entryPoint: .weeklyReview
        )

        XCTAssertTrue(logger.contains(.planRecommendationTapped))
        XCTAssertEqual(
            logger.lastProperties(for: .planRecommendationTapped)?["entry_point"],
            WeeklyProgressAnalyticsEntryPoint.weeklyReview.rawValue
        )
    }

    func testPlanEditStartedFromWeeklyReviewLogged() {
        coordinator.logPlanEditStartedFromWeeklyReview(
            summary: strongSummary,
            entryPoint: .weeklyReview,
            recommendationKind: .reviewPlanManually
        )

        XCTAssertTrue(logger.contains(.planEditStartedFromWeeklyReview))
        XCTAssertEqual(
            logger.lastProperties(for: .planEditStartedFromWeeklyReview)?["entry_point"],
            WeeklyProgressAnalyticsEntryPoint.weeklyReview.rawValue
        )
        XCTAssertEqual(
            logger.lastProperties(for: .planEditStartedFromWeeklyReview)?["recommendation_kind"],
            WeeklyPlanRecommendationKind.reviewPlanManually.rawValue
        )
    }

    func testWeightSpikeExplanationShownLogged() {
        let spikeSummary = UnifiedWeeklyReviewTestFixtures.summary(
            base: strongSummary,
            verdict: .noisyButLikelyOkay,
            hasSuddenSpike: true
        )

        coordinator.logWeightSpikeExplanationShown(
            summary: spikeSummary,
            surface: .journeyDetail
        )

        XCTAssertTrue(logger.contains(.weightSpikeExplanationShown))
        XCTAssertEqual(
            logger.lastProperties(for: .weightSpikeExplanationShown)?["has_weight_spike"],
            "true"
        )
    }

    func testDailyReviewTeaserViewedLogged() {
        coordinator.logDailyReviewTeaserViewed(foodLoggedDays: 4)

        XCTAssertTrue(logger.contains(.dailyReviewTeaserViewed))
        XCTAssertEqual(
            logger.lastProperties(for: .dailyReviewTeaserViewed)?["food_logged_days_bucket"],
            WeeklyProgressAnalyticsFoodLoggedDaysBucket.building.rawValue
        )
        XCTAssertEqual(
            logger.lastProperties(for: .dailyReviewTeaserViewed)?["surface"],
            WeeklyProgressAnalyticsSurface.todayTeaser.rawValue
        )
    }

    func testAnalyticsPropertiesArePrivacySafe() {
        let spikeSummary = UnifiedWeeklyReviewTestFixtures.summary(
            base: strongSummary,
            hasSuddenSpike: true
        )

        coordinator.logCardViewed(summary: strongSummary)
        coordinator.logReviewOpened(summary: strongSummary)
        coordinator.logMaintenanceBlockViewed(
            summary: strongSummary,
            showsLearnedEstimate: true,
            surface: .journeyCard
        )
        coordinator.logPlanRecommendationShown(
            summary: strongSummary,
            recommendationKind: .holdSteady,
            surface: .planDashboard
        )
        coordinator.logPlanRecommendationTapped(
            summary: strongSummary,
            recommendationKind: .holdSteady,
            surface: .journeyDetail,
            entryPoint: .journeyCard
        )
        coordinator.logPlanEditStartedFromWeeklyReview(
            summary: strongSummary,
            entryPoint: .weeklyReview,
            recommendationKind: .holdSteady
        )
        coordinator.logWeightSpikeExplanationShown(
            summary: spikeSummary,
            surface: .journeyDetail
        )
        coordinator.logDailyReviewTeaserViewed(foodLoggedDays: 5)

        for entry in logger.events {
            assertPrivacySafeProperties(entry.properties.asParameters())
        }
    }

    func testNoRawCaloriesOrRawWeightLogged() {
        coordinator.logCardViewed(summary: strongSummary)
        coordinator.logReviewOpened(summary: strongSummary)
        coordinator.logMaintenanceBlockViewed(
            summary: strongSummary,
            showsLearnedEstimate: true,
            surface: .journeyCard
        )
        coordinator.logPlanRecommendationShown(
            summary: strongSummary,
            recommendationKind: .holdSteady,
            surface: .planDashboard
        )
        coordinator.logPlanRecommendationTapped(
            summary: strongSummary,
            recommendationKind: .holdSteady,
            surface: .planDashboard,
            entryPoint: .planDashboard
        )
        coordinator.logPlanEditStartedFromWeeklyReview(
            summary: strongSummary,
            entryPoint: .weeklyReview,
            recommendationKind: .holdSteady
        )

        for entry in logger.events {
            assertNoRawCaloriesOrWeight(
                in: entry.properties.asParameters(),
                summary: strongSummary
            )
        }
    }

    func testReleaseNoOpLoggerDoesNotCrash() {
        let releaseCoordinator = WeeklyProgressAnalyticsCoordinator(
            analyticsLogger: NoOpWeeklyProgressAnalyticsLogger()
        )
        let spikeSummary = UnifiedWeeklyReviewTestFixtures.summary(
            base: strongSummary,
            hasSuddenSpike: true
        )

        releaseCoordinator.updateContext(from: strongSummary)
        releaseCoordinator.logCardViewed(summary: strongSummary)
        releaseCoordinator.logReviewOpened(summary: strongSummary)
        releaseCoordinator.logReviewCompleted(summary: strongSummary)
        releaseCoordinator.logRestorePending()
        releaseCoordinator.logMaintenanceBlockViewed(
            summary: strongSummary,
            showsLearnedEstimate: true,
            surface: .journeyCard
        )
        releaseCoordinator.logPlanRecommendationShown(
            summary: strongSummary,
            recommendationKind: .holdSteady,
            surface: .planDashboard
        )
        releaseCoordinator.logPlanRecommendationTapped(
            summary: strongSummary,
            recommendationKind: .holdSteady,
            surface: .planDashboard,
            entryPoint: .weeklyReview
        )
        releaseCoordinator.logPlanEditStartedFromWeeklyReview(
            summary: strongSummary,
            entryPoint: .weeklyReview,
            recommendationKind: .holdSteady
        )
        releaseCoordinator.logPlanEditStartedFromWeeklyReview(
            recommendationKind: .holdSteady,
            entryPoint: .weeklyReview,
            foodLoggedDays: 5,
            weightEntryCount: 3,
            calendarSpanDays: 14,
            confidence: .medium
        )
        releaseCoordinator.logWeightSpikeExplanationShown(
            summary: spikeSummary,
            surface: .journeyDetail
        )
        releaseCoordinator.logDailyReviewTeaserViewed(foodLoggedDays: 2)
        releaseCoordinator.logDailyReviewOpenedFromToday(foodLoggedDays: 2)
        releaseCoordinator.logStaleOrSyncing(
            summary: strongSummary,
            surface: .journeyCard,
            freshnessInput: WeeklyProgressFreshnessInput(
                isRestoringAccount: true,
                isCrossDeviceRefreshing: false,
                pendingUploadCount: nil,
                lastRefreshAt: nil,
                recentlyRestoredAt: nil,
                now: Date()
            )
        )
    }

    // MARK: - Privacy helpers

    private let allowedPropertyKeys: Set<String> = [
        "confidence_level",
        "data_window_days",
        "food_logged_days_bucket",
        "weight_entry_count_bucket",
        "recommendation_kind",
        "has_maintenance_estimate",
        "has_weight_spike",
        "entry_point",
        "surface"
    ]

    private let forbiddenPropertyKeys: Set<String> = [
        "weight_kg",
        "calories",
        "calorie_target",
        "maintenance_kcal",
        "estimated_maintenance_kcal",
        "uid",
        "user_id",
        "email",
        "review_text",
        "summary_text",
        "food_name",
        "protein_grams",
        "water_ml"
    ]

    private func assertPrivacySafeProperties(_ properties: [String: String]) {
        for key in properties.keys {
            XCTAssertTrue(
                allowedPropertyKeys.contains(key),
                "Unexpected analytics property key: \(key)"
            )
            XCTAssertFalse(
                forbiddenPropertyKeys.contains(key),
                "Forbidden analytics property key: \(key)"
            )
        }

        for (key, value) in properties {
            XCTAssertFalse(value.isEmpty, "Empty analytics value for \(key)")
            XCTAssertNil(
                PlanCopySafetyPolicy.forbiddenViolation(in: value),
                "Forbidden copy in analytics value for \(key): \(value)"
            )
            let lowered = value.lowercased()
            XCTAssertFalse(lowered.contains("@"), "PII-like value for \(key): \(value)")
        }
    }

    private func assertNoRawCaloriesOrWeight(
        in properties: [String: String],
        summary: WeeklyProgressSummary
    ) {
        for key in forbiddenPropertyKeys {
            XCTAssertFalse(properties.keys.contains(key), "Forbidden key logged: \(key)")
        }

        let serialized = properties.values.joined(separator: " ")
        for raw in rawCalorieAndWeightValues(from: summary) {
            XCTAssertFalse(
                serialized.contains(raw),
                "Raw calorie/weight value \"\(raw)\" leaked into analytics properties"
            )
        }
    }

    private func rawCalorieAndWeightValues(from summary: WeeklyProgressSummary) -> [String] {
        var values: [String] = []

        if let averageDailyCalories = summary.averageDailyCalories, averageDailyCalories > 0 {
            values.append(String(averageDailyCalories))
        }
        if let maintenanceKcal = summary.maintenanceEstimate.estimatedMaintenanceKcal {
            values.append(String(maintenanceKcal))
        }
        if let staticTDEE = summary.maintenanceEstimate.staticTDEEKcal {
            values.append(String(staticTDEE))
        }

        for weight in [
            summary.startingWeightKg,
            summary.endingWeightKg,
            summary.weightChangeKg,
            summary.weeklyWeightChangeKg
        ].compactMap({ $0 }) {
            values.append(String(weight))
            values.append(String(format: "%.1f", weight))
        }

        return Array(Set(values)).filter { !$0.isEmpty }
    }
}
