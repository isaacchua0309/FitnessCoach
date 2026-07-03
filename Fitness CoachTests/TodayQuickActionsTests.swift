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
    }

    func testProductionConfigurationReflectsPipelineReadiness() {
        let configuration = TodayQuickActionPolicy.configuration()

        XCTAssertEqual(configuration.showsScanMeal, TodayPhotoScanAvailability.isPipelineReady)
    }
}
