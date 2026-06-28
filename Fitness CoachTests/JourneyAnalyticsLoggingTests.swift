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
        let state = ProgressPreviewData.state

        let snapshot = JourneyAnalyticsContextBuilder.snapshot(
            from: state,
            healthConnected: true
        )

        XCTAssertTrue(snapshot.hasProfile)
        XCTAssertFalse(snapshot.progressPercentBucket.contains("."))
        XCTAssertFalse(snapshot.currentStreakBucket.isEmpty)
        XCTAssertGreaterThan(snapshot.journeyLevel, 0)
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
                journeyLevel: 7
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
            "journey_level",
            "range_days",
            "cta_type",
            "expanded",
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
    }
}

final class NoOpJourneyAnalyticsLoggerTests: XCTestCase {

    func testNoOpLoggerDoesNotCrash() {
        let logger = NoOpJourneyAnalyticsLogger()
        logger.log(.screenViewed, properties: JourneyAnalyticsProperties(hasProfile: true))
        logger.log(.weightCTATapped, properties: JourneyAnalyticsProperties(ctaType: "log_weight"))
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

    func testScreenViewedFiresOncePerSession() {
        coordinator.updateContext(from: ProgressPreviewData.state, healthConnected: false)
        coordinator.logScreenViewed()
        coordinator.logScreenViewed()

        XCTAssertEqual(analytics.events.filter { $0.event == .screenViewed }.count, 1)
        XCTAssertEqual(analytics.lastEvent, .screenViewed)
        XCTAssertEqual(analytics.lastProperties?["has_profile"], "true")
    }

    func testSectionViewedFiresOnceUntilContextReset() {
        coordinator.updateContext(from: ProgressPreviewData.state, healthConnected: true)
        coordinator.logTransformationViewed()
        coordinator.logTransformationViewed()

        XCTAssertEqual(analytics.events.filter { $0.event == .transformationViewed }.count, 1)

        coordinator.updateContext(from: ProgressPreviewData.state, healthConnected: true)
        coordinator.logTransformationViewed()

        XCTAssertEqual(analytics.events.filter { $0.event == .transformationViewed }.count, 2)
    }

    func testWeightCTATappedEvent() {
        coordinator.updateContext(from: ProgressPreviewData.state, healthConnected: false)
        coordinator.logCTATapped(.logWeight)

        XCTAssertEqual(analytics.lastEvent, .weightCTATapped)
        XCTAssertEqual(analytics.lastProperties?["cta_type"], "log_weight")
    }

    func testCoachCTATappedEvent() {
        coordinator.updateContext(from: ProgressPreviewData.state, healthConnected: false)
        coordinator.logCTATapped(.logFood)

        XCTAssertEqual(analytics.lastEvent, .coachCTATapped)
        XCTAssertEqual(analytics.lastProperties?["cta_type"], "log_food")
    }

    func testPlanCTAsDoNotEmitCoachOrWeightEvents() {
        coordinator.updateContext(from: ProgressPreviewData.state, healthConnected: false)
        coordinator.logCTATapped(.connectAppleHealth)
        coordinator.logCTATapped(.updateGoal)

        XCTAssertTrue(analytics.events.isEmpty)
    }

    func testRangeChangedIncludesRangeDays() {
        coordinator.updateContext(from: ProgressPreviewData.state, healthConnected: false)
        coordinator.logRangeChanged(days: 14)

        XCTAssertEqual(analytics.lastEvent, .rangeChanged)
        XCTAssertEqual(analytics.lastProperties?["range_days"], "14")
    }

    func testAnalyticsExpandedEvent() {
        coordinator.updateContext(from: ProgressPreviewData.state, healthConnected: false)
        coordinator.logAnalyticsExpanded()

        XCTAssertEqual(analytics.lastEvent, .analyticsExpanded)
        XCTAssertEqual(analytics.lastProperties?["expanded"], "true")
    }

    func testLoggedPropertiesNeverIncludeRawWeightOrCalories() {
        coordinator.updateContext(from: ProgressPreviewData.state, healthConnected: true)
        coordinator.logScreenViewed()
        coordinator.logCTATapped(.logWeight)
        coordinator.logRangeChanged(days: 28)

        for entry in analytics.events {
            let parameters = entry.properties.asParameters()
            XCTAssertNotNil(parameters["progress_percent_bucket"])
            XCTAssertNil(parameters["weight_kg"])
            XCTAssertNil(parameters["calories"])
            for value in parameters.values {
                XCTAssertFalse(value.localizedCaseInsensitiveContains("kg"))
                XCTAssertFalse(value.localizedCaseInsensitiveContains("kcal"))
            }
        }
    }
}
