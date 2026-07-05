//
//  HealthDependencies.swift
//  Fitness Coach
//
//  Typed health platform dependency bundle for AppContainer wiring.
//

import Foundation

/// Resolved HealthKit, sync, cache, and training infrastructure for `AppContainer`.
struct HealthDependencies {
    let healthTrainingService: HealthTrainingService
    let healthKitWorkoutReader: HealthKitWorkoutReading
    let healthKitStepReader: HealthKitStepReading
    let healthCacheStore: LocalHealthCacheStore
    let healthDataRepository: HealthDataRepository
    let healthBaselineService: HealthBaselineService
    let trainingLoadEngine: TrainingLoadEngine
    let workoutIntelligenceEngine: WorkoutIntelligenceEngine
    let recoveryEngine: RecoveryEngine
    let adaptiveNutritionEngine: AdaptiveNutritionEngine
    let nextBestActionEngine: HealthNextBestActionEngine
    let weeklyReviewEngine: WeeklyReviewEngine
    let healthActivityQueryService: HealthActivityQueryService
    let healthSyncService: HealthSyncService
    let healthIntegrationConnectionStore: any HealthIntegrationConnectionStoring
    let healthSummarySyncConsentStorage: any HealthSummarySyncConsentStoring
    let healthSummarySyncConsentStore: HealthSummarySyncConsentStore
    let healthSummaryRemoteSyncClient: any HealthSummaryRemoteSyncing
    let healthSummarySyncService: HealthSummarySyncService
    let healthSyncStateStore: HealthSyncStateStore
    let trainingInsightsStore: TrainingInsightsStore
    let trainingInsightsModel: TrainingInsightsModel

    /// Builds shared health platform dependencies for `AppContainer`.
    ///
    /// Requires auth session wiring for UID-scoped cache/consent stores and the refresh bus.
    static func build(
        session: AuthDependencies,
        inMemory: Bool
    ) -> HealthDependencies {
        let healthTrainingService = HealthTrainingService()
        let sharedHealthKitManager = HealthKitManager()
        let workoutReader = HealthTrainingReaderFactory.makeWorkoutReader(
            healthKitManager: sharedHealthKitManager
        )
        let stepReader = HealthTrainingReaderFactory.makeStepReader(
            healthKitManager: sharedHealthKitManager
        )
        let healthCacheStore = LocalHealthCacheStore(userProvider: session.authUIDCache)
        let healthDataRepository = HealthDataRepository(
            healthKitManager: sharedHealthKitManager,
            cacheStore: healthCacheStore
        )
        let healthBaselineService = HealthBaselineService(repository: healthDataRepository)
        let trainingLoadEngine = TrainingLoadEngine()
        let workoutIntelligenceEngine = WorkoutIntelligenceEngine()
        let recoveryEngine = RecoveryEngine()
        let adaptiveNutritionEngine = AdaptiveNutritionEngine()
        let nextBestActionEngine = HealthNextBestActionEngine()
        let weeklyReviewEngine = WeeklyReviewEngine()
        let healthActivityQueryService = HealthActivityQueryService(
            workoutReader: workoutReader,
            stepReader: stepReader,
            healthDataRepository: healthDataRepository
        )
        let healthIntegrationConnectionStore: any HealthIntegrationConnectionStoring = inMemory
            ? LockedHealthIntegrationConnectionStore()
            : UserDefaultsHealthIntegrationConnectionStore()
        let healthSyncService = HealthSyncService(
            repository: healthDataRepository,
            cacheStore: healthCacheStore,
            connectionStore: healthIntegrationConnectionStore
        )

        let remoteSummarySyncCapable = HealthIntelligenceFeatureFlags.healthSummaryRemoteSyncEnabled
        let healthSummarySyncConsentStorage: any HealthSummarySyncConsentStoring = inMemory
            ? LockedHealthSummarySyncConsentStore()
            : UserDefaultsHealthSummarySyncConsentStore()
        let healthSummarySyncConsentStore = HealthSummarySyncConsentStore(
            storage: healthSummarySyncConsentStorage,
            userProvider: session.authUIDCache
        )
        let remoteSyncActiveProvider: @Sendable () -> Bool = {
            HealthSummarySyncConsentResolver.isRemoteSyncActive(
                storage: healthSummarySyncConsentStorage,
                userProvider: session.authUIDCache,
                featureFlagEnabled: remoteSummarySyncCapable
            )
        }
        let healthSummaryRemoteSyncClient: any HealthSummaryRemoteSyncing = (inMemory || !remoteSummarySyncCapable)
            ? NoopHealthSummaryRemoteSyncClient()
            : FirestoreHealthSummaryRemoteSyncClient(userProvider: session.authUIDCache)
        let healthSummarySyncService = HealthSummarySyncService(
            remoteSyncClient: healthSummaryRemoteSyncClient,
            cacheStore: healthCacheStore,
            repository: healthDataRepository,
            userProvider: session.authUIDCache,
            localHealthSyncService: healthSyncService,
            remoteSyncEnabled: remoteSyncActiveProvider
        )
        let healthSyncStateStore = HealthSyncStateStore(
            syncService: healthSyncService,
            remoteSummarySyncService: remoteSummarySyncCapable ? healthSummarySyncService : nil,
            syncEnabled: HealthIntelligenceFeatureFlags.isSyncEnabled,
            remoteSummarySyncEnabled: remoteSyncActiveProvider
        )

        if HealthIntelligenceFeatureFlags.isSyncEnabled {
            session.refreshCenter.healthDayChangeHandler = { [healthSyncStateStore] in
                healthSyncStateStore.refreshOnDayChange()
            }
        }

        let trainingInsightsStore = TrainingInsightsStore(
            integration: healthTrainingService,
            healthSyncStateStore: HealthIntelligenceFeatureFlags.isSyncEnabled
                ? healthSyncStateStore
                : nil,
            connectionStore: healthIntegrationConnectionStore
        )
        let trainingInsightsModel = TrainingInsightsModel(workoutReader: workoutReader)

        HealthTrainingDebugLogger.event(
            "Training integration wired",
            fields: [
                "bundleId": Bundle.main.bundleIdentifier ?? "unknown",
                "initialDataSource": trainingInsightsStore.dataSource.rawValue
            ]
        )

        return HealthDependencies(
            healthTrainingService: healthTrainingService,
            healthKitWorkoutReader: workoutReader,
            healthKitStepReader: stepReader,
            healthCacheStore: healthCacheStore,
            healthDataRepository: healthDataRepository,
            healthBaselineService: healthBaselineService,
            trainingLoadEngine: trainingLoadEngine,
            workoutIntelligenceEngine: workoutIntelligenceEngine,
            recoveryEngine: recoveryEngine,
            adaptiveNutritionEngine: adaptiveNutritionEngine,
            nextBestActionEngine: nextBestActionEngine,
            weeklyReviewEngine: weeklyReviewEngine,
            healthActivityQueryService: healthActivityQueryService,
            healthSyncService: healthSyncService,
            healthIntegrationConnectionStore: healthIntegrationConnectionStore,
            healthSummarySyncConsentStorage: healthSummarySyncConsentStorage,
            healthSummarySyncConsentStore: healthSummarySyncConsentStore,
            healthSummaryRemoteSyncClient: healthSummaryRemoteSyncClient,
            healthSummarySyncService: healthSummarySyncService,
            healthSyncStateStore: healthSyncStateStore,
            trainingInsightsStore: trainingInsightsStore,
            trainingInsightsModel: trainingInsightsModel
        )
    }
}
