//
//  NextBestActionBuilderTests.swift
//  Fitness CoachTests
//

import XCTest
@testable import Fitness_Coach

final class NextBestActionBuilderTests: XCTestCase {

    private var calendar: Calendar { Calendar.current }

    // MARK: - Priority 1: Log breakfast

    func testLogBreakfastBeforeLunchWithNoMeals() {
        let action = resolve(
            hour: 9,
            foodEntries: [],
            proteinProgress: 0,
            waterProgress: 0
        )

        XCTAssertEqual(action.reason, .logBreakfast)
        XCTAssertEqual(action.primaryCTA, .logMeal(TodayCoachPrompt.logMeal(.breakfast)))
        XCTAssertTrue(action.secondaryCTAs.isEmpty)
        XCTAssertEqual(action.title, FormaProductCopy.Today.NextAction.logBreakfastTitle)
    }

    // MARK: - Priority 2: Log first meal

    func testLogFirstMealAfterLunchWithNoMeals() {
        let action = resolve(
            hour: 14,
            foodEntries: [],
            proteinProgress: 0,
            waterProgress: 0
        )

        XCTAssertEqual(action.reason, .logFirstMeal)
        XCTAssertEqual(action.primaryCTA, .logMeal(TodayCoachPrompt.logMeal()))
        XCTAssertEqual(action.title, FormaProductCopy.Today.NextAction.logFirstMealTitle)
    }

    // MARK: - Priority 3: Protein behind

    func testEatProteinWhenProteinBehind() {
        let action = resolve(
            hour: 14,
            foodEntries: [foodEntry(mealType: .breakfast)],
            proteinProgress: 0.4,
            waterProgress: 0.9
        )

        XCTAssertEqual(action.reason, .eatProtein)
        XCTAssertEqual(action.primaryCTA, .scanFood)
        XCTAssertEqual(action.secondaryCTAs, [.logMeal(TodayCoachPrompt.logMeal())])
        XCTAssertEqual(action.title, FormaProductCopy.Today.NextAction.eatProteinTitle)
    }

    // MARK: - Priority 4: Water behind

    func testAddWaterWhenHydrationBehind() {
        let action = resolve(
            hour: 14,
            foodEntries: [foodEntry(mealType: .breakfast), foodEntry(mealType: .lunch)],
            proteinProgress: 0.9,
            waterProgress: 0.5
        )

        XCTAssertEqual(action.reason, .addWater)
        XCTAssertEqual(action.primaryCTA, .addWater(amountMl: 500))
        XCTAssertEqual(action.title, FormaProductCopy.Today.NextAction.hydrationBehindTitle)
    }

    // MARK: - Priority 5: Workout incomplete

    func testCompleteWorkoutOnLikelyTrainingDay() {
        let monday = mondayDate(hour: 14)
        let action = resolve(
            date: monday,
            foodEntries: [foodEntry(mealType: .breakfast), foodEntry(mealType: .lunch)],
            proteinProgress: 0.9,
            waterProgress: 0.85,
            hasWorkout: false,
            trainingFrequencyPerWeek: 3
        )

        XCTAssertEqual(action.reason, .completeWorkout)
        XCTAssertEqual(action.primaryCTA, .logWorkout)
        XCTAssertEqual(action.title, FormaProductCopy.Today.NextAction.completeWorkoutTitle)
    }

    func testSkipsWorkoutActionWhenWorkoutLogged() {
        let monday = mondayDate(hour: 14)
        let action = resolve(
            date: monday,
            foodEntries: [foodEntry(mealType: .breakfast), foodEntry(mealType: .lunch)],
            proteinProgress: 0.9,
            waterProgress: 0.85,
            hasWorkout: true,
            trainingFrequencyPerWeek: 3,
            calorieSummary: nearTargetCalories
        )

        XCTAssertEqual(action.reason, .keepDinnerLight)
    }

    // MARK: - Priority 6: Calories close to limit

    func testKeepDinnerLightWhenCaloriesNearTarget() {
        let action = resolve(
            hour: 18,
            foodEntries: [foodEntry(mealType: .breakfast), foodEntry(mealType: .lunch)],
            proteinProgress: 0.9,
            waterProgress: 0.85,
            calorieSummary: nearTargetCalories
        )

        XCTAssertEqual(action.reason, .keepDinnerLight)
        XCTAssertEqual(action.primaryCTA, .logMeal(TodayCoachPrompt.logMeal(.dinner)))
        XCTAssertEqual(action.title, FormaProductCopy.Today.NextAction.keepDinnerLightTitle)
    }

    // MARK: - Priority 7: Calories exceeded

