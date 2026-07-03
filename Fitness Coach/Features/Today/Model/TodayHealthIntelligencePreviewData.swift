//
//  TodayHealthIntelligencePreviewData.swift
//  Fitness Coach
//
//  Forma — Preview fixtures for Today Health Intelligence SwiftUI components.
//

import Foundation

enum TodayHealthIntelligencePreviewData {

    private static var referenceDay: Date {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(secondsFromGMT: 0) ?? .gmt
        return calendar.startOfDay(
            for: calendar.date(from: DateComponents(year: 2026, month: 7, day: 3))!
        )
    }

    static var readyDay: TodayHealthIntelligenceSectionState {
        build(from: readyDaySnapshot, nutritionProgress: sampleNutritionProgress)
    }

    static var workoutDay: TodayHealthIntelligenceSectionState {
        build(from: workoutDaySnapshot, nutritionProgress: sampleNutritionProgress)
    }

    static var lowRecoveryDay: TodayHealthIntelligenceSectionState {
        build(from: lowRecoveryDaySnapshot, nutritionProgress: sampleNutritionProgress)
    }

    static var noHealthData: TodayHealthIntelligenceSectionState {
        build(from: noHealthDataSnapshot)
    }

    static var loading: TodayHealthIntelligenceSectionState {
        TodayHealthIntelligencePresentationBuilder.buildSection(
            snapshot: nil,
            isLoading: true,
            isUIEnabled: true
        ) ?? fallbackLoadingSection
    }

    private static var sampleNutritionProgress: TodayHealthIntelligenceNutritionProgress {
        TodayHealthIntelligenceNutritionProgress(
            calorieRemaining: 620,
            proteinRemainingGrams: 42,
            waterRemainingMl: 800,
            hasCalorieTarget: true,
            hasProteinTarget: true,
            hasWaterTarget: true
        )
    }

    private static func build(
        from snapshot: HealthIntelligenceSnapshot,
        nutritionProgress: TodayHealthIntelligenceNutritionProgress = .unavailable
    ) -> TodayHealthIntelligenceSectionState {
        TodayHealthIntelligencePresentationBuilder.buildSection(
            snapshot: snapshot,
            nutritionProgress: nutritionProgress,
            isUIEnabled: true
        ) ?? fallbackLoadingSection
    }

    private static var fallbackLoadingSection: TodayHealthIntelligenceSectionState {
        TodayHealthIntelligenceSectionState(
            recoveryCard: .loading,
            dailyMission: .loading,
            nextBestAction: .loading,
            workoutCard: nil,
            adaptiveNutritionCard: nil,
            isLoading: true,
            fallbackMessage: nil
        )
    }

    private static var readyDaySnapshot: HealthIntelligenceSnapshot {
        HealthIntelligenceSnapshot(
            date: referenceDay,
            recovery: RecoverySummary(
                score: 84,
                status: .ready,
                title: "Ready to train",
                explanation: "Sleep and recovery signals look supportive for your usual plan today.",
                recommendedTraining: "Your usual training plan looks reasonable today.",
                recommendedNutrition: "Stick with your normal protein and hydration rhythm.",
                confidence: .high,
                contributingFactors: [],
                missingSignals: []
            ),
            workout: nil,
            activity: ActivitySummary(steps: 8_450, activeEnergyKcal: 420, exerciseMinutes: 38),
            nutritionAdjustment: .none,
            weeklyReview: nil,
            planConfidence: PlanHealthConfidence(score: 0.82, label: "High"),
            nextBestAction: .none
        )
    }

