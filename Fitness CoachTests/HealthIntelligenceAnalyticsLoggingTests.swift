//
//  HealthIntelligenceAnalyticsLoggingTests.swift
//  Fitness CoachTests
//
//  Forma — Health Intelligence analytics wiring and privacy guardrails.
//

import XCTest
@testable import Fitness_Coach

final class HealthIntelligenceAnalyticsContextBuilderTests: XCTestCase {

    func testHealthDataStateMapping() {
        XCTAssertEqual(
            HealthIntelligenceAnalyticsContextBuilder.healthDataState(from: .ready).rawValue,
            "full"
        )
        XCTAssertEqual(
            HealthIntelligenceAnalyticsContextBuilder.healthDataState(from: .partialHealthPermission).rawValue,
            "partial"
        )
        XCTAssertEqual(
            HealthIntelligenceAnalyticsContextBuilder.healthDataState(from: .limitedEstimate).rawValue,
            "partial"
        )
        XCTAssertEqual(
            HealthIntelligenceAnalyticsContextBuilder.healthDataState(from: .noHealthPermission).rawValue,
            "none"
        )
        XCTAssertEqual(
            HealthIntelligenceAnalyticsContextBuilder.healthDataState(from: .noHealthDataYet).rawValue,
            "none"
        )
        XCTAssertEqual(
            HealthIntelligenceAnalyticsContextBuilder.healthDataState(from: .unavailableOnDevice).rawValue,
            "unavailable"
        )
    }

    func testPropertiesUseBucketsNotRawValues() {
        let snapshot = HealthIntelligenceSnapshot.previewConnected()
        let properties = HealthIntelligenceAnalyticsContextBuilder.properties(
            from: snapshot,
            surface: .today
        ).asParameters()

        XCTAssertNotNil(properties["health_data_state"])
        XCTAssertNotNil(properties["recovery_status"])
        XCTAssertNotNil(properties["confidence_bucket"])
        XCTAssertNotNil(properties["has_workout_today"])
        XCTAssertNotNil(properties["missing_signal_count"])
        XCTAssertNotNil(properties["feature_flag_state"])

        let bannedKeys: Set<String> = [
            "hrv",
            "resting_heart_rate",
            "heart_rate",
            "workout_title",
            "food_text",
            "raw_snapshot",
        ]
        for key in properties.keys {
            XCTAssertFalse(bannedKeys.contains(key), "Unexpected sensitive key: \(key)")
        }

        for value in properties.values {
            XCTAssertFalse(value.localizedCaseInsensitiveContains("bpm"))
            XCTAssertFalse(value.localizedCaseInsensitiveContains("ms"))
        }
    }

    func testConfidenceBucketNormalization() {
        XCTAssertEqual(
            HealthIntelligenceAnalyticsContextBuilder.confidenceBucket(from: "Strong fit"),
            "high"
        )
        XCTAssertEqual(
            HealthIntelligenceAnalyticsContextBuilder.confidenceBucket(from: "Reasonable fit"),
            "moderate"
        )
        XCTAssertEqual(
            HealthIntelligenceAnalyticsContextBuilder.confidenceBucket(from: "Limited fit"),
            "low"
        )
    }

    func testFeatureFlagStateIsCompact() {
        let state = HealthIntelligenceAnalyticsContextBuilder.featureFlagState(
            from: HealthIntelligenceFeatureFlags.Snapshot(
                healthIntelligenceEnabled: true,
                healthIntelligenceEnginesEnabled: true,
                healthIntelligenceUIEnabled: false,
                healthIntelligenceCoachContextEnabled: false,
                healthIntelligenceWeeklyReviewEnabled: false,
                isSyncEnabled: true,
                isRepositoryReadRoutingEnabled: true,
                shouldTodayModelLoadHealthIntelligence: false,
                shouldJourneyModelLoadHealthIntelligence: false,
                shouldPlanModelLoadHealthIntelligence: false,
                shouldCoachLoadHealthIntelligence: false
            )
        )

        XCTAssertTrue(state.contains("ui:0"))
        XCTAssertTrue(state.contains("coach:0"))
        XCTAssertFalse(state.contains("true"))
    }
}

final class NoOpHealthIntelligenceAnalyticsLoggerTests: XCTestCase {

    func testNoOpLoggerDoesNotCrash() {
        let logger = NoOpHealthIntelligenceAnalyticsLogger()
        logger.log(
            .snapshotLoaded,
            properties: HealthIntelligenceAnalyticsProperties(healthDataState: "full")
        )
        logger.log(
            .todayRecoveryCardViewed,
            properties: HealthIntelligenceAnalyticsProperties(recoveryStatus: "ready")
        )
    }
}

