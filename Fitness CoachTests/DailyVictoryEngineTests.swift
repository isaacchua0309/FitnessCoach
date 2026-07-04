//
//  DailyVictoryEngineTests.swift
//  Fitness CoachTests
//

import XCTest
@testable import Fitness_Coach

final class DailyVictoryEngineTests: XCTestCase {

    func testNoActionFallbackShowsStartEncouragement() {
        let victory = resolve(
            foodEntries: [],
            proteinConsumed: 0,
            waterConsumedMl: 0,
            calorieConsumed: 0,
            hasWorkout: false
        )

        XCTAssertEqual(victory.kind, .startEncouragement)
        XCTAssertEqual(victory.message, FormaProductCopy.Today.Victory.startEncouragement)
        XCTAssertTrue(victory.isVisible)
    }

    func testMealVictoryShowsFirstMealLogged() {
        let victory = resolve(
            foodEntries: [TodayPreviewData.foodEntries[0]],
            proteinConsumed: 40,
            waterConsumedMl: 0,
            calorieConsumed: 320,
            hasWorkout: false
        )

        XCTAssertEqual(victory.kind, .firstMeal)
        XCTAssertEqual(victory.message, FormaProductCopy.Today.Victory.firstMeal)
    }

    func testProteinVictoryShowsTargetReached() {
        let victory = resolve(
            foodEntries: TodayPreviewData.foodEntries,
            proteinConsumed: 170,
            proteinTarget: 170,
            waterConsumedMl: 1_200,
            calorieConsumed: 1_200,
            hasWorkout: false
        )

        XCTAssertEqual(victory.kind, .proteinTarget)
        XCTAssertEqual(victory.message, FormaProductCopy.Today.Victory.proteinTarget)
    }

    func testWaterVictoryShowsTargetReached() {
        let victory = resolve(
            foodEntries: TodayPreviewData.foodEntries,
            proteinConsumed: 120,
            waterConsumedMl: 3_500,
            waterTargetMl: 3_500,
            calorieConsumed: 1_200,
            hasWorkout: false
        )

        XCTAssertEqual(victory.kind, .waterTarget)
        XCTAssertEqual(victory.message, FormaProductCopy.Today.Victory.waterTarget)
    }

    func testWorkoutVictoryShowsCompleted() {
        let victory = resolve(
            foodEntries: TodayPreviewData.foodEntries,
            proteinConsumed: 120,
            waterConsumedMl: 1_200,
            calorieConsumed: 1_200,
            hasWorkout: true,
            appleHealthWorkoutCount: 1
        )

        XCTAssertEqual(victory.kind, .workoutCompleted)
        XCTAssertEqual(victory.message, FormaProductCopy.Today.Victory.workoutCompleted)
    }

    func testCaloriesVictoryShowsOnTarget() {
        let victory = resolve(
            foodEntries: TodayPreviewData.foodEntries,
            proteinConsumed: 120,
            waterConsumedMl: 1_200,
            calorieConsumed: 1_720,
            calorieTarget: 1_800,
            calorieRemaining: 80,
            calorieProgress: 0.96,
            hasWorkout: false
        )

        XCTAssertEqual(victory.kind, .caloriesOnTarget)
        XCTAssertEqual(victory.message, FormaProductCopy.Today.Victory.caloriesOnTarget)
    }

    func testMeaningfulActionWithoutSpecificWinShowsShowedUp() {
        let victory = resolve(
            foodEntries: TodayPreviewData.foodEntries,
            proteinConsumed: 79,
            waterConsumedMl: 1_200,
            calorieConsumed: 710,
            hasWorkout: false
        )

        XCTAssertEqual(victory.kind, .showedUp)
        XCTAssertEqual(victory.message, FormaProductCopy.Today.Victory.showedUp)
    }

    func testCaloriesVictoryTakesPriorityOverWorkout() {
        let victory = resolve(
            foodEntries: TodayPreviewData.foodEntries,
            proteinConsumed: 120,
            waterConsumedMl: 1_200,
            calorieConsumed: 1_720,
            calorieTarget: 1_800,
            calorieRemaining: 80,
            calorieProgress: 0.96,
            hasWorkout: true,
            appleHealthWorkoutCount: 1
        )

        XCTAssertEqual(victory.kind, .caloriesOnTarget)
    }

    // MARK: - Fixtures

    private func resolve(
        foodEntries: [FoodEntry],
        proteinConsumed: Double,
        proteinTarget: Double = 170,
        waterConsumedMl: Int,
        waterTargetMl: Int = 3_500,
        calorieConsumed: Int,
        calorieTarget: Int = 1_800,
        calorieRemaining: Int? = nil,
        calorieProgress: Double? = nil,
        hasWorkout: Bool,
        appleHealthWorkoutCount: Int? = nil,
        weightLoggedToday: Bool = false
    ) -> TodayVictoryState {
        let proteinRemaining = max(proteinTarget - proteinConsumed, 0)
        let waterRemaining = max(waterTargetMl - waterConsumedMl, 0)
        let remaining = calorieRemaining ?? max(calorieTarget - calorieConsumed, 0)
        let progress = calorieProgress ?? (calorieTarget > 0 ? Double(calorieConsumed) / Double(calorieTarget) : 0)

        return DailyVictoryEngine.resolve(
            DailyVictoryInput(
                foodEntries: foodEntries,
                proteinProgress: MacroProgress(
                    consumed: proteinConsumed,
                    target: proteinTarget,
                    remaining: proteinRemaining,
                    progress: proteinTarget > 0 ? proteinConsumed / proteinTarget : 0
                ),
                waterSummary: WaterSummary(
                    consumedMl: waterConsumedMl,
                    targetMl: waterTargetMl,
                    remainingMl: waterRemaining,
                    progress: waterTargetMl > 0 ? Double(waterConsumedMl) / Double(waterTargetMl) : 0
                ),
                calorieSummary: CalorieSummary(
                    consumed: calorieConsumed,
                    target: calorieTarget,
                    remaining: remaining,
                    progress: progress,
                    isOverTarget: calorieConsumed > calorieTarget
                ),
                workoutSummary: TodayWorkoutSummary(
                    workoutCaloriesBurned: hasWorkout ? 250 : 0,
                    workoutCount: hasWorkout ? 1 : 0,
                    hasWorkout: hasWorkout
                ),
                activityContext: TodayActivityContext(
                    trainingIntegration: .connected,
                    trainingDataSource: .appleHealth,
                    appleHealthWorkoutCount: appleHealthWorkoutCount,
                    stepsToday: nil
                ),
                weightLoggedToday: weightLoggedToday
            )
        )
    }
}
