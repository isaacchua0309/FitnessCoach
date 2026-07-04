//
//  WeeklyProgressAnalyticsLoggingTests.swift
//  Fitness CoachTests
//
//  Forma — Weekly Progress Loop v1 analytics wiring and privacy guardrails.
//

import XCTest
@testable import Fitness_Coach

final class WeeklyProgressAnalyticsContextBuilderTests: XCTestCase {

    func testPropertiesUseBucketsNotRawValues() {
        let summary = JourneyPreviewData.strongMomentum.weeklyProgressSummary

        let properties = WeeklyProgressAnalyticsContextBuilder.properties(
            from: summary,
            recommendationKind: .holdSteady,
            surface: .journeyCard
        ).asParameters()

        XCTAssertEqual(properties["confidence_level"], summary.confidence.rawValue)
        XCTAssertEqual(properties["surface"], WeeklyProgressAnalyticsSurface.journeyCard.rawValue)
        XCTAssertEqual(properties["recommendation_kind"], WeeklyPlanRecommendationKind.holdSteady.rawValue)
        XCTAssertNotNil(properties["food_logged_days_bucket"])
        XCTAssertNotNil(properties["weight_entry_count_bucket"])
        XCTAssertNotNil(properties["data_window_days"])
        XCTAssertFalse(properties.keys.contains("weight_kg"))
        XCTAssertFalse(properties.keys.contains("calories"))
        XCTAssertFalse(properties.keys.contains("uid"))
    }

    func testFoodLoggedDaysBuckets() {
        XCTAssertEqual(
            WeeklyProgressAnalyticsContextBuilder.foodLoggedDaysBucket(foodLoggedDays: 0).rawValue,
            WeeklyProgressAnalyticsFoodLoggedDaysBucket.none.rawValue
        )
        XCTAssertEqual(
            WeeklyProgressAnalyticsContextBuilder.foodLoggedDaysBucket(foodLoggedDays: 7).rawValue,
            WeeklyProgressAnalyticsFoodLoggedDaysBucket.full.rawValue
        )
    }

    func testWeightEntryCountBuckets() {
        XCTAssertEqual(
            WeeklyProgressAnalyticsContextBuilder.weightEntryCountBucket(weightEntryCount: 0).rawValue,
            WeeklyProgressAnalyticsWeightEntryCountBucket.zero.rawValue
        )
        XCTAssertEqual(
            WeeklyProgressAnalyticsContextBuilder.weightEntryCountBucket(weightEntryCount: 5).rawValue,
            WeeklyProgressAnalyticsWeightEntryCountBucket.high.rawValue
        )
    }

    func testStaleOrSyncingInput() {
        let syncing = WeeklyProgressFreshnessInput(
            isRestoringAccount: false,
            isCrossDeviceRefreshing: true,
            pendingUploadCount: nil,
            lastRefreshAt: nil,
            recentlyRestoredAt: nil,
            now: Date()
        )
        XCTAssertTrue(WeeklyProgressAnalyticsContextBuilder.isStaleOrSyncing(syncing))

        let fresh = WeeklyProgressFreshnessInput(
            isRestoringAccount: false,
            isCrossDeviceRefreshing: false,
            pendingUploadCount: 0,
            lastRefreshAt: Date(),
            recentlyRestoredAt: nil,
            now: Date()
        )
        XCTAssertFalse(WeeklyProgressAnalyticsContextBuilder.isStaleOrSyncing(fresh))
    }
}

@MainActor
final class WeeklyProgressAnalyticsCoordinatorTests: XCTestCase {

    func testCardViewedLogsOncePerSession() {
        let logger = CapturingWeeklyProgressAnalyticsLogger()
        let coordinator = WeeklyProgressAnalyticsCoordinator(analyticsLogger: logger)
        let summary = JourneyPreviewData.strongMomentum.weeklyProgressSummary

        coordinator.logCardViewed(summary: summary)
        coordinator.logCardViewed(summary: summary)

        XCTAssertEqual(logger.eventCount(for: .cardViewed), 1)
        XCTAssertEqual(logger.lastEvent, .cardViewed)
    }

    func testMaintenanceEstimateShownForLearnedEstimate() {
        let logger = CapturingWeeklyProgressAnalyticsLogger()
        let coordinator = WeeklyProgressAnalyticsCoordinator(analyticsLogger: logger)
        let summary = JourneyPreviewData.strongMomentum.weeklyProgressSummary

        coordinator.logMaintenanceBlockViewed(
            summary: summary,
            showsLearnedEstimate: true,
            surface: .journeyCard
        )

        XCTAssertTrue(logger.contains(.maintenanceEstimateShown))
    }

    func testMaintenanceInsufficientDataWhenNotLearned() {
        let logger = CapturingWeeklyProgressAnalyticsLogger()
        let coordinator = WeeklyProgressAnalyticsCoordinator(analyticsLogger: logger)
        let summary = JourneyPreviewData.brandNewUser.weeklyProgressSummary

        coordinator.logMaintenanceBlockViewed(
            summary: summary,
            showsLearnedEstimate: false,
            surface: .journeyCard
        )

        XCTAssertTrue(logger.contains(.maintenanceEstimateInsufficientData))
    }

    func testPlanRecommendationShownRequiresKind() {
        let logger = CapturingWeeklyProgressAnalyticsLogger()
        let coordinator = WeeklyProgressAnalyticsCoordinator(analyticsLogger: logger)
        let summary = JourneyPreviewData.strongMomentum.weeklyProgressSummary

        coordinator.logPlanRecommendationShown(
            summary: summary,
            recommendationKind: nil,
            surface: .planDashboard
        )
        XCTAssertFalse(logger.contains(.planRecommendationShown))

        coordinator.logPlanRecommendationShown(
            summary: summary,
            recommendationKind: .holdSteady,
            surface: .planDashboard
        )
        XCTAssertTrue(logger.contains(.planRecommendationShown))
    }

    func testDailyReviewTeaserViewedUsesBucketedFoodDays() {
        let logger = CapturingWeeklyProgressAnalyticsLogger()
        let coordinator = WeeklyProgressAnalyticsCoordinator(analyticsLogger: logger)

        coordinator.logDailyReviewTeaserViewed(foodLoggedDays: 4)

        let properties = logger.lastProperties(for: .dailyReviewTeaserViewed)
        XCTAssertEqual(properties?["food_logged_days_bucket"], "3_4")
        XCTAssertEqual(properties?["surface"], WeeklyProgressAnalyticsSurface.todayTeaser.rawValue)
    }
}
