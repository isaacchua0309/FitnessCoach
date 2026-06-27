//
//  FoodEntryFormFormatterTests.swift
//  Fitness CoachTests
//

import XCTest
@testable import Fitness_Coach

final class FoodEntryFormFormatterTests: XCTestCase {

    func testDisplayFoodNameCapitalizesAllLowercaseInput() {
        XCTAssertEqual(FoodEntryFormFormatter.displayFoodName("chicken breast"), "Chicken breast")
    }

    func testDisplayFoodNamePreservesMixedCaseInput() {
        XCTAssertEqual(FoodEntryFormFormatter.displayFoodName("McSpicy"), "McSpicy")
    }

    func testDisplayMealTypeLabelOmitsUnknown() {
        XCTAssertNil(FoodEntryFormFormatter.displayMealTypeLabel(.unknown))
        XCTAssertNil(FoodEntryFormFormatter.displayMealTypeLabel(nil))
        XCTAssertEqual(FoodEntryFormFormatter.displayMealTypeLabel(.lunch), "Lunch")
    }

    func testTimelineMacroSummaryUsesCompactProteinOnlyFormat() {
        XCTAssertEqual(
            FoodEntryFormFormatter.timelineMacroSummary(protein: 31, carbs: 0, fat: 0),
            "31g protein"
        )
    }

    func testTimelineMacroSummaryUsesFullFormatWhenCarbsOrFatPresent() {
        XCTAssertEqual(
            FoodEntryFormFormatter.timelineMacroSummary(protein: 31, carbs: 0, fat: 3.6),
            "31g protein · 0g carbs · 3.6g fat"
        )
    }

    func testTimelineSubtitleOmitsUnknownMealType() {
        XCTAssertEqual(
            FoodEntryFormFormatter.timelineSubtitle(mealType: .unknown, protein: 31, carbs: 0, fat: 3.6),
            "31g protein · 0g carbs · 3.6g fat"
        )
    }

    func testTimelineSubtitleIncludesKnownMealType() {
        XCTAssertEqual(
            FoodEntryFormFormatter.timelineSubtitle(mealType: .lunch, protein: 31, carbs: 0, fat: 0),
            "Lunch · 31g protein"
        )
    }

    func testTimelineSubtitleReturnsNilWhenNoMealTypeOrMacros() {
        XCTAssertNil(
            FoodEntryFormFormatter.timelineSubtitle(mealType: .unknown, protein: 0, carbs: 0, fat: 0)
        )
    }
}
