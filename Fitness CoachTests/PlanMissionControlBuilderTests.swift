//
//  PlanMissionControlBuilderTests.swift
//  Fitness CoachTests
//

import XCTest
@testable import Fitness_Coach

final class PlanMissionControlBuilderTests: XCTestCase {

    private let referenceDate = Calendar.current.date(
        from: DateComponents(year: 2026, month: 6, day: 28)
    )!
    private let calendar = Calendar.current

    // MARK: - Mission

    func testLoseMissionStateUsesGoalDirectionAndWeeklyPace() {
        let dashboard = PlanMissionControlFixtures.loseDashboard

        XCTAssertEqual(dashboard.mission.goalDirection, .lose)
        XCTAssertEqual(dashboard.mission.goalWeightKg, 75)
        XCTAssertEqual(dashboard.mission.expectedWeeklyChangeKg, 0.8)
        XCTAssertNotNil(dashboard.mission.expectedWeeklyChangeLabel)
        XCTAssertFalse(dashboard.mission.strategyName.isEmpty)
    }

    func testGainMissionStateUsesGainDirection() {
        let dashboard = PlanMissionControlFixtures.gainDashboard

        XCTAssertEqual(dashboard.mission.goalDirection, .gain)
        XCTAssertNil(dashboard.mission.expectedWeeklyChangeLabel)
    }

    func testMaintainMissionStateUsesMaintainDirection() {
        let dashboard = PlanMissionControlFixtures.maintainDashboard

        XCTAssertEqual(dashboard.mission.goalDirection, .maintain)
        XCTAssertNil(dashboard.mission.totalToLoseOrGainKg)
    }

    func testActiveUserMissionUsesLoggedCurrentWeight() {
        let dashboard = PlanMissionControlFixtures.activeUserDashboard

        XCTAssertTrue(dashboard.mission.usesLoggedCurrentWeight)
        XCTAssertEqual(dashboard.mission.currentWeightKg, 89.6)
    }

    // MARK: - Today’s mission

    func testTodayMissionIncludesFullMacroTargets() {
        let today = PlanMissionControlFixtures.loseDashboard.todayMission

        XCTAssertEqual(today.calorieTarget, 2233)
        XCTAssertEqual(today.proteinTargetG, 180)
        XCTAssertEqual(today.carbTargetG, 180)
        XCTAssertEqual(today.fatTargetG, 58)
        XCTAssertEqual(today.waterTargetMl, 3150)
        XCTAssertFalse(today.progressCopy.isEmpty)
    }

    // MARK: - Week

    func testNewUserWeekStateIsIncompleteWithoutLogs() {
        let week = PlanMissionControlFixtures.newUserDashboard.week

        XCTAssertEqual(week.overallStatus, .incomplete)
        XCTAssertFalse(week.hasWeeklyData)
    }

    func testActiveUserWeekStateReflectsLogging() {
        let week = PlanMissionControlFixtures.activeUserDashboard.week

        XCTAssertTrue(week.hasWeeklyData)
        XCTAssertGreaterThan(week.proteinAdherence.achieved, 0)
        XCTAssertEqual(week.trainingDays, 2)
    }

    // MARK: - Milestone

    func testLoseProfileHasNextMilestone() {
        let milestone = PlanMissionControlFixtures.loseDashboard.nextMilestone

        XCTAssertFalse(milestone.showsEmptyState)
        XCTAssertNotNil(milestone.milestoneLabel)
        XCTAssertNotNil(milestone.milestoneType)
    }

    func testMaintainProfileMilestoneEmptyWhenStartEqualsGoal() {
        let milestone = PlanMissionControlFixtures.maintainDashboard.nextMilestone

        XCTAssertTrue(milestone.showsEmptyState)
    }

    // MARK: - Rationale

    func testRationaleIncludesStructuredMetrics() {
        let rationale = PlanMissionControlFixtures.loseDashboard.rationale

        XCTAssertNotNil(rationale.metrics)
        XCTAssertEqual(rationale.metrics?.targetCaloriesKcal, 2233)
        XCTAssertGreaterThan(rationale.metrics?.maintenanceCaloriesKcal ?? 0, 0)
        XCTAssertGreaterThan(rationale.metrics?.bmrKcal ?? 0, 0)
        XCTAssertNotNil(rationale.calculationDetails)
    }

    func testRationaleSummaryUsesResolvedAgeFromBirthDate() throws {
        let profile = PlanMissionControlFixtures.loseProfile
        let result = try PlanCalculationBridge.planResult(from: profile, referenceDate: referenceDate)
        let rationale = PlanRationaleCopyBuilder.build(
            profile: profile,
            result: result,
            referenceDate: referenceDate
        )

        XCTAssertTrue(rationale.summary.contains("age (28)"))
    }

    // MARK: - Activity assumptions

    func testActivityAssumptionsUseStoredProfileValues() {
        let assumptions = PlanMissionControlFixtures.loseDashboard.activityAssumptions

        XCTAssertEqual(assumptions.estimatedStepsPerDay, 7500)
        XCTAssertEqual(assumptions.trainingSessionsPerWeek, 3)
        XCTAssertTrue(assumptions.usesActivityLevelDefaults)
        XCTAssertEqual(assumptions.resolvedAgeYears, 28)
    }

    func testActivityAssumptionsIncludeAppleHealthNoteWhenNotConnected() {
        let note = PlanMissionControlFixtures.loseDashboard.activityAssumptions.appleHealthInsightsNote

        XCTAssertTrue(note.contains("does not automatically change"))
    }

    func testLegacyProfileMissingBirthdaySurfacesInConfidence() {
        let confidence = PlanMissionControlFixtures.incompleteDataDashboard.confidence

        XCTAssertTrue(confidence.missingSignals.contains(FormaProductCopy.PlanMissionControl.missingBirthday))
    }

    // MARK: - Confidence & adjustment

    func testConfidenceScoreIsWithinBounds() {
        for dashboard in [
            PlanMissionControlFixtures.loseDashboard,
            PlanMissionControlFixtures.activeUserDashboard,
            PlanMissionControlFixtures.incompleteDataDashboard
        ] {
            XCTAssert((0...100).contains(dashboard.confidence.confidenceScore))
            XCTAssertFalse(dashboard.confidence.safeCopy.isEmpty)
        }
    }

    func testAdjustmentStateUsesProfileUpdatedAt() {
        let adjustment = PlanMissionControlFixtures.loseDashboard.adjustment

        XCTAssertTrue(adjustment.canEditPlan)
        XCTAssertEqual(adjustment.lastUpdated, PlanMissionControlFixtures.loseProfile.updatedAt)
        XCTAssertFalse(adjustment.editSafetyCopy.isEmpty)
    }

    // MARK: - Integration with ProfileDashboardState

    func testPlanStateBuilderEmbedsMissionControlDashboard() {
        let state = PlanStateBuilder.dashboardState(
            profile: PlanMissionControlFixtures.loseProfile,
            referenceDate: referenceDate
        )

        XCTAssertEqual(state.missionControl.mission.goalDirection, .lose)
        XCTAssertEqual(state.rationale.metrics?.targetCaloriesKcal, state.missionControl.rationale.metrics?.targetCaloriesKcal)
    }
}
