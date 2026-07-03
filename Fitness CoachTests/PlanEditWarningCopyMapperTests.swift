//
//  PlanEditWarningCopyMapperTests.swift
//  Fitness CoachTests
//

import XCTest
@testable import Fitness_Coach

final class PlanEditWarningCopyMapperTests: XCTestCase {

    func testAggressiveDeficitCodeMapsToFriendlyCopy() {
        let warning = PlanEditWarningCopyMapper.userFacingWarning(
            warningCode: "aggressiveDeficit",
            isAggressive: false
        )

        XCTAssertEqual(warning?.title, FormaProductCopy.PlanEditReview.aggressiveDeficitTitle)
        XCTAssertEqual(warning?.body, FormaProductCopy.PlanEditReview.aggressiveDeficitBody)
        XCTAssertFalse(warning?.title.contains("aggressiveDeficit") == true)
    }

    func testIsAggressiveFlagMapsToFriendlyCopy() {
        let warning = PlanEditWarningCopyMapper.userFacingWarning(
            warningCode: nil,
            isAggressive: true
        )

        XCTAssertNotNil(warning)
        XCTAssertEqual(warning?.title, FormaProductCopy.PlanEditReview.aggressiveDeficitTitle)
    }

    func testUnknownWarningCodeReturnsNil() {
        let warning = PlanEditWarningCopyMapper.userFacingWarning(
            warningCode: "someInternalCode",
            isAggressive: false
        )

        XCTAssertNil(warning)
    }
}
