//
//  PlanBodyBaselineValidationBuilderTests.swift
//  Fitness CoachTests
//

import XCTest
@testable import Fitness_Coach

final class PlanBodyBaselineValidationBuilderTests: XCTestCase {

    func testValidHeightAndWeightPass() {
        let result = PlanBodyBaselineValidationBuilder.validate(
            heightText: "175",
            weightText: "80"
        )

        XCTAssertTrue(result.isValid)
        XCTAssertNil(result.heightMessage)
        XCTAssertNil(result.weightMessage)
    }

    func testEmptyHeightFails() {
        let result = PlanBodyBaselineValidationBuilder.validate(
            heightText: "",
            weightText: "80"
        )

        XCTAssertFalse(result.isValid)
        XCTAssertEqual(
            result.heightMessage,
            FormaProductCopy.PlanEditBodyBaseline.validationEnterHeight
        )
    }

    func testOutOfRangeWeightFails() {
        let result = PlanBodyBaselineValidationBuilder.validate(
            heightText: "175",
            weightText: "10"
        )

        XCTAssertFalse(result.isValid)
        XCTAssertEqual(
            result.weightMessage,
            FormaProductCopy.PlanEditBodyBaseline.validationWeightOutOfRange
        )
    }
}
