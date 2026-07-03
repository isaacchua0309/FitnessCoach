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

    func testConfigurationIncludesWaterPresets() {
        let configuration = TodayQuickActionPolicy.configuration(isScanFoodAvailable: true)

        XCTAssertEqual(
            configuration.waterPresetAmountsMl,
            TodayActionCoordinator.defaultWaterPresetAmountsMl
        )
    }

    func testPrimaryActionsAlwaysVisibleRegardlessOfScanFood() {
        for scanAvailable in [true, false] {
            XCTAssertTrue(TodayQuickActionPolicy.isVisible(.logMeal, isScanFoodAvailable: scanAvailable))
            XCTAssertTrue(TodayQuickActionPolicy.isVisible(.addWater, isScanFoodAvailable: scanAvailable))
        }
    }

    func testScanMealVisibleOnlyWhenPipelineReady() {
        XCTAssertTrue(TodayQuickActionPolicy.isVisible(.scanFood, isScanFoodAvailable: true))
        XCTAssertFalse(TodayQuickActionPolicy.isVisible(.scanFood, isScanFoodAvailable: false))
    }

    func testWeightAndWorkoutNotVisibleInQuickActions() {
        for scanAvailable in [true, false] {
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
            FormaProductCopy.Today.QuickActions.title(for: .addWater),
            "Water"
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

    func testProductionConfigurationReflectsPipelineReadiness() {
        let configuration = TodayQuickActionPolicy.configuration()

        XCTAssertEqual(configuration.showsScanMeal, TodayPhotoScanAvailability.isPipelineReady)
    }
}
