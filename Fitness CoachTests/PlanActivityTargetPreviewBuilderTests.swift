//
//  PlanActivityTargetPreviewBuilderTests.swift
//  Fitness CoachTests
//

import XCTest
@testable import Fitness_Coach

final class PlanActivityTargetPreviewBuilderTests: XCTestCase {

    func testPreviewIncludesMaintenanceTargetProteinAndTraining() {
        let formState = PlanFormState(profile: PlanMissionControlFixtures.loseProfile)
        let projection = PlanProjectionBuilder.build(
            formState: formState,
            goalType: .loseFat
        )

        let preview = PlanActivityTargetPreviewBuilder.build(
            projection: projection,
            formState: formState
        )

        XCTAssertTrue(preview.isComplete)
        XCTAssertNotNil(preview.maintenanceCalories)
        XCTAssertNotNil(preview.targetCalories)
        XCTAssertNotNil(preview.proteinTarget)
        XCTAssertTrue(preview.trainingAssumption.contains("training"))
        XCTAssertTrue(preview.trainingAssumption.contains("steps/day"))
    }
}
