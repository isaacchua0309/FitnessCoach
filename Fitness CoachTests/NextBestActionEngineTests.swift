//
//  NextBestActionEngineTests.swift
//  Fitness CoachTests
//

import XCTest
@testable import Fitness_Coach

final class NextBestActionEngineTests: XCTestCase {

    private var calendar: Calendar { Calendar.current }

    // MARK: - Priority 1: Meals

    func testLogFirstMealBeforeBreakfastWindow() {
        let action = resolve(
            hour: 9,
            foodEntries: [],
            proteinProgress: 0,
            waterProgress: 0
        )

        XCTAssertEqual(action.reason, .logFirstMeal)
        XCTAssertEqual(action.primaryCTA, .logMeal(TodayCoachPrompt.logMeal()))
        XCTAssertTrue(action.secondaryCTAs.isEmpty)
    }

    func testLogMissedBreakfastAfterWindowWithNoMeals() {
        let action = resolve(
            hour: 12,
            foodEntries: [],
            proteinProgress: 0,
            waterProgress: 0
        )

        XCTAssertEqual(action.reason, .logMissedMeal(.breakfast))
        XCTAssertEqual(action.primaryCTA, .logMeal(TodayCoachPrompt.logMeal(.breakfast)))
    }

    func testLogMissedLunchAfterWindow() {
        let breakfast = foodEntry(mealType: .breakfast)
        let action = resolve(
            hour: 16,
            foodEntries: [breakfast],
            proteinProgress: 0.2,
            waterProgress: 0.5
        )

        XCTAssertEqual(action.reason, .logMissedMeal(.lunch))
        XCTAssertEqual(action.primaryCTA, .logMeal(TodayCoachPrompt.logMeal(.lunch)))
    }

    func testLogMissedDinnerAfterWindow() {
        let entries = [
            foodEntry(mealType: .breakfast),
            foodEntry(mealType: .lunch)
        ]
        let action = resolve(
            hour: 22,
            foodEntries: entries,
            proteinProgress: 0.5,
            waterProgress: 0.5
        )

        XCTAssertEqual(action.reason, .logMissedMeal(.dinner))
        XCTAssertEqual(action.primaryCTA, .logMeal(TodayCoachPrompt.logMeal(.dinner)))
    }

    // MARK: - Priority 2: Protein

    func testEatProteinWhenFarBelowPace() {
        let action = resolve(
            hour: 14,
            foodEntries: [foodEntry(mealType: .breakfast)],
            proteinProgress: 0.15,
            waterProgress: 0.9
        )

        XCTAssertEqual(action.reason, .eatProtein)
        XCTAssertEqual(action.primaryCTA, .logMeal(TodayCoachPrompt.logProtein))
        XCTAssertTrue(action.secondaryCTAs.isEmpty)
        XCTAssertTrue(action.title.contains("protein"))
    }

    func testProteinLowButOnPaceDoesNotTriggerProteinAction() {
        let action = resolve(
            hour: 8,
            foodEntries: [foodEntry(mealType: .breakfast)],
            proteinProgress: 0.25,
            waterProgress: 0.2,
            weightLoggedToday: true,
            hasRecentWeight: true
        )

        XCTAssertEqual(action.reason, .addWater)
    }

    // MARK: - Priority 3: Water

    func testAddWaterWhenHydrationLow() {
        let action = resolve(
            hour: 14,
            foodEntries: [foodEntry(mealType: .breakfast), foodEntry(mealType: .lunch)],
            proteinProgress: 0.85,
            waterProgress: 0.5,
            weightLoggedToday: true,
            hasRecentWeight: true
        )

        XCTAssertEqual(action.reason, .addWater)
        XCTAssertEqual(action.primaryCTA, .addWater(amountMl: 500))
    }

    // MARK: - Priority 4: Weight

    func testLogWeightWhenMissingTodayAndNoRecentWeight() {
        let action = resolve(
            hour: 14,
            foodEntries: [foodEntry(mealType: .breakfast), foodEntry(mealType: .lunch)],
            proteinProgress: 0.9,
            waterProgress: 0.85,
            weightLoggedToday: false,
            hasRecentWeight: false
        )

        XCTAssertEqual(action.reason, .logWeight)
        XCTAssertEqual(action.primaryCTA, .logWeight)
    }

    func testSkipsLogWeightWhenRecentWeightExists() {
        let action = resolve(
            hour: 14,
            foodEntries: [foodEntry(mealType: .breakfast), foodEntry(mealType: .lunch)],
            proteinProgress: 0.9,
            waterProgress: 0.85,
            weightLoggedToday: false,
            hasRecentWeight: true,
            activityContext: connectedActivityContext
        )

        XCTAssertEqual(action.reason, .onTrack)
    }

    // MARK: - Priority 5: Apple Health

