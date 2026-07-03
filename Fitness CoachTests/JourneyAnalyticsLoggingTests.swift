//
//  JourneyAnalyticsLoggingTests.swift
//  Fitness CoachTests
//
//  Forma — Journey analytics wiring and privacy guardrails.
//

import XCTest
@testable import Fitness_Coach

final class JourneyAnalyticsContextBuilderTests: XCTestCase {

    func testSnapshotUsesBucketsNotRawProgress() {
        let state = JourneyPreviewData.state

        let snapshot = JourneyAnalyticsContextBuilder.snapshot(
            from: state,
            healthConnected: true
        )

        XCTAssertTrue(snapshot.hasProfile)
        XCTAssertFalse(snapshot.progressPercentBucket.contains("."))
        XCTAssertFalse(snapshot.currentStreakBucket.isEmpty)
        XCTAssertGreaterThan(snapshot.unlockedMilestoneCount, 0)
        XCTAssertEqual(snapshot.userStage, JourneyAnalyticsUserStage.consistent.rawValue)
        XCTAssertTrue(snapshot.hasProjection)
        XCTAssertNotNil(snapshot.milestoneType)
        XCTAssertNotNil(snapshot.chapter)
        XCTAssertGreaterThan(snapshot.insightCount, 0)
        XCTAssertNotEqual(
            snapshot.weeklyCompletionBucket,
            JourneyAnalyticsWeeklyCompletionBucket.none.rawValue
        )
    }

    func testBrandNewUserSnapshotUsesNewStage() {
        let snapshot = JourneyAnalyticsContextBuilder.snapshot(
            from: JourneyPreviewData.brandNewUser,
            healthConnected: false
        )

        XCTAssertEqual(snapshot.userStage, JourneyAnalyticsUserStage.new.rawValue)
        XCTAssertFalse(snapshot.hasProjection)
        XCTAssertEqual(snapshot.insightCount, 0)
        XCTAssertEqual(snapshot.milestoneType, "first-meal")
    }

    func testWeekOneUserSnapshotUsesActiveStage() {
        let snapshot = JourneyAnalyticsContextBuilder.snapshot(
            from: JourneyPreviewData.weekOne,
            healthConnected: true
        )

        XCTAssertEqual(snapshot.userStage, JourneyAnalyticsUserStage.active.rawValue)
    }

    func testSparseDataUserSnapshotUsesEarlyStage() {
        let snapshot = JourneyAnalyticsContextBuilder.snapshot(
            from: JourneyPreviewData.sparseData,
            healthConnected: false
        )

        XCTAssertEqual(snapshot.userStage, JourneyAnalyticsUserStage.early.rawValue)
    }

    func testProgressPercentBuckets() {
        XCTAssertEqual(
            JourneyAnalyticsContextBuilder.progressPercentBucket(nil),
            JourneyAnalyticsProgressPercentBucket.none.rawValue
        )
        XCTAssertEqual(
            JourneyAnalyticsContextBuilder.progressPercentBucket(5),
            JourneyAnalyticsProgressPercentBucket.low.rawValue
        )
        XCTAssertEqual(
            JourneyAnalyticsContextBuilder.progressPercentBucket(40),
            JourneyAnalyticsProgressPercentBucket.mid.rawValue
        )
        XCTAssertEqual(
            JourneyAnalyticsContextBuilder.progressPercentBucket(100),
            JourneyAnalyticsProgressPercentBucket.complete.rawValue
        )
    }

    func testWeeklyCompletionBuckets() {
        XCTAssertEqual(
            JourneyAnalyticsContextBuilder.weeklyCompletionBucket(foodLoggedDays: 0),
            JourneyAnalyticsWeeklyCompletionBucket.none.rawValue
        )
        XCTAssertEqual(
            JourneyAnalyticsContextBuilder.weeklyCompletionBucket(foodLoggedDays: 2),
            JourneyAnalyticsWeeklyCompletionBucket.low.rawValue
        )
        XCTAssertEqual(
            JourneyAnalyticsContextBuilder.weeklyCompletionBucket(foodLoggedDays: 4),
            JourneyAnalyticsWeeklyCompletionBucket.building.rawValue
        )
        XCTAssertEqual(
            JourneyAnalyticsContextBuilder.weeklyCompletionBucket(foodLoggedDays: 7),
            JourneyAnalyticsWeeklyCompletionBucket.full.rawValue
        )
    }

