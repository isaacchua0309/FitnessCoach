//
//  TodayQuickActionsTests.swift
//  Fitness CoachTests
//

import XCTest
@testable import Fitness_Coach

final class TodayQuickActionsTests: XCTestCase {

    func testScanFoodHiddenWhenPipelineUnavailable() {
        let items = TodayQuickActionPolicy.menuItems(isScanFoodAvailable: false)

        XCTAssertFalse(items.contains { $0.kind == .scanFood })
        XCTAssertEqual(items.map(\.kind), [.manualEntry, .addWater, .logWeight, .askCoach])
    }

    func testScanFoodVisibleWhenPipelineAvailable() {
        let items = TodayQuickActionPolicy.menuItems(isScanFoodAvailable: true)

        XCTAssertEqual(items.first?.kind, .scanFood)
        XCTAssertTrue(items.first?.isEnabled == true)
        XCTAssertTrue(TodayQuickActionPolicy.isVisible(.scanFood, isScanFoodAvailable: true))
    }

    func testCoreActionsAlwaysVisibleRegardlessOfScanFood() {
        for scanAvailable in [true, false] {
            XCTAssertTrue(TodayQuickActionPolicy.isVisible(.manualEntry, isScanFoodAvailable: scanAvailable))
            XCTAssertTrue(TodayQuickActionPolicy.isVisible(.addWater, isScanFoodAvailable: scanAvailable))
            XCTAssertTrue(TodayQuickActionPolicy.isVisible(.logWeight, isScanFoodAvailable: scanAvailable))
            XCTAssertTrue(TodayQuickActionPolicy.isVisible(.askCoach, isScanFoodAvailable: scanAvailable))
        }
    }

    func testScanFoodNotVisibleWhenPipelineUnavailable() {
        XCTAssertFalse(TodayQuickActionPolicy.isVisible(.scanFood, isScanFoodAvailable: false))
    }

    func testScanFoodPipelineReadyWhenClientWired() {
        XCTAssertTrue(CoachMealPhotoPipeline.isClientPipelineReady)
        XCTAssertTrue(TodayPhotoScanAvailability.isPipelineReady)
    }

    func testQuickActionTitlesUseProductCopy() {
        XCTAssertEqual(
            FormaProductCopy.Today.QuickActions.title(for: .manualEntry),
            "Manual Entry"
        )
        XCTAssertEqual(
            FormaProductCopy.Today.QuickActions.title(for: .addWater),
            "Add Water"
        )
        XCTAssertFalse(FormaProductCopy.Today.QuickActions.inlineAccessibilityHint(for: .manualEntry).isEmpty)
    }

    func testProductionMenuReflectsPipelineReadiness() {
        let productionItems = TodayQuickActionPolicy.menuItems()
        let kinds = Set(productionItems.map(\.kind))

        if TodayPhotoScanAvailability.isPipelineReady {
            XCTAssertTrue(kinds.contains(.scanFood))
            XCTAssertTrue(kinds.contains(.manualEntry))
        } else {
            XCTAssertFalse(kinds.contains(.scanFood))
            XCTAssertEqual(productionItems.map(\.kind), [.manualEntry, .addWater, .logWeight, .askCoach])
        }
    }
}
