//
//  ActivityTrainingDefaultsResolverTests.swift
//  Fitness CoachTests
//
//  Forma — Training rhythm defaults from activity level.
//

import XCTest
@testable import Fitness_Coach

final class ActivityTrainingDefaultsResolverTests: XCTestCase {

    private let resolver = ActivityTrainingDefaultsResolver()

    func testSedentaryReturnsZeroDaysAnd3000Steps() {
        let defaults = resolver.defaults(for: .sedentary)
        XCTAssertEqual(defaults.trainingDaysPerWeek, 0)
        XCTAssertEqual(defaults.averageStepsPerDay, 3000)
    }

    func testLightlyActiveReturnsOneDayAnd5000Steps() {
        let defaults = resolver.defaults(for: .lightlyActive)
        XCTAssertEqual(defaults.trainingDaysPerWeek, 1)
        XCTAssertEqual(defaults.averageStepsPerDay, 5000)
    }

    func testModeratelyActiveReturnsThreeDaysAnd7500Steps() {
        let defaults = resolver.defaults(for: .moderatelyActive)
        XCTAssertEqual(defaults.trainingDaysPerWeek, 3)
        XCTAssertEqual(defaults.averageStepsPerDay, 7500)
    }

    func testVeryActiveReturnsFiveDaysAnd10000Steps() {
        let defaults = resolver.defaults(for: .veryActive)
        XCTAssertEqual(defaults.trainingDaysPerWeek, 5)
        XCTAssertEqual(defaults.averageStepsPerDay, 10_000)
    }

    func testAthleteReturnsSixDaysAnd12000Steps() {
        let defaults = resolver.defaults(for: .athlete)
        XCTAssertEqual(defaults.trainingDaysPerWeek, 6)
        XCTAssertEqual(defaults.averageStepsPerDay, 12_000)
    }
}
