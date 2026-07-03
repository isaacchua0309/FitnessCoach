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

    private static var now: Date {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(secondsFromGMT: 0) ?? .gmt
        return calendar.date(from: DateComponents(year: 2026, month: 7, day: 3, hour: 12))!
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

    static var partialPermission: TodayHealthIntelligenceSectionState {
        build(
            from: sparseSnapshot,
            nutritionProgress: sampleNutritionProgress,
            availability: partialAvailability,
            isAppleHealthConnected: true,
            cachedDayCount: 5
        )
    }

    static var noPermission: TodayHealthIntelligenceSectionState {
        build(
            snapshot: nil,
            nutritionProgress: sampleNutritionProgress,
            availability: deniedAvailability,
            isAppleHealthConnected: false,
            cachedDayCount: 0
        )
    }

    static var noSleepOrHeart: TodayHealthIntelligenceSectionState {
        build(
            from: missingSleepHeartSnapshot,
            nutritionProgress: sampleNutritionProgress,
            availability: readableAvailability,
            isAppleHealthConnected: true,
            cachedDayCount: 14,
            baseline: baselineMissingSleepAndHeart
        )
    }

    static var syncFailed: TodayHealthIntelligenceSectionState {
        build(
            from: activityOnlySnapshot,
            nutritionProgress: sampleNutritionProgress,
            availability: readableAvailability,
            isAppleHealthConnected: true,
            cachedDayCount: 7,
            errorMessage: "Network unavailable",
            syncPhase: .failed
        )
    }

    static var noWorkoutHistory: TodayHealthIntelligenceSectionState {
        build(
            from: activityOnlySnapshot,
            nutritionProgress: sampleNutritionProgress,
            availability: readableAvailability,
            isAppleHealthConnected: true,
            cachedDayCount: 10,
            baseline: baselineWithoutWorkouts
        )
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
        nutritionProgress: TodayHealthIntelligenceNutritionProgress = .unavailable,
        availability: HealthDataAvailability? = nil,
        isAppleHealthConnected: Bool = false,
        cachedDayCount: Int = 0,
        errorMessage: String? = nil,
        syncPhase: HealthSyncPhase? = nil,
        baseline: HealthBaselineContext? = nil
    ) -> TodayHealthIntelligenceSectionState {
        build(
            snapshot: snapshot,
            nutritionProgress: nutritionProgress,
            availability: availability,
            isAppleHealthConnected: isAppleHealthConnected,
            cachedDayCount: cachedDayCount,
            errorMessage: errorMessage,
            syncPhase: syncPhase,
            baseline: baseline
        )
    }

    private static func build(
        snapshot: HealthIntelligenceSnapshot?,
        nutritionProgress: TodayHealthIntelligenceNutritionProgress = .unavailable,
        availability: HealthDataAvailability? = nil,
        isAppleHealthConnected: Bool = false,
        cachedDayCount: Int = 0,
        errorMessage: String? = nil,
        syncPhase: HealthSyncPhase? = nil,
        baseline: HealthBaselineContext? = nil
    ) -> TodayHealthIntelligenceSectionState {
        TodayHealthIntelligencePresentationBuilder.buildSection(
            snapshot: snapshot,
            nutritionProgress: nutritionProgress,
            isUIEnabled: true,
            availability: availability,
            isAppleHealthConnected: isAppleHealthConnected,
            cachedDayCount: cachedDayCount,
            errorMessage: errorMessage,
            syncPhase: syncPhase,
            baseline: baseline
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
            fallbackMessage: nil,
            uiState: nil,
            staleDataLabel: nil
        )
    }

    // MARK: - Availability fixtures

    private static var readableAvailability: HealthDataAvailability {
        HealthDataAvailability(
            isHealthDataAvailable: true,
            permissionStatus: .uniform(.available, isHealthDataAvailable: true),
            cachedDayCount: 7
        )
    }

    private static var deniedAvailability: HealthDataAvailability {
        HealthDataAvailability(
            isHealthDataAvailable: true,
            permissionStatus: .uniform(.denied, isHealthDataAvailable: true),
            cachedDayCount: 0
        )
    }

    private static var partialAvailability: HealthDataAvailability {
        var access: [HealthSignalKind: HealthSignalAccess] = [:]
        for signal in HealthSignalKind.allCases {
            access[signal] = signal == .stepCount ? .available : .denied
        }
        return HealthDataAvailability(
            isHealthDataAvailable: true,
            permissionStatus: HealthPermissionStatus(
                isHealthDataAvailable: true,
                signalAccess: access,
                resolvedAt: now
            ),
            cachedDayCount: 5
        )
    }

    // MARK: - Baseline fixtures

    private static var baselineWithoutWorkouts: HealthBaselineContext {
        HealthBaselineContext(
            targetDate: referenceDay,
            averageSteps7d: 8_000,
            averageSteps28d: 7_500,
            averageActiveEnergy7d: 400,
            averageActiveEnergy28d: 380,
            averageSleepDuration7d: 7.5,
            averageSleepDuration28d: 7.2,
            averageRestingHeartRate28d: 58,
            averageHRV28d: 45,
            averageWorkoutLoad28d: nil,
            workoutDays7d: 0,
            workoutDays28d: 0,
            availableSignals: [.steps, .activeEnergy, .sleep, .restingHeartRate, .hrv],
            missingSignals: [.workoutLoad]
        )
    }

    private static var baselineMissingSleepAndHeart: HealthBaselineContext {
        HealthBaselineContext(
            targetDate: referenceDay,
            averageSteps7d: 8_000,
            averageSteps28d: 7_500,
            averageActiveEnergy7d: 400,
            averageActiveEnergy28d: 380,
            averageSleepDuration7d: nil,
            averageSleepDuration28d: nil,
            averageRestingHeartRate28d: nil,
            averageHRV28d: nil,
            averageWorkoutLoad28d: 120,
            workoutDays7d: 2,
            workoutDays28d: 8,
            availableSignals: [.steps, .activeEnergy, .workoutLoad],
            missingSignals: [.sleep, .restingHeartRate, .hrv]
        )
    }

    // MARK: - Snapshot fixtures

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

    private static var sparseSnapshot: HealthIntelligenceSnapshot {
        HealthIntelligenceSnapshot(
            date: referenceDay,
            recovery: RecoverySummary(
                score: nil,
                status: .unknown,
                title: "Recovery forming",
                explanation: "Limited signals available today.",
                recommendedTraining: "Use how you feel today.",
                recommendedNutrition: "Keep logging meals and water.",
                confidence: .low,
                contributingFactors: [],
                missingSignals: [.sleep, .hrv]
            ),
            workout: nil,
            activity: ActivitySummary(steps: 4_500, activeEnergyKcal: nil, exerciseMinutes: nil),
            nutritionAdjustment: .none,
            weeklyReview: nil,
            planConfidence: .unknown,
            nextBestAction: .none
        )
    }

    private static var missingSleepHeartSnapshot: HealthIntelligenceSnapshot {
        HealthIntelligenceSnapshot(
            date: referenceDay,
            recovery: RecoverySummary(
                score: 58,
                status: .moderate,
                title: "Moderate recovery",
                explanation: "Sleep and heart signals are limited today.",
                recommendedTraining: "Train with care.",
                recommendedNutrition: "Prioritize protein and hydration.",
                confidence: .moderate,
                contributingFactors: [],
                missingSignals: [.sleep, .restingHeartRate, .hrv]
            ),
            workout: .noWorkout,
            activity: ActivitySummary(steps: 7_000, activeEnergyKcal: 350, exerciseMinutes: 25),
            nutritionAdjustment: .none,
            weeklyReview: nil,
            planConfidence: PlanHealthConfidence(score: 0.5, label: "Moderate"),
            nextBestAction: .none
        )
    }

    private static var activityOnlySnapshot: HealthIntelligenceSnapshot {
        HealthIntelligenceSnapshot(
            date: referenceDay,
            recovery: RecoverySummary(
                score: 60,
                status: .moderate,
                title: "Moderate recovery",
                explanation: "Activity signals are available.",
                recommendedTraining: "Steady pacing may work well today.",
                recommendedNutrition: "Keep protein on track.",
                confidence: .moderate,
                contributingFactors: [],
                missingSignals: [.sleep, .hrv]
            ),
            workout: .noWorkout,
            activity: ActivitySummary(steps: 8_000, activeEnergyKcal: 400, exerciseMinutes: 30),
            nutritionAdjustment: .none,
            weeklyReview: nil,
            planConfidence: PlanHealthConfidence(score: 0.5, label: "Moderate"),
            nextBestAction: .none
        )
    }
}
