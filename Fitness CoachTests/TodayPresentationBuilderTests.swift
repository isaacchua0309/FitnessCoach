//
//  TodayPresentationBuilderTests.swift
//  Fitness CoachTests
//

import XCTest
@testable import Fitness_Coach

final class TodayPresentationBuilderTests: XCTestCase {

    func testBrandNewUserMissionAndMealsPhases() {
        let state = build(
            foodEntries: [],
            hasPriorFoodLogs: false
        )

        XCTAssertEqual(state.mission.phase, .brandNewUser)
        XCTAssertEqual(state.meals.phase, .brandNewUser)
        XCTAssertFalse(state.smartCoach.isVisible)
        XCTAssertEqual(state.smartCoach.context, .hidden)
        XCTAssertEqual(state.victory.kind, .startEncouragement)
        XCTAssertEqual(state.victory.message, FormaProductCopy.Today.Victory.startEncouragement)
    }

    func testReturningUserNoMealsToday() {
        let state = build(
            foodEntries: [],
            hasPriorFoodLogs: true
        )

        XCTAssertEqual(state.mission.phase, .noMealsLogged)
        XCTAssertEqual(state.meals.phase, .noMealsToday)
        XCTAssertFalse(state.smartCoach.isVisible)
    }

    func testSomeMealsLoggedBuildsMealsState() {
        let state = build(
            foodEntries: TodayPreviewData.foodEntries,
            hasPriorFoodLogs: true,
            calorieConsumed: 710,
            calorieRemaining: 1_090,
            calorieProgress: 0.39
        )

        XCTAssertEqual(state.meals.phase, .hasMeals)
        XCTAssertEqual(state.meals.entryCount, TodayPreviewData.foodEntries.count)
        XCTAssertEqual(state.mission.phase, .inProgress)
        XCTAssertFalse(state.meals.isEmpty)
    }

    func testCalorieTargetMetShowsVictory() {
        let state = build(
            foodEntries: TodayPreviewData.foodEntries,
            hasPriorFoodLogs: true,
            calorieConsumed: 1_720,
            calorieTarget: 1_800,
            calorieRemaining: 80,
            calorieProgress: 0.96,
            proteinConsumed: 165,
            proteinTarget: 170,
            waterConsumedMl: 3_200,
            waterTargetMl: 3_500
        )

        XCTAssertEqual(state.mission.phase, .targetMet)
        XCTAssertTrue(state.victory.isVisible)
        XCTAssertEqual(state.victory.kind, .caloriesOnTarget)
        XCTAssertEqual(state.victory.message, FormaProductCopy.Today.Victory.caloriesOnTarget)
    }

    func testCalorieTargetExceededMissionAndSmartCoach() {
        let state = build(
            foodEntries: TodayPreviewData.foodEntries,
            hasPriorFoodLogs: true,
            calorieConsumed: 2_100,
            calorieTarget: 1_800,
            calorieRemaining: 0,
            calorieProgress: 1.17,
            isOverTarget: true
        )

        XCTAssertEqual(state.mission.phase, .overTarget)
        XCTAssertEqual(state.mission.status, .overBudget)
        XCTAssertTrue(state.smartCoach.isVisible)
        XCTAssertEqual(state.smartCoach.context, .caloriesExceeded)
        XCTAssertEqual(state.victory.kind, .showedUp)
    }

    func testProteinBehindMacroHydrationAndSmartCoach() {
        let state = build(
            foodEntries: TodayPreviewData.foodEntries,
            hasPriorFoodLogs: true,
            proteinConsumed: 40,
            proteinTarget: 170,
            waterConsumedMl: 3_000,
            waterTargetMl: 3_500
        )

        XCTAssertEqual(state.macroHydration.focus, .proteinBehind)
        XCTAssertNil(state.macroHydration.guidanceLine)
        XCTAssertTrue(state.smartCoach.isVisible)
        XCTAssertEqual(state.smartCoach.context, .proteinBehind)
    }

    func testWaterBehindMacroHydrationFocus() {
        let state = build(
            foodEntries: TodayPreviewData.foodEntries,
            hasPriorFoodLogs: true,
            proteinConsumed: 160,
            proteinTarget: 170,
            waterConsumedMl: 500,
            waterTargetMl: 3_500
        )

        XCTAssertEqual(state.macroHydration.focus, .waterBehind)
        XCTAssertNil(state.macroHydration.guidanceLine)
        XCTAssertTrue(state.smartCoach.isVisible)
        XCTAssertEqual(state.smartCoach.context, .waterBehind)
    }

    func testWorkoutCompletedActivityPhase() {
        let state = build(
            foodEntries: TodayPreviewData.foodEntries,
            hasPriorFoodLogs: true,
            hasWorkout: true,
            appleHealthWorkoutCount: 1,
            activityContext: TodayActivityContext(
                trainingIntegration: .connected,
                trainingDataSource: .appleHealth,
                appleHealthWorkoutCount: 1,
                stepsToday: 8_000
            )
        )

        XCTAssertEqual(state.activity.phase, .workoutCompleted)
        XCTAssertTrue(state.activity.hasWorkout)
    }

