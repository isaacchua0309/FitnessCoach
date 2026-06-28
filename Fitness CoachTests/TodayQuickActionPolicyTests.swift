//
//  TodayQuickActionPolicyTests.swift
//  Fitness CoachTests
//

import XCTest
@testable import Fitness_Coach

final class TodayQuickActionPolicyTests: XCTestCase {

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
}
