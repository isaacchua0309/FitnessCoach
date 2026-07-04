//
//  CoachHealthContextCopyTests.swift
//  Fitness CoachTests
//
//  Ensures health-missing copy stays distinct from backend-unavailable messaging.
//

import XCTest
@testable import Fitness_Coach

final class CoachHealthContextCopyTests: XCTestCase {

    func testMissingHealthDisclaimerDoesNotUseCoachUnavailableCopy() {
        let missing = CoachMissingDataContext(
            stepsMissing: true,
            healthKitUnavailable: true,
            stepsUnavailable: true
        )

        let disclaimer = CoachAIResponseContextAdapter.missingDataDisclaimer(missing)

        XCTAssertNotNil(disclaimer)
        XCTAssertFalse(disclaimer?.contains(FormaProductCopy.Error.coachUnavailable) == true)
        XCTAssertTrue(disclaimer?.contains("Apple Health") == true)
    }

    func testHealthActivityHintDoesNotUseCoachUnavailableCopy() {
        let hint = CoachTodayContextBuilder.healthActivityNote(
            trainingDataSource: .unavailable,
            trainingIntegration: .connected
        )

        XCTAssertEqual(hint, FormaProductCopy.Today.Activity.healthUnavailableNote)
        XCTAssertNotEqual(hint, FormaProductCopy.Error.coachUnavailable)
    }
}