    private static var workoutDaySnapshot: HealthIntelligenceSnapshot {
        HealthIntelligenceSnapshot(
            date: referenceDay,
            recovery: RecoverySummary(
                score: 74,
                status: .moderate,
                title: "Moderate recovery",
                explanation: "Recovery is acceptable after recent training.",
                recommendedTraining: "You can train, but avoid stacking intensity tonight.",
                recommendedNutrition: "Prioritize protein and hydration after your workout.",
                confidence: .moderate,
                contributingFactors: [],
                missingSignals: []
            ),
            workout: WorkoutSummary(
                hasWorkout: true,
                primaryWorkoutType: .strength,
                title: "Strength training",
                workoutCount: 1,
                totalDurationMinutes: 50,
                totalActiveCalories: 320,
                intensity: .moderate,
                demand: .high,
                latestWorkoutStart: referenceDay,
                latestWorkoutEnd: referenceDay,
                nutritionAdvice: "Aim for 30–40g protein in your next meal.",
                hydrationAdviceMl: 700,
                explanation: "Strength training added meaningful load today.",
                confidence: .high,
                sourceSummary: "Synced workout."
            ),
            activity: ActivitySummary(steps: 9_120, activeEnergyKcal: 560, exerciseMinutes: 52),
            nutritionAdjustment: AdaptiveNutritionSummary(
                proteinRecommendationGrams: 35,
                suggestedProteinRemaining: 28,
                waterIncreaseMl: 350,
                suggestedWaterRemainingMl: 900,
                calorieAdvice: "Keep calories steady and prioritize protein after training.",
                shouldChangeTarget: false,
                suggestedCalorieAdjustment: 0,
                adjustmentReason: "",
                priority: 6,
                confidence: .high,
                missingSignals: []
            ),
            weeklyReview: nil,
            planConfidence: PlanHealthConfidence(score: 0.78, label: "Moderate"),
            nextBestAction: NextBestAction(
                id: "log-protein",
                title: "Log protein",
                message: "You still have meaningful protein left after today's workout.",
                ctaTitle: "Log meal",
                destination: .logMeal,
                priority: 2,
                reason: .postWorkoutRecovery,
                createdAt: referenceDay,
                expiresAt: nil
            )
        )
    }

    private static var lowRecoveryDaySnapshot: HealthIntelligenceSnapshot {
        HealthIntelligenceSnapshot(
            date: referenceDay,
            recovery: RecoverySummary(
                score: 48,
                status: .low,
                title: "Recovery is low",
                explanation: "Sleep was short and recent training load is elevated.",
                recommendedTraining: "Keep today lighter and avoid stacking hard sessions.",
                recommendedNutrition: "Prioritize protein, hydration, and steady fueling today.",
                confidence: .moderate,
                contributingFactors: [],
                missingSignals: []
            ),
            workout: nil,
            activity: ActivitySummary(steps: 5_600, activeEnergyKcal: 290, exerciseMinutes: 22),
            nutritionAdjustment: AdaptiveNutritionSummary(
                proteinRecommendationGrams: nil,
                suggestedProteinRemaining: nil,
                waterIncreaseMl: 250,
                suggestedWaterRemainingMl: 1_100,
                calorieAdvice: "Keep fueling steady while recovery catches up.",
                shouldChangeTarget: false,
                suggestedCalorieAdjustment: 0,
                adjustmentReason: "",
                priority: 3,
                confidence: .moderate,
                missingSignals: []
            ),
            weeklyReview: nil,
            planConfidence: PlanHealthConfidence(score: 0.62, label: "Moderate"),
            nextBestAction: NextBestAction(
                id: "recover",
                title: "Prioritize recovery",
                message: "Recovery is low today. Keep movement light and fuel steadily.",
                ctaTitle: "View recovery",
                destination: .viewRecovery,
                priority: 2,
                reason: .lowRecovery,
                createdAt: referenceDay,
                expiresAt: nil
            )
        )
    }

    private static var noHealthDataSnapshot: HealthIntelligenceSnapshot {
        HealthIntelligenceSnapshot(
            date: referenceDay,
            recovery: .unknown,
            workout: nil,
            activity: .empty,
            nutritionAdjustment: .none,
            weeklyReview: nil,
            planConfidence: .unknown,
            nextBestAction: NextBestAction(
                id: "connect-health",
                title: "Connect Apple Health",
                message: "Enable Apple Health to unlock recovery and activity insights.",
                ctaTitle: "",
                destination: .none,
                priority: 1,
                reason: .connectHealth,
                createdAt: referenceDay,
                expiresAt: nil
            )
        )
    }
}