    func testConnectAppleHealthWhenGateShows() {
        let action = resolve(
            hour: 14,
            foodEntries: [foodEntry(mealType: .breakfast), foodEntry(mealType: .lunch)],
            proteinProgress: 0.9,
            waterProgress: 0.85,
            weightLoggedToday: true,
            hasRecentWeight: true,
            activityContext: TodayActivityContext(
                trainingIntegration: .notConnected,
                trainingDataSource: .appleHealth,
                appleHealthWorkoutCount: nil
            )
        )

        XCTAssertEqual(action.reason, .connectAppleHealth)
        XCTAssertEqual(action.primaryCTA, .openHealth)
    }

    // MARK: - Priority 6: Review today

    func testReviewTodayInEveningWhenMealsLogged() {
        let action = resolve(
            hour: 20,
            foodEntries: [foodEntry(mealType: .breakfast), foodEntry(mealType: .lunch)],
            proteinProgress: 0.9,
            waterProgress: 0.85,
            weightLoggedToday: true,
            hasRecentWeight: true,
            activityContext: connectedActivityContext,
            hasDailyReview: false
        )

        XCTAssertEqual(action.reason, .reviewToday)
        XCTAssertEqual(action.primaryCTA, .reviewToday)
    }

    func testSkipsReviewTodayWhenReviewExists() {
        let action = resolve(
            hour: 20,
            foodEntries: [foodEntry(mealType: .breakfast), foodEntry(mealType: .lunch)],
            proteinProgress: 0.9,
            waterProgress: 0.85,
            weightLoggedToday: true,
            hasRecentWeight: true,
            activityContext: connectedActivityContext,
            hasDailyReview: true
        )

        XCTAssertEqual(action.reason, .onTrack)
        XCTAssertEqual(action.primaryCTA, .none)
    }

    // MARK: - Priority 7: On track

    func testOnTrackWhenKeyGoalsComplete() {
        let action = resolve(
            hour: 14,
            foodEntries: [foodEntry(mealType: .breakfast), foodEntry(mealType: .lunch)],
            proteinProgress: 0.9,
            waterProgress: 0.85,
            weightLoggedToday: true,
            hasRecentWeight: true,
            activityContext: connectedActivityContext
        )

        XCTAssertEqual(action.reason, .onTrack)
        XCTAssertEqual(action.primaryCTA, .none)
        XCTAssertEqual(action.title, FormaProductCopy.Today.NextAction.onTrackTitle)
    }

    // MARK: - Meal window helpers

    func testMissedMealTypePrioritizesDinnerOverLunch() {
        XCTAssertEqual(
            NextBestActionEngine.missedMealType(foodEntries: [], hour: 22),
            .dinner
        )
    }

    func testHasLoggedMealMatchesMealType() {
        let entries = [foodEntry(mealType: .lunch)]
        XCTAssertTrue(NextBestActionEngine.hasLoggedMeal(.lunch, in: entries))
        XCTAssertFalse(NextBestActionEngine.hasLoggedMeal(.dinner, in: entries))
    }

    // MARK: - Helpers

    private var connectedActivityContext: TodayActivityContext {
        TodayActivityContext(
            trainingIntegration: .connected,
            trainingDataSource: .appleHealth,
            appleHealthWorkoutCount: 1
        )
    }

    private func resolve(
        hour: Int,
        foodEntries: [FoodEntry],
        proteinProgress: Double,
        waterProgress: Double,
        weightLoggedToday: Bool = false,
        hasRecentWeight: Bool = false,
        activityContext: TodayActivityContext = .default,
        hasDailyReview: Bool = false
    ) -> NextBestActionState {
        NextBestActionEngine.resolve(
            NextBestActionInput(
                date: TodayDashboardFixtures.date(hour: hour),
                calendar: calendar,
                foodEntries: foodEntries,
                proteinProgress: MacroProgress(
                    consumed: proteinProgress * 180,
                    target: 180,
                    remaining: 180 * (1 - proteinProgress),
                    progress: proteinProgress
                ),
                waterProgress: waterProgress,
                weightLoggedToday: weightLoggedToday,
                hasRecentWeight: hasRecentWeight,
                activityContext: activityContext,
                hasDailyReview: hasDailyReview
            )
        )
    }

    private func foodEntry(mealType: MealType) -> FoodEntry {
        FoodEntry(
            id: UUID(),
            dailyLogId: UUID(),
            mealType: mealType,
            name: "Test meal",
            quantity: 1,
            unit: "serving",
            calories: 300,
            protein: 25,
            carbs: 20,
            fat: 10,
            fiber: nil,
            sodium: nil,
            source: .manual,
            confidence: .high,
            imageUrl: nil,
            notes: nil,
            createdAt: TodayDashboardFixtures.date(hour: 8),
            updatedAt: TodayDashboardFixtures.date(hour: 8)
        )
    }
}
