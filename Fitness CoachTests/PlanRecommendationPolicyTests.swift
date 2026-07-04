//
//  PlanRecommendationPolicyTests.swift
//  Fitness CoachTests
//
//  Forma — Unit tests for safe weekly plan recommendation policy.
//

import XCTest
@testable import Fitness_Coach

final class PlanRecommendationPolicyTests: XCTestCase {

    private let automaticChangeDisclaimer =
        "Forma will not change your plan automatically — review and confirm any update."

    // MARK: - Core recommendation kinds

    func testInsufficientDataShowsKeepLogging() {
        let recommendation = recommend(
            verdict: .notEnoughData,
            confidence: .unavailable,
            sufficiency: unavailableSufficiency()
        )

        XCTAssertEqual(recommendation.kind, .notEnoughData)
        XCTAssertFalse(recommendation.shouldShowPlanCTA)
        XCTAssertNil(recommendation.suggestedCalorieDelta)
    }

    func testPoorLoggingShowsImproveConsistency() {
        let recommendation = recommend(
            verdict: .needsConsistencyFirst,
            confidence: .medium,
            sufficiency: sufficiency(
                confidence: .medium,
                reasons: [.inconsistentLogging]
            )
        )

        XCTAssertEqual(recommendation.kind, .improveConsistencyFirst)
        XCTAssertFalse(recommendation.shouldShowPlanCTA)
        XCTAssertNil(recommendation.suggestedCalorieDelta)
    }

    func testOnTrackShowsHoldSteady() {
        let recommendation = recommend(
            verdict: .onTrack,
            confidence: .medium,
            trendDirection: .losingAboutAsExpected
        )

        XCTAssertEqual(recommendation.kind, .holdSteady)
        XCTAssertFalse(recommendation.shouldShowPlanCTA)
        XCTAssertNil(recommendation.suggestedCalorieDelta)
    }

    func testLosingTooFastSuggestsSmallIncrease() {
        let recommendation = recommend(
            verdict: .likelyTooAggressive,
            confidence: .medium,
            trendDirection: .losingFasterThanExpected,
            weeklyWeightChangeKg: -1.2,
            endingWeightKg: 80
        )

        XCTAssertEqual(recommendation.kind, .considerSmallIncrease)
        XCTAssertTrue(recommendation.shouldShowPlanCTA)
        XCTAssertEqual(recommendation.suggestedCalorieDelta, 150)
    }

    func testLosingTooSlowWithGoodAdherenceSuggestsReviewPlan() {
        let recommendation = recommend(
            verdict: .likelyTooSlow,
            confidence: .high,
            trendDirection: .losingSlowerThanExpected,
            weeklyWeightChangeKg: -0.1,
            foodLoggedDays: 7,
            calorieTargetHitDays: 6,
            currentCalorieTargetKcal: 2_233,
            staticTDEEKcal: 2_400
        )

        XCTAssertEqual(recommendation.kind, .considerSmallDecrease)
        XCTAssertTrue(recommendation.shouldShowPlanCTA)
        XCTAssertEqual(recommendation.suggestedCalorieDelta, -100)
    }

    func testLosingTooSlowWithPoorAdherenceDoesNotSuggestDecrease() {
        let recommendation = recommend(
            verdict: .likelyTooSlow,
            confidence: .high,
            trendDirection: .losingSlowerThanExpected,
            weeklyWeightChangeKg: -0.1,
            foodLoggedDays: 7,
            calorieTargetHitDays: 2
        )

        XCTAssertEqual(recommendation.kind, .improveConsistencyFirst)
        XCTAssertNil(recommendation.suggestedCalorieDelta)
        XCTAssertTrue(
            recommendation.reasons.contains {
                $0.contains("adherence") || $0.contains("consistency")
            }
        )
    }

    func testWeightSpikeSuggestsWait() {
        let recommendation = recommend(
            verdict: .noisyButLikelyOkay,
            confidence: .medium,
            hasSuddenSpike: true,
            sufficiency: sufficiency(
                confidence: .medium,
                reasons: [.weightTrendTooNoisy]
            )
        )

        XCTAssertEqual(recommendation.kind, .waitBecauseScaleIsNoisy)
        XCTAssertFalse(recommendation.shouldShowPlanCTA)
        XCTAssertNil(recommendation.suggestedCalorieDelta)
    }

    func testLowConfidenceDoesNotSuggestCalorieDelta() {
        let recommendation = recommend(
            verdict: .likelyTooAggressive,
            confidence: .low,
            trendDirection: .losingFasterThanExpected,
            weeklyWeightChangeKg: -1.0,
            endingWeightKg: 80
        )

        XCTAssertEqual(recommendation.kind, .reviewPlanManually)
        XCTAssertNil(recommendation.suggestedCalorieDelta)
        XCTAssertTrue(recommendation.shouldShowPlanCTA)
    }

