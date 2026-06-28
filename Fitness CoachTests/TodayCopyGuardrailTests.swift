//
//  TodayCopyGuardrailTests.swift
//  Fitness CoachTests
//
//  Forma — Today tab copy must not imply Dynamic Calories or forbidden manual fields.
//

import XCTest
@testable import Fitness_Coach

final class TodayCopyGuardrailTests: XCTestCase {

    func testTodayCopyAvoidsDynamicCaloriesLanguage() {
        for sample in todayCopySamples() {
            XCTAssertNil(
                PlanCopySafetyPolicy.forbiddenViolation(in: sample),
                "Forbidden Today copy in: \(sample)"
            )
        }
    }

    func testTodayCopyAvoidsManualBodyCompositionFields() {
        let forbidden = ["body fat", "bodyfat", "enter your age", "log steps", "gym session"]
        for sample in todayCopySamples() {
            let lowered = sample.lowercased()
            for term in forbidden where lowered.contains(term) {
                XCTFail("Today copy mentions forbidden manual field \"\(term)\": \(sample)")
            }
        }
    }

    private func todayCopySamples() -> [String] {
        var samples: [String] = [
            FormaProductCopy.Today.caloriesRemaining,
            FormaProductCopy.Today.caloriesAboveTarget,
            FormaProductCopy.Today.defaultCoachNote,
            FormaProductCopy.Today.focusProteinLow,
            FormaProductCopy.Today.focusWaterLow,
            FormaProductCopy.Today.focusOnTrack,
            FormaProductCopy.Today.Mission.statusOverTarget,
            FormaProductCopy.Today.Mission.statusOnTrack,
            FormaProductCopy.Today.CoachTip.overTarget,
            FormaProductCopy.Today.CoachTip.allGoalsMet,
            FormaProductCopy.Today.CoachTip.morningNoBreakfast,
            FormaProductCopy.Today.CoachTip.eveningSimpleDinner,
            FormaProductCopy.Today.CoachTip.lunchProteinGap(caloriesRemaining: "1,200", proteinGrams: 35),
            FormaProductCopy.Today.EmptyState.newProfileMissionStatus,
            FormaProductCopy.Today.EmptyState.newDayMissionStatus,
            FormaProductCopy.Today.EmptyState.loadErrorLocalBody,
            FormaProductCopy.Today.EmptyState.refreshErrorLocalBody,
            FormaProductCopy.Today.Activity.disconnectedMessage,
            FormaProductCopy.Today.DailySummary.explanationDetail,
            TodayPreviewData.partialDay.aiCoachTip.message
        ]

        let overTarget = TodayPreviewData.overTargetDay
        samples.append(
            TodayEmptyStateFormatting.missionStatusLine(
                mealsEmptyKind: overTarget.emptyContext.mealsEmptyKind,
                calorieSummary: overTarget.mission.calorieSummary,
                proteinProgress: overTarget.macroBalance.macroSummary.protein
            )
        )

        return samples
    }
}
