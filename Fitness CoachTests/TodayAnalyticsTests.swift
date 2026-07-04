//
//  TodayAnalyticsTests.swift
//  Fitness CoachTests
//

import XCTest
@testable import Fitness_Coach

final class TodayAnalyticsTests: XCTestCase {

    func testSnapshotIncludesSafeStatusFields() {
        let state = TodayDashboardFixtures.partialDay(
            proteinConsumed: 90,
            proteinTarget: 180,
            foodEntries: TodayPreviewData.foodEntries,
            date: TodayDashboardFixtures.date(hour: 14)
        )

        let snapshot = TodayAnalyticsContextBuilder.snapshot(
            from: state,
            healthConnected: true
        )

        XCTAssertTrue(snapshot.hasMealLogged)
        XCTAssertEqual(snapshot.healthConnected, true)
        XCTAssertEqual(snapshot.dayStage, TodayAnalyticsDayStage.afternoon.rawValue)
        XCTAssertEqual(
            snapshot.nextActionType,
            TodayNextActionFormatting.analyticsReason(state.nextBestAction.reason)
        )
        XCTAssertEqual(snapshot.proteinStatus, TodayAnalyticsNutrientStatus.behind.rawValue)
        XCTAssertEqual(snapshot.waterStatus, TodayAnalyticsNutrientStatus.behind.rawValue)
        XCTAssertEqual(snapshot.calorieStatus, TodayAnalyticsCalorieStatus.under.rawValue)
    }

    func testEmptyDayUsesBehindStatuses() {
        let state = TodayDashboardFixtures.emptyDay(date: TodayDashboardFixtures.date(hour: 9))

        let snapshot = TodayAnalyticsContextBuilder.snapshot(
            from: state,
            healthConnected: false
        )

        XCTAssertFalse(snapshot.hasMealLogged)
        XCTAssertEqual(snapshot.dayStage, TodayAnalyticsDayStage.morning.rawValue)
        XCTAssertEqual(snapshot.proteinStatus, TodayAnalyticsNutrientStatus.behind.rawValue)
        XCTAssertEqual(snapshot.waterStatus, TodayAnalyticsNutrientStatus.behind.rawValue)
        XCTAssertEqual(snapshot.calorieStatus, TodayAnalyticsCalorieStatus.under.rawValue)
        XCTAssertEqual(snapshot.workoutStatus, TodayAnalyticsWorkoutStatus.none.rawValue)
    }

    func testOverTargetCaloriesUseOverStatus() {
        let status = TodayAnalyticsContextBuilder.calorieStatus(
            from: CalorieSummary(
                consumed: 2_100,
                target: 1_800,
                remaining: 0,
                progress: 1.17,
                isOverTarget: true
            )
        )

        XCTAssertEqual(status, .over)
    }

    func testNearTargetCaloriesUseNearStatus() {
        let status = TodayAnalyticsContextBuilder.calorieStatus(
            from: CalorieSummary(
                consumed: 1_620,
                target: 1_800,
                remaining: 180,
                progress: 0.9,
                isOverTarget: false
            )
        )

        XCTAssertEqual(status, .near)
    }

    func testCompletedWorkoutStatus() {
        let state = TodayPreviewData.workoutCompleted

        let snapshot = TodayAnalyticsContextBuilder.snapshot(
            from: state,
            healthConnected: true
        )

        XCTAssertEqual(snapshot.workoutStatus, TodayAnalyticsWorkoutStatus.completed.rawValue)
    }

    func testDayStageBuckets() {
        XCTAssertEqual(
            TodayAnalyticsContextBuilder.dayStage(for: TodayDashboardFixtures.date(hour: 9)).rawValue,
            "morning"
        )
        XCTAssertEqual(
            TodayAnalyticsContextBuilder.dayStage(for: TodayDashboardFixtures.date(hour: 14)).rawValue,
            "afternoon"
        )
        XCTAssertEqual(
            TodayAnalyticsContextBuilder.dayStage(for: TodayDashboardFixtures.date(hour: 19)).rawValue,
            "evening"
        )
        XCTAssertEqual(
            TodayAnalyticsContextBuilder.dayStage(for: TodayDashboardFixtures.date(hour: 22)).rawValue,
            "night"
        )
    }

