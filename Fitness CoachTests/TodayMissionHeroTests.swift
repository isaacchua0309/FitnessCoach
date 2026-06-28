//
//  TodayMissionHeroTests.swift
//  Fitness CoachTests
//

import XCTest
@testable import Fitness_Coach

final class TodayMissionHeroTests: XCTestCase {

    func testNewProfileNoMealsShowsPlanReadyStatusAndLogCTA() {
        let model = displayModel(
            consumed: 0,
            target: 2_230,
            remaining: 2_230,
            proteinConsumed: 0,
            proteinTarget: 170,
            mealsEmptyKind: .newProfileNoMeals
        )

        XCTAssertEqual(model.statusLine, FormaProductCopy.Today.EmptyState.newProfileMissionStatus)
        XCTAssertEqual(model.primaryMetricValue, "2,230 remaining")
        XCTAssertTrue(model.showsLogMealCTA)
    }

    func testReturningUserNewDayShowsFreshTargetsStatus() {
        let model = displayModel(
            consumed: 0,
            target: 2_230,
            remaining: 2_230,
            proteinConsumed: 0,
            proteinTarget: 170,
            mealsEmptyKind: .newDayNoMeals
        )

        XCTAssertEqual(model.statusLine, FormaProductCopy.Today.EmptyState.newDayMissionStatus)
        XCTAssertTrue(model.showsLogMealCTA)
    }

    func testUnderTargetShowsOnTrackStatus() {
        let model = displayModel(
            consumed: 380,
            target: 2_230,
            remaining: 1_850,
            proteinConsumed: 160,
            proteinTarget: 170,
            mealsEmptyKind: .hasMeals
        )

        XCTAssertEqual(model.statusLine, FormaProductCopy.Today.Mission.statusOnTrack)
        XCTAssertEqual(model.primaryMetricValue, "1,850 remaining")
        XCTAssertFalse(model.showsLogMealCTA)
    }

    func testNearTargetShowsNearTargetStatus() {
        let model = displayModel(
            consumed: 2_050,
            target: 2_230,
            remaining: 180,
            proteinConsumed: 160,
            proteinTarget: 170,
            mealsEmptyKind: .hasMeals
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
            mealsEmptyKind: .hasMeals
        )

        XCTAssertTrue(model.isOverTarget)
        XCTAssertEqual(model.primaryMetricLabel, FormaProductCopy.Today.Mission.caloriesOverLabel)
        XCTAssertEqual(model.primaryMetricValue, "170 \(FormaProductCopy.Today.Mission.overSuffix)")
        XCTAssertEqual(model.statusLine, FormaProductCopy.Today.Mission.statusOverTarget)
    }

    func testAccessibilityLabelIncludesMissionSummary() {
        let model = displayModel(
            consumed: 500,
            target: 2_230,
            remaining: 1_730,
            proteinConsumed: 40,
            proteinTarget: 170,
            mealsEmptyKind: .hasMeals
        )

        XCTAssertTrue(model.accessibilityLabel.contains(FormaProductCopy.Today.Mission.sectionTitle))
        XCTAssertTrue(model.accessibilityLabel.contains("remaining"))
        XCTAssertTrue(model.accessibilityLabel.contains("Goal:"))
    }

    func testProteinLowShowsProteinGapStatus() {
        let model = displayModel(
            consumed: 900,
            target: 2_230,
            remaining: 1_330,
            proteinConsumed: 40,
            proteinTarget: 170,
            mealsEmptyKind: .hasMeals
        )

        XCTAssertEqual(model.statusLine, FormaProductCopy.Today.Mission.statusProteinGap)
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
        mealsEmptyKind: TodayMealsEmptyKind
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
            mealsEmptyKind: mealsEmptyKind
        )
    }
}
