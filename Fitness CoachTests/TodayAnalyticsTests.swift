//
//  TodayAnalyticsTests.swift
//  Fitness CoachTests
//

import XCTest
@testable import Fitness_Coach

final class TodayAnalyticsTests: XCTestCase {

    func testSnapshotIncludesSafeBucketsAndFlags() {
        let state = TodayDashboardFixtures.partialDay(
            proteinConsumed: 90,
            proteinTarget: 180,
            foodEntries: TodayPreviewData.foodEntries
        )

        let snapshot = TodayAnalyticsContextBuilder.snapshot(
            from: state,
            healthConnected: true
        )

        XCTAssertTrue(snapshot.hasMeals)
        XCTAssertEqual(snapshot.healthConnected, true)
        XCTAssertEqual(snapshot.nextActionReason, TodayNextActionFormatting.analyticsReason(state.nextBestAction.reason))
        XCTAssertFalse(snapshot.calorieProgressBucket.isEmpty)
        XCTAssertFalse(snapshot.proteinProgressBucket.isEmpty)
    }

    func testEmptyDayUsesNoneBuckets() {
        let state = TodayDashboardFixtures.emptyDay()

        let snapshot = TodayAnalyticsContextBuilder.snapshot(
            from: state,
            healthConnected: false
        )

        XCTAssertFalse(snapshot.hasMeals)
        XCTAssertEqual(snapshot.calorieProgressBucket, TodayAnalyticsProgressBucket.none.rawValue)
        XCTAssertEqual(snapshot.proteinProgressBucket, TodayAnalyticsProgressBucket.none.rawValue)
    }

    func testOverTargetCaloriesUseOverBucket() {
        let bucket = TodayAnalyticsContextBuilder.calorieBucket(
            from: CalorieSummary(
                consumed: 2_100,
                target: 1_800,
                remaining: 0,
                progress: 1.17,
                isOverTarget: true
            )
        )

        XCTAssertEqual(bucket, TodayAnalyticsProgressBucket.over.rawValue)
    }

    func testPropertiesOmitsSensitiveFields() {
        let parameters = TodayAnalyticsProperties.from(
            snapshot: TodayAnalyticsSnapshot(
                hasMeals: true,
                calorieProgressBucket: "mid",
                proteinProgressBucket: "low",
                healthConnected: true,
                nextActionReason: "add_water"
            ),
            actionType: "add_water",
            mealType: "lunch"
        ).asParameters()

        XCTAssertEqual(parameters["hasMeals"], "true")
        XCTAssertEqual(parameters["mealType"], "lunch")
        XCTAssertNil(parameters["foodName"])
        XCTAssertNil(parameters["name"])
    }

    func testWaterAmountBuckets() {
        XCTAssertEqual(TodayAnalyticsContextBuilder.waterAmountBucket(250), "small")
        XCTAssertEqual(TodayAnalyticsContextBuilder.waterAmountBucket(500), "medium")
        XCTAssertEqual(TodayAnalyticsContextBuilder.waterAmountBucket(900), "large")
    }

    func testGoalConnectionDestinationMapping() {
        XCTAssertEqual(
            TodayAnalyticsContextBuilder.goalConnectionDestination(.journey),
            "journey"
        )
        XCTAssertEqual(
            TodayAnalyticsContextBuilder.goalConnectionDestination(.plan),
            "plan"
        )
    }
}

// MARK: - Event emission (coordinator integration)

@MainActor
final class TodayAnalyticsEventEmissionTests: XCTestCase {

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
        coordinator.updateAnalyticsContext(
            from: TodayDashboardFixtures.partialDay(),
            healthConnected: false
        )
    }

    func testTodayViewedEventName() {
        coordinator.logTodayViewed()
        XCTAssertEqual(analytics.events.last?.event, .viewed)
        XCTAssertEqual(analytics.events.last?.properties.hasMeals, false)
    }

    func testMealSavedEmitsMealTypeOnly() throws {
        try harness.seedProfile()
        _ = try harness.actionCenter.ensureTodayLog()

        var formState = FoodEntryFormState()
        formState.mealType = .breakfast
        formState.name = "Private"
        formState.caloriesText = "400"
        formState.proteinText = "30"
        formState.carbsText = "20"
        formState.fatText = "10"

        coordinator.saveMeal(from: formState)

        let saved = try XCTUnwrap(analytics.events.last { $0.event == .logMealSaved })
        XCTAssertEqual(saved.properties.mealType, "breakfast")
        XCTAssertNil(saved.properties.asParameters()["name"])
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
