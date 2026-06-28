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

        let summary = OnboardingProfileConflictSummaryBuilder.build(
            localProfile: local,
            cloudDocument: cloudDocument
        )

        XCTAssertTrue(summary.showsComparison)
        XCTAssertTrue(summary.existingDailyTargetLabel.contains("1950"))
        XCTAssertTrue(summary.newDailyTargetLabel.contains("2080"))
        XCTAssertTrue(summary.existingGoalWeightLabel.contains("72"))
        XCTAssertTrue(summary.newGoalWeightLabel.contains("79.5"))
    }

    func testHidesComparisonWhenValuesMatch() {
        let profile = ProfileTestFixtures.sampleProfile
        let cloudDocument = ProfileTestFixtures.cloudDocument(for: profile)

        let summary = OnboardingProfileConflictSummaryBuilder.build(
            localProfile: profile,
            cloudDocument: cloudDocument
        )

        XCTAssertFalse(summary.showsComparison)
    }
}
