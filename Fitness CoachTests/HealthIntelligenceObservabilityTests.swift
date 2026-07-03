//
//  HealthIntelligenceObservabilityTests.swift
//  Fitness CoachTests
//
//  Forma — Pipeline observability and privacy guardrails.
//

import XCTest
@testable import Fitness_Coach

final class HealthIntelligenceObservabilityTests: XCTestCase {

    override func tearDown() {
        HealthIntelligencePipelineAnalytics.resetForTesting()
        HealthIntelligenceFeatureFlags.testOverride = nil
        super.tearDown()
    }

    func testPipelineAnalyticsLocalSyncSuccessUsesCanonicalEventName() {
        let analytics = CapturingHealthIntelligenceAnalyticsLogger()
        HealthIntelligencePipelineAnalytics.register(analytics)

        let state = HealthSyncState.idle.updating(
            phase: .succeeded,
            trigger: .today,
            progress: HealthSyncProgress(daysRequested: 1, daysCompleted: 1, currentDay: nil),
            signalResults: [],
            lastSuccessfulSyncAt: Date(),
            lastError: nil
        )

        HealthIntelligencePipelineAnalytics.logLocalSyncFinished(state, durationMs: 250)

        XCTAssertEqual(analytics.lastEvent, .healthLocalSyncSuccess)
        XCTAssertEqual(analytics.lastProperties?["sync_duration_ms"], "250")
        XCTAssertEqual(analytics.lastProperties?["sync_trigger"], "today")
    }

    func testPipelineAnalyticsPermissionPartialUsesBucketedCounts() {
        let analytics = CapturingHealthIntelligenceAnalyticsLogger()
        HealthIntelligencePipelineAnalytics.register(analytics)

        let status = HealthPermissionStatus.uniform(
            .available,
            isHealthDataAvailable: true,
            signals: [.stepCount, .workout]
        )

        HealthIntelligencePipelineAnalytics.logPermissionResolved(status)

        XCTAssertEqual(analytics.lastEvent, .healthPermissionPartial)
        XCTAssertEqual(analytics.lastProperties?["available_signal_count"], "2")
        XCTAssertNil(analytics.lastProperties?["hrv"])
    }

    func testPipelineAnalyticsRemoteSyncIncludesPayloadCountsOnly() {
        let analytics = CapturingHealthIntelligenceAnalyticsLogger()
        HealthIntelligencePipelineAnalytics.register(analytics)

        HealthIntelligencePipelineAnalytics.logRemoteSyncFinished(
            phase: .succeeded,
            trigger: "afterLocalRefresh",
            dailyCount: 7,
            workoutCount: 3,
            recoveryCount: 7,
            errorDescription: nil
        )

        XCTAssertEqual(analytics.lastEvent, .healthRemoteSyncSuccess)
        XCTAssertEqual(analytics.lastProperties?["payload_daily_count"], "7")
        XCTAssertEqual(analytics.lastProperties?["payload_workout_count"], "3")
        XCTAssertEqual(analytics.lastProperties?["payload_recovery_count"], "7")
    }

    func testPipelineAnalyticsRespectsFeatureFlag() {
        HealthIntelligenceFeatureFlags.testOverride = TestHealthIntelligenceFeatureFlags(
            healthIntelligenceEnabled: true,
            healthIntelligencePipelineAnalyticsEnabled: false
        )
        let analytics = CapturingHealthIntelligenceAnalyticsLogger()
        HealthIntelligencePipelineAnalytics.register(analytics)

        HealthIntelligencePipelineAnalytics.logSnapshotComposed(
            mode: .today,
            dataGapCount: 0,
            recoveryStatus: RecoveryStatus.ready.rawValue,
            hasWorkout: false
        )

        XCTAssertTrue(analytics.events.isEmpty)
    }

    @MainActor
    func testCoordinatorLogsCoachHealthContextAvailabilityEvents() {
        let analytics = CapturingHealthIntelligenceAnalyticsLogger()
        let coordinator = HealthIntelligenceAnalyticsCoordinator(analyticsLogger: analytics)
        let snapshot = HealthIntelligenceSnapshot.previewConnected()

        coordinator.logCoachHealthContextAvailable(from: snapshot)
        coordinator.logCoachHealthContextPartial(from: snapshot)

        XCTAssertTrue(analytics.contains(.coachHealthContextAvailable))
        XCTAssertTrue(analytics.contains(.coachHealthContextPartial))
        XCTAssertNotNil(analytics.lastProperties(for: .coachHealthContextAvailable)?["surface"])
    }
}

#if DEBUG
extension TestHealthIntelligenceFeatureFlags {
    init(
        healthIntelligenceEnabled: Bool = true,
        healthIntelligencePipelineAnalyticsEnabled: Bool = true
    ) {
        self.healthIntelligenceEnabled = healthIntelligenceEnabled
        self.healthIntelligenceEnginesEnabled = true
        self.healthIntelligenceUIEnabled = false
        self.healthIntelligenceCoachContextEnabled = false
        self.healthIntelligenceWeeklyReviewEnabled = false
        self.isSyncEnabled = true
        self.healthSummaryRemoteSyncEnabled = false
        self.healthIntelligencePipelineAnalyticsEnabled = healthIntelligencePipelineAnalyticsEnabled
        self.isRepositoryReadRoutingEnabled = true
        self.isTodayModelDebugFetchEnabled = false
        self.isJourneyModelDebugFetchEnabled = false
        self.isPlanModelDebugFetchEnabled = false
    }
}
#endif