    // MARK: - Safety & copy

    func testSuggestedDeltaNeverExceedsSmallSafeRange() {
        let aggressive = recommend(
            verdict: .likelyTooAggressive,
            confidence: .high,
            trendDirection: .losingFasterThanExpected,
            weeklyWeightChangeKg: -2.0,
            endingWeightKg: 80
        )
        let moderate = recommend(
            verdict: .likelyTooAggressive,
            confidence: .high,
            trendDirection: .losingFasterThanExpected,
            weeklyWeightChangeKg: -0.6,
            endingWeightKg: 80
        )
        let decrease = recommend(
            verdict: .likelyTooSlow,
            confidence: .high,
            trendDirection: .losingSlowerThanExpected,
            weeklyWeightChangeKg: -0.1,
            foodLoggedDays: 7,
            calorieTargetHitDays: 6
        )

        XCTAssertEqual(aggressive.suggestedCalorieDelta, 150)
        XCTAssertEqual(moderate.suggestedCalorieDelta, 100)
        XCTAssertEqual(decrease.suggestedCalorieDelta, -100)

        for delta in [aggressive, moderate, decrease].compactMap(\.suggestedCalorieDelta) {
            XCTAssertLessThanOrEqual(abs(delta), 150)
            XCTAssertTrue(
                PlanRecommendationPolicy.validatedCalorieDelta(
                    proposedDelta: delta,
                    currentTargetKcal: 2_233,
                    tdeeKcal: 2_400,
                    calorieFloorKcal: 1_500
                ) == delta
            )
        }
    }

    func testRecommendationNeverAutoApplies() {
        let scenarios: [WeeklyPlanRecommendation] = [
            recommend(verdict: .notEnoughData, confidence: .unavailable, sufficiency: unavailableSufficiency()),
            recommend(verdict: .onTrack, confidence: .medium),
            recommend(verdict: .needsConsistencyFirst, confidence: .medium, sufficiency: sufficiency(confidence: .medium, reasons: [.inconsistentLogging])),
            recommend(verdict: .likelyTooAggressive, confidence: .medium, trendDirection: .losingFasterThanExpected, weeklyWeightChangeKg: -1.0, endingWeightKg: 80),
            recommend(verdict: .noisyButLikelyOkay, confidence: .medium, hasSuddenSpike: true, sufficiency: sufficiency(confidence: .medium, reasons: [.weightTrendTooNoisy]))
        ]

        for recommendation in scenarios {
            XCTAssertTrue(
                recommendation.safetyNotes.contains(automaticChangeDisclaimer),
                "Missing disclaimer for \(recommendation.kind)"
            )
        }
    }

    func testRecommendationCopyIsSupportive() {
        let recommendation = recommend(
            verdict: .likelyTooSlow,
            confidence: .high,
            trendDirection: .losingSlowerThanExpected,
            weeklyWeightChangeKg: -0.1,
            foodLoggedDays: 7,
            calorieTargetHitDays: 2
        )

        let combined = [
            recommendation.title,
            recommendation.message,
            recommendation.reasons.joined(separator: " ")
        ].joined(separator: " ").lowercased()

        XCTAssertFalse(combined.contains("you failed"))
        XCTAssertFalse(combined.contains("bad job"))
        XCTAssertTrue(combined.contains("consistency") || combined.contains("logging"))
    }

    func testRecommendationHasCTAOnlyWhenAppropriate() {
        let holdSteady = recommend(verdict: .onTrack, confidence: .medium)
        let insufficient = recommend(
            verdict: .notEnoughData,
            confidence: .unavailable,
            sufficiency: unavailableSufficiency()
        )
        let wait = recommend(
            verdict: .noisyButLikelyOkay,
            confidence: .medium,
            hasSuddenSpike: true,
            sufficiency: sufficiency(confidence: .medium, reasons: [.weightTrendTooNoisy])
        )
        let increase = recommend(
            verdict: .likelyTooAggressive,
            confidence: .medium,
            trendDirection: .losingFasterThanExpected,
            weeklyWeightChangeKg: -1.0,
            endingWeightKg: 80
        )

        XCTAssertFalse(holdSteady.shouldShowPlanCTA)
        XCTAssertNil(holdSteady.ctaTitle)

        XCTAssertFalse(insufficient.shouldShowPlanCTA)
        XCTAssertNil(insufficient.ctaTitle)

        XCTAssertFalse(wait.shouldShowPlanCTA)
        XCTAssertNil(wait.ctaTitle)

        XCTAssertTrue(increase.shouldShowPlanCTA)
        XCTAssertEqual(increase.ctaTitle, "Review plan")
    }

    // MARK: - Fixtures

