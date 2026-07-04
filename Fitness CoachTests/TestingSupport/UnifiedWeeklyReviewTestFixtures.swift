//
//  UnifiedWeeklyReviewTestFixtures.swift
//  Fitness CoachTests
//
//  Shared fixtures for unified weekly review presentation tests.
//

import Foundation
@testable import Fitness_Coach

enum UnifiedWeeklyReviewTestFixtures {

    static func summary(
        base: WeeklyProgressSummary,
        verdict: WeeklyProgressVerdict? = nil,
        confidence: WeeklyProgressConfidenceLevel? = nil,
        hasSuddenSpike: Bool? = nil,
        maintenanceEstimate: MaintenanceEstimate? = nil
    ) -> WeeklyProgressSummary {
        WeeklyProgressSummary(
            id: base.id,
            startDate: base.startDate,
            endDate: base.endDate,
            generatedAt: base.generatedAt,
            confidence: confidence ?? base.confidence,
            verdict: verdict ?? base.verdict,
            nextAction: base.nextAction,
            maintenanceEstimate: maintenanceEstimate ?? base.maintenanceEstimate,
            foodLoggedDays: base.foodLoggedDays,
            totalDays: base.totalDays,
            averageDailyCalories: base.averageDailyCalories,
            averageDailyProteinGrams: base.averageDailyProteinGrams,
            proteinHitDays: base.proteinHitDays,
            calorieTargetHitDays: base.calorieTargetHitDays,
            waterTargetHitDays: base.waterTargetHitDays,
            trainingDays: base.trainingDays,
            startingWeightKg: base.startingWeightKg,
            endingWeightKg: base.endingWeightKg,
            weightChangeKg: base.weightChangeKg,
            weeklyWeightChangeKg: base.weeklyWeightChangeKg,
            hasSuddenSpike: hasSuddenSpike ?? base.hasSuddenSpike,
            headline: base.headline,
            summary: base.summary,
            primaryInsight: base.primaryInsight,
            nextActionTitle: base.nextActionTitle,
            nextActionSubtitle: base.nextActionSubtitle,
            caveats: base.caveats
        )
    }

    static func lowConfidenceMaintenanceEstimate(
        from base: MaintenanceEstimate
    ) -> MaintenanceEstimate {
        let sufficiency = WeeklyProgressDataSufficiency(
            confidence: .low,
            isEligibleForMaintenanceEstimate: true,
            isEligibleForKcalMaintenanceDisplay: false,
            isEligibleForPlanRecommendation: true,
            foodLoggedDays: base.sufficiency.foodLoggedDays,
            weightEntryCount: base.sufficiency.weightEntryCount,
            calendarSpanDays: base.sufficiency.calendarSpanDays,
            reasons: base.sufficiency.reasons,
            userFacingSummary: WeeklyProgressConfidencePolicy.confidenceCopy(for: .low)
        )

        return MaintenanceEstimate(
            method: .trendBucketOnly,
            confidence: .low,
            estimatedMaintenanceKcal: nil,
            staticTDEEKcal: base.staticTDEEKcal,
            averageDailyCalories: base.averageDailyCalories,
            estimatedDailyEnergyBalanceKcal: base.estimatedDailyEnergyBalanceKcal,
            weightChangeKg: base.weightChangeKg,
            weeklyWeightChangeKg: base.weeklyWeightChangeKg,
            trendDirection: base.trendDirection,
            sufficiency: sufficiency,
            shouldShowWaterWeightDisclaimer: base.shouldShowWaterWeightDisclaimer,
            explanation: sufficiency.userFacingSummary,
            caveats: base.caveats
        )
    }

    static func makeHealthIntelligenceSection() -> JourneyHealthIntelligenceSectionState {
        let calendar = Calendar(identifier: .gregorian)
        let weekEnd = calendar.startOfDay(
            for: calendar.date(from: DateComponents(year: 2026, month: 7, day: 3))!
        )
        let weekStart = calendar.date(byAdding: .day, value: -6, to: weekEnd)!
        let review = WeeklyHealthReview(
            weekStartDate: weekStart,
            weekEndDate: weekEnd,
            title: "Solid training week",
            summary: "You logged workouts on four days and kept protein steady.",
            stats: WeeklyStats(
                totalWorkouts: 4,
                totalWorkoutMinutes: 180,
                totalActiveCalories: 900,
                averageSteps: 8_500,
                totalSteps: 59_500,
                proteinHitDays: 5,
                calorieTargetHitDays: 4,
                waterHitDays: 4,
                averageRecoveryScore: 72,
                lowRecoveryDays: 1,
                weightChangeKg: -0.4,
                loggingConsistencyDays: 6
            ),
            wins: ["4 workouts logged", "Protein on track most days"],
            risks: ["One low-recovery day after a hard session"],
            nextWeekFocus: ["Keep protein steady", "Add one easy recovery walk"],
            confidence: .moderate,
            missingSignals: [],
            generatedAt: weekEnd
        )

        let detail = WeeklyReviewPresentationBuilder.buildDetail(from: review)!
        return JourneyHealthIntelligenceSectionState(
            weeklyReviewCard: WeeklyReviewPresentationBuilder.buildCard(from: review),
            weeklyReviewDetail: detail,
            recoveryTimeline: .loading,
            workoutHistory: .loading,
            milestones: .loading,
            progress: .loading,
            connectHealthCTA: nil,
            isLoading: false,
            errorMessage: nil,
            fallbackMessage: nil,
            staleDataLabel: nil,
            partialSignalsNote: nil,
            uiState: nil
        )
    }
}
