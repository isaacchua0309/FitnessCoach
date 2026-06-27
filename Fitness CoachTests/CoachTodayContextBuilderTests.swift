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
        let log = DailyNutritionSummaryTestFixtures.baselineLog
        let (calorie, macro, water) = TodayDashboardNutritionMapper.maps(from: log)

        let state = CoachTodayContextBuilder.build(
            dailyLog: log,
            weightLogged: false,
            hasWorkout: false
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
        let log = DailyNutritionSummaryTestFixtures.baselineLog
        let (_, macro, water) = TodayDashboardNutritionMapper.maps(from: log)

        let state = CoachTodayContextBuilder.build(
            dailyLog: log,
            weightLogged: false,
            hasWorkout: false
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
        let log = DailyNutritionSummaryTestFixtures.baselineLog
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
            weightLogged: false,
            hasWorkout: false
        )

        XCTAssertEqual(state.caloriesLine, "0 eaten · \(emptyLog.targets.calorieTarget) target")
        XCTAssertEqual(state.proteinLine, "Protein 0 / \(Int(emptyLog.targets.proteinTarget)) g")
        XCTAssertEqual(
            state.waterLine,
            "Water 0 / \(emptyLog.targets.waterTargetMl) ml"
        )
        XCTAssertEqual(state.suggestedFocus, FormaProductCopy.Today.focusProteinLow)
    }
}
