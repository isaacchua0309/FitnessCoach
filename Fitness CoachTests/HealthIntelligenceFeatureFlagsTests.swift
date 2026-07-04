//
//  HealthIntelligenceFeatureFlagsTests.swift
//  Fitness CoachTests
//

import XCTest
@testable import Fitness_Coach

final class HealthIntelligenceFeatureFlagsTests: XCTestCase {

    override func tearDown() {
        HealthIntelligenceFeatureFlags.testOverride = nil
        FormaAbTest.testOverride = nil
        super.tearDown()
    }

    // MARK: - Defaults

    func testDefaultsAreAllEnabled() {
        let defaults = HealthIntelligenceFeatureFlags.snapshot()

        XCTAssertTrue(defaults.healthIntelligenceEnabled)
        XCTAssertTrue(defaults.healthIntelligenceEnginesEnabled)
        XCTAssertTrue(defaults.healthIntelligenceUIEnabled)
        XCTAssertTrue(defaults.healthIntelligenceCoachContextEnabled)
        XCTAssertTrue(defaults.shouldCoachLoadHealthIntelligence)
        XCTAssertTrue(defaults.healthIntelligenceWeeklyReviewEnabled)
        XCTAssertTrue(defaults.healthSummaryRemoteSyncEnabled)
        XCTAssertTrue(defaults.isSyncEnabled)
        XCTAssertTrue(defaults.isRepositoryReadRoutingEnabled)
        XCTAssertTrue(defaults.shouldTodayModelLoadHealthIntelligence)
    }

    func testDocumentedDefaultConstantsMatchSnapshot() {
        XCTAssertEqual(
            HealthIntelligenceFeatureFlags.Defaults.foundationEnabled,
            HealthIntelligenceFeatureFlags.snapshot().healthIntelligenceEnabled
        )
        XCTAssertEqual(
            HealthIntelligenceFeatureFlags.Defaults.enginesEnabled,
            HealthIntelligenceFeatureFlags.snapshot().healthIntelligenceEnginesEnabled
        )
        XCTAssertEqual(
            HealthIntelligenceFeatureFlags.Defaults.uiEnabled,
            HealthIntelligenceFeatureFlags.snapshot().healthIntelligenceUIEnabled
        )
        XCTAssertEqual(
            HealthIntelligenceFeatureFlags.Defaults.coachContextEnabled,
            HealthIntelligenceFeatureFlags.snapshot().healthIntelligenceCoachContextEnabled
        )
        XCTAssertEqual(
            HealthIntelligenceFeatureFlags.Defaults.weeklyReviewEnabled,
            HealthIntelligenceFeatureFlags.snapshot().healthIntelligenceWeeklyReviewEnabled
        )
    }

    // MARK: - Independent toggles

    func testEnginesCanRunWhileUIIsOff() {
        applyAbTestOverride { $0.uiEnabled = false }

        let flags = HealthIntelligenceFeatureFlags.snapshot()

        XCTAssertTrue(flags.healthIntelligenceEnginesEnabled)
        XCTAssertFalse(flags.healthIntelligenceUIEnabled)
        XCTAssertFalse(flags.shouldTodayModelLoadHealthIntelligence)
        XCTAssertFalse(flags.shouldJourneyModelLoadHealthIntelligence)
        XCTAssertFalse(flags.shouldPlanModelLoadHealthIntelligence)
    }

    func testCoachContextEnabledByDefaultAndCanBeDisabledOperationally() {
        XCTAssertTrue(HealthIntelligenceFeatureFlags.snapshot().shouldCoachLoadHealthIntelligence)

        applyAbTestOverride { $0.coachContextEnabled = false }
        XCTAssertFalse(HealthIntelligenceFeatureFlags.snapshot().shouldCoachLoadHealthIntelligence)

        applyAbTestOverride { $0.coachContextEnabled = true }
        XCTAssertTrue(HealthIntelligenceFeatureFlags.snapshot().shouldCoachLoadHealthIntelligence)
    }

    func testWeeklyReviewRequiresExplicitEnable() {
        applyAbTestOverride { $0.weeklyReviewEnabled = false }
        XCTAssertFalse(HealthIntelligenceFeatureFlags.snapshot().healthIntelligenceWeeklyReviewEnabled)

        applyAbTestOverride { $0.weeklyReviewEnabled = true }
        XCTAssertTrue(HealthIntelligenceFeatureFlags.snapshot().healthIntelligenceWeeklyReviewEnabled)
    }

