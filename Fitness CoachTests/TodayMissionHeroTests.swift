//
//  TodayMissionHeroTests.swift
//  Fitness CoachTests
//

import XCTest
@testable import Fitness_Coach

final class TodayMissionHeroTests: XCTestCase {

    func testNewDayState() {
        let model = displayModel(
            consumed: 0,
            target: 1_800,
            remaining: 1_800,
            proteinConsumed: 0,
            proteinTarget: 170,
            waterConsumedMl: 0,
            waterTargetMl: 3_150,
            waterRemainingMl: 3_150,
            mealsEmptyKind: .newDayNoMeals
        )

        XCTAssertEqual(model.primaryKind, .remaining)
        XCTAssertEqual(model.primaryValue, "1,800 remaining")
        XCTAssertEqual(model.statusLine, FormaProductCopy.Today.Mission.statusEmptyDay)
        XCTAssertEqual(model.goalLine, "Goal: 1,800 kcal")
        XCTAssertEqual(model.consumedLine, "Consumed: 0 kcal")
        XCTAssertEqual(model.proteinRemainingLine, "Protein remaining: 170g")
        XCTAssertEqual(model.waterRemainingLine, "Water remaining: 3150 ml")
        XCTAssertTrue(model.showsLogMealCTA)
    }

    func testMealLoggedState() {
        let model = displayModel(
            consumed: 710,
            target: 1_800,
            remaining: 1_090,
            proteinConsumed: 79,
            proteinTarget: 170,
            waterConsumedMl: 500,
            waterTargetMl: 3_150,
            waterRemainingMl: 2_650,
            mealsEmptyKind: .hasMeals
        )

        XCTAssertEqual(model.primaryKind, .remaining)
        XCTAssertEqual(model.primaryValue, "1,090 remaining")
        XCTAssertEqual(model.goalLine, "Goal: 1,800 kcal")
        XCTAssertEqual(model.consumedLine, "Consumed: 710 kcal")
        XCTAssertEqual(model.proteinRemainingLine, "Protein remaining: 91g")
        XCTAssertEqual(model.waterRemainingLine, "Water remaining: 2650 ml")
        XCTAssertTrue(model.statusLine.isEmpty)
        XCTAssertFalse(model.showsLogMealCTA)
    }

    func testOverTargetState() {
        let model = displayModel(
            consumed: 2_050,
            target: 1_800,
            remaining: 0,
            progress: 1.14,
            isOverTarget: true,
            proteinConsumed: 120,
            proteinTarget: 170,
            waterConsumedMl: 2_000,
            waterTargetMl: 3_150,
            waterRemainingMl: 1_150,
            mealsEmptyKind: .hasMeals
        )

        XCTAssertEqual(model.primaryKind, .over)
        XCTAssertEqual(model.primaryValue, "250 over")
        XCTAssertEqual(model.statusLine, FormaProductCopy.Today.Mission.statusOverTarget)
        XCTAssertFalse(model.showsLogMealCTA)
    }

    func testTargetReachedState() {
        let model = displayModel(
            consumed: 1_720,
            target: 1_800,
            remaining: 80,
            progress: 0.96,
            proteinConsumed: 165,
            proteinTarget: 170,
            waterConsumedMl: 3_200,
            waterTargetMl: 3_150,
            waterRemainingMl: 0,
            mealsEmptyKind: .hasMeals
        )

        XCTAssertEqual(model.primaryKind, .targetReached)
        XCTAssertEqual(model.primaryValue, FormaProductCopy.Today.Mission.targetReachedPrimary)
        XCTAssertEqual(model.statusLine, FormaProductCopy.Today.Mission.statusTargetReached)
        XCTAssertEqual(model.proteinRemainingLine, FormaProductCopy.Today.Mission.proteinOnTrack)
        XCTAssertEqual(model.waterRemainingLine, FormaProductCopy.Today.Mission.waterOnTrack)
    }

