//
//  PlanWeeklyRecommendationTestFixtures.swift
//  Fitness CoachTests
//
//  Shared fixtures for Plan weekly recommendation integration tests.
//

import Foundation
@testable import Fitness_Coach

enum PlanWeeklyRecommendationTestFixtures {

    static var strongSummary: WeeklyProgressSummary {
        JourneyPreviewData.strongMomentum.weeklyProgressSummary
    }

    static var insufficientSummary: WeeklyProgressSummary {
        JourneyPreviewData.brandNewUser.weeklyProgressSummary
    }

    static func summary(
        base: WeeklyProgressSummary = strongSummary,
        verdict: WeeklyProgressVerdict? = nil,
        confidence: WeeklyProgressConfidenceLevel? = nil,
        hasSuddenSpike: Bool? = nil,
        maintenanceEstimate: MaintenanceEstimate? = nil
    ) -> WeeklyProgressSummary {
        UnifiedWeeklyReviewTestFixtures.summary(
            base: base,
            verdict: verdict,
            confidence: confidence,
            hasSuddenSpike: hasSuddenSpike,
            maintenanceEstimate: maintenanceEstimate
        )
    }

    static func maintenanceEstimate(
        base: MaintenanceEstimate = strongSummary.maintenanceEstimate,
        confidence: WeeklyProgressConfidenceLevel,
        method: MaintenanceEstimateMethod? = nil,
        estimatedMaintenanceKcal: Int? = nil,
        trendDirection: MaintenanceTrendDirection? = nil,
        reasons: [WeeklyProgressInsufficientDataReason] = [],
        hasSuddenSpike: Bool = false
    ) -> MaintenanceEstimate {
        let eligibleForKcal = confidence == .medium || confidence == .high
        let sufficiency = WeeklyProgressDataSufficiency(
            confidence: confidence,
            isEligibleForMaintenanceEstimate: confidence != .unavailable,
            isEligibleForKcalMaintenanceDisplay: eligibleForKcal,
            isEligibleForPlanRecommendation: confidence != .unavailable,
            foodLoggedDays: base.sufficiency.foodLoggedDays,
            weightEntryCount: base.sufficiency.weightEntryCount,
            calendarSpanDays: base.sufficiency.calendarSpanDays,
            reasons: reasons,
            userFacingSummary: WeeklyProgressConfidencePolicy.confidenceCopy(
                for: confidence,
                hasSuddenSpike: hasSuddenSpike
            )
        )

        let resolvedMethod: MaintenanceEstimateMethod
        if let method {
            resolvedMethod = method
        } else if confidence == .unavailable || confidence == .low {
            resolvedMethod = .trendBucketOnly
        } else if confidence == .medium, base.staticTDEEKcal != nil {
            resolvedMethod = .conservativeBlend
        } else {
            resolvedMethod = .learnedEnergyBalance
        }

        let learnedKcal: Int?
        if let estimatedMaintenanceKcal {
            learnedKcal = estimatedMaintenanceKcal
        } else if eligibleForKcal {
            learnedKcal = base.estimatedMaintenanceKcal ?? 2_500
        } else {
            learnedKcal = nil
        }

        return MaintenanceEstimate(
            method: resolvedMethod,
            confidence: confidence,
            estimatedMaintenanceKcal: learnedKcal,
            staticTDEEKcal: base.staticTDEEKcal,
            averageDailyCalories: base.averageDailyCalories,
            estimatedDailyEnergyBalanceKcal: base.estimatedDailyEnergyBalanceKcal,
            weightChangeKg: base.weightChangeKg,
            weeklyWeightChangeKg: base.weeklyWeightChangeKg,
            trendDirection: trendDirection ?? base.trendDirection,
            sufficiency: sufficiency,
            shouldShowWaterWeightDisclaimer: hasSuddenSpike,
            explanation: sufficiency.userFacingSummary,
            caveats: base.caveats
        )
    }

    static func holdSteadySummary() -> WeeklyProgressSummary {
        summary(
            verdict: .onTrack,
            confidence: .medium,
            maintenanceEstimate: maintenanceEstimate(
                confidence: .medium,
                trendDirection: .losingAboutAsExpected
            )
        )
    }

    static func reviewPlanSummary() -> WeeklyProgressSummary {
        let base = strongSummary
        let maintenance = maintenanceEstimate(
            base: base,
            confidence: .medium,
            trendDirection: .losingFasterThanExpected
        )

        return WeeklyProgressSummary(
            id: base.id,
            startDate: base.startDate,
            endDate: base.endDate,
            generatedAt: base.generatedAt,
            confidence: .medium,
            verdict: .likelyTooAggressive,
            nextAction: .reviewPlan,
            maintenanceEstimate: maintenance,
            foodLoggedDays: base.foodLoggedDays,
            totalDays: base.totalDays,
            averageDailyCalories: base.averageDailyCalories,
            averageDailyProteinGrams: base.averageDailyProteinGrams,
            proteinHitDays: base.proteinHitDays,
            calorieTargetHitDays: base.calorieTargetHitDays,
            waterTargetHitDays: base.waterTargetHitDays,
            trainingDays: base.trainingDays,
            startingWeightKg: base.startingWeightKg,
            endingWeightKg: base.endingWeightKg ?? 80,
            weightChangeKg: -1.0,
            weeklyWeightChangeKg: -1.0,
            hasSuddenSpike: false,
            headline: base.headline,
            summary: base.summary,
            primaryInsight: base.primaryInsight,
            nextActionTitle: base.nextActionTitle,
            nextActionSubtitle: base.nextActionSubtitle,
            caveats: base.caveats
        )
    }

    static func improveConsistencySummary() -> WeeklyProgressSummary {
        summary(
            verdict: .needsConsistencyFirst,
            confidence: .medium,
            maintenanceEstimate: maintenanceEstimate(
                confidence: .medium,
                reasons: [.inconsistentLogging]
            )
        )
    }

    static func waitBecauseNoisySummary() -> WeeklyProgressSummary {
        summary(
            verdict: .noisyButLikelyOkay,
            confidence: .medium,
            hasSuddenSpike: true,
            maintenanceEstimate: maintenanceEstimate(
                confidence: .medium,
                reasons: [.weightTrendTooNoisy],
                hasSuddenSpike: true
            )
        )
    }

    static func lowConfidenceAggressiveSummary() -> WeeklyProgressSummary {
        summary(
            verdict: .likelyTooAggressive,
            confidence: .low,
            maintenanceEstimate: maintenanceEstimate(
                confidence: .low,
                trendDirection: .losingFasterThanExpected
            )
        )
    }
}

struct FixedWeeklyProgressSummaryBuilder: WeeklyProgressSummaryBuilding {
    let summary: WeeklyProgressSummary

    func buildSummary(
        asOf date: Date,
        profile: UserProfile?,
        dailyLogs: [DailyLog],
        weightEntries: [WeightEntry],
        trainingDayStarts: Set<Date>?
    ) -> WeeklyProgressSummary {
        summary
    }
}
