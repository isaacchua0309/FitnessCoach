//
//  TodayQuickActionsTests.swift
//  Fitness CoachTests
//

import XCTest
@testable import Fitness_Coach

final class TodayQuickActionsTests: XCTestCase {

    func testScanFoodAlwaysPresentEvenWhenPipelineUnavailable() {
        let items = TodayQuickActionPolicy.menuItems(isScanFoodAvailable: false)

        XCTAssertEqual(items.first?.kind, .scanFood)
        XCTAssertFalse(items.first?.isEnabled == true)
        XCTAssertEqual(items.map(\.kind), [.scanFood, .logMeal, .addWater, .logWeight, .logWorkout])
    }

    func testScanFoodEnabledAndFirstWhenPipelineAvailable() {
        let items = TodayQuickActionPolicy.menuItems(isScanFoodAvailable: true)

        XCTAssertEqual(items.first?.kind, .scanFood)
        XCTAssertTrue(items.first?.isEnabled == true)
        XCTAssertTrue(TodayQuickActionPolicy.isVisible(.scanFood, isScanFoodAvailable: true))
    }

    func testLogMealIsPrimaryQuickAction() {
        let items = TodayQuickActionPolicy.menuItems(isScanFoodAvailable: true)

        let logMeal = items.first { $0.kind == .logMeal }

        XCTAssertEqual(logMeal?.presentation, .primary)
    }

    func testCoreActionsAlwaysVisibleRegardlessOfScanFood() {
        for scanAvailable in [true, false] {
            XCTAssertTrue(TodayQuickActionPolicy.isVisible(.logMeal, isScanFoodAvailable: scanAvailable))
            XCTAssertTrue(TodayQuickActionPolicy.isVisible(.addWater, isScanFoodAvailable: scanAvailable))
            XCTAssertTrue(TodayQuickActionPolicy.isVisible(.logWeight, isScanFoodAvailable: scanAvailable))
            XCTAssertTrue(TodayQuickActionPolicy.isVisible(.logWorkout, isScanFoodAvailable: scanAvailable))
            XCTAssertTrue(TodayQuickActionPolicy.isVisible(.scanFood, isScanFoodAvailable: scanAvailable))
        }
    }

    func testActionOrderPrioritizesHighFrequencyLogging() {
        let items = TodayQuickActionPolicy.menuItems(isScanFoodAvailable: true)

        XCTAssertEqual(
            items.map(\.kind),
            [.scanFood, .logMeal, .addWater, .logWeight, .logWorkout]
        )
    }

    func testQuickActionTitlesUseProductCopy() {
        XCTAssertEqual(
            FormaProductCopy.Today.QuickActions.title(for: .logMeal),
            "Log Meal"
        )
        XCTAssertEqual(
            FormaProductCopy.Today.QuickActions.title(for: .logWorkout),
            "Log Workout"
        )
        XCTAssertFalse(FormaProductCopy.Today.QuickActions.inlineAccessibilityHint(for: .logWorkout).isEmpty)
    }

    func testProductionMenuReflectsPipelineReadiness() {
        let productionItems = TodayQuickActionPolicy.menuItems()
        let scanItem = productionItems.first { $0.kind == .scanFood }

        XCTAssertNotNil(scanItem)
        XCTAssertEqual(scanItem?.isEnabled, TodayPhotoScanAvailability.isPipelineReady)
        XCTAssertTrue(productionItems.contains { $0.kind == .logMeal })
        XCTAssertTrue(productionItems.contains { $0.kind == .logWorkout })
    }
}