    func testFocusHydrationRecoveryWhenOverTarget() {
        let action = resolve(
            hour: 20,
            foodEntries: [foodEntry(mealType: .breakfast), foodEntry(mealType: .lunch)],
            proteinProgress: 0.95,
            waterProgress: 0.9,
            calorieSummary: overTargetCalories
        )

        XCTAssertEqual(action.reason, .focusHydrationRecovery)
        XCTAssertEqual(action.primaryCTA, .addWater(amountMl: 500))
        XCTAssertEqual(action.title, FormaProductCopy.Today.NextAction.focusHydrationRecoveryTitle)
    }

    // MARK: - Priority 8: All targets met

    func testAllTargetsMetWhenNoHigherPriorityApplies() {
        let action = resolve(
            hour: 14,
            foodEntries: [foodEntry(mealType: .breakfast), foodEntry(mealType: .lunch)],
            proteinProgress: 0.95,
            waterProgress: 0.9,
            trainingFrequencyPerWeek: 0,
            calorieSummary: inProgressCalories
        )

        XCTAssertEqual(action.reason, TodayNextBestActionReason.allTargetsMet)
        XCTAssertEqual(action.primaryCTA, TodayNextBestActionCTA.none)
        XCTAssertEqual(action.title, FormaProductCopy.Today.NextAction.allTargetsMetTitle)
    }

    // MARK: - Priority ordering

    func testProteinBeatsWaterWhenBothBehind() {
        let action = resolve(
            hour: 14,
            foodEntries: [foodEntry(mealType: .breakfast)],
            proteinProgress: 0.4,
            waterProgress: 0.2
        )

        XCTAssertEqual(action.reason, .eatProtein)
    }

    func testMealLoggingBeatsProteinWhenNoMealsLogged() {
        let action = resolve(
            hour: 10,
            foodEntries: [],
            proteinProgress: 0,
            waterProgress: 0
        )

        XCTAssertEqual(action.reason, .logBreakfast)
    }

    func testIsLikelyTrainingDayUsesWeekdayHeuristic() {
        XCTAssertTrue(
            NextBestActionEngine.isLikelyTrainingDay(
                frequency: 3,
                date: mondayDate(hour: 10),
                calendar: calendar
            )
        )
        XCTAssertFalse(
            NextBestActionEngine.isLikelyTrainingDay(
                frequency: 3,
                date: TodayDashboardFixtures.date(hour: 10),
                calendar: calendar
            )
        )
    }

    // MARK: - Helpers

    private var nearTargetCalories: CalorieSummary {
        CalorieSummary(
            consumed: 1_620,
            target: 1_800,
            remaining: 180,
            progress: 0.9,
            isOverTarget: false
        )
    }

    private var overTargetCalories: CalorieSummary {
        CalorieSummary(
            consumed: 2_050,
            target: 1_800,
            remaining: 0,
            progress: 1.14,
            isOverTarget: true
        )
    }

    private var inProgressCalories: CalorieSummary {
        CalorieSummary(
            consumed: 900,
            target: 1_800,
            remaining: 900,
            progress: 0.5,
            isOverTarget: false
        )
    }

    private func mondayDate(hour: Int) -> Date {
        var components = DateComponents()
        components.year = 2026
        components.month = 6
        components.day = 29
        components.hour = hour
        return calendar.date(from: components) ?? TodayDashboardFixtures.date(hour: hour)
    }

    private func resolve(
        hour: Int,
        foodEntries: [FoodEntry],
        proteinProgress: Double,
        waterProgress: Double,
        hasWorkout: Bool = false,
        trainingFrequencyPerWeek: Int = 0,
        calorieSummary: CalorieSummary? = nil
    ) -> NextBestActionState {
        resolve(
            date: TodayDashboardFixtures.date(hour: hour),
            foodEntries: foodEntries,
            proteinProgress: proteinProgress,
            waterProgress: waterProgress,
            hasWorkout: hasWorkout,
            trainingFrequencyPerWeek: trainingFrequencyPerWeek,
            calorieSummary: calorieSummary
        )
    }

    private func resolve(
        date: Date,
        foodEntries: [FoodEntry],
        proteinProgress: Double,
        waterProgress: Double,
        hasWorkout: Bool = false,
        trainingFrequencyPerWeek: Int = 0,
        calorieSummary: CalorieSummary? = nil
    ) -> NextBestActionState {
        let calories = calorieSummary ?? inProgressCalories
        return NextBestActionEngine.resolve(
            NextBestActionInput(
                date: date,
                calendar: calendar,
                foodEntries: foodEntries,
                proteinProgress: MacroProgress(
                    consumed: proteinProgress * 180,
                    target: 180,
                    remaining: 180 * (1 - proteinProgress),
                    progress: proteinProgress
                ),
                waterProgress: waterProgress,
                calorieSummary: calories,
                workoutSummary: TodayWorkoutSummary(
                    workoutCaloriesBurned: hasWorkout ? 250 : 0,
                    workoutCount: hasWorkout ? 1 : 0,
                    hasWorkout: hasWorkout
                ),
                activityContext: .default,
                trainingFrequencyPerWeek: trainingFrequencyPerWeek
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
