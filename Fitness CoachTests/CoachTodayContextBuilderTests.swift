//
//  CoachTodayContextBuilderTests.swift
//  Fitness CoachTests
//
//  Forma — Coach today context uses shared nutrition mapping and Today focus.
//

import XCTest
@testable import Fitness_Coach

final class CoachTodayContextBuilderTests: XCTestCase {

    func testBuildUsesTodayDashboardNutritionMapper() {
        let log = DailyLogFixtures.baselineLog
        let (calorie, macro, water) = TodayDashboardNutritionMapper.maps(from: log)

        let state = CoachTodayContextBuilder.build(
            dailyLog: log,
            latestFoodEntry: nil,
            weightLogged: false,
            hasWorkout: false,
            steps: nil,
            healthActivityNote: nil
        )

        XCTAssertEqual(
            state.caloriesLine,
            CoachTodayContextBuilder.caloriesLine(from: calorie)
        )
        XCTAssertEqual(
            state.proteinLine,
            CoachTodayContextBuilder.proteinLine(
                consumed: macro.protein.consumed,
                target: macro.protein.target
            )
        )
        XCTAssertEqual(
            state.waterLine,
            CoachTodayContextBuilder.waterLine(
                consumedMl: water.consumedMl,
                targetMl: water.targetMl
            )
        )
    }

    func testSuggestedFocusMatchesTodayFocusBuilder() {
        let log = DailyLogFixtures.baselineLog
        let (_, macro, water) = TodayDashboardNutritionMapper.maps(from: log)

        let state = CoachTodayContextBuilder.build(
            dailyLog: log,
            latestFoodEntry: nil,
            weightLogged: false,
            hasWorkout: false,
            steps: nil,
            healthActivityNote: nil
        )

        let expected = TodayFocusBuilder.focus(
            proteinProgress: macro.protein.progress,
            waterProgress: water.progress,
            weightLogged: false,
            hasWorkout: false
        )

        XCTAssertEqual(state.suggestedFocus, expected)
    }

    func testEmptyDayFormatsEatenAndTargets() {
        let log = DailyLogFixtures.baselineLog
        var emptyLog = log
        emptyLog.totals = MacroTotals(
            calories: 0,
            protein: 0,
            carbs: 0,
            fat: 0,
            fiber: nil,
            sodium: nil
        )
        emptyLog.waterConsumedMl = 0

        let state = CoachTodayContextBuilder.build(
            dailyLog: emptyLog,
            latestFoodEntry: nil,
            weightLogged: false,
            hasWorkout: false,
            steps: nil,
            healthActivityNote: nil
        )

        XCTAssertEqual(state.caloriesLine, "0 eaten · \(emptyLog.targets.calorieTarget) target")
        XCTAssertEqual(state.proteinLine, "Protein 0 / \(Int(emptyLog.targets.proteinTarget)) g")
        XCTAssertEqual(
            state.waterLine,
            "Water 0 / \(emptyLog.targets.waterTargetMl) ml"
        )
        XCTAssertEqual(state.suggestedFocus, FormaProductCopy.Today.focusProteinLow)
        XCTAssertTrue(state.activityLines.contains(FormaProductCopy.Today.Activity.stepsUnavailable))
    }

    func testActivityLinesIncludeLatestMealStepsAndWorkout() {
        let log = DailyLogFixtures.baselineLog
        let entry = CoachMutationTestFixtures.chickenFoodEntry

        let state = CoachTodayContextBuilder.build(
            dailyLog: log,
            latestFoodEntry: entry,
            weightLogged: false,
            hasWorkout: true,
            steps: 8_420,
            healthActivityNote: nil
        )

        XCTAssertTrue(
            state.activityLines.contains(
                FormaProductCopy.Coach.latestMealLine(name: "Chicken breast", calories: 330)
            )
        )
        XCTAssertTrue(state.activityLines.contains(FormaProductCopy.Today.Activity.stepsToday(8_420)))
        XCTAssertTrue(state.activityLines.contains(FormaProductCopy.Today.Activity.workoutCompletedLine))
        XCTAssertNil(state.activityHintLine)
    }

    func testHealthUnavailableUsesHintInsteadOfStepsUnavailableLine() {
        let log = DailyLogFixtures.baselineLog

        let state = CoachTodayContextBuilder.build(
            dailyLog: log,
            latestFoodEntry: nil,
            weightLogged: false,
            hasWorkout: false,
            steps: nil,
            healthActivityNote: FormaProductCopy.Today.Activity.healthUnavailableNote
        )

        XCTAssertFalse(state.activityLines.contains(FormaProductCopy.Today.Activity.stepsUnavailable))
        XCTAssertEqual(state.activityHintLine, FormaProductCopy.Today.Activity.healthUnavailableNote)
    }

    func testHealthActivityNoteForDisconnectedAppleHealth() {
        XCTAssertEqual(
            CoachTodayContextBuilder.healthActivityNote(
                trainingDataSource: .appleHealth,
                trainingIntegration: .notConnected
            ),
            FormaProductCopy.Today.Activity.healthConnectNote
        )
        XCTAssertEqual(
            CoachTodayContextBuilder.healthActivityNote(
                trainingDataSource: .unavailable,
                trainingIntegration: .connected
            ),
            FormaProductCopy.Today.Activity.healthUnavailableNote
        )
    }
}
