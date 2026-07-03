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
            FormaProductCopy.PlanMissionControl.adjustmentRuleHighHunger
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
                FormaProductCopy.PlanMissionControl.adjustmentRuleAggressiveRecoveryNote,
                FormaProductCopy.PlanMissionControl.adjustmentTrendTooEarly,
                FormaProductCopy.PlanMissionControl.adjustmentTrendStable(days: 10)
            ]
        ).joined(separator: " ").lowercased()

        XCTAssertFalse(combined.contains("diagnos"))
        XCTAssertFalse(combined.contains("clinical"))
        XCTAssertNil(PlanCopySafetyPolicy.forbiddenViolation(in: combined))
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