    func testUIControlsSurfaceLoading() {
        applyAbTestOverride { $0.uiEnabled = true }
        var flags = HealthIntelligenceFeatureFlags.snapshot()
        XCTAssertTrue(flags.shouldTodayModelLoadHealthIntelligence)
        XCTAssertTrue(flags.shouldJourneyModelLoadHealthIntelligence)
        XCTAssertTrue(flags.shouldPlanModelLoadHealthIntelligence)

        applyAbTestOverride { $0.uiEnabled = false; $0.todayDebugFetchEnabled = false; $0.journeyDebugFetchEnabled = false; $0.planDebugFetchEnabled = false }
        flags = HealthIntelligenceFeatureFlags.snapshot()
        XCTAssertFalse(flags.shouldTodayModelLoadHealthIntelligence)
        XCTAssertFalse(flags.shouldJourneyModelLoadHealthIntelligence)
        XCTAssertFalse(flags.shouldPlanModelLoadHealthIntelligence)
    }

    // MARK: - Master switch

    func testFoundationDisabledTurnsOffAllDerivedFlags() {
        applyAbTestOverride {
            $0.foundationEnabled = false
            $0.uiEnabled = true
            $0.coachContextEnabled = true
            $0.weeklyReviewEnabled = true
        }

        let flags = HealthIntelligenceFeatureFlags.snapshot()

        XCTAssertFalse(flags.healthIntelligenceEnabled)
        XCTAssertFalse(flags.healthIntelligenceEnginesEnabled)
        XCTAssertFalse(flags.healthIntelligenceUIEnabled)
        XCTAssertFalse(flags.healthIntelligenceCoachContextEnabled)
        XCTAssertFalse(flags.healthIntelligenceWeeklyReviewEnabled)
        XCTAssertFalse(flags.isSyncEnabled)
        XCTAssertFalse(flags.shouldCoachLoadHealthIntelligence)
    }

    func testEnginesDisabledTurnsOffCompositionAndSurfaces() {
        applyAbTestOverride {
            $0.enginesEnabled = false
            $0.uiEnabled = true
            $0.coachContextEnabled = true
        }

        let flags = HealthIntelligenceFeatureFlags.snapshot()

        XCTAssertFalse(flags.healthIntelligenceEnginesEnabled)
        XCTAssertFalse(flags.shouldTodayModelLoadHealthIntelligence)
        XCTAssertFalse(flags.shouldCoachLoadHealthIntelligence)
    }

    // MARK: - Injectable override

    func testOverrideProviderIsUsedByStaticAccessors() {
        #if DEBUG
        HealthIntelligenceFeatureFlags.testOverride = TestHealthIntelligenceFeatureFlags(
            healthIntelligenceEnabled: true,
            healthIntelligenceEnginesEnabled: true,
            healthIntelligenceUIEnabled: true,
            healthIntelligenceCoachContextEnabled: true,
            healthIntelligenceWeeklyReviewEnabled: true
        )

        XCTAssertTrue(HealthIntelligenceFeatureFlags.healthIntelligenceUIEnabled)
        XCTAssertTrue(HealthIntelligenceFeatureFlags.shouldCoachLoadHealthIntelligence)
        XCTAssertTrue(HealthIntelligenceFeatureFlags.healthIntelligenceWeeklyReviewEnabled)
        #endif
    }

    // MARK: - Weekly review service integration

    func testWeeklyReviewServiceNoOpsWhenWeeklyReviewFlagDisabled() async {
        let harness = WeeklyReviewServiceTestSupport.makeHarness(
            referenceDate: WeeklyReviewServiceTestSupport.day(2026, 7, 8, hour: 12),
            calendar: WeeklyReviewServiceTestSupport.makeCalendar(),
            weeklyReviewEnabled: false
        )
        harness.seedCompletedWeek(
            weekEnd: WeeklyReviewServiceTestSupport.day(2026, 7, 5)
        )

        let review = await harness.service.getLatestCompletedWeeklyReview()

        XCTAssertNil(review)
        XCTAssertEqual(harness.countingEngine.evaluateCount, 0)
    }

    func testWeeklyReviewServiceRunsWhenWeeklyReviewFlagEnabled() async {
        let calendar = WeeklyReviewServiceTestSupport.makeCalendar()
        let referenceDate = WeeklyReviewServiceTestSupport.day(2026, 7, 8, hour: 12, calendar: calendar)
        let harness = WeeklyReviewServiceTestSupport.makeHarness(
            referenceDate: referenceDate,
            calendar: calendar,
            weeklyReviewEnabled: true
        )
        harness.seedCompletedWeek(
            weekEnd: WeeklyReviewServiceTestSupport.day(2026, 7, 5, calendar: calendar)
        )

        let review = await harness.service.getLatestCompletedWeeklyReview(calendar: calendar)

        XCTAssertNotNil(review)
    }

    // MARK: - Helpers

    private func applyAbTestOverride(_ mutate: (inout FormaAbTestSnapshot) -> Void) {
        var snapshot = FormaAbTestSnapshot.allEnabled
        mutate(&snapshot)
        FormaAbTest.testOverride = snapshot
    }
}