    func testAppleHealthUnavailableActivityPhase() {
        let state = build(
            foodEntries: [],
            hasPriorFoodLogs: true,
            activityContext: TodayActivityContext(
                trainingIntegration: .unavailable,
                trainingDataSource: .unavailable,
                appleHealthWorkoutCount: nil,
                stepsToday: nil
            )
        )

        XCTAssertEqual(state.activity.phase, .healthUnavailable)
        XCTAssertTrue(state.activity.showsConnectCTA == false)
    }

    func testEndOfDayWrapUpVisibleInEveningWithMeals() {
        let evening = TodayDashboardFixtures.date(hour: 20)
        let state = build(
            date: evening,
            foodEntries: TodayPreviewData.foodEntries,
            hasPriorFoodLogs: true
        )

        XCTAssertTrue(state.endOfDay.isVisible)
        XCTAssertEqual(state.endOfDay.sectionTitle, FormaProductCopy.Today.EndOfDay.sectionTitle)
        XCTAssertEqual(state.endOfDay.journeyActionTitle, FormaProductCopy.Today.EndOfDay.seeJourneyAction)
        XCTAssertFalse(state.endOfDay.rows.isEmpty)
    }

    func testEndOfDayWrapUpHiddenDuringMorning() {
        let morning = TodayDashboardFixtures.date(hour: 9)
        let state = build(
            date: morning,
            foodEntries: TodayPreviewData.foodEntries,
            hasPriorFoodLogs: true
        )

        XCTAssertFalse(state.endOfDay.isVisible)
    }

    func testQuickActionsBuiltFromPolicy() {
        let state = build(foodEntries: [], hasPriorFoodLogs: false)

        XCTAssertFalse(state.quickActions.items.isEmpty)
        XCTAssertEqual(state.quickActions.sectionTitle, FormaProductCopy.Today.QuickActions.sectionTitle)
        XCTAssertTrue(state.quickActions.items.contains { $0.kind == .logMeal })
    }

    // MARK: - Fixtures

    private func build(
        date: Date = TodayDashboardFixtures.date(hour: 14),
        foodEntries: [FoodEntry],
        hasPriorFoodLogs: Bool,
        calorieConsumed: Int = 500,
        calorieTarget: Int = 1_800,
        calorieRemaining: Int = 1_300,
        calorieProgress: Double = 0.28,
        isOverTarget: Bool = false,
        proteinConsumed: Double = 79,
        proteinTarget: Double = 170,
        waterConsumedMl: Int = 1_200,
        waterTargetMl: Int = 3_500,
        hasWorkout: Bool = false,
        appleHealthWorkoutCount: Int? = nil,
        activityContext: TodayActivityContext = .default
    ) -> TodayDashboardState {
        let proteinRemaining = max(proteinTarget - proteinConsumed, 0)
        let waterRemaining = max(waterTargetMl - waterConsumedMl, 0)

        return TodayPresentationBuilder.dashboard(
            from: TodayMissionControlInputs(
                date: date,
                calorieSummary: CalorieSummary(
                    consumed: calorieConsumed,
                    target: calorieTarget,
                    remaining: calorieRemaining,
                    progress: calorieProgress,
                    isOverTarget: isOverTarget
                ),
                macroSummary: MacroSummary(
                    protein: MacroProgress(
                        consumed: proteinConsumed,
                        target: proteinTarget,
                        remaining: proteinRemaining,
                        progress: proteinTarget > 0 ? proteinConsumed / proteinTarget : 0
                    ),
                    carbs: MacroProgress(consumed: 0, target: 160, remaining: 160, progress: 0),
                    fat: MacroProgress(consumed: 0, target: 60, remaining: 60, progress: 0)
                ),
                waterSummary: WaterSummary(
                    consumedMl: waterConsumedMl,
                    targetMl: waterTargetMl,
                    remainingMl: waterRemaining,
                    progress: waterTargetMl > 0 ? Double(waterConsumedMl) / Double(waterTargetMl) : 0
                ),
                weightSummary: TodayWeightSummary(
                    weightKg: nil,
                    displayText: "Not logged today"
                ),
                weightLoggedToday: false,
                hasRecentWeight: true,
                workoutSummary: TodayWorkoutSummary(
                    workoutCaloriesBurned: hasWorkout ? 250 : 0,
                    workoutCount: hasWorkout ? 1 : 0,
                    hasWorkout: hasWorkout
                ),
                foodEntries: foodEntries,
                hasPriorFoodLogs: hasPriorFoodLogs,
                dailyReview: nil,
                goalWeightKg: 75,
                profileWeightKg: 80,
                latestWeightKg: nil,
                activityContext: activityContext,
                stepGoalAssumption: 7_500,
                trainingFrequencyPerWeek: 0
            )
        )
    }
}