    func testInsightCountBucketCapsAtThree() {
        XCTAssertEqual(
            JourneyAnalyticsContextBuilder.insightCountBucket(0).rawValue,
            "0"
        )
        XCTAssertEqual(
            JourneyAnalyticsContextBuilder.insightCountBucket(3).rawValue,
            "3"
        )
        XCTAssertEqual(
            JourneyAnalyticsContextBuilder.insightCountBucket(9).rawValue,
            "3"
        )
    }

    func testPropertiesOmitsSensitiveFields() {
        let parameters = JourneyAnalyticsContextBuilder.properties(
            from: JourneyAnalyticsSnapshot(
                hasProfile: true,
                hasWeightLogs: true,
                usesSyntheticBaseline: false,
                progressPercentBucket: "26_50",
                currentStreakBucket: "4_7",
                unlockedMilestoneCount: 3,
                healthConnected: true,
                userStage: JourneyAnalyticsUserStage.active.rawValue,
                hasProjection: true,
                milestoneType: "first-week",
                chapter: 2,
                insightCount: 2,
                weeklyCompletionBucket: JourneyAnalyticsWeeklyCompletionBucket.strong.rawValue
            )
        ).asParameters()

        let allowedKeys: Set<String> = [
            "has_profile",
            "has_weight_logs",
            "uses_synthetic_baseline",
            "progress_percent_bucket",
            "current_streak_bucket",
            "unlocked_milestone_count",
            "health_connected",
            "user_stage",
            "has_projection",
            "milestone_type",
            "chapter",
            "insight_count",
            "weekly_completion_bucket",
            "cta_type",
        ]
        let bannedKeys: Set<String> = [
            "weight_kg",
            "current_weight",
            "goal_weight",
            "calories",
            "calorie_target",
            "protein_g",
            "body_fat",
            "raw_progress",
            "journey_level",
            "range_days",
            "expanded",
        ]
        for key in parameters.keys {
            XCTAssertTrue(
                allowedKeys.contains(key) || !bannedKeys.contains(key),
                "Unexpected sensitive key: \(key)"
            )
        }

        for value in parameters.values {
            XCTAssertFalse(value.contains("kg"))
            XCTAssertFalse(value.contains("kcal"))
        }

        XCTAssertEqual(parameters["user_stage"], "active")
        XCTAssertEqual(parameters["has_projection"], "true")
        XCTAssertEqual(parameters["milestone_type"], "first-week")
        XCTAssertEqual(parameters["chapter"], "2")
        XCTAssertEqual(parameters["insight_count"], "2")
        XCTAssertEqual(parameters["weekly_completion_bucket"], "5_6")
    }
}

final class NoOpJourneyAnalyticsLoggerTests: XCTestCase {

    func testNoOpLoggerDoesNotCrash() {
        let logger = NoOpJourneyAnalyticsLogger()
        logger.log(.viewed, properties: JourneyAnalyticsProperties(hasProfile: true))
        logger.log(.weightCTATapped, properties: JourneyAnalyticsProperties(ctaType: "log_weight"))
        logger.log(.goToTodayTapped, properties: JourneyAnalyticsProperties(userStage: "new"))
    }
}

@MainActor
final class JourneyAnalyticsCoordinatorTests: XCTestCase {

    private var analytics: CapturingJourneyAnalyticsLogger!
    private var coordinator: JourneyAnalyticsCoordinator!

    override func setUp() {
        super.setUp()
        analytics = CapturingJourneyAnalyticsLogger()
        coordinator = JourneyAnalyticsCoordinator(analyticsLogger: analytics)
    }

    func testViewedFiresOncePerSession() {
        coordinator.updateContext(from: JourneyPreviewData.state, healthConnected: false)
        coordinator.logViewed()
        coordinator.logViewed()

        XCTAssertEqual(analytics.events.filter { $0.event == .viewed }.count, 1)
        XCTAssertEqual(analytics.lastEvent, .viewed)
        XCTAssertEqual(analytics.lastProperties?["has_profile"], "true")
        XCTAssertEqual(analytics.lastProperties?["user_stage"], "consistent")
    }

    func testHeroViewedFiresOnceUntilContextReset() {
        coordinator.updateContext(from: JourneyPreviewData.state, healthConnected: true)
        coordinator.logHeroViewed()
        coordinator.logHeroViewed()

        XCTAssertEqual(analytics.events.filter { $0.event == .heroViewed }.count, 1)

        coordinator.updateContext(from: JourneyPreviewData.state, healthConnected: true)
        coordinator.logHeroViewed()

        XCTAssertEqual(analytics.events.filter { $0.event == .heroViewed }.count, 2)
    }

