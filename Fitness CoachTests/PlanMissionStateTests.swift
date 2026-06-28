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
        let mission = PlanMissionControlFixtures.loseDashboard.mission

        XCTAssertEqual(mission.sectionTitle, FormaProductCopy.PlanMissionControl.heroSectionTitle)
        XCTAssertEqual(mission.headlineValue, "Lose 15 kg")
        XCTAssertEqual(mission.progressRouteLabel, "Current 90 kg → Goal 75 kg")
        XCTAssertTrue(mission.showsProgressBar)
        XCTAssertEqual(mission.adjustPlanTitle, FormaProductCopy.PlanMissionControl.adjustPlan)
        XCTAssertEqual(mission.goalDirection, .lose)
        XCTAssertNotNil(mission.expectedWeeklyChangeLabel)
        XCTAssertTrue(mission.expectedWeeklyChangeLabel?.contains("/week") == true)
        XCTAssertFalse(mission.accessibilitySummary.isEmpty)
        XCTAssertTrue(mission.accessibilitySummary.contains(mission.headlineValue))
    }

    func testGainWeightHeroShowsGainHeadline() {
        let mission = PlanMissionControlFixtures.gainDashboard.mission

        XCTAssertEqual(mission.goalDirection, .gain)
        XCTAssertEqual(mission.headlineValue, "Gain 6 kg")
        XCTAssertEqual(mission.progressRouteLabel, "Current 70 kg → Goal 76 kg")
        XCTAssertTrue(mission.showsProgressBar)
        XCTAssertNil(mission.expectedWeeklyChangeLabel)
    }

    func testMaintainHeroShowsHoldCopy() {
        let mission = PlanMissionControlFixtures.maintainDashboard.mission

        XCTAssertEqual(mission.goalDirection, .maintain)
        XCTAssertEqual(mission.headlineValue, "Maintain 72 kg")
        XCTAssertEqual(mission.progressRouteLabel, "Current 72 kg · Goal hold")
        XCTAssertFalse(mission.showsProgressBar)
        XCTAssertEqual(mission.progressCompleteLabel, FormaProductCopy.PlanMissionControl.progressOnPlan)
        XCTAssertNil(mission.expectedWeeklyChangeLabel)
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
        let mission = PlanMissionControlFixtures.dashboard(for: profile).mission

        XCTAssertEqual(mission.goalDirection, .maintain)
        XCTAssertEqual(mission.headlineValue, "Maintain 75 kg")
    }

    func testNoLoggedWeightUsesProfileCurrentWeight() {
        let mission = PlanMissionControlFixtures.loseDashboard.mission

        XCTAssertFalse(mission.usesLoggedCurrentWeight)
        XCTAssertEqual(mission.currentWeightKg, 90)
        XCTAssertEqual(mission.progressRouteLabel, "Current 90 kg → Goal 75 kg")
    }

    func testLatestLoggedWeightOverridesProfileCurrentWeight() {
        let mission = PlanMissionControlFixtures.activeUserDashboard.mission

        XCTAssertTrue(mission.usesLoggedCurrentWeight)
        XCTAssertEqual(mission.currentWeightKg, 89.6)
        XCTAssertEqual(mission.progressRouteLabel, "Current 89.6 kg → Goal 75 kg")
        XCTAssertNotEqual(mission.currentWeightKg, PlanMissionControlFixtures.loseProfile.currentWeightKg)
    }

    func testNewUserWithoutLogsShowsStartLoggingStatus() {
        let mission = PlanMissionControlFixtures.newUserDashboard.mission

        XCTAssertEqual(
            mission.statusCopy,
            FormaProductCopy.PlanMissionControl.statusStartLogging
        )
    }

    func testAccessibilitySummaryIncludesHeroFields() {
        let mission = PlanMissionControlFixtures.loseDashboard.mission

        XCTAssertTrue(mission.accessibilitySummary.contains("Your Goal"))
        XCTAssertTrue(mission.accessibilitySummary.contains(mission.statusCopy))
        XCTAssertFalse(mission.accessibilitySummary.lowercased().contains("onboarding baseline"))
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
