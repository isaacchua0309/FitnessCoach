//
//  TodayNextActionFormattingTests.swift
//  Fitness CoachTests
//

import XCTest
@testable import Fitness_Coach

final class TodayNextActionFormattingTests: XCTestCase {

    func testDisplayModelUsesNextBestActionSectionTitle() {
        let action = proteinAction(remainingGrams: 35)
        let display = TodayNextActionFormatting.displayModel(for: action)

        XCTAssertEqual(display.sectionTitle, "Next Best Action")
        XCTAssertEqual(display.headline, "Eat 35g protein in your next meal.")
        XCTAssertEqual(display.subtitle, FormaProductCopy.Today.NextAction.eatProteinSubtitle)
        XCTAssertEqual(display.primaryButtonTitle, "Plan meal")
        XCTAssertTrue(display.showsPrimaryButton)
    }

    func testMissedLunchDisplayAndCTA() {
        let action = NextBestActionState(
            title: FormaProductCopy.Today.NextAction.logMissedMealTitle(.lunch),
            subtitle: FormaProductCopy.Today.NextAction.logMissedMealSubtitle(.lunch),
            reason: .logMissedMeal(.lunch),
            primaryCTA: .logMeal(TodayCoachPrompt.logMeal(.lunch)),
            secondaryCTAs: []
        )
        let display = TodayNextActionFormatting.displayModel(for: action)

        XCTAssertEqual(display.headline, "Log lunch to keep today accurate.")
        XCTAssertEqual(display.primaryButtonTitle, "Log lunch")
    }

    func testWaterDisplayAndCTA() {
        let action = NextBestActionState(
            title: FormaProductCopy.Today.NextAction.drinkWaterTitle(amountMl: 500),
            subtitle: FormaProductCopy.Today.NextAction.addWaterSubtitle,
            reason: .addWater,
            primaryCTA: .addWater(amountMl: 500),
            secondaryCTAs: []
        )
        let display = TodayNextActionFormatting.displayModel(for: action)

        XCTAssertEqual(display.headline, "Drink 500ml water.")
        XCTAssertEqual(display.primaryButtonTitle, "Add water")
    }

    func testOnTrackHidesPrimaryButton() {
        let action = NextBestActionState(
            title: FormaProductCopy.Today.NextAction.onTrackTitle,
            subtitle: FormaProductCopy.Today.NextAction.onTrackSubtitle,
            reason: .onTrack,
            primaryCTA: .none,
            secondaryCTAs: []
        )
        let display = TodayNextActionFormatting.displayModel(for: action)

        XCTAssertFalse(display.showsPrimaryButton)
        XCTAssertNil(display.primaryButtonTitle)
    }

    func testAccessibilityLabelIncludesHeadlineSubtitleAndButton() {
        let action = proteinAction(remainingGrams: 35)
        let display = TodayNextActionFormatting.displayModel(for: action)

        XCTAssertTrue(display.accessibilityLabel.contains("Next Best Action"))
        XCTAssertTrue(display.accessibilityLabel.contains("Eat 35g protein in your next meal."))
        XCTAssertTrue(display.accessibilityLabel.contains("Plan meal button"))
    }

    func testRouteMapsAddWaterToNativeLog() {
        XCTAssertEqual(
            TodayNextActionFormatting.route(for: .addWater(amountMl: 500)),
            .logWater(amountMl: 500)
        )
    }

    func testRouteMapsLogMealToNativeSheetWithMealType() {
        XCTAssertEqual(
            TodayNextActionFormatting.route(for: .logMeal(TodayCoachPrompt.logMeal(.lunch))),
            .presentLogMeal(mealType: .lunch)
        )
    }

    func testRouteMapsLogWeightToNativeSheet() {
        XCTAssertEqual(
            TodayNextActionFormatting.route(for: .logWeight),
            .presentLogWeight
        )
    }

    func testRouteMapsScanFoodToCoach() {
        XCTAssertEqual(
            TodayNextActionFormatting.route(for: .scanFood),
            .openCoach(TodayCoachPrompt.scanFood)
        )
    }

    func testRouteMapsReviewTodayToCoach() {
        XCTAssertEqual(
            TodayNextActionFormatting.route(for: .reviewToday),
            .openCoach(TodayCoachPrompt.reviewToday)
        )
    }

    func testRouteMapsOpenHealthToTrainingInsights() {
        XCTAssertEqual(
            TodayNextActionFormatting.route(for: .openHealth),
            .openTrainingInsights
        )
    }

    func testMealTypeParsesFromCoachPrefill() {
        XCTAssertEqual(
            TodayNextActionFormatting.mealType(from: TodayCoachPrompt.logMeal(.dinner)),
            .dinner
        )
        XCTAssertNil(TodayNextActionFormatting.mealType(from: TodayCoachPrompt.logProtein))
    }

    private func proteinAction(remainingGrams: Int) -> NextBestActionState {
        NextBestActionState(
            title: FormaProductCopy.Today.NextAction.eatProteinTitle(grams: remainingGrams),
            subtitle: FormaProductCopy.Today.NextAction.eatProteinSubtitle,
            reason: .eatProtein,
            primaryCTA: .logMeal(TodayCoachPrompt.logProtein),
            secondaryCTAs: []
        )
    }
}
