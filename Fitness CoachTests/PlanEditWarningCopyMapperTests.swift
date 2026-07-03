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

    func testFasterCutProjectionTriggersFriendlyWarning() {
        var formState = PlanFormState(profile: PlanMissionControlFixtures.loseProfile)
        formState.weightLossPaceChoice = .aggressive

        let projection = PlanProjectionBuilder.build(
            formState: formState,
            goalType: .loseFat
        )

        let warning = PlanEditWarningCopyMapper.userFacingWarning(
            warningCode: nil,
            isAggressive: false,
            projection: projection
        )

        XCTAssertNotNil(warning)
        XCTAssertEqual(warning?.title, FormaProductCopy.PlanEditReview.aggressiveDeficitTitle)
    }

    func testModerateProjectionDoesNotTriggerDifficultyWarning() {
        var formState = PlanFormState(profile: PlanMissionControlFixtures.loseProfile)
        formState.weightLossPaceChoice = .moderate

        let projection = PlanProjectionBuilder.build(
            formState: formState,
            goalType: .loseFat
        )

        let warning = PlanEditWarningCopyMapper.userFacingWarning(
            warningCode: nil,
            isAggressive: false,
            projection: projection
        )

        XCTAssertNil(warning)
    }

    func testUserFacingWarningCopyAvoidsRawEnumKeys() {
        let samples = [
            FormaProductCopy.PlanEditReview.aggressiveDeficitTitle,
            FormaProductCopy.PlanEditReview.aggressiveDeficitBody,
            PlanEditWarningCopyMapper.aggressiveDeficitWarning().title,
            PlanEditWarningCopyMapper.aggressiveDeficitWarning().body
        ]

        for sample in samples {
            XCTAssertFalse(sample.contains("aggressiveDeficit"))
            XCTAssertFalse(sample.contains("loseFat"))
            XCTAssertFalse(sample.contains("WeightLossPaceChoice"))
            XCTAssertNil(
                PlanCopySafetyPolicy.forbiddenViolation(in: sample),
                "Forbidden Plan copy in: \(sample)"
            )
        }
    }
}