    private func recommend(
        verdict: WeeklyProgressVerdict,
        confidence: WeeklyProgressConfidenceLevel,
        trendDirection: MaintenanceTrendDirection = .unclear,
        weeklyWeightChangeKg: Double? = nil,
        endingWeightKg: Double = 80,
        startingWeightKg: Double = 80.5,
        foodLoggedDays: Int = 7,
        calorieTargetHitDays: Int = 5,
        hasSuddenSpike: Bool = false,
        sufficiency: WeeklyProgressDataSufficiency? = nil,
        currentCalorieTargetKcal: Int = 2_233,
        staticTDEEKcal: Int = 2_400,
        calorieFloorKcal: Int = 1_500
    ) -> WeeklyPlanRecommendation {
        let resolvedSufficiency = sufficiency ?? self.sufficiency(
            confidence: confidence,
            foodLoggedDays: foodLoggedDays,
            hasSuddenSpike: hasSuddenSpike
        )

        let maintenance = MaintenanceEstimate(
            method: confidence == .low ? .trendBucketOnly : .learnedEnergyBalance,
            confidence: confidence,
            estimatedMaintenanceKcal: confidence == .low ? nil : 2_500,
            staticTDEEKcal: staticTDEEKcal,
            averageDailyCalories: 2_100,
            estimatedDailyEnergyBalanceKcal: -200,
            weightChangeKg: weeklyWeightChangeKg,
            weeklyWeightChangeKg: weeklyWeightChangeKg,
            trendDirection: trendDirection,
            sufficiency: resolvedSufficiency,
            shouldShowWaterWeightDisclaimer: hasSuddenSpike,
            explanation: resolvedSufficiency.userFacingSummary,
            caveats: []
        )

        let summary = WeeklyProgressSummary(
            id: "policy-test",
            startDate: Date(timeIntervalSince1970: 0),
            endDate: Date(timeIntervalSince1970: 86_400 * 7),
            generatedAt: Date(timeIntervalSince1970: 0),
            confidence: confidence,
            verdict: verdict,
            nextAction: .reviewPlan,
            maintenanceEstimate: maintenance,
            foodLoggedDays: foodLoggedDays,
            totalDays: 7,
            averageDailyCalories: 2_100,
            averageDailyProteinGrams: 170,
            proteinHitDays: 5,
            calorieTargetHitDays: calorieTargetHitDays,
            waterTargetHitDays: 5,
            trainingDays: nil,
            startingWeightKg: startingWeightKg,
            endingWeightKg: endingWeightKg,
            weightChangeKg: weeklyWeightChangeKg,
            weeklyWeightChangeKg: weeklyWeightChangeKg,
            hasSuddenSpike: hasSuddenSpike,
            headline: "Test headline",
            summary: "Test summary",
            primaryInsight: "Test insight",
            nextActionTitle: "Review your plan",
            nextActionSubtitle: "Test subtitle",
            caveats: []
        )

        return PlanRecommendationPolicy.recommend(
            PlanRecommendationInput(
                summary: summary,
                currentCalorieTargetKcal: currentCalorieTargetKcal,
                staticTDEEKcal: staticTDEEKcal,
                calorieFloorKcal: calorieFloorKcal,
                goalDirection: .lose
            )
        )
    }

    private func sufficiency(
        confidence: WeeklyProgressConfidenceLevel,
        foodLoggedDays: Int = 7,
        weightEntryCount: Int = 4,
        calendarSpanDays: Int = 14,
        reasons: [WeeklyProgressInsufficientDataReason] = [],
        hasSuddenSpike: Bool = false
    ) -> WeeklyProgressDataSufficiency {
        WeeklyProgressDataSufficiency(
            confidence: confidence,
            isEligibleForMaintenanceEstimate: confidence != .unavailable,
            isEligibleForKcalMaintenanceDisplay: confidence == .medium || confidence == .high,
            isEligibleForPlanRecommendation: confidence != .unavailable,
            foodLoggedDays: foodLoggedDays,
            weightEntryCount: weightEntryCount,
            calendarSpanDays: calendarSpanDays,
            reasons: reasons,
            userFacingSummary: WeeklyProgressConfidencePolicy.confidenceCopy(for: confidence)
        )
    }

    private func unavailableSufficiency() -> WeeklyProgressDataSufficiency {
        WeeklyProgressDataSufficiency(
            confidence: .unavailable,
            isEligibleForMaintenanceEstimate: false,
            isEligibleForKcalMaintenanceDisplay: false,
            isEligibleForPlanRecommendation: false,
            foodLoggedDays: 2,
            weightEntryCount: 1,
            calendarSpanDays: 3,
            reasons: [.notEnoughFoodLoggedDays, .notEnoughWeightEntries],
            userFacingSummary: WeeklyProgressConfidencePolicy.insufficientDataCopy(
                for: [.notEnoughFoodLoggedDays]
            )
        )
    }
}
