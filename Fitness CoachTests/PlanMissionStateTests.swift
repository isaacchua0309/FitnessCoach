//
//  PlanMissionStateTests.swift
//  Fitness CoachTests
//

import XCTest
@testable import Fitness_Coach

final class PlanStrategyHeroTests: XCTestCase {

    func testWeightLossHeroShowsStrategyFocusedCopy() {
        let strategy = PlanMissionControlFixtures.loseDashboard.strategy

        XCTAssertEqual(strategy.sectionTitle, "Your Strategy")
        XCTAssertEqual(strategy.primaryGoal, "Lose 15 kg")
        XCTAssertEqual(strategy.dailyTargetValue, "2233 kcal")
        XCTAssertEqual(strategy.expectedPaceValue, "~0.8 kg/week")
        XCTAssertEqual(strategy.strategyStatusValue, "Aggressive Cut")
        XCTAssertEqual(strategy.supportiveLine, "Demanding but achievable.")
        XCTAssertEqual(strategy.goalDirection, .lose)
        XCTAssertFalse(strategy.accessibilitySummary.isEmpty)
        XCTAssertFalse(strategy.accessibilitySummary.contains("% complete"))
    }

    func testMaintenanceHeroShowsHoldStrategy() {
        let strategy = PlanMissionControlFixtures.maintainDashboard.strategy

        XCTAssertEqual(strategy.primaryGoal, "Maintain weight")
        XCTAssertEqual(strategy.goalDirection, .maintain)
        XCTAssertNil(strategy.expectedPaceValue)
        XCTAssertEqual(strategy.strategyStatusValue, "Maintenance")
        XCTAssertEqual(strategy.supportiveLine, "Designed to maintain your current weight.")
    }

    func testMuscleGainHeroShowsBuildMuscleStrategy() {
        let strategy = PlanMissionControlFixtures.gainDashboard.strategy

        XCTAssertEqual(strategy.primaryGoal, "Build muscle")
        XCTAssertEqual(strategy.goalDirection, .gain)
        XCTAssertNil(strategy.expectedPaceValue)
        XCTAssertEqual(strategy.strategyStatusValue, "Lean Gain")
        XCTAssertEqual(strategy.supportiveLine, "Built for lean muscle growth.")
    }

    func testMissingTargetUsesFallbackPrimaryGoal() {
        let fallback = PlanMissionHeroCopyBuilder.primaryGoalValue(
            direction: .lose,
            totalChangeKg: nil
        )

        XCTAssertEqual(fallback, "Lose weight")

        var profile = PlanMissionControlFixtures.loseProfile
        profile.currentWeightKg = 75
        profile.goalWeightKg = 75
        let strategy = PlanMissionControlFixtures.dashboard(for: profile).strategy

        XCTAssertEqual(strategy.goalDirection, .maintain)
        XCTAssertEqual(strategy.primaryGoal, "Maintain weight")
    }

    func testAggressiveCutStatusInStrategyHero() {
        let strategy = PlanMissionControlFixtures.loseDashboard.strategy

        XCTAssertEqual(strategy.strategyStatusValue, FormaProductCopy.PlanStrategyHero.statusAggressiveCut)
        XCTAssertEqual(strategy.supportiveLine, FormaProductCopy.PlanStrategyHero.supportiveAggressiveCut)
    }

    func testModerateCutStatusUsesSteadyProgressSupportiveLine() {
        let strategy = PlanMissionControlFixtures.moderateDeficitDashboard.strategy

        XCTAssertEqual(strategy.strategyStatusValue, "Moderate Cut")
        XCTAssertEqual(strategy.supportiveLine, "Built for steady progress.")
    }

    func testAccessibilitySummaryIncludesStrategyFields() {
        let strategy = PlanMissionControlFixtures.loseDashboard.strategy

        XCTAssertTrue(strategy.accessibilitySummary.contains("Your Strategy"))
        XCTAssertTrue(strategy.accessibilitySummary.contains(strategy.primaryGoal))
        XCTAssertTrue(strategy.accessibilitySummary.contains(strategy.dailyTargetValue))
        XCTAssertTrue(strategy.accessibilitySummary.contains(strategy.strategyStatusValue))
        XCTAssertTrue(strategy.accessibilitySummary.contains(strategy.supportiveLine))
    }
}
