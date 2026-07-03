//
//  PlanNumericInputParserTests.swift
//  Fitness CoachTests
//

import XCTest
@testable import Fitness_Coach

final class PlanNumericInputParserTests: XCTestCase {

    func testAcceptsDecimalInput() {
        let result = PlanNumericInputParser.parsePositiveDecimal("72.5")
        XCTAssertEqual(try? result.get(), 72.5)
    }

    func testRejectsEmptyInput() {
        XCTAssertEqual(
            PlanNumericInputParser.parsePositiveDecimal("   "),
            .failure(.empty)
        )
    }

    func testRejectsInvalidCharacters() {
        XCTAssertEqual(
            PlanNumericInputParser.parsePositiveDecimal("72kg"),
            .failure(.invalidFormat)
        )
        XCTAssertEqual(
            PlanNumericInputParser.parsePositiveDecimal("12.3.4"),
            .failure(.invalidFormat)
        )
    }

    func testRejectsNonPositiveValues() {
        XCTAssertEqual(
            PlanNumericInputParser.parsePositiveDecimal("0"),
            .failure(.nonPositive)
        )
    }
}
