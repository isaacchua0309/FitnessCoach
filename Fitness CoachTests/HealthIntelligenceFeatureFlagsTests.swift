//
//  HealthIntelligenceFeatureFlagsTests.swift
//  Fitness CoachTests
//

import XCTest
@testable import Fitness_Coach

final class HealthIntelligenceFeatureFlagsTests: XCTestCase {

    override func tearDown() {
        HealthIntelligenceFeatureFlags.testOverride = nil
        super.tearDown()
    }

    // MARK: - Production defaults

    func testProductionDefaultsAreSafeForRelease() {
        let defaults = HealthIntelligenceFeatureFlags.snapshot()

        XCTAssertTrue(defaults.healthIntelligenceEnabled)
        XCTAssertTrue(defaults.healthIntelligenceEnginesEnabled)
        XCTAssertFalse(defaults.healthIntelligenceUIEnabled)
        XCTAssertFalse(defaults.healthIntelligenceCoachContextEnabled)
        XCTAssertFalse(defaults.healthIntelligenceWeeklyReviewEnabled)
        XCTAssertTrue(defaults.isSyncEnabled)
        XCTAssertTrue(defaults.isRepositoryReadRoutingEnabled)
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
        let flags = HealthIntelligenceFeatureFlags.snapshot(environment: [
            HealthIntelligenceFeatureFlags.EnvironmentKey.ui: "0"
        ])

        XCTAssertTrue(flags.healthIntelligenceEnginesEnabled)
        XCTAssertFalse(flags.healthIntelligenceUIEnabled)
        XCTAssertFalse(flags.shouldTodayModelLoadHealthIntelligence)
        XCTAssertFalse(flags.shouldJourneyModelLoadHealthIntelligence)
        XCTAssertFalse(flags.shouldPlanModelLoadHealthIntelligence)
    }

    func testCoachContextRequiresExplicitEnable() {
        let off = HealthIntelligenceFeatureFlags.snapshot(environment: [
            HealthIntelligenceFeatureFlags.EnvironmentKey.coachContext: "0"
        ])
        XCTAssertFalse(off.shouldCoachLoadHealthIntelligence)

        let on = HealthIntelligenceFeatureFlags.snapshot(environment: [
            HealthIntelligenceFeatureFlags.EnvironmentKey.coachContext: "1"
        ])
        XCTAssertTrue(on.shouldCoachLoadHealthIntelligence)
    }

    func testWeeklyReviewRequiresExplicitEnable() {
        let off = HealthIntelligenceFeatureFlags.snapshot(environment: [
            HealthIntelligenceFeatureFlags.EnvironmentKey.weeklyReview: "0"
        ])
        XCTAssertFalse(off.healthIntelligenceWeeklyReviewEnabled)

        let on = HealthIntelligenceFeatureFlags.snapshot(environment: [
            HealthIntelligenceFeatureFlags.EnvironmentKey.weeklyReview: "1"
        ])
        XCTAssertTrue(on.healthIntelligenceWeeklyReviewEnabled)
    }

    func testUIControlsSurfaceLoading() {
        let on = HealthIntelligenceFeatureFlags.snapshot(environment: [
            HealthIntelligenceFeatureFlags.EnvironmentKey.ui: "1"
        ])
        XCTAssertTrue(on.shouldTodayModelLoadHealthIntelligence)
        XCTAssertTrue(on.shouldJourneyModelLoadHealthIntelligence)
        XCTAssertTrue(on.shouldPlanModelLoadHealthIntelligence)

        let off = HealthIntelligenceFeatureFlags.snapshot(environment: [
            HealthIntelligenceFeatureFlags.EnvironmentKey.ui: "0"
        ])
        XCTAssertFalse(off.shouldTodayModelLoadHealthIntelligence)
        XCTAssertFalse(off.shouldJourneyModelLoadHealthIntelligence)
        XCTAssertFalse(off.shouldPlanModelLoadHealthIntelligence)
    }

    // MARK: - Master switch

    func testFoundationDisabledTurnsOffAllDerivedFlags() {
        let flags = HealthIntelligenceFeatureFlags.snapshot(environment: [
            HealthIntelligenceFeatureFlags.EnvironmentKey.foundation: "0",
            HealthIntelligenceFeatureFlags.EnvironmentKey.ui: "1",
            HealthIntelligenceFeatureFlags.EnvironmentKey.coachContext: "1",
            HealthIntelligenceFeatureFlags.EnvironmentKey.weeklyReview: "1"
        ])

        XCTAssertFalse(flags.healthIntelligenceEnabled)
        XCTAssertFalse(flags.healthIntelligenceEnginesEnabled)
        XCTAssertFalse(flags.healthIntelligenceUIEnabled)
        XCTAssertFalse(flags.healthIntelligenceCoachContextEnabled)
        XCTAssertFalse(flags.healthIntelligenceWeeklyReviewEnabled)
        XCTAssertFalse(flags.isSyncEnabled)
        XCTAssertFalse(flags.shouldCoachLoadHealthIntelligence)
    }

    func testEnginesDisabledTurnsOffCompositionAndSurfaces() {
        let flags = HealthIntelligenceFeatureFlags.snapshot(environment: [
            HealthIntelligenceFeatureFlags.EnvironmentKey.engines: "0",
            HealthIntelligenceFeatureFlags.EnvironmentKey.ui: "1",
            HealthIntelligenceFeatureFlags.EnvironmentKey.coachContext: "1"
        ])

        XCTAssertFalse(flags.healthIntelligenceEnginesEnabled)
        XCTAssertFalse(flags.shouldTodayModelLoadHealthIntelligence)
        XCTAssertFalse(flags.shouldCoachLoadHealthIntelligence)
    }

    // MARK: - Legacy keys

    func testLegacyEnvironmentKeysAreHonored() {
        let flags = HealthIntelligenceFeatureFlags.snapshot(environment: [
            HealthIntelligenceFeatureFlags.EnvironmentKey.uiLegacy: "1",
            HealthIntelligenceFeatureFlags.EnvironmentKey.coachContextLegacy: "1",
            HealthIntelligenceFeatureFlags.EnvironmentKey.weeklyReviewLegacy: "1"
        ])

        XCTAssertTrue(flags.healthIntelligenceUIEnabled)
        XCTAssertTrue(flags.healthIntelligenceCoachContextEnabled)
        XCTAssertTrue(flags.healthIntelligenceWeeklyReviewEnabled)
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
}
