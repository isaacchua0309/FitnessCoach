//
//  OnboardingProfileConflictSummaryBuilderTests.swift
//  Fitness CoachTests
//

import XCTest
@testable import Fitness_Coach

final class OnboardingProfileConflictSummaryBuilderTests: XCTestCase {

    func testBuildsDistinctComparisonLabels() {
        var local = ProfileTestFixtures.sampleProfile
        local.targets.calorieTarget = 2_080
        local.goalWeightKg = 79.5

        var cloudProfile = ProfileTestFixtures.sampleProfile
        cloudProfile.targets.calorieTarget = 1_950
        cloudProfile.goalWeightKg = 72
        let cloudDocument = ProfileTestFixtures.cloudDocument(for: cloudProfile)

        let summary = ProfilePlanConflictSummaryBuilder.build(
            localProfile: local,
            cloudDocument: cloudDocument
        )

        XCTAssertTrue(summary.showsComparison)
        XCTAssertTrue(summary.existingDailyTargetLabel.contains("1950"))
        XCTAssertTrue(summary.deviceDailyTargetLabel.contains("2080"))
        XCTAssertTrue(summary.existingGoalWeightLabel.contains("72"))
        XCTAssertTrue(summary.deviceGoalWeightLabel.contains("79.5"))
        XCTAssertNotNil(summary.existingUpdatedAtLabel)
        XCTAssertNotNil(summary.devicePaceLabel)
    }

    func testHidesComparisonWhenCoreValuesMatch() {
        let profile = ProfileTestFixtures.sampleProfile
        let cloudDocument = ProfileTestFixtures.cloudDocument(for: profile)

        let summary = ProfilePlanConflictSummaryBuilder.build(
            localProfile: profile,
            cloudDocument: cloudDocument
        )

        XCTAssertFalse(summary.showsComparison)
        XCTAssertNotNil(summary.existingUpdatedAtLabel)
        XCTAssertNotNil(summary.devicePaceLabel)
    }

    func testHandlesMissingOptionalValuesGracefully() {
        var local = ProfileTestFixtures.sampleProfile
        local.targets.calorieTarget = 0
        local.goalWeightKg = 0

        var cloudProfile = ProfileTestFixtures.sampleProfile
        cloudProfile.targets.calorieTarget = 0
        cloudProfile.goalWeightKg = 0
        let cloudDocument = CloudUserProfileDocument(
            profile: cloudProfile,
            onboardingCompletedAt: ProfileTestFixtures.referenceDate,
            updatedAt: .distantPast
        )

        let summary = ProfilePlanConflictSummaryBuilder.build(
            localProfile: local,
            cloudDocument: cloudDocument
        )

        XCTAssertEqual(summary.existingDailyTargetLabel, "—")
        XCTAssertEqual(summary.deviceDailyTargetLabel, "—")
        XCTAssertEqual(summary.existingGoalWeightLabel, "—")
        XCTAssertEqual(summary.deviceGoalWeightLabel, "—")
        XCTAssertNil(summary.existingUpdatedAtLabel)
    }
}