    func testRevampSectionEventsUseCanonicalNames() {
        coordinator.updateContext(from: JourneyPreviewData.strongMomentum, healthConnected: true)

        coordinator.logHeroViewed()
        coordinator.logProjectionViewed()
        coordinator.logMilestoneViewed()
        coordinator.logWeeklyConsistencyViewed()
        coordinator.logStoryViewed()
        coordinator.logInsightsViewed()
        coordinator.logMonthlyRecapViewed()
        coordinator.logChapterViewed()

        let eventNames = Set(analytics.events.map(\.event.rawValue))
        XCTAssertTrue(eventNames.contains("journey_hero_viewed"))
        XCTAssertTrue(eventNames.contains("journey_projection_viewed"))
        XCTAssertTrue(eventNames.contains("journey_milestone_viewed"))
        XCTAssertTrue(eventNames.contains("journey_weekly_consistency_viewed"))
        XCTAssertTrue(eventNames.contains("journey_story_viewed"))
        XCTAssertTrue(eventNames.contains("journey_insights_viewed"))
        XCTAssertTrue(eventNames.contains("journey_monthly_recap_viewed"))
        XCTAssertTrue(eventNames.contains("journey_chapter_viewed"))
        XCTAssertFalse(eventNames.contains("journey_transformation_viewed"))
        XCTAssertFalse(eventNames.contains("journey_milestone_rail_viewed"))
    }

    func testGoToTodayTappedFiresEveryTime() {
        coordinator.updateContext(from: JourneyPreviewData.brandNewUser, healthConnected: false)
        coordinator.logGoToTodayTapped()
        coordinator.logGoToTodayTapped()

        XCTAssertEqual(analytics.events.filter { $0.event == .goToTodayTapped }.count, 2)
        XCTAssertEqual(analytics.lastProperties?["user_stage"], "new")
    }

    func testDeprecatedStartingEmptyStateViewedDoesNotEmit() {
        coordinator.updateContext(from: JourneyPreviewData.brandNewUser, healthConnected: false)
        coordinator.logStartingEmptyStateViewed()

        XCTAssertTrue(analytics.events.isEmpty)
    }

    func testWeightCTATappedEvent() {
        coordinator.updateContext(from: JourneyPreviewData.state, healthConnected: false)
        coordinator.logCTATapped(.logWeight)

        XCTAssertEqual(analytics.lastEvent, .milestoneCTATapped)
        XCTAssertTrue(analytics.events.contains { $0.event == .weightCTATapped })
        XCTAssertEqual(analytics.lastProperties?["cta_type"], "log_weight")
    }

    func testCoachCTATappedEvent() {
        coordinator.updateContext(from: JourneyPreviewData.state, healthConnected: false)
        coordinator.logCTATapped(.logFood)

        XCTAssertEqual(analytics.lastEvent, .milestoneCTATapped)
        XCTAssertTrue(analytics.events.contains { $0.event == .coachCTATapped })
        XCTAssertEqual(analytics.lastProperties?["cta_type"], "log_food")
    }

    func testMilestoneCTATappedOnlyForLoggingCTAs() {
        coordinator.updateContext(from: JourneyPreviewData.state, healthConnected: false)
        coordinator.logCTATapped(.connectAppleHealth)

        XCTAssertTrue(analytics.events.isEmpty)
    }

    func testPlanCTAsDoNotEmitCoachOrWeightEvents() {
        coordinator.updateContext(from: JourneyPreviewData.state, healthConnected: false)
        coordinator.logCTATapped(.connectAppleHealth)
        coordinator.logCTATapped(.updateGoal)

        XCTAssertTrue(analytics.events.isEmpty)
    }

    func testLoggedPropertiesNeverIncludeRawWeightOrCalories() {
        coordinator.updateContext(from: JourneyPreviewData.state, healthConnected: true)
        coordinator.logViewed()
        coordinator.logCTATapped(.logWeight)

        for entry in analytics.events {
            let parameters = entry.properties.asParameters()
            XCTAssertNotNil(parameters["progress_percent_bucket"])
            XCTAssertNotNil(parameters["weekly_completion_bucket"])
            XCTAssertNil(parameters["weight_kg"])
            XCTAssertNil(parameters["calories"])
            for value in parameters.values {
                XCTAssertFalse(value.localizedCaseInsensitiveContains("kg"))
                XCTAssertFalse(value.localizedCaseInsensitiveContains("kcal"))
            }
        }
    }
}