@MainActor
final class HealthIntelligenceAnalyticsCoordinatorTests: XCTestCase {

    private var analytics: CapturingHealthIntelligenceAnalyticsLogger!
    private var coordinator: HealthIntelligenceAnalyticsCoordinator!

    override func setUp() {
        super.setUp()
        analytics = CapturingHealthIntelligenceAnalyticsLogger()
        coordinator = HealthIntelligenceAnalyticsCoordinator(analyticsLogger: analytics)
    }

    private func makeReadySnapshot() -> HealthIntelligenceSnapshot {
        HealthIntelligenceSnapshot(
            date: Date(),
            recovery: RecoverySummary(
                score: 82,
                status: .ready,
                title: "Ready to train",
                explanation: "Recovery looks solid today.",
                recommendedTraining: "You can train normally today.",
                recommendedNutrition: "Stay on your usual plan.",
                confidence: .high,
                contributingFactors: [],
                missingSignals: []
            ),
            workout: nil,
            activity: ActivitySummary(steps: 5_000, activeEnergyKcal: 300, exerciseMinutes: 30),
            nutritionAdjustment: .none,
            weeklyReview: nil,
            planConfidence: PlanHealthConfidence(score: 0.82, label: "Strong fit"),
            nextBestAction: .none
        )
    }

    func testSnapshotLoadedUsesCanonicalEventName() {
        let snapshot = makeReadySnapshot()
        let context = HealthIntelligencePresentationContext(snapshot: snapshot)

        coordinator.logSnapshotLoaded(surface: .today, context: context)

        XCTAssertEqual(analytics.lastEvent, .snapshotLoaded)
        XCTAssertEqual(analytics.lastProperties?["surface"], "today")
        XCTAssertEqual(analytics.lastProperties?["health_data_state"], "full")
    }

    func testRecoveryCardViewedFiresOncePerSession() {
        coordinator.updateContext(from: HealthIntelligencePresentationContext(
            snapshot: makeReadySnapshot()
        ), surface: .today)

        coordinator.logTodayRecoveryCardViewed()
        coordinator.logTodayRecoveryCardViewed()

        XCTAssertEqual(analytics.eventCount(for: .todayRecoveryCardViewed), 1)
    }

    func testNextBestActionTappedIncludesActionType() {
        coordinator.updateContext(from: HealthIntelligencePresentationContext(
            snapshot: makeReadySnapshot()
        ), surface: .today)

        coordinator.logTodayNextBestActionTapped(destination: .logMeal)

        XCTAssertEqual(analytics.lastEvent, .todayNextBestActionTapped)
        XCTAssertEqual(analytics.lastProperties?["action_type"], "log_meal")
    }

    func testConnectHealthNextBestActionAlsoLogsPermissionCTA() {
        coordinator.updateContext(from: HealthIntelligencePresentationContext(
            snapshot: makeReadySnapshot()
        ), surface: .today)

        coordinator.logTodayNextBestActionTapped(destination: .connectHealth)

        XCTAssertTrue(analytics.contains(.todayNextBestActionTapped))
        XCTAssertTrue(analytics.contains(.healthPermissionCTATapped))
        XCTAssertEqual(analytics.lastProperties(for: .healthPermissionCTATapped)?["cta_surface"], "today")
    }

    func testPlanHealthConfidenceViewedFiresOnce() {
        coordinator.updateContext(from: HealthIntelligencePresentationContext(
            snapshot: makeReadySnapshot()
        ), surface: .plan)

        coordinator.logPlanHealthConfidenceViewed(confidenceBucket: "high")
        coordinator.logPlanHealthConfidenceViewed(confidenceBucket: "high")

        XCTAssertEqual(analytics.eventCount(for: .planHealthConfidenceViewed), 1)
        XCTAssertEqual(analytics.lastProperties(for: .planHealthConfidenceViewed)?["confidence_bucket"], "high")
    }

    func testLoggedPropertiesNeverIncludeRawHealthValues() {
        let snapshot = makeReadySnapshot()
        coordinator.logSnapshotLoaded(
            surface: .journey,
            context: HealthIntelligencePresentationContext(snapshot: snapshot)
        )
        coordinator.logCoachHealthContextUsed(from: snapshot)

        for entry in analytics.events {
            let parameters = entry.properties.asParameters()
            XCTAssertNil(parameters["hrv"])
            XCTAssertNil(parameters["resting_heart_rate"])
            XCTAssertNil(parameters["workout_title"])
            for value in parameters.values {
                XCTAssertFalse(value.localizedCaseInsensitiveContains("bpm"))
            }
        }
    }
}
