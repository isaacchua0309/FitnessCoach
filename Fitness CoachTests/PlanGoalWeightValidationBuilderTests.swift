//
//  PlanGoalWeightValidationBuilderTests.swift
//  Fitness CoachTests
//
//  Forma — Goal weight validation for Edit Plan.
//

import XCTest
@testable import Fitness_Coach

final class PlanGoalWeightValidationBuilderTests: XCTestCase {

    func testFatLossRequiresLowerGoalWeight() {
        let message = PlanGoalWeightValidationBuilder.validate(
            goalWeightText: "80",
            currentWeightKg: 75,
            heightCm: 170,
            goalType: .loseFat
        )

        XCTAssertNotNil(message)
        XCTAssertTrue(message?.contains("below") == true)
    }

    func testGainRequiresHigherGoalWeight() {
        let message = PlanGoalWeightValidationBuilder.validate(
            goalWeightText: "70",
            currentWeightKg: 75,
            heightCm: 170,
            goalType: .gainMuscle
        )

        XCTAssertNotNil(message)
        XCTAssertTrue(message?.contains("above") == true)
    }

    func testMaintainRequiresMatchingGoalWeight() {
        let message = PlanGoalWeightValidationBuilder.validate(
            goalWeightText: "80",
            currentWeightKg: 75,
            heightCm: 170,
            goalType: .maintain
        )

        XCTAssertNotNil(message)
        XCTAssertTrue(message?.contains("near") == true)
    }

    func testValidFatLossGoalReturnsNil() {
        let message = PlanGoalWeightValidationBuilder.validate(
            goalWeightText: "70",
            currentWeightKg: 80,
            heightCm: 170,
            goalType: .loseFat
        )

        XCTAssertNil(message)
    }
}
