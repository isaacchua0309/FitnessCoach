//
//  WeeklyProgressConfidencePolicyTests.swift
//  Fitness CoachTests
//
//  Forma — Unit tests for Weekly Progress confidence and sufficiency gates.
//

import XCTest
@testable import Fitness_Coach

final class WeeklyProgressConfidencePolicyTests: XCTestCase {

    // MARK: - Unavailable gates

    func testBelowSevenDaysIsUnavailable() {
        let result = evaluate(
            foodLoggedDays: 5,
            weightEntryCount: 3,
            calendarSpanDays: 6,
            loggingConsistencyRatio: 1.0
        )

        XCTAssertEqual(result.confidence, .unavailable)
        XCTAssertFalse(result.isEligibleForMaintenanceEstimate)
        XCTAssertFalse(result.isEligibleForKcalMaintenanceDisplay)
        XCTAssertFalse(result.isEligibleForPlanRecommendation)
        XCTAssertTrue(result.reasons.contains(.notEnoughCalendarSpan))
    }

    func testBelowFiveFoodDaysIsUnavailable() {
        let result = evaluate(
            foodLoggedDays: 4,
            weightEntryCount: 3,
            calendarSpanDays: 7,
            loggingConsistencyRatio: 4.0 / 7.0
        )

        XCTAssertEqual(result.confidence, .unavailable)
        XCTAssertTrue(result.reasons.contains(.notEnoughFoodLoggedDays))
    }

    func testBelowThreeWeightsIsUnavailable() {
        let result = evaluate(
            foodLoggedDays: 5,
            weightEntryCount: 2,
            calendarSpanDays: 7,
            loggingConsistencyRatio: 5.0 / 7.0
        )

        XCTAssertEqual(result.confidence, .unavailable)
        XCTAssertTrue(result.reasons.contains(.notEnoughWeightEntries))
    }

    // MARK: - Confidence tiers

    func testSevenToThirteenDaysIsLowConfidenceNoKcalDisplay() {
        let result = evaluate(
            foodLoggedDays: 6,
            weightEntryCount: 3,
            calendarSpanDays: 10,
            loggingConsistencyRatio: 6.0 / 10.0
        )

        XCTAssertEqual(result.confidence, .low)
        XCTAssertTrue(result.isEligibleForMaintenanceEstimate)
        XCTAssertFalse(result.isEligibleForKcalMaintenanceDisplay)
        XCTAssertTrue(result.isEligibleForPlanRecommendation)
        XCTAssertFalse(result.reasons.contains(.inconsistentLogging))
    }

    func testFourteenToTwentySevenDaysIsMediumConfidence() {
        let result = evaluate(
            foodLoggedDays: 10,
            weightEntryCount: 3,
            calendarSpanDays: 14,
            loggingConsistencyRatio: 10.0 / 14.0
        )

        XCTAssertEqual(result.confidence, .medium)
        XCTAssertTrue(result.isEligibleForKcalMaintenanceDisplay)
        XCTAssertTrue(result.isEligibleForPlanRecommendation)
    }

    func testTwentyEightDaysIsHighConfidence() {
        let result = evaluate(
            foodLoggedDays: 20,
            weightEntryCount: 4,
            calendarSpanDays: 28,
            loggingConsistencyRatio: 20.0 / 28.0
        )

        XCTAssertEqual(result.confidence, .high)
        XCTAssertTrue(result.isEligibleForKcalMaintenanceDisplay)
        XCTAssertTrue(result.isEligibleForPlanRecommendation)
    }

    // MARK: - Logging quality & spike caveats

    func testPoorLoggingConsistencyBlocksRecommendation() {
        let result = evaluate(
            foodLoggedDays: 5,
            weightEntryCount: 3,
            calendarSpanDays: 14,
            loggingConsistencyRatio: 0.5
        )

        XCTAssertTrue(result.reasons.contains(.inconsistentLogging))
        XCTAssertFalse(result.isEligibleForPlanRecommendation)
        XCTAssertFalse(WeeklyProgressConfidencePolicy.canRecommendPreciseCalorieAdjustment(result))
        XCTAssertEqual(
            result.userFacingSummary,
            WeeklyProgressConfidencePolicy.insufficientDataCopy(for: [.inconsistentLogging])
        )
    }

    func testSuddenSpikeAddsWaterWeightCaveat() {
        let result = evaluate(
            foodLoggedDays: 10,
            weightEntryCount: 3,
            calendarSpanDays: 14,
            hasSuddenSpike: true,
            loggingConsistencyRatio: 10.0 / 14.0
        )

        XCTAssertTrue(result.reasons.contains(.weightTrendTooNoisy))
        XCTAssertEqual(
            result.userFacingSummary,
            WeeklyProgressConfidencePolicy.confidenceCopy(for: .medium, hasSuddenSpike: true)
        )
        XCTAssertTrue(
            result.userFacingSummary.contains(FormaProductCopy.WeightSpikeEducation.confidenceSuffix)
        )
    }

    func testNoMedicalCopyOrAggressiveRecommendationCopy() {
        let samples = [
            WeeklyProgressConfidencePolicy.confidenceCopy(for: .unavailable),
            WeeklyProgressConfidencePolicy.confidenceCopy(for: .low),
            WeeklyProgressConfidencePolicy.confidenceCopy(for: .medium),
            WeeklyProgressConfidencePolicy.confidenceCopy(for: .high),
            WeeklyProgressConfidencePolicy.confidenceCopy(for: .medium, hasSuddenSpike: true),
            WeeklyProgressConfidencePolicy.insufficientDataCopy(for: [.notEnoughFoodLoggedDays]),
            WeeklyProgressConfidencePolicy.insufficientDataCopy(for: [.inconsistentLogging]),
            WeeklyProgressConfidencePolicy.insufficientDataCopy(for: [.weightTrendTooNoisy]),
            WeeklyProgressConfidencePolicy.waterWeightNoiseWarningCopy(),
            WeeklyProgressConfidencePolicy.holdSteadyDespiteNoiseCopy(),
            evaluate(
                foodLoggedDays: 10,
                weightEntryCount: 3,
                calendarSpanDays: 14,
                loggingConsistencyRatio: 10.0 / 14.0
            ).userFacingSummary
        ]

        let combined = samples.joined(separator: " ").lowercased()

        XCTAssertFalse(combined.contains("diagnos"))
        XCTAssertFalse(combined.contains("prescri"))
        XCTAssertFalse(combined.contains("doctor"))
        XCTAssertFalse(combined.contains("medical"))
        XCTAssertFalse(combined.contains("crash diet"))
        XCTAssertFalse(combined.contains("slash"))
        XCTAssertFalse(combined.contains("definitely water"))
    }

    // MARK: - Helpers

    private func evaluate(
        foodLoggedDays: Int,
        weightEntryCount: Int,
        calendarSpanDays: Int,
        hasSuddenSpike: Bool = false,
        loggingConsistencyRatio: Double
    ) -> WeeklyProgressDataSufficiency {
        WeeklyProgressConfidencePolicy.evaluate(
            foodLoggedDays: foodLoggedDays,
            weightEntryCount: weightEntryCount,
            calendarSpanDays: calendarSpanDays,
            hasSuddenSpike: hasSuddenSpike,
            loggingConsistencyRatio: loggingConsistencyRatio
        )
    }
}
