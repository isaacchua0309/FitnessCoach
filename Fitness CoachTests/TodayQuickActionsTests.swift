//
//  TodayQuickActionsTests.swift
//  Fitness CoachTests
//

import XCTest
@testable import Fitness_Coach

final class TodayQuickActionsTests: XCTestCase {

    func testConfigurationShowsScanMealOnlyWhenPipelineReady() {
        let available = TodayQuickActionPolicy.configuration(isScanFoodAvailable: true)
        let unavailable = TodayQuickActionPolicy.configuration(isScanFoodAvailable: false)

        XCTAssertTrue(available.showsScanMeal)
        XCTAssertFalse(unavailable.showsScanMeal)
    }

    func testLogMealAlwaysVisibleRegardlessOfScanFood() {
        for scanAvailable in [true, false] {
            XCTAssertTrue(TodayQuickActionPolicy.isVisible(.logMeal, isScanFoodAvailable: scanAvailable))
        }
    }

    func testScanMealVisibleOnlyWhenPipelineReady() {
        XCTAssertTrue(TodayQuickActionPolicy.isVisible(.scanFood, isScanFoodAvailable: true))
        XCTAssertFalse(TodayQuickActionPolicy.isVisible(.scanFood, isScanFoodAvailable: false))
    }

    func testWaterWeightAndWorkoutNotVisibleInQuickActions() {
        for scanAvailable in [true, false] {
            XCTAssertFalse(TodayQuickActionPolicy.isVisible(.addWater, isScanFoodAvailable: scanAvailable))
            XCTAssertFalse(TodayQuickActionPolicy.isVisible(.logWeight, isScanFoodAvailable: scanAvailable))
            XCTAssertFalse(TodayQuickActionPolicy.isVisible(.logWorkout, isScanFoodAvailable: scanAvailable))
        }
    }

    func testQuickActionTitlesUseProductCopy() {
        XCTAssertEqual(
            FormaProductCopy.Today.QuickActions.title(for: .logMeal),
            "Log Meal"
        )
        XCTAssertEqual(
            FormaProductCopy.Today.QuickActions.title(for: .scanFood),
            "Scan Meal"
        )
        XCTAssertEqual(
            FormaProductCopy.Today.QuickActions.sectionTitle,
            "Fast log"
        )
    }

    func testWaterQuickAddLabelsUseProductCopy() {
        XCTAssertEqual(FormaProductCopy.Today.Water.quickAddLabel(250), "+250 ml")
        XCTAssertEqual(FormaProductCopy.Today.Water.quickAddLabel(1_000), "+1 L")
        XCTAssertEqual(FormaProductCopy.Today.Water.addedMessage(amountMl: 500), "Added 500 ml")
        XCTAssertEqual(FormaProductCopy.Today.Water.addedMessage(amountMl: 1_000), "Added 1 L")
        XCTAssertEqual(
            FormaProductCopy.Today.Water.logFailedMessage,
            "Couldn't add water. Try again."
        )
    }

    func testLogMealMicrocopyPointsToCoach() {
        XCTAssertEqual(
            FormaProductCopy.Today.QuickActions.logMealMicrocopy,
            "Coach will estimate it from a photo, voice note, or text."
        )
        XCTAssertEqual(
            FormaProductCopy.Today.NextAction.logBreakfastSubtitle,
            "Send a photo, speak, or describe your meal."
        )
        XCTAssertEqual(
            FormaProductCopy.Today.mealsLogMealAccessibilityHint,
            "Opens Coach to log a meal"
        )
    }

    func testFoodFormTitlesReflectFallbackEditingRoles() {
        XCTAssertEqual(FormaProductCopy.FoodForm.editNutritionTitle, "Edit nutrition")
        XCTAssertEqual(FormaProductCopy.FoodForm.createCustomFoodTitle, "Create custom food")
        XCTAssertEqual(FormaProductCopy.Today.Meals.editSheetTitle, "Edit nutrition")
    }

    func testProductionConfigurationReflectsPipelineReadiness() {
        let configuration = TodayQuickActionPolicy.configuration()

        XCTAssertEqual(configuration.showsScanMeal, TodayPhotoScanAvailability.isPipelineReady)
    }
}
