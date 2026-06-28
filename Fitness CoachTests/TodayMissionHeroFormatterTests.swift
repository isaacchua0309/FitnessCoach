//
//  TodayMissionHeroFormatterTests.swift
//  Fitness CoachTests
//

import XCTest
@testable import Fitness_Coach

final class TodayMissionHeroFormatterTests: XCTestCase {

    func testNoFoodLoggedShowsStartFirstMealStatus() {
        let model = displayModel(
            consumed: 0,
            target: 2_230,
            remaining: 2_230,
            proteinConsumed: 0,
            proteinTarget: 170,
            mealsEmpty: true
        )

        XCTAssertEqual(model.statusLine, FormaProductCopy.Today.Mission.statusStartFirstMeal)
        XCTAssertEqual(model.primaryMetricValue, "2,230 remaining")
        XCTAssertEqual(model.proteinLine, TodayMissionHeroFormatter.proteinRemainingLine(170))
    }

    func testUnderTargetShowsOnTrackStatus() {
        let model = displayModel(
            consumed: 380,
            target: 2_230,
            remaining: 1_850,
            proteinConsumed: 160,
            proteinTarget: 170,
            mealsEmpty: false
        )

        XCTAssertEqual(model.statusLine, FormaProductCopy.Today.Mission.statusOnTrack)
        XCTAssertEqual(model.primaryMetricValue, "1,850 remaining")
        XCTAssertEqual(model.goalLine, "Goal: 2,230 kcal")
        XCTAssertEqual(model.consumedLine, "Consumed: 380 kcal")
        XCTAssertEqual(model.proteinLine, FormaProductCopy.Today.Mission.proteinOnTrack)
        XCTAssertFalse(model.isOverTarget)
    }

    func testNearTargetShowsNearTargetStatus() {
        let model = displayModel(
            consumed: 2_050,
            target: 2_230,
            remaining: 180,
            proteinConsumed: 160,
            proteinTarget: 170,
            mealsEmpty: false
        )

        XCTAssertTrue(TodayMissionHeroFormatter.isNearTarget(
            CalorieSummary(
                consumed: 2_050,
                target: 2_230,
                remaining: 180,
                progress: Double(2_050) / Double(2_230),
                isOverTarget: false
            )
        ))
        XCTAssertEqual(model.statusLine, FormaProductCopy.Today.Mission.statusNearTarget)
        XCTAssertEqual(model.primaryMetricValue, "180 remaining")
    }

    func testOverTargetUsesNonShamingStatusAndOverMetric() {
        let model = displayModel(
            consumed: 2_400,
            target: 2_230,
            remaining: 0,
            progress: 1.08,
            isOverTarget: true,
            proteinConsumed: 120,
            proteinTarget: 170,
            mealsEmpty: false
        )

        XCTAssertTrue(model.isOverTarget)
        XCTAssertEqual(model.primaryMetricLabel, FormaProductCopy.Today.Mission.caloriesOverLabel)
        XCTAssertEqual(model.primaryMetricValue, "170 over")
        XCTAssertEqual(model.statusLine, FormaProductCopy.Today.Mission.statusOverTarget)
        XCTAssertTrue(model.accessibilityLabel.contains(FormaProductCopy.Today.Mission.statusOverTarget))
    }

    func testProteinLowShowsProteinGapStatus() {
        let model = displayModel(
            consumed: 900,
            target: 2_230,
            remaining: 1_330,
            proteinConsumed: 40,
            proteinTarget: 170,
            mealsEmpty: false
        )

        XCTAssertEqual(model.statusLine, FormaProductCopy.Today.Mission.statusProteinGap)
        XCTAssertEqual(model.proteinLine, TodayMissionHeroFormatter.proteinRemainingLine(130))
    }

    func testProteinCompleteShowsProteinOnTrackSubMetric() {
        let model = displayModel(
            consumed: 1_200,
            target: 2_230,
            remaining: 1_030,
            proteinConsumed: 165,
            proteinTarget: 170,
            mealsEmpty: false
        )

        XCTAssertEqual(model.proteinLine, FormaProductCopy.Today.Mission.proteinOnTrack)
        XCTAssertEqual(model.statusLine, FormaProductCopy.Today.Mission.statusOnTrack)
    }

    func testAccessibilityLabelSummarizesCaloriesAndProtein() {
        let model = displayModel(
            consumed: 380,
            target: 2_230,
            remaining: 1_850,
            proteinConsumed: 45,
            proteinTarget: 170,
            mealsEmpty: false
        )

        XCTAssertTrue(model.accessibilityLabel.contains(FormaProductCopy.Today.Mission.sectionTitle))
        XCTAssertTrue(model.accessibilityLabel.contains("1,850 remaining"))
        XCTAssertTrue(model.accessibilityLabel.contains("Goal: 2,230 kcal"))
        XCTAssertTrue(model.accessibilityLabel.contains("Consumed: 380 kcal"))
        XCTAssertTrue(model.accessibilityLabel.contains(TodayMissionHeroFormatter.proteinRemainingLine(125)))
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
        mealsEmpty: Bool
    ) -> TodayMissionHeroDisplayModel {
        let proteinRemaining = max(proteinTarget - proteinConsumed, 0)
        let proteinProgress = proteinTarget > 0 ? proteinConsumed / proteinTarget : 0
        let mission = TodayMissionState(
            status: isOverTarget ? .overBudget : .needsFocus,
            calorieSummary: CalorieSummary(
                consumed: consumed,
                target: target,
                remaining: remaining,
                progress: progress ?? (target > 0 ? Double(consumed) / Double(target) : 0),
                isOverTarget: isOverTarget
            ),
            weightSummary: TodayWeightSummary(weightKg: nil, displayText: "Not logged today"),
            goalProgress: nil,
            focusMessage: "",
            proteinRemainingGrams: proteinRemaining
        )
        return TodayMissionHeroFormatter.displayModel(
            mission: mission,
            proteinProgress: MacroProgress(
                consumed: proteinConsumed,
                target: proteinTarget,
                remaining: proteinRemaining,
                progress: proteinProgress
            ),
            mealsEmpty: mealsEmpty
        )
    }
}
