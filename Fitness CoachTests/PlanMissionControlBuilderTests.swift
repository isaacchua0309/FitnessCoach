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

    // MARK: - Strategy

    func testLoseMissionStateUsesGoalDirectionAndWeeklyPace() {
        let dashboard = PlanMissionControlFixtures.loseDashboard

        XCTAssertEqual(dashboard.strategy.goalDirection, .lose)
        XCTAssertNotNil(dashboard.strategy.expectedPaceValue)
        XCTAssertEqual(dashboard.strategy.sectionTitle, "Your Strategy")
        XCTAssertEqual(dashboard.strategy.primaryGoal, "Lose 15 kg")
        XCTAssertFalse(dashboard.strategy.accessibilitySummary.isEmpty)
        XCTAssertEqual(dashboard.adjustPlanCTA.title, "Adjust Plan")
    }

    func testGainMissionStateUsesGainDirection() {
        let dashboard = PlanMissionControlFixtures.gainDashboard

        XCTAssertEqual(dashboard.strategy.goalDirection, .gain)
        XCTAssertNil(dashboard.strategy.expectedPaceValue)
        XCTAssertEqual(dashboard.strategy.primaryGoal, "Build muscle")
    }

    func testMaintainMissionStateUsesMaintainDirection() {
        let dashboard = PlanMissionControlFixtures.maintainDashboard

        XCTAssertEqual(dashboard.strategy.goalDirection, .maintain)
        XCTAssertEqual(dashboard.strategy.primaryGoal, "Maintain weight")
    }

    func testActiveUserStrategyShowsDailyTargetAndStatus() {
        let dashboard = PlanMissionControlFixtures.activeUserDashboard

        XCTAssertEqual(dashboard.strategy.dailyTargetValue, "2233 kcal")
        XCTAssertEqual(dashboard.strategy.strategyStatusValue, "Aggressive Cut")
    }

    // MARK: - Daily targets

    func testDailyTargetsIncludeFullMacroPrescription() {
        let today = PlanMissionControlFixtures.loseDashboard.dailyTargets

        XCTAssertEqual(today.sectionTitle, "Daily Targets")
        XCTAssertEqual(today.caloriesLabel, "2233 kcal")
        XCTAssertEqual(today.proteinLabel, "180g protein")
        XCTAssertEqual(today.carbsLabel, "180g carbs")
        XCTAssertEqual(today.fatLabel, "58g fat")
        XCTAssertEqual(today.waterLabel, DailyTargetsStateBuilder.waterLabel(for: 3150))
        XCTAssertEqual(today.prescriptionCopy, "Built for fat loss while preserving muscle.")
        XCTAssertEqual(today.trainingTargetLabel, "3 training sessions/week")
    }

    // MARK: - Rationale

    func testRationaleIncludesStructuredMetrics() throws {
        let profile = PlanMissionControlFixtures.loseProfile
        let result = try PlanCalculationBridge.planResult(from: profile, referenceDate: referenceDate)
        let rationale = PlanRationaleCopyBuilder.build(
            profile: profile,
            result: result,
            referenceDate: referenceDate
        )

        XCTAssertNotNil(rationale.metrics)
        XCTAssertEqual(rationale.metrics?.targetCaloriesKcal, result.calorieTargetKcal)
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

    // MARK: - Plan assumptions

    func testAssumptionsUseStoredProfileValues() {
        let assumptions = PlanMissionControlFixtures.loseDashboard.assumptions

        XCTAssertEqual(assumptions.rows.first { $0.id == "activity" }?.value, "Moderately active")
        XCTAssertEqual(assumptions.rows.first { $0.id == "age" }?.value, "28")
        XCTAssertEqual(assumptions.rows.first { $0.id == "weight" }?.value, "90 kg")
    }

    func testAssumptionsDoNotSurfaceStepsOrTrainingRows() {
        let assumptions = PlanMissionControlFixtures.loseDashboard.assumptions

        XCTAssertFalse(assumptions.rows.contains { $0.label.contains("Steps") })
        XCTAssertFalse(assumptions.rows.contains { $0.label.contains("Training") })
    }

    func testLegacyProfileMissingBirthdaySurfacesInConfidence() {
        let confidence = PlanMissionControlFixtures.incompleteDataDashboard.confidence

        XCTAssertTrue(confidence.improvementActions.contains {
            $0.text == FormaProductCopy.PlanMissionControl.planConfidenceActionAddProfileDetails
        })
    }

    // MARK: - Confidence

    func testConfidenceScoreIsWithinBounds() {
        for dashboard in [
            PlanMissionControlFixtures.loseDashboard,
            PlanMissionControlFixtures.activeUserDashboard,
            PlanMissionControlFixtures.incompleteDataDashboard
        ] {
            XCTAssert((0...100).contains(dashboard.confidence.confidenceScore))
            XCTAssertFalse(dashboard.confidence.scoreHeadline.isEmpty)
        }
    }

    func testConnectedDashboardSurfacesAppleHealthInConfidence() {
        let confidence = PlanMissionControlFixtures.connectedDashboard.confidence

        XCTAssertEqual(
            confidence.compactSignals.first { $0.id == "appleHealth" }?.value,
            "Connected"
        )
        XCTAssertFalse(confidence.showsAppleHealthAction)
    }

    func testDisconnectedDashboardOffersAppleHealthActionInConfidence() {
        let confidence = PlanMissionControlFixtures.loseDashboard.confidence

        XCTAssertTrue(confidence.showsAppleHealthAction)
        XCTAssertEqual(confidence.appleHealthActionTitle, TrainingIntegrationCopy.connectAppleHealth)
    }

    // MARK: - Integration with PlanDashboardState

    func testPlanStateBuilderEmbedsPresentationSections() throws {
        let profile = PlanMissionControlFixtures.loseProfile
        let state = PlanStateBuilder.dashboardState(
            profile: profile,
            referenceDate: referenceDate
        )
        let result = try PlanCalculationBridge.planResult(from: profile, referenceDate: referenceDate)
        let rationale = PlanPresentationBuilder.rationaleState(
            profile: profile,
            result: result,
            referenceDate: referenceDate
        )

        XCTAssertEqual(state.strategy.goalDirection, .lose)
        XCTAssertEqual(rationale.metrics?.targetCaloriesKcal, result.calorieTargetKcal)
        XCTAssertNotNil(state.explanation.calculationDetails)
        XCTAssertFalse(state.adjustmentRules.rules.isEmpty)
        XCTAssertNotNil(state.review.lastUpdatedLabel)
    }
}
