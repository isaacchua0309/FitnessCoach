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

    func testFatLossRejectsGoalEqualToCurrentWeight() {
        let message = PlanGoalWeightValidationBuilder.validate(
            goalWeightText: "75",
            currentWeightKg: 75,
            heightCm: 170,
            goalType: .loseFat
        )

        XCTAssertNotNil(message)
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
        XCTAssertTrue(message?.contains("close") == true)
    }

    func testMaintainAllowsGoalNearCurrentWeight() {
        let message = PlanGoalWeightValidationBuilder.validate(
            goalWeightText: "75.2",
            currentWeightKg: 75,
            heightCm: 170,
            goalType: .maintain
        )

        XCTAssertNil(message)
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

    func testRejectsInvalidCharacters() {
        let message = PlanGoalWeightValidationBuilder.validate(
            goalWeightText: "70abc",
            currentWeightKg: 80,
            heightCm: 170,
            goalType: .loseFat
        )

        XCTAssertEqual(
            message,
            FormaProductCopy.PlanEditTarget.validationInvalidNumber()
        )
    }

    func testRejectsEmptyGoalWeight() {
        let message = PlanGoalWeightValidationBuilder.validate(
            goalWeightText: "",
            currentWeightKg: 80,
            heightCm: 170,
            goalType: .loseFat
        )

        XCTAssertEqual(
            message,
            FormaProductCopy.PlanEditTarget.validationEnterGoalWeight()
        )
    }

    func testRejectsGoalBelowSafeMinimum() {
        let message = PlanGoalWeightValidationBuilder.validate(
            goalWeightText: "30",
            currentWeightKg: 80,
            heightCm: 170,
            goalType: .loseFat
        )

        XCTAssertNotNil(message)
        XCTAssertTrue(message?.contains("at least") == true)
    }

    func testRejectsGoalAboveRealisticMaximum() {
        let message = PlanGoalWeightValidationBuilder.validate(
            goalWeightText: "250",
            currentWeightKg: 80,
            heightCm: 170,
            goalType: .gainMuscle
        )

        XCTAssertNotNil(message)
        XCTAssertTrue(message?.contains("up to") == true)
    }

    func testAcceptsDecimalGoalWeight() {
        let message = PlanGoalWeightValidationBuilder.validate(
            goalWeightText: "69.5",
            currentWeightKg: 80,
            heightCm: 170,
            goalType: .loseFat
        )

        XCTAssertNil(message)
    }
}
