//
//  PlanEditMotionTests.swift
//  Fitness CoachTests
//

import XCTest
@testable import Fitness_Coach

final class PlanEditMotionTests: XCTestCase {

    func testAnimationReturnsNilWhenReduceMotionEnabled() {
        XCTAssertNil(PlanEditMotion.animation(PlanEditMotion.stepTransition, reduceMotion: true))
    }

    func testAnimationReturnsBaseWhenReduceMotionDisabled() {
        XCTAssertEqual(
            PlanEditMotion.animation(PlanEditMotion.stepTransition, reduceMotion: false),
            PlanEditMotion.stepTransition
        )
    }

    func testSelectedScaleIsSubtle() {
        XCTAssertLessThanOrEqual(PlanEditMotion.selectedScale, 1.02)
        XCTAssertGreaterThan(PlanEditMotion.selectedScale, 1)
    }
}
