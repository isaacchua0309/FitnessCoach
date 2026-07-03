//
//  PlanBodyBaselineSummaryBuilderTests.swift
//  Fitness CoachTests
//

import XCTest
@testable import Fitness_Coach

final class PlanBodyBaselineSummaryBuilderTests: XCTestCase {

    func testSummaryIncludesMeasurementsAndCoachingLine() {
        let formState = PlanFormState(profile: PlanMissionControlFixtures.loseProfile)
        let projection = PlanProjectionBuilder.build(
            formState: formState,
            goalType: .loseFat
        )

        let summary = PlanBodyBaselineSummaryBuilder.summary(
            formState: formState,
            projection: projection
        )

        XCTAssertTrue(summary.isComplete)
        XCTAssertEqual(summary.coachingLine, FormaProductCopy.PlanEditBodyBaseline.coachingLine)
        XCTAssertNotNil(summary.bodyContextLine)
        XCTAssertNotNil(summary.maintenancePreviewLine)
    }

    func testProjectionUsesFriendlyMaintenanceCopy() {
        let formState = PlanFormState(profile: PlanMissionControlFixtures.loseProfile)
        let projection = PlanProjectionBuilder.build(
            formState: formState,
            goalType: .loseFat
        )

        let projectionState = PlanBodyBaselineSummaryBuilder.projection(
            formState: formState,
            projection: projection
        )

        XCTAssertFalse(projectionState.isPlaceholder)
        XCTAssertTrue(
            projectionState.maintenanceLine?.contains("maintenance at") == true
        )
        XCTAssertEqual(
            projectionState.adjustmentLine,
            FormaProductCopy.PlanEditBodyBaseline.targetAdjustedFromBaseline
        )
    }

    func testIncompleteInputsUsePlaceholderProjection() {
        var formState = PlanFormState.defaultDraftValues()
        formState.heightCmText = ""
        formState.currentWeightKgText = ""

        let projection = PlanProjectionBuilder.build(
            formState: formState,
            goalType: .loseFat
        )

        let projectionState = PlanBodyBaselineSummaryBuilder.projection(
            formState: formState,
            projection: projection
        )

        XCTAssertTrue(projectionState.isPlaceholder)
        XCTAssertNil(projectionState.maintenanceLine)
    }
}
