//
//  PlanAdjustmentRulesStateTests.swift
//  Fitness CoachTests
//

import XCTest
@testable import Fitness_Coach

final class PlanAdjustmentRulesStateTests: XCTestCase {

    private let referenceDate = Calendar.current.date(
        from: DateComponents(year: 2026, month: 6, day: 28)
    )!
    private let calendar = Calendar.current

    func testGenericRules() throws {
        let profile = PlanMissionControlFixtures.loseProfile
        let result = try PlanCalculationBridge.planResult(
            from: profile,
            referenceDate: referenceDate
        )
        let state = PlanAdjustmentRulesStateBuilder.build(
            profile: profile,
            planResult: result,
            allWeights: [],
            referenceDate: referenceDate,
            calendar: calendar
        )

        XCTAssertEqual(state.sectionTitle, "When to Adjust")
        XCTAssertEqual(state.reviewHeading, "Review your plan if:")
        XCTAssertEqual(state.rules.map(\.text), [
            FormaProductCopy.PlanMissionControl.adjustmentRuleWeightFlat,
            FormaProductCopy.PlanMissionControl.adjustmentRulePoorEnergy,
            FormaProductCopy.PlanMissionControl.adjustmentRuleTrainingDrops,
            FormaProductCopy.PlanMissionControl.adjustmentRuleHighHunger,
            FormaProductCopy.PlanMissionControl.adjustmentRuleWaitForWeeklySignal
        ])
    }

    func testAggressivePlanWarning() throws {
        let profile = PlanMissionControlFixtures.loseProfile
        let result = try PlanCalculationBridge.planResult(
            from: profile,
            referenceDate: referenceDate
        )
        let state = PlanAdjustmentRulesStateBuilder.build(
            profile: profile,
            planResult: result,
            allWeights: [],
            referenceDate: referenceDate,
            calendar: calendar
        )

        XCTAssertEqual(
            state.aggressivePlanNote,
            FormaProductCopy.PlanMissionControl.adjustmentRuleAggressiveRecoveryNote
        )
    }

    func testStableTrendHint() throws {
        let profile = PlanMissionControlFixtures.maintainProfile
        let result = try PlanCalculationBridge.planResult(
            from: profile,
            referenceDate: referenceDate
        )
        let weights = stableWeightEntries
        let state = PlanAdjustmentRulesStateBuilder.build(
            profile: profile,
            planResult: result,
            allWeights: weights,
            referenceDate: referenceDate,
            calendar: calendar
        )

        XCTAssertEqual(
            state.trendHint,
            FormaProductCopy.PlanMissionControl.adjustmentTrendStable(days: 10)
        )
    }

    func testInsufficientDataFallback() throws {
        let profile = PlanMissionControlFixtures.maintainProfile
        let result = try PlanCalculationBridge.planResult(
            from: profile,
            referenceDate: referenceDate
        )
        let state = PlanAdjustmentRulesStateBuilder.build(
            profile: profile,
            planResult: result,
            allWeights: [],
            referenceDate: referenceDate,
            calendar: calendar
        )

        XCTAssertNil(state.trendHint)
        XCTAssertNil(state.aggressivePlanNote)
    }

    func testEarlyTrendDataUsesTooEarlyHint() throws {
        let profile = PlanMissionControlFixtures.maintainProfile
        let result = try PlanCalculationBridge.planResult(
            from: profile,
            referenceDate: referenceDate
        )
        let weights = [
            WeightEntry(
                id: UUID(),
                date: referenceDate,
                weightKg: 72,
                note: nil,
                createdAt: referenceDate
            )
        ]
        let state = PlanAdjustmentRulesStateBuilder.build(
            profile: profile,
            planResult: result,
            allWeights: weights,
            referenceDate: referenceDate,
            calendar: calendar
        )

        XCTAssertEqual(
            state.trendHint,
            FormaProductCopy.PlanMissionControl.adjustmentTrendTooEarly
        )
    }

    func testAdjustmentCopyAvoidsMedicalClaims() {
        let combined = (
            [
                FormaProductCopy.PlanMissionControl.adjustmentRuleWeightFlat,
                FormaProductCopy.PlanMissionControl.adjustmentRulePoorEnergy,
                FormaProductCopy.PlanMissionControl.adjustmentRuleTrainingDrops,
                FormaProductCopy.PlanMissionControl.adjustmentRuleHighHunger,
                FormaProductCopy.PlanMissionControl.adjustmentRuleWaitForWeeklySignal,
                FormaProductCopy.PlanMissionControl.adjustmentRuleAggressiveRecoveryNote,
                FormaProductCopy.PlanMissionControl.adjustmentTrendTooEarly,
                FormaProductCopy.PlanMissionControl.adjustmentTrendStable(days: 10)
            ]
        ).joined(separator: " ").lowercased()

        XCTAssertFalse(combined.contains("diagnos"))
        XCTAssertFalse(combined.contains("clinical"))
        XCTAssertNil(PlanCopySafetyPolicy.forbiddenViolation(in: combined))
    }

    func testWeeklyRecommendationSafetyCopyAlignsWithDashboard() throws {
        let dashboard = PlanMissionControlFixtures.activeUserDashboard
        let weekly = dashboard.weeklyRecommendation
        let editContext = PlanEditWeeklyReviewContextBuilder.build(from: dashboard)

        XCTAssertEqual(weekly.safetyCopy, FormaProductCopy.PlanMissionControl.weeklyRecommendationSafetyCopy)
        XCTAssertEqual(editContext.safetyCopy, weekly.safetyCopy)
        XCTAssertTrue(editContext.caveats.contains(weekly.safetyCopy))
        XCTAssertTrue(weekly.accessibilitySummary.contains(weekly.safetyCopy))
    }

    func testAdjustmentRulesIncludeWeeklySignalWithoutAutoApplyLanguage() throws {
        let profile = PlanMissionControlFixtures.loseProfile
        let result = try PlanCalculationBridge.planResult(
            from: profile,
            referenceDate: referenceDate
        )
        let state = PlanAdjustmentRulesStateBuilder.build(
            profile: profile,
            planResult: result,
            allWeights: [],
            referenceDate: referenceDate,
            calendar: calendar
        )

        XCTAssertTrue(
            state.rules.contains {
                $0.text == FormaProductCopy.PlanMissionControl.adjustmentRuleWaitForWeeklySignal
            }
        )

        let combined = (
            state.rules.map(\.text) + [PlanMissionControlFixtures.activeUserDashboard.weeklyRecommendation.safetyCopy]
        ).joined(separator: " ").lowercased()

        XCTAssertTrue(combined.contains("weekly"))
        XCTAssertTrue(combined.contains("without confirmation"))
        XCTAssertFalse(combined.contains("auto-apply"))
        XCTAssertFalse(combined.contains("automatically update"))
    }

    private var stableWeightEntries: [WeightEntry] {
        let dates = [10, 7, 4, 0].compactMap { offset in
            calendar.date(byAdding: .day, value: -offset, to: referenceDate)
        }
        let weights = [72.0, 72.1, 71.9, 72.0]
        return zip(dates, weights).map { date, weight in
            WeightEntry(
                id: UUID(),
                date: date,
                weightKg: weight,
                note: nil,
                createdAt: date
            )
        }
    }
}
