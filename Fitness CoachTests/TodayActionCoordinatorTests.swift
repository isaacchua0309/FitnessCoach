//
//  TodayActionCoordinatorTests.swift
//  Fitness CoachTests
//

import XCTest
@testable import Fitness_Coach

@MainActor
final class TodayActionCoordinatorTests: XCTestCase {

    private var harness: FitnessActionCenterTestSupport.Harness!
    private var analytics: CapturingTodayAnalyticsLogger!
    private var coordinator: TodayActionCoordinator!

    override func setUp() async throws {
        harness = try FitnessActionCenterTestSupport.makeHarness()
        analytics = CapturingTodayAnalyticsLogger()
        coordinator = TodayActionCoordinator(
            actionCenter: harness.actionCenter,
            analyticsLogger: analytics,
            logDate: { [harness] in harness.today }
        )
    }

    func testAddWaterLogsNativelyWithoutCoach() throws {
        try harness.seedProfile()
        _ = try harness.actionCenter.ensureTodayLog()

        var coachOpened = false
        coordinator.onOpenCoach = { _ in coachOpened = true }

        let action = NextBestActionState(
            title: FormaProductCopy.Today.NextAction.drinkWaterTitle(amountMl: 500),
            subtitle: nil,
            reason: .addWater,
            primaryCTA: .addWater(amountMl: 500),
            secondaryCTAs: []
        )

        coordinator.handleCTA(.addWater(amountMl: 500), from: action)

        XCTAssertFalse(coachOpened)
        XCTAssertFalse(coordinator.isPresentingLogWeightSheet)
        XCTAssertNil(coordinator.logMealPresentation)
        let log = try XCTUnwrap(try harness.dailyLogService.getLog(for: harness.today))
        XCTAssertEqual(log.waterConsumedMl, 500)
    }

    func testLogMealPresentsNativeSheet() {
        var coachOpened = false
        coordinator.onOpenCoach = { _ in coachOpened = true }

        coordinator.performQuickAction(.manualEntry)

        XCTAssertFalse(coachOpened)
        XCTAssertNotNil(coordinator.logMealPresentation)
    }

    func testAddWaterPresentsNativeSheet() {
        coordinator.performQuickAction(.addWater)

        XCTAssertTrue(coordinator.isPresentingAddWaterSheet)
    }

    func testAskCoachRoutesToCoach() {
        var coachPrefill: String?
        coordinator.onOpenCoach = { coachPrefill = $0 }

        coordinator.performQuickAction(.askCoach)

        XCTAssertNil(coachPrefill)
    }

    func testReviewTodayRoutesToCoach() {
        var coachPrefill: String?
        coordinator.onOpenCoach = { coachPrefill = $0 }

        let action = NextBestActionState(
            title: FormaProductCopy.Today.NextAction.reviewTodayTitle,
            subtitle: nil,
            reason: .reviewToday,
            primaryCTA: .reviewToday,
            secondaryCTAs: []
        )

        coordinator.handleCTA(.reviewToday, from: action)

        XCTAssertEqual(coachPrefill, TodayCoachPrompt.reviewToday)
    }

    func testMissedMealNextActionPresentsNativeSheetWithMealType() {
        var coachOpened = false
        coordinator.onOpenCoach = { _ in coachOpened = true }

        let action = NextBestActionState(
            title: FormaProductCopy.Today.NextAction.logMissedMealTitle(.lunch),
            subtitle: nil,
            reason: .logMissedMeal(.lunch),
            primaryCTA: .logMeal(TodayCoachPrompt.logMeal(.lunch)),
            secondaryCTAs: []
        )

        coordinator.handleCTA(action.primaryCTA, from: action)

        XCTAssertFalse(coachOpened)
        XCTAssertEqual(coordinator.logMealPresentation?.mealType, .lunch)
    }

    func testCTATappedAnalyticsEvent() {
        let action = NextBestActionState(
            title: FormaProductCopy.Today.NextAction.drinkWaterTitle(amountMl: 500),
            subtitle: nil,
            reason: .addWater,
            primaryCTA: .addWater(amountMl: 500),
            secondaryCTAs: []
        )

        coordinator.handleCTA(.addWater(amountMl: 500), from: action)

        XCTAssertEqual(analytics.events.count, 1)
        XCTAssertEqual(analytics.events.first?.event, .nextActionCTATapped)
        XCTAssertEqual(analytics.events.first?.properties.reason, "add_water")
        XCTAssertEqual(analytics.events.first?.properties.cta, "add_water")
        XCTAssertEqual(analytics.events.first?.properties.route, "native_log_water")
    }

    func testQuickActionAnalyticsEvent() {
        coordinator.performQuickAction(.manualEntry)

        XCTAssertTrue(analytics.events.contains { $0.event == .quickActionTapped })
        XCTAssertEqual(analytics.events.last?.properties.action, "manualEntry")
        XCTAssertEqual(analytics.events.last?.properties.route, "native_log_meal_sheet")
    }
}

private final class CapturingTodayAnalyticsLogger: TodayAnalyticsLogging, @unchecked Sendable {
    struct Event {
        let event: TodayAnalyticsEvent
        let properties: TodayAnalyticsProperties
    }

    private(set) var events: [Event] = []

    func log(_ event: TodayAnalyticsEvent, properties: TodayAnalyticsProperties) {
        events.append(Event(event: event, properties: properties))
    }
}
