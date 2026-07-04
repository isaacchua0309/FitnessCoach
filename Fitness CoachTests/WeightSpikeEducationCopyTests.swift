//
//  WeightSpikeEducationCopyTests.swift
//  Fitness CoachTests
//

import XCTest
@testable import Fitness_Coach

final class WeightSpikeEducationCopyTests: XCTestCase {

    func testCentralizedCopyIncludesRequiredVariants() {
        let copy = FormaProductCopy.WeightSpikeEducation.self

        XCTAssertFalse(copy.shortTitle.isEmpty)
        XCTAssertFalse(copy.shortBody.isEmpty)
        XCTAssertFalse(copy.detailBody.isEmpty)
        XCTAssertFalse(copy.accessibilityLabel.isEmpty)
        XCTAssertTrue(copy.detailBody.count > copy.shortBody.count)
    }

    func testCopyAvoidsDiagnosticClaims() {
        let combined = [
            FormaProductCopy.WeightSpikeEducation.shortBody,
            FormaProductCopy.WeightSpikeEducation.detailBody,
            FormaProductCopy.WeightSpikeEducation.waitRecommendationReason,
            FormaProductCopy.WeightSpikeEducation.holdSteadyNote
        ].joined(separator: " ").lowercased()

        XCTAssertFalse(combined.contains("diagnos"))
        XCTAssertFalse(combined.contains("definitely water"))
        XCTAssertFalse(combined.contains("water weight"))
    }

    func testConfidencePolicyDelegatesToCentralizedCopy() {
        XCTAssertEqual(
            WeeklyProgressConfidencePolicy.waterWeightNoiseWarningCopy(),
            FormaProductCopy.WeightSpikeEducation.shortBody
        )
        XCTAssertEqual(
            WeeklyProgressConfidencePolicy.holdSteadyDespiteNoiseCopy(),
            FormaProductCopy.WeightSpikeEducation.holdSteadyNote
        )
    }

    func testNoisySummaryUsesWaitRecommendationPolicyCopy() {
        let dashboard = JourneyPreviewData.strongMomentum
        var summary = dashboard.weeklyProgressSummary
        summary = WeeklyProgressSummary(
            id: summary.id,
            startDate: summary.startDate,
            endDate: summary.endDate,
            generatedAt: summary.generatedAt,
            confidence: summary.confidence,
            verdict: .noisyButLikelyOkay,
            nextAction: .holdSteady,
            maintenanceEstimate: summary.maintenanceEstimate,
            foodLoggedDays: summary.foodLoggedDays,
            totalDays: summary.totalDays,
            averageDailyCalories: summary.averageDailyCalories,
            averageDailyProteinGrams: summary.averageDailyProteinGrams,
            proteinHitDays: summary.proteinHitDays,
            calorieTargetHitDays: summary.calorieTargetHitDays,
            waterTargetHitDays: summary.waterTargetHitDays,
            trainingDays: summary.trainingDays,
            startingWeightKg: summary.startingWeightKg,
            endingWeightKg: summary.endingWeightKg,
            weightChangeKg: summary.weightChangeKg,
            weeklyWeightChangeKg: summary.weeklyWeightChangeKg,
            hasSuddenSpike: true,
            headline: summary.headline,
            summary: summary.summary,
            primaryInsight: summary.primaryInsight,
            nextActionTitle: summary.nextActionTitle,
            nextActionSubtitle: summary.nextActionSubtitle,
            caveats: summary.caveats
        )

        let recommendation = PlanRecommendationPolicy.recommend(
            PlanRecommendationInput(
                summary: summary,
                currentCalorieTargetKcal: 2_000,
                staticTDEEKcal: 2_400,
                calorieFloorKcal: 1_500,
                goalDirection: .lose
            )
        )

        XCTAssertEqual(recommendation.kind, .waitBecauseScaleIsNoisy)
        XCTAssertEqual(
            recommendation.title,
            FormaProductCopy.WeightSpikeEducation.waitRecommendationTitle
        )
        XCTAssertEqual(
            recommendation.message,
            FormaProductCopy.WeightSpikeEducation.waitRecommendationMessage
        )
        XCTAssertFalse(recommendation.shouldShowPlanCTA)
    }
}
