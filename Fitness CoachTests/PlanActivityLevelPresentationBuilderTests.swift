//
//  PlanActivityLevelPresentationBuilderTests.swift
//  Fitness CoachTests
//

import XCTest
@testable import Fitness_Coach

final class PlanActivityLevelPresentationBuilderTests: XCTestCase {

    func testOptionsIncludeFriendlyCopyForAllLevels() throws {
        let formState = PlanFormState(profile: PlanMissionControlFixtures.loseProfile)
        let options = PlanActivityLevelPresentationBuilder.options(formState: formState)

        XCTAssertEqual(options.count, ActivityLevel.allCases.count)

        let sedentary = try XCTUnwrap(options.first { $0.level == .sedentary })
        XCTAssertEqual(sedentary.description, FormaProductCopy.PlanEditActivity.sedentaryDescription)
        XCTAssertEqual(sedentary.exampleBehavior, FormaProductCopy.PlanEditActivity.sedentaryExample)

        let athlete = try XCTUnwrap(options.first { $0.level == .athlete })
        XCTAssertEqual(athlete.description, FormaProductCopy.PlanEditActivity.athleteDescription)
        XCTAssertEqual(athlete.exampleBehavior, FormaProductCopy.PlanEditActivity.athleteExample)
    }

    func testMaintenanceImpactAvailableWithCompleteProfile() {
        let formState = PlanFormState(profile: PlanMissionControlFixtures.loseProfile)
        let presentation = PlanActivityLevelPresentationBuilder.presentation(
            for: .moderatelyActive,
            formState: formState
        )

        XCTAssertNotNil(presentation.maintenanceImpactLabel)
        XCTAssertTrue(presentation.maintenanceImpactLabel?.contains("maintenance") == true)
    }

    func testHigherActivityShowsHigherMaintenanceEstimate() {
        let formState = PlanFormState(profile: PlanMissionControlFixtures.loseProfile)
        let sedentary = PlanActivityLevelPresentationBuilder.presentation(
            for: .sedentary,
            formState: formState
        )
        let athlete = PlanActivityLevelPresentationBuilder.presentation(
            for: .athlete,
            formState: formState
        )

        let sedentaryKcal = maintenanceValue(from: sedentary.maintenanceImpactLabel)
        let athleteKcal = maintenanceValue(from: athlete.maintenanceImpactLabel)

        XCTAssertNotNil(sedentaryKcal)
        XCTAssertNotNil(athleteKcal)
        XCTAssertGreaterThan(athleteKcal!, sedentaryKcal!)
    }

    private func maintenanceValue(from label: String?) -> Int? {
        guard let label else { return nil }
        let digits = label.filter { $0.isNumber }
        return Int(digits)
    }
}
