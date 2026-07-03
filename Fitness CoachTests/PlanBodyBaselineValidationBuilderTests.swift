//
//  PlanBodyBaselineValidationBuilderTests.swift
//  Fitness CoachTests
//

import XCTest
@testable import Fitness_Coach

final class PlanBodyBaselineValidationBuilderTests: XCTestCase {

    func testValidHeightAndWeight() {
        let result = PlanBodyBaselineValidationBuilder.validate(
            heightText: "175",
            weightText: "80"
        )

        XCTAssertTrue(result.isValid)
    }

    func testEmptyHeightFails() {
        let result = PlanBodyBaselineValidationBuilder.validate(
            heightText: "",
            weightText: "80"
        )

        XCTAssertEqual(
            result.heightMessage,
            FormaProductCopy.PlanEditBodyBaseline.validationEnterHeight
        )
    }

    func testOutOfRangeWeightFails() {
        let result = PlanBodyBaselineValidationBuilder.validate(
            heightText: "175",
            weightText: "20"
        )

        XCTAssertEqual(
            result.weightMessage,
            FormaProductCopy.PlanEditBodyBaseline.validationWeightOutOfRange
        )
    }

    func testInvalidCharactersFail() {
        let result = PlanBodyBaselineValidationBuilder.validate(
            heightText: "17o",
            weightText: "80"
        )

        XCTAssertEqual(
            result.heightMessage,
            FormaProductCopy.PlanEditBodyBaseline.validationInvalidNumber
        )
    }

    func testDecimalWeightAccepted() {
        let result = PlanBodyBaselineValidationBuilder.validate(
            heightText: "175",
            weightText: "80.4"
        )

        XCTAssertTrue(result.isValid)
    }
}
