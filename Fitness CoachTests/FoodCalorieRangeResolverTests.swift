//
//  FoodCalorieRangeResolverTests.swift
//  Fitness CoachTests
//

import XCTest
@testable import Fitness_Coach

final class FoodCalorieRangeResolverTests: XCTestCase {

    func testUsesExplicitRangeWhenPresent() {
        let resolution = FoodCalorieRangeResolver.resolve(
            totalCalories: 520,
            confidence: .medium,
            lower: 450,
            upper: 750
        )

        XCTAssertEqual(resolution.lower, 450)
        XCTAssertEqual(resolution.upper, 750)
        XCTAssertEqual(resolution.source, .explicit)
        XCTAssertNil(resolution.warning)
    }

    func testDerivesRangeFromConfidenceWhenMissing() {
        let resolution = FoodCalorieRangeResolver.resolve(
            totalCalories: 300,
            confidence: .medium,
            lower: nil,
            upper: nil
        )

        XCTAssertEqual(resolution.lower, 232)
        XCTAssertEqual(resolution.upper, 368)
        XCTAssertEqual(resolution.source, .derivedFromConfidence)
    }

    func testHighConfidenceDerivedRangeUsesDocumentedMargin() {
        let resolution = FoodCalorieRangeResolver.resolve(
            totalCalories: 400,
            confidence: .high,
            lower: nil,
            upper: nil
        )

        XCTAssertEqual(resolution.lower, 350)
        XCTAssertEqual(resolution.upper, 450)
    }

    func testLowConfidenceDerivedRangeUsesWiderMargin() {
        let resolution = FoodCalorieRangeResolver.resolve(
            totalCalories: 400,
            confidence: .low,
            lower: nil,
            upper: nil
        )

        XCTAssertEqual(resolution.lower, 260)
        XCTAssertEqual(resolution.upper, 540)
    }

    func testRepairsReversedBounds() {
        let resolution = FoodCalorieRangeResolver.resolve(
            totalCalories: 500,
            confidence: .medium,
            lower: 700,
            upper: 400
        )

        XCTAssertEqual(resolution.lower, 400)
        XCTAssertEqual(resolution.upper, 700)
        XCTAssertEqual(resolution.source, .repaired)
        XCTAssertNotNil(resolution.warning)
    }

    func testRepairsRangeThatDoesNotBracketEstimate() {
        let resolution = FoodCalorieRangeResolver.resolve(
            totalCalories: 500,
            confidence: .medium,
            lower: 520,
            upper: 540
        )

        XCTAssertLessThanOrEqual(resolution.lower, 500)
        XCTAssertGreaterThanOrEqual(resolution.upper, 500)
        XCTAssertEqual(resolution.source, .repaired)
    }
}