    func testMissingCalorieTargetFallback() {
        let model = displayModel(
            consumed: 500,
            target: 0,
            remaining: 0,
            proteinConsumed: 40,
            proteinTarget: 0,
            waterConsumedMl: 0,
            waterTargetMl: 0,
            waterRemainingMl: 0,
            mealsEmptyKind: .hasMeals
        )

        XCTAssertEqual(model.primaryKind, .missingTarget)
        XCTAssertEqual(model.primaryValue, FormaProductCopy.Today.Mission.missingCalorieTarget)
        XCTAssertEqual(model.goalLine, FormaProductCopy.Today.Mission.missingCalorieTarget)
        XCTAssertEqual(model.consumedLine, "Consumed: 500 kcal")
        XCTAssertTrue(model.waterRemainingLine.isEmpty)
    }

    func testNextStepLineIsFormatted() {
        let model = displayModel(
            consumed: 0,
            target: 1_800,
            remaining: 1_800,
            proteinConsumed: 0,
            proteinTarget: 170,
            waterConsumedMl: 0,
            waterTargetMl: 3_150,
            waterRemainingMl: 3_150,
            mealsEmptyKind: .newDayNoMeals,
            nextStepLine: "Log breakfast to start today."
        )

        XCTAssertEqual(model.nextStepLine, "Next: Log breakfast to start today.")
    }

    func testAccessibilityLabelIncludesMissionSummary() {
        let model = displayModel(
            consumed: 500,
            target: 1_800,
            remaining: 1_300,
            proteinConsumed: 40,
            proteinTarget: 170,
            waterConsumedMl: 500,
            waterTargetMl: 3_150,
            waterRemainingMl: 2_650,
            mealsEmptyKind: .hasMeals
        )

        XCTAssertTrue(model.accessibilityLabel.contains(FormaProductCopy.Today.Mission.sectionTitle))
        XCTAssertTrue(model.accessibilityLabel.contains("remaining"))
        XCTAssertTrue(model.accessibilityLabel.contains("Goal:"))
        XCTAssertTrue(model.accessibilityLabel.contains("Consumed:"))
        XCTAssertTrue(model.accessibilityLabel.contains("Protein remaining:"))
        XCTAssertTrue(model.accessibilityLabel.contains("Water remaining:"))
    }

    // MARK: - Helpers

    private func displayModel(
        consumed: Int,
        target: Int,
        remaining: Int,
        progress: Double? = nil,
        isOverTarget: Bool = false,
        proteinConsumed: Double,
        proteinTarget: Double,
        waterConsumedMl: Int,
        waterTargetMl: Int,
        waterRemainingMl: Int,
        mealsEmptyKind: TodayMealsEmptyKind,
        nextStepLine: String = ""
    ) -> TodayMissionHeroDisplayModel {
        let proteinRemaining = max(proteinTarget - proteinConsumed, 0)
        let proteinProgress = proteinTarget > 0 ? proteinConsumed / proteinTarget : 0
        let waterProgress = waterTargetMl > 0 ? Double(waterConsumedMl) / Double(waterTargetMl) : 0
        return TodayMissionHeroFormatter.displayModel(
            calorieSummary: CalorieSummary(
                consumed: consumed,
                target: target,
                remaining: remaining,
                progress: progress ?? (target > 0 ? Double(consumed) / Double(target) : 0),
                isOverTarget: isOverTarget
            ),
            proteinProgress: MacroProgress(
                consumed: proteinConsumed,
                target: proteinTarget,
                remaining: proteinRemaining,
                progress: proteinProgress
            ),
            waterSummary: WaterSummary(
                consumedMl: waterConsumedMl,
                targetMl: waterTargetMl,
                remainingMl: waterRemainingMl,
                progress: waterProgress
            ),
            mealsEmptyKind: mealsEmptyKind,
            nextStepLine: nextStepLine
        )
    }
}
