//
//  HealthIntelligenceDependencies.swift
//  Fitness Coach
//
//  Typed Health Intelligence engine and snapshot bundle for AppContainer wiring.
//

import Foundation

/// Resolved Health Intelligence services for `AppContainer`.
struct HealthIntelligenceDependencies {
    let healthIntelligenceContextBuilder: HealthIntelligenceContextBuilder
    let healthIntelligenceEngine: any HealthIntelligenceEngineing
    let healthIntelligenceSnapshotService: any HealthIntelligenceSnapshotServing
    let weeklyReviewService: any WeeklyReviewServing

    static func build(
        health: HealthDependencies,
        persistence: PersistenceDependencies
    ) -> HealthIntelligenceDependencies {
        let healthIntelligenceContextBuilder = HealthIntelligenceContextBuilder(
            repository: health.healthDataRepository,
            nutritionProvider: DailyLogNutritionProvider(reader: persistence.dailyLogService),
            weightProvider: WeightLogWeightProvider(reader: persistence.weightLogService),
            userPlanProvider: UserProfilePlanProvider(profileService: persistence.userProfileService)
        )
        let healthIntelligenceEngine = HealthIntelligenceEngine(
            contextBuilder: healthIntelligenceContextBuilder,
            dependencies: HealthIntelligenceEngineDependencies(
                trainingLoad: health.trainingLoadEngine,
                workout: health.workoutIntelligenceEngine,
                recovery: health.recoveryEngine,
                adaptiveNutrition: health.adaptiveNutritionEngine,
                nextBestAction: health.nextBestActionEngine,
                weeklyReview: health.weeklyReviewEngine
            )
        )
        let healthIntelligenceSnapshotService = HealthIntelligenceSnapshotService(
            engine: healthIntelligenceEngine,
            cacheStore: health.healthCacheStore,
            enginesEnabled: HealthIntelligenceFeatureFlags.healthIntelligenceEnginesEnabled
        )
        health.healthSyncStateStore.setSnapshotService(healthIntelligenceSnapshotService)
        let weeklyReviewService = WeeklyReviewService(
            contextBuilder: healthIntelligenceContextBuilder,
            weeklyReviewEngine: health.weeklyReviewEngine,
            recoveryEngine: health.recoveryEngine,
            trainingLoadEngine: health.trainingLoadEngine,
            cacheStore: health.healthCacheStore,
            enginesEnabled: HealthIntelligenceFeatureFlags.healthIntelligenceEnginesEnabled,
            weeklyReviewEnabled: HealthIntelligenceFeatureFlags.healthIntelligenceWeeklyReviewEnabled
        )

        #if DEBUG
        HealthIntelligenceEngineLogger.wiringRegistered(
            fields: [
                "enginesEnabled": String(HealthIntelligenceFeatureFlags.healthIntelligenceEnginesEnabled),
                "uiEnabled": String(HealthIntelligenceFeatureFlags.isUIEnabled),
                "repository": "HealthDataRepository",
                "contextBuilder": "HealthIntelligenceContextBuilder"
            ]
        )
        #endif

        return HealthIntelligenceDependencies(
            healthIntelligenceContextBuilder: healthIntelligenceContextBuilder,
            healthIntelligenceEngine: healthIntelligenceEngine,
            healthIntelligenceSnapshotService: healthIntelligenceSnapshotService,
            weeklyReviewService: weeklyReviewService
        )
    }
}
