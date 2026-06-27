//
//  TodayFocusBuilderTests.swift
//  Fitness CoachTests
//

import XCTest
@testable import Fitness_Coach

final class TodayFocusBuilderTests: XCTestCase {

    func testFocusPrioritizesProteinWhenItIsMostBehind() {
        XCTAssertEqual(
            TodayFocusBuilder.focus(
                proteinProgress: 0.2,
                waterProgress: 0.5,
                weightLogged: false,
                hasWorkout: false
            ),
            FormaProductCopy.Today.focusProteinLow
        )
    }

    func testFocusPrioritizesWaterWhenItIsMoreBehindThanProtein() {
        XCTAssertEqual(
            TodayFocusBuilder.focus(
                proteinProgress: 0.5,
                waterProgress: 0.2,
                weightLogged: false,
                hasWorkout: false
            ),
            FormaProductCopy.Today.focusWaterLow
        )
    }

    func testFocusUsesWaterWhenProteinOnTrack() {
        XCTAssertEqual(
            TodayFocusBuilder.focus(
                proteinProgress: 0.95,
                waterProgress: 0.3,
                weightLogged: false,
                hasWorkout: false
            ),
            FormaProductCopy.Today.focusWaterLow
        )
    }

    func testFocusUsesWeightWhenNutritionOnTrackButWeightMissing() {
        XCTAssertEqual(
            TodayFocusBuilder.focus(
                proteinProgress: 0.95,
                waterProgress: 0.9,
                weightLogged: false,
                hasWorkout: false
            ),
            FormaProductCopy.Today.focusLogWeight
        )
    }

    func testFocusUsesTrainingWhenManualWorkoutStillNeeded() {
        XCTAssertEqual(
            TodayFocusBuilder.focus(
                proteinProgress: 0.95,
                waterProgress: 0.9,
                weightLogged: true,
                hasWorkout: false,
                trainingIntegration: .connected,
                trainingDataSource: .unavailable
            ),
            FormaProductCopy.Today.focusTraining
        )
    }

    func testFocusUsesTrainingWhenAppleHealthNotConnected() {
        XCTAssertEqual(
            TodayFocusBuilder.focus(
                proteinProgress: 0.95,
                waterProgress: 0.9,
                weightLogged: true,
                hasWorkout: false,
                trainingIntegration: .notConnected,
                trainingDataSource: .appleHealth
            ),
            FormaProductCopy.Today.focusTraining
        )
    }

    func testFocusOnTrackWhenGoalsMet() {
        XCTAssertEqual(
            TodayFocusBuilder.focus(
                proteinProgress: 0.95,
                waterProgress: 0.9,
                weightLogged: true,
                hasWorkout: true,
                trainingIntegration: .connected,
                trainingDataSource: .appleHealth
            ),
            FormaProductCopy.Today.focusOnTrack
        )
    }

    func testFocusSkipsTrainingWhenAppleHealthConnectedWithNoWorkout() {
        XCTAssertEqual(
            TodayFocusBuilder.focus(
                proteinProgress: 0.95,
                waterProgress: 0.9,
                weightLogged: true,
                hasWorkout: false,
                trainingIntegration: .connected,
                trainingDataSource: .appleHealth
            ),
            FormaProductCopy.Today.focusOnTrack
        )
    }
}
