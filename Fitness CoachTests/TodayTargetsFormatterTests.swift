//
//  TodayTargetsFormatterTests.swift
//  Fitness CoachTests
//

import XCTest
@testable import Fitness_Coach

final class TodayTargetsFormatterTests: XCTestCase {

    func testMacroProgressUsesSpacedGramUnit() {
        XCTAssertEqual(
            TodayTargetsFormatter.macroProgress(consumed: 31, target: 180),
            "31 / 180 g"
        )
    }

    func testMacroProgressFormatsFractionalGrams() {
        XCTAssertEqual(
            TodayTargetsFormatter.macroProgress(consumed: 19.5, target: 60),
            "19.5 / 60 g"
        )
    }

    func testWaterProgressUsesSpacedMilliliterUnit() {
        XCTAssertEqual(
            TodayTargetsFormatter.waterProgress(consumedMl: 500, targetMl: 3_150),
            "500 / 3150 ml"
        )
    }
}
