//
//  FoodCompoundDishDetectorTests.swift
//  Fitness CoachTests
//

import XCTest
@testable import Fitness_Coach

final class FoodCompoundDishDetectorTests: XCTestCase {

    func testChickenRiceRequiresDecomposition() {
        let analysis = FoodCompoundDishDetector.analyze(prompt: "log chicken rice")
        XCTAssertTrue(FoodCompoundDishDetector.isKnownCompoundDish("log chicken rice"))
        XCTAssertGreaterThanOrEqual(analysis.minRequiredComponents, 3)
        XCTAssertTrue(analysis.requiresAssumptions)
    }

    func testCaiFanWithTwoDishesRequiresThreeComponents() {
        let analysis = FoodCompoundDishDetector.analyze(
            prompt: "log cai fan with sweet sour pork and broccoli"
        )
        XCTAssertEqual(analysis.minRequiredComponents, 3)
    }

    func testProteinShakeIsNotCompoundDish() {
        XCTAssertFalse(FoodCompoundDishDetector.isKnownCompoundDish("log protein shake"))
    }

    func testRiceBowlIsAmbiguousServing() {
        let analysis = FoodCompoundDishDetector.analyze(prompt: "rice bowl")
        XCTAssertTrue(analysis.isAmbiguousServing)
        XCTAssertTrue(analysis.requiresAssumptions)
    }

    func testSameAsBreakfastIsContextReference() {
        let analysis = FoodCompoundDishDetector.analyze(prompt: "same as breakfast")
        XCTAssertTrue(analysis.isContextReference)
        XCTAssertTrue(analysis.requiresAssumptions)
    }
}
