//
//  PlanMissionStateTests.swift
//  Fitness CoachTests
//

import XCTest
@testable import Fitness_Coach

final class PlanMissionStateTests: XCTestCase {

    private let calendar = Calendar.current
    private let referenceDate = Calendar.current.date(
        from: DateComponents(year: 2026, month: 6, day: 28)
    )!

    func testLoseWeightHeroShowsGoalProgressFirst() {
        let dashboard = PlanMissionControlFixtures.loseDashboard
        let strategy = dashboard.strategy

        XCTAssertEqual(strategy.sectionTitle, FormaProductCopy.PlanMissionControl.heroSectionTitle)
        XCTAssertEqual(strategy.headline, "Lose 15 kg")
        XCTAssertEqual(strategy.progressRouteLabel, "Current 90 kg → Goal 75 kg")
        XCTAssertTrue(strategy.showsProgressBar)
        XCTAssertEqual(strategy.goalDirection, .lose)
        XCTAssertNotNil(strategy.expectedPaceLabel)
        XCTAssertTrue(strategy.expectedPaceLabel?.contains("/week") == true)
        XCTAssertFalse(strategy.accessibilitySummary.isEmpty)
        XCTAssertTrue(strategy.accessibilitySummary.contains(strategy.headline))
    }

    func testGainWeightHeroShowsGainHeadline() {
        let strategy = PlanMissionControlFixtures.gainDashboard.strategy

        XCTAssertEqual(strategy.goalDirection, .gain)
        XCTAssertEqual(strategy.headline, "Gain 6 kg")
        XCTAssertEqual(strategy.progressRouteLabel, "Current 70 kg → Goal 76 kg")
        XCTAssertTrue(strategy.showsProgressBar)
        XCTAssertNil(strategy.expectedPaceLabel)
    }

    func testMaintainHeroShowsHoldCopy() {
        let strategy = PlanMissionControlFixtures.maintainDashboard.strategy

        XCTAssertEqual(strategy.goalDirection, .maintain)
        XCTAssertEqual(strategy.headline, "Maintain 72 kg")
        XCTAssertEqual(strategy.progressRouteLabel, "Current 72 kg · Goal hold")
        XCTAssertFalse(strategy.showsProgressBar)
        XCTAssertEqual(strategy.progressCompleteLabel, FormaProductCopy.PlanMissionControl.progressOnPlan)
        XCTAssertNil(strategy.expectedPaceLabel)
    }

    func testMissingGoalUsesFallbackHeadline() {
        let headline = PlanMissionHeroCopyBuilder.headlineValue(
            direction: .lose,
            totalChangeKg: nil,
            goalWeightKg: 75
        )

        XCTAssertEqual(headline, FormaProductCopy.PlanMissionControl.headlineLoseFallback)

        var profile = PlanMissionControlFixtures.loseProfile
        profile.currentWeightKg = 75
        profile.goalWeightKg = 75
        let strategy = PlanMissionControlFixtures.dashboard(for: profile).strategy

        XCTAssertEqual(strategy.goalDirection, .maintain)
        XCTAssertEqual(strategy.headline, "Maintain 75 kg")
    }

    func testNoLoggedWeightUsesProfileCurrentWeight() {
        let strategy = PlanMissionControlFixtures.loseDashboard.strategy

        XCTAssertFalse(strategy.usesLoggedCurrentWeight)
        XCTAssertEqual(strategy.progressRouteLabel, "Current 90 kg → Goal 75 kg")
    }

    func testLatestLoggedWeightOverridesProfileCurrentWeight() {
        let strategy = PlanMissionControlFixtures.activeUserDashboard.strategy

        XCTAssertTrue(strategy.usesLoggedCurrentWeight)
        XCTAssertEqual(strategy.progressRouteLabel, "Current 89.6 kg → Goal 75 kg")
    }

    func testNewUserWithoutLogsShowsNeedsDataStatus() {
        let status = PlanMissionControlFixtures.newUserDashboard.status

        XCTAssertEqual(status.tone, .needsData)
        XCTAssertFalse(status.message.isEmpty)
    }

    func testAccessibilitySummaryIncludesHeroFields() {
        let dashboard = PlanMissionControlFixtures.loseDashboard

        XCTAssertTrue(dashboard.strategy.accessibilitySummary.contains("Your Goal"))
        XCTAssertFalse(dashboard.strategy.accessibilitySummary.lowercased().contains("onboarding baseline"))
    }

    func testProgressBarAccessibilityValueFormatsPercent() {
        XCTAssertEqual(
            PlanMissionHeroCopyBuilder.progressBarAccessibilityValue(percent: 42),
            "42 percent complete"
        )
        XCTAssertEqual(
            PlanMissionHeroCopyBuilder.progressBarAccessibilityValue(percent: nil),
            FormaProductCopy.PlanMissionControl.accessibilityProgressZero
        )
    }
}