    func testPropertiesOmitsSensitiveFields() {
        let parameters = TodayAnalyticsProperties.from(
            snapshot: TodayAnalyticsSnapshot(
                dayStage: TodayAnalyticsDayStage.afternoon.rawValue,
                nextActionType: "add_water",
                hasMealLogged: true,
                proteinStatus: TodayAnalyticsNutrientStatus.behind.rawValue,
                waterStatus: TodayAnalyticsNutrientStatus.onTrack.rawValue,
                calorieStatus: TodayAnalyticsCalorieStatus.under.rawValue,
                workoutStatus: TodayAnalyticsWorkoutStatus.none.rawValue,
                healthConnected: true
            ),
            actionType: "add_water",
            mealType: "lunch"
        ).asParameters()

        XCTAssertEqual(parameters["has_meal_logged"], "true")
        XCTAssertEqual(parameters["meal_type"], "lunch")
        XCTAssertEqual(parameters["day_stage"], "afternoon")
        XCTAssertEqual(parameters["next_action_type"], "add_water")
        XCTAssertEqual(parameters["protein_status"], "behind")
        XCTAssertEqual(parameters["water_status"], "on_track")
        XCTAssertEqual(parameters["calorie_status"], "under")
        XCTAssertEqual(parameters["workout_status"], "none")
        XCTAssertNil(parameters["foodName"])
        XCTAssertNil(parameters["calories"])
        XCTAssertNil(parameters["weight"])
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
            from: TodayDashboardFixtures.partialDay(
                foodEntries: TodayPreviewData.foodEntries,
                date: TodayDashboardFixtures.date(hour: 14)
            ),
            healthConnected: false
        )
    }

    func testTodayViewedEventName() {
        coordinator.logTodayViewed()
        XCTAssertEqual(analytics.events.last?.event.rawValue, "today_viewed")
        XCTAssertEqual(analytics.events.last?.properties.hasMealLogged, true)
        XCTAssertEqual(analytics.events.last?.properties.dayStage, "afternoon")
    }

    func testMissionAndSectionViewEvents() {
        coordinator.logMissionViewed()
        coordinator.logDailyVictoryViewed()
        coordinator.logSmartCoachViewed()
        coordinator.logEndOfDayWrapViewed()

        XCTAssertEqual(analytics.events.map(\.event.rawValue), [
            "today_mission_viewed",
            "today_daily_victory_viewed",
            "today_smart_coach_viewed",
            "today_end_of_day_wrap_viewed"
        ])
    }

    func testPrimaryCTATappedEvent() {
        coordinator.logPrimaryCTATapped()
        XCTAssertEqual(analytics.events.last?.event.rawValue, "today_primary_cta_tapped")
        XCTAssertEqual(analytics.events.last?.properties.actionType, "log_meal")
    }

    func testNextBestActionViewAndTapEvents() {
        let action = NextBestActionState(
            title: "Protein",
            subtitle: nil,
            reason: .eatProtein,
            primaryCTA: .scanFood,
            secondaryCTAs: []
        )

        coordinator.logNextActionViewed(for: action)
        coordinator.handleCTA(.scanFood, from: action)

        XCTAssertEqual(analytics.events[0].event.rawValue, "today_next_best_action_viewed")
        XCTAssertEqual(analytics.events[1].event.rawValue, "today_next_best_action_tapped")
        XCTAssertEqual(analytics.events[1].properties.action, "eat_protein")
    }

    func testMealAddAndEditTappedEvents() {
        coordinator.logMeal(for: .lunch)
        XCTAssertEqual(analytics.events.last?.event.rawValue, "today_meal_add_tapped")
        XCTAssertEqual(analytics.events.last?.properties.mealType, "lunch")

        let entry = TodayPreviewData.foodEntries[0]
        coordinator.openEditFood(entry)
        XCTAssertEqual(analytics.events.last?.event.rawValue, "today_meal_edit_tapped")
        XCTAssertEqual(analytics.events.last?.properties.mealType, "breakfast")
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
        XCTAssertNil(saved.properties.asParameters()["calories"])
    }
}
