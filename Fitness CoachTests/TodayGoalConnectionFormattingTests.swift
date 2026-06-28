//
//  TodayGoalConnectionFormattingTests.swift
//  Fitness CoachTests
//

import XCTest
@testable import Fitness_Coach

final class TodayGoalConnectionFormattingTests: XCTestCase {

    func testLoseWeightUsesDistanceCopy() {
        let model = TodayGoalConnectionFormatting.displayModel(
            for: TodayGoalConnectionInput(
                latestWeightKg: nil,
                profileWeightKg: 87.4,
                goalWeightKg: 75
            )
        )

        XCTAssertEqual(model?.message, "12.4kg to your goal.")
        XCTAssertEqual(model?.destination, .journey)
        XCTAssertTrue(model?.accessibilityLabel.contains("12.4kg to your goal.") ?? false)
    }

    func testGainWeightUsesDistanceCopy() {
        let model = TodayGoalConnectionFormatting.displayModel(
            for: TodayGoalConnectionInput(
                latestWeightKg: 70,
                profileWeightKg: 70,
                goalWeightKg: 82
            )
        )

        XCTAssertEqual(model?.message, "12kg to your goal.")
        XCTAssertEqual(model?.destination, .journey)
    }

    func testMaintainGoalUsesWeeklyProgressCopy() {
        let model = TodayGoalConnectionFormatting.displayModel(
            for: TodayGoalConnectionInput(
                latestWeightKg: 75,
                profileWeightKg: 75,
                goalWeightKg: 75
            )
        )

        XCTAssertEqual(
            model?.message,
            FormaProductCopy.Today.GoalConnection.maintainProgress
        )
        XCTAssertEqual(model?.destination, .journey)
    }

    func testMissingGoalReturnsNil() {
        let model = TodayGoalConnectionFormatting.displayModel(
            for: TodayGoalConnectionInput(
                latestWeightKg: 80,
                profileWeightKg: 80,
                goalWeightKg: nil
            )
        )

        XCTAssertNil(model)
    }

    func testLatestWeightOverridesProfileWeight() {
        let resolved = TodayGoalConnectionFormatting.resolvedCurrentWeight(
            latestWeightKg: 87.4,
            profileWeightKg: 80
        )

        XCTAssertEqual(resolved, 87.4)

        let model = TodayGoalConnectionFormatting.displayModel(
            for: TodayGoalConnectionInput(
                latestWeightKg: 87.4,
                profileWeightKg: 80,
                goalWeightKg: 75
            )
        )

        XCTAssertEqual(model?.message, "12.4kg to your goal.")
    }

    func testNearGoalUsesCloserCopy() {
        let model = TodayGoalConnectionFormatting.displayModel(
            for: TodayGoalConnectionInput(
                latestWeightKg: 74.2,
                profileWeightKg: 74.2,
                goalWeightKg: 75
            )
        )

        XCTAssertEqual(model?.message, "Today's effort moves you closer to 75kg.")
    }

    func testMissingCurrentAndProfileWeightReturnsNil() {
        let model = TodayGoalConnectionFormatting.displayModel(
            for: TodayGoalConnectionInput(
                latestWeightKg: nil,
                profileWeightKg: nil,
                goalWeightKg: 75
            )
        )

        XCTAssertNil(model)
    }

    func testStateBuilderUsesLatestWeightForMissionGoalProgress() {
        let state = TodayMissionControlStateBuilder.build(
            from: TodayMissionControlInputs(
                date: Date(),
                calorieSummary: CalorieSummary(
                    consumed: 500,
                    target: 1_800,
                    remaining: 1_300,
                    progress: 0.28,
                    isOverTarget: false
                ),
                macroSummary: MacroSummary(
                    protein: MacroProgress(consumed: 31, target: 180, remaining: 149, progress: 0.17),
                    carbs: MacroProgress(consumed: 0, target: 160, remaining: 160, progress: 0),
                    fat: MacroProgress(consumed: 0, target: 60, remaining: 60, progress: 0)
                ),
                waterSummary: WaterSummary(
                    consumedMl: 500,
                    targetMl: 3_150,
                    remainingMl: 2_650,
                    progress: 0.16
                ),
                weightSummary: TodayWeightSummary(
                    weightKg: 87.4,
                    displayText: "87.40 kg"
                ),
                weightLoggedToday: true,
                hasRecentWeight: true,
                workoutSummary: TodayWorkoutSummary(
                    workoutCaloriesBurned: 0,
                    workoutCount: 0,
                    hasWorkout: false
                ),
                foodEntries: [],
                streaks: StreakSummary(
                    loggingStreak: 0,
                    proteinStreak: 0,
                    hydrationStreak: 0,
                    workoutStreak: 0
                ),
                weekLoggedDays: 0,
                dailyBrief: TodayDailyBrief(
                    greeting: "Good morning.",
                    priorities: [],
                    recommendation: "Stay consistent today."
                ),
                dailyReview: nil,
                goalWeightKg: 75,
                profileWeightKg: 80,
                latestWeightKg: 87.4,
                userName: nil,
                activityContext: .default,
                stepGoalAssumption: nil,
                trainingFrequencyPerWeek: nil
            )
        )

        XCTAssertEqual(state.mission.goalProgress?.currentWeightKg, 87.4)
        XCTAssertEqual(state.mission.goalProgress?.kgToGo, 12.4, accuracy: 0.001)
        XCTAssertEqual(state.goalConnection?.message, "12.4kg to your goal.")
    }
}
