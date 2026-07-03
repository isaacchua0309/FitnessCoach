//
//  TodayNextActionFormattingTests.swift
//  Fitness CoachTests
//

import XCTest
@testable import Fitness_Coach

final class TodayNextActionFormattingTests: XCTestCase {

    func testDisplayModelUsesNextBestActionSectionTitle() {
        let action = proteinAction()
        let display = TodayNextActionFormatting.displayModel(for: action)

        XCTAssertEqual(display.sectionTitle, "Next Best Action")
        XCTAssertEqual(display.headline, FormaProductCopy.Today.NextAction.eatProteinTitle)
        XCTAssertEqual(display.subtitle, FormaProductCopy.Today.NextAction.eatProteinSubtitle)
        XCTAssertEqual(display.primaryButtonTitle, "Scan food")
        XCTAssertEqual(display.secondaryButtonTitle, "Log meal")
        XCTAssertTrue(display.showsPrimaryButton)
        XCTAssertTrue(display.showsSecondaryButton)
    }

    func testLogBreakfastDisplayAndCTA() {
        let action = NextBestActionState(
            title: FormaProductCopy.Today.NextAction.logBreakfastTitle,
            subtitle: FormaProductCopy.Today.NextAction.logBreakfastSubtitle,
            reason: .logBreakfast,
            primaryCTA: .logMeal(TodayCoachPrompt.logMeal(.breakfast)),
            secondaryCTAs: []
        )
        let display = TodayNextActionFormatting.displayModel(for: action)

        XCTAssertEqual(display.headline, "Log breakfast to start today.")
        XCTAssertEqual(display.primaryButtonTitle, "Log breakfast")
    }

    func testWaterDisplayAndCTA() {
        let action = NextBestActionState(
            title: FormaProductCopy.Today.NextAction.hydrationBehindTitle,
            subtitle: FormaProductCopy.Today.NextAction.hydrationBehindSubtitle,
            reason: .addWater,
            primaryCTA: .addWater(amountMl: 500),
            secondaryCTAs: []
        )
        let display = TodayNextActionFormatting.displayModel(for: action)

        XCTAssertEqual(display.headline, "Hydration is behind.")
        XCTAssertEqual(display.primaryButtonTitle, "Add water")
    }

    func testAllTargetsMetHidesPrimaryButton() {
        let action = NextBestActionState(
            title: FormaProductCopy.Today.NextAction.allTargetsMetTitle,
            subtitle: FormaProductCopy.Today.NextAction.allTargetsMetSubtitle,
            reason: .allTargetsMet,
            primaryCTA: .none,
            secondaryCTAs: []
        )
        let display = TodayNextActionFormatting.displayModel(for: action)

        XCTAssertFalse(display.showsPrimaryButton)
        XCTAssertNil(display.primaryButtonTitle)
    }

    func testAccessibilityLabelIncludesHeadlineSubtitleAndButtons() {
        let action = proteinAction()
        let display = TodayNextActionFormatting.displayModel(for: action)

        XCTAssertTrue(display.accessibilityLabel.contains("Next Best Action"))
        XCTAssertTrue(display.accessibilityLabel.contains(FormaProductCopy.Today.NextAction.eatProteinTitle))
        XCTAssertTrue(display.accessibilityLabel.contains("Scan food button"))
        XCTAssertTrue(display.accessibilityLabel.contains("Log meal button"))
    }

    func testRouteMapsAddWaterToNativeLog() {
        XCTAssertEqual(
            TodayNextActionFormatting.route(for: .addWater(amountMl: 500)),
            .logWater(amountMl: 500)
        )
    }

    func testRouteMapsLogMealToCoachMealLoggingWithMealType() {
        XCTAssertEqual(
            TodayNextActionFormatting.route(for: .logMeal(TodayCoachPrompt.logMeal(.lunch))),
            .openCoach(.logMeal(mealType: .lunch))
        )
    }

    func testRouteMapsLogWorkoutToTrainingInsights() {
        XCTAssertEqual(
            TodayNextActionFormatting.route(for: .logWorkout),
            .openTrainingInsights
        )
    }

    func testRouteMapsScanFoodToCoach() {
        XCTAssertEqual(
            TodayNextActionFormatting.route(for: .scanFood),
            .openCoach(.scanFood)
        )
    }

    func testRouteMapsLogWeightToNativeSheet() {
        XCTAssertEqual(
            TodayNextActionFormatting.route(for: .logWeight),
            .presentLogWeight
        )
    }

    func testMealTypeParsesFromCoachPrefill() {
        XCTAssertEqual(
            TodayNextActionFormatting.mealType(from: TodayCoachPrompt.logMeal(.dinner)),
            .dinner
        )
        XCTAssertNil(TodayNextActionFormatting.mealType(from: TodayCoachPrompt.scanFood))
    }

    private func proteinAction() -> NextBestActionState {
        NextBestActionState(
            title: FormaProductCopy.Today.NextAction.eatProteinTitle,
            subtitle: FormaProductCopy.Today.NextAction.eatProteinSubtitle,
            reason: .eatProtein,
            primaryCTA: .scanFood,
            secondaryCTAs: [.logMeal(TodayCoachPrompt.logMeal())]
        )
    }
}
