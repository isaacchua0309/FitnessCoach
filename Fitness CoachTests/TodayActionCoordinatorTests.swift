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
        XCTAssertEqual(analytics.events.first?.event, .nextActionTapped)
        XCTAssertEqual(analytics.events.first?.properties.reason, "add_water")
        XCTAssertEqual(analytics.events.first?.properties.cta, "add_water")
        XCTAssertEqual(analytics.events.first?.properties.route, "native_log_water")
        XCTAssertEqual(analytics.events.first?.properties.actionType, "next_best_action")
    }

    func testQuickActionAnalyticsEvent() {
        coordinator.performQuickAction(.manualEntry)

        let quickAction = analytics.events.first { $0.event == .quickActionTapped }
        XCTAssertNotNil(quickAction)
        XCTAssertEqual(quickAction?.properties.action, "manualEntry")
        XCTAssertEqual(quickAction?.properties.route, "native_log_meal_sheet")
        XCTAssertTrue(analytics.events.contains { $0.event == .logMealStarted })
    }

    func testLogMealSavedDoesNotIncludeFoodName() throws {
        try harness.seedProfile()
        _ = try harness.actionCenter.ensureTodayLog()

        var formState = FoodEntryFormState()
        formState.mealType = .lunch
        formState.name = "Secret meal name"
        formState.caloriesText = "500"
        formState.proteinText = "40"
        formState.carbsText = "30"
        formState.fatText = "10"

        coordinator.saveMeal(from: formState)

        let saved = try XCTUnwrap(analytics.events.last { $0.event == .logMealSaved })
        XCTAssertEqual(saved.properties.mealType, "lunch")
        XCTAssertNil(saved.properties.asParameters()["foodName"])
        XCTAssertNil(saved.properties.asParameters()["name"])
    }

    func testWaterAddedLogsAmountBucket() throws {
        try harness.seedProfile()
        _ = try harness.actionCenter.ensureTodayLog()

        coordinator.handleCTA(.addWater(amountMl: 500), from: NextBestActionState(
            title: "Water",
            subtitle: nil,
            reason: .addWater,
            primaryCTA: .addWater(amountMl: 500),
            secondaryCTAs: []
        ))

        let waterEvent = try XCTUnwrap(analytics.events.last { $0.event == .waterAdded })
        XCTAssertEqual(waterEvent.properties.waterAmountBucket, "medium")
    }

    func testWeightLoggedEvent() throws {
        try harness.seedProfile()
        _ = try harness.actionCenter.ensureTodayLog()

        coordinator.saveWeight(72.5)

        XCTAssertTrue(analytics.events.contains { $0.event == .weightLogged })
    }

    func testMealDeletedLogsMealTypeOnly() throws {
        try harness.seedProfile()
        let log = try harness.actionCenter.ensureTodayLog()
        let entry = try harness.actionCenter.logFood(
            FoodDraft(
                mealType: .breakfast,
                name: "Sensitive food",
                calories: 300,
                protein: 20,
                carbs: 10,
                fat: 8,
                source: .manual,
                confidence: .high
            ),
            date: harness.today
        )

        coordinator.requestDeleteFood(entry)
        coordinator.confirmDeleteFood()

        let deleted = try XCTUnwrap(analytics.events.last { $0.event == .mealDeleted })
        XCTAssertEqual(deleted.properties.mealType, "breakfast")
        XCTAssertNil(deleted.properties.asParameters()["foodName"])
    }

    func testScanFoodQuickActionLogsDedicatedEvent() {
        coordinator.performQuickAction(.scanFood)

        XCTAssertTrue(analytics.events.contains { $0.event == .scanFoodTapped })
    }

    func testGoalConnectionTappedEvent() {
        coordinator.logGoalConnectionTapped(destination: .journey)

        XCTAssertEqual(analytics.events.last?.event, .goalConnectionTapped)
        XCTAssertEqual(analytics.events.last?.properties.destination, "journey")
    }

    func testNextActionViewedEvent() {
        let action = NextBestActionState(
            title: FormaProductCopy.Today.NextAction.onTrackTitle,
            subtitle: nil,
            reason: .onTrack,
            primaryCTA: .none,
            secondaryCTAs: []
        )

        coordinator.logNextActionViewed(for: action)

        XCTAssertEqual(analytics.events.last?.event, .nextActionViewed)
        XCTAssertEqual(analytics.events.last?.properties.reason, "on_track")
    }

    func testTodayViewedEvent() {
        coordinator.logTodayViewed()

        XCTAssertEqual(analytics.events.last?.event, .viewed)
    }

    func testMealEditStartedAndSavedEvents() throws {
        try harness.seedProfile()
        _ = try harness.actionCenter.ensureTodayLog()
        let entry = try harness.actionCenter.logFood(
            FoodDraft(
                mealType: .dinner,
                name: "Private dinner",
                calories: 600,
                protein: 45,
                carbs: 20,
                fat: 15,
                source: .manual,
                confidence: .high
            ),
            date: harness.today
        )

        coordinator.openEditFood(entry)
        XCTAssertEqual(analytics.events.last?.event, .mealEditStarted)
        XCTAssertEqual(analytics.events.last?.properties.mealType, "dinner")

        var editForm = FoodEntryFormState(foodEntry: entry)
        editForm.name = "Updated label"
        editForm.caloriesText = "650"
        editForm.proteinText = "50"
        editForm.carbsText = "22"
        editForm.fatText = "16"

        coordinator.saveFoodEdit(from: editForm)

        let saved = try XCTUnwrap(analytics.events.last { $0.event == .mealEditSaved })
        XCTAssertEqual(saved.properties.mealType, "dinner")
        XCTAssertNil(saved.properties.asParameters()["foodName"])
    }

    func testAnalyticsContextBucketsAttachToEvents() {
        coordinator.updateAnalyticsContext(
            from: TodayDashboardFixtures.partialDay(
                proteinConsumed: 90,
                proteinTarget: 180,
                foodEntries: TodayPreviewData.foodEntries
            ),
            healthConnected: true
        )

        coordinator.logTodayViewed()

        let viewed = analytics.events.last
        XCTAssertEqual(viewed?.properties.hasMeals, true)
        XCTAssertEqual(viewed?.properties.healthConnected, true)
        XCTAssertNotNil(viewed?.properties.calorieProgressBucket)
        XCTAssertNotNil(viewed?.properties.proteinProgressBucket)
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
