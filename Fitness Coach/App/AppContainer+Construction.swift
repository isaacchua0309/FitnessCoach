//
//  AppContainer+Construction.swift
//  Fitness Coach
//
//  Private domain-grouped construction helpers for AppContainer.
//  See Docs/Architecture/DependencyInjectionMap.md
//

import Foundation
import SwiftData

// MARK: - Construction bundles (private)

extension AppContainer {

    struct SessionBundle {
        let refreshCenter: AppRefreshCenter
        let accountRestoreSessionState: AccountRestoreSessionState
        let authManager: AuthManager
        let authUIDCache: AuthUIDCache
        let onboardingUserDefaults: UserDefaults
        let onboardingDraftStore: OnboardingDraftStore
        let publicEntrySessionStore: PublicEntrySessionStore
        let onboardingCoachingContextStore: OnboardingCoachingContextStore
        let onboardingRoutingConfiguration: OnboardingRoutingConfiguration
    }

    struct AnalyticsBundle {
        let onboardingAnalyticsLogger: any OnboardingAnalyticsLogging
        let todayAnalyticsLogger: any TodayAnalyticsLogging
        let planAnalyticsLogger: any PlanAnalyticsLogging
        let journeyAnalyticsLogger: any JourneyAnalyticsLogging
        let weeklyProgressAnalyticsLogger: any WeeklyProgressAnalyticsLogging
        let publicEntryAnalyticsLogger: any PublicEntryAnalyticsLogging
        let themeAnalyticsLogger: any ThemeAnalyticsLogging
        let settingsAnalyticsLogger: any SettingsAnalyticsLogging
        let healthIntelligenceAnalyticsLogger: any HealthIntelligenceAnalyticsLogging
    }

    struct HealthBundle {
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
        let healthSummarySyncConsentStorage: any HealthSummarySyncConsentStoring
        let healthSummarySyncConsentStore: HealthSummarySyncConsentStore
        let healthSummaryRemoteSyncClient: any HealthSummaryRemoteSyncing
        let healthSummarySyncService: HealthSummarySyncService
        let healthSyncStateStore: HealthSyncStateStore
        let trainingInsightsStore: TrainingInsightsStore
        let trainingInsightsModel: TrainingInsightsModel
    }

    struct PersistenceBundle {
        let modelContainer: ModelContainer
        let store: SwiftDataStore
        let accountSyncOutboxStore: SwiftDataAccountSyncOutboxStore
        let accountLocalMutationTracker: AccountLocalMutationTracker
        let userProfileService: UserProfileService
        let cloudUserProfileStore: CloudUserProfileStoring
        let accountDataRemoteStore: any AccountDataRemoteStore
        let accountSyncUploader: AccountSyncUploader
        let accountSyncPuller: AccountSyncPuller
        let accountSyncDiagnostics: AccountSyncDiagnostics
        let accountDeletionGuard: AccountDeletionGuard
        let accountSyncCoordinator: AccountSyncCoordinator
        let profileCloudSyncStore: ProfileCloudSyncStore
        let dailyLogService: DailyLogService
        let profileBootstrapService: ProfileBootstrapService
        let profileBootstrapCoordinatorService: ProfileBootstrapCoordinatorService
        let cloudUploadFailureNotifier: ProfileCloudUploadFailureNotifier
        let targetService: TargetService
        let foodLogService: FoodLogService
        let waterLogService: WaterLogService
        let weightLogService: WeightLogService
    }

    struct HealthIntelligenceBundle {
        let healthIntelligenceContextBuilder: HealthIntelligenceContextBuilder
        let healthIntelligenceEngine: any HealthIntelligenceEngineing
        let healthIntelligenceSnapshotService: any HealthIntelligenceSnapshotServing
        let weeklyReviewService: any WeeklyReviewServing
    }

    struct CoachPlatformBundle {
        let coachTimelineStore: SwiftDataCoachTimelineStore
        let coachChatTranscriptStore: SwiftDataCoachChatTranscriptStore
        let coachTimelineBackfillService: CoachTimelineBackfillService
        let coachTimelineRecorder: DefaultCoachTimelineRecorder
    }

    struct AIBundle {
        let llmClient: LLMClient
        let aiService: AIService
        let aiCommandParsingEnabled: Bool
        #if DEBUG
        let wiring: (clientType: String, baseURL: URL?, authAttached: Bool)
        #endif
    }

    struct AccountLifecycleBundle {
        let accountRestoreStateStore: AccountRestoreStateStore
        let accountLocalDataInspector: AccountLocalDataInspector
        let accountSyncCursorStore: AccountSyncCursorStore
        let accountIncrementalPuller: AccountIncrementalPuller
        let accountDataRefreshEventBus: AccountDataRefreshEventBus
        let crossDeviceSyncCoordinator: CrossDeviceSyncCoordinator
        let accountRealtimeChangeListener: AccountRealtimeChangeListening
        let accountRemoteDataInspector: AccountRemoteDataInspector
        let accountDataNamespaceService: AccountDataNamespaceService
        let accountMigrationService: AccountMigrationService
        let accountInitialRestoreService: AccountInitialRestoreService
        let accountRestoreDiagnostics: AccountRestoreDiagnostics
        let accountRestoreCoordinator: AccountRestoreCoordinator
        let accountDeletionRemoteClient: any AccountDeletionRemoteDeleting
        let localAccountDataWipeService: LocalAccountDataWipeService
        let accountDeletionRouter: DeferredAccountDeletionRouter
        let accountDeletionCoordinator: AccountDeletionCoordinator
        let accountDataExportService: AccountDataExportService
    }
}

// MARK: - Session / auth / onboarding

extension AppContainer {

    static func buildSession(
        inMemory: Bool,
        onboardingUserDefaults: UserDefaults?,
        onboardingRoutingConfiguration: OnboardingRoutingConfiguration?
    ) -> SessionBundle {
        let authManager = AuthManager()
        let authUIDCache = AuthUIDCache()
        authUIDCache.update(uid: authManager.currentUID)

        let userDefaults = makeOnboardingUserDefaults(inMemory: inMemory, override: onboardingUserDefaults)

        return SessionBundle(
            refreshCenter: AppRefreshCenter(),
            accountRestoreSessionState: AccountRestoreSessionState(),
            authManager: authManager,
            authUIDCache: authUIDCache,
            onboardingUserDefaults: userDefaults,
            onboardingDraftStore: OnboardingDraftStore(userDefaults: userDefaults),
            publicEntrySessionStore: PublicEntrySessionStore(userDefaults: userDefaults),
            onboardingCoachingContextStore: OnboardingCoachingContextStore(userDefaults: userDefaults),
            onboardingRoutingConfiguration: onboardingRoutingConfiguration ?? .production
        )
    }

    static func buildAnalytics(
        onboardingAnalyticsLogger: (any OnboardingAnalyticsLogging)?,
        todayAnalyticsLogger: (any TodayAnalyticsLogging)?,
        planAnalyticsLogger: (any PlanAnalyticsLogging)?,
        journeyAnalyticsLogger: (any JourneyAnalyticsLogging)?,
        weeklyProgressAnalyticsLogger: (any WeeklyProgressAnalyticsLogging)?,
        publicEntryAnalyticsLogger: (any PublicEntryAnalyticsLogging)?,
        themeAnalyticsLogger: (any ThemeAnalyticsLogging)?,
        settingsAnalyticsLogger: (any SettingsAnalyticsLogging)?,
        healthIntelligenceAnalyticsLogger: (any HealthIntelligenceAnalyticsLogging)?
    ) -> AnalyticsBundle {
        #if DEBUG
        return AnalyticsBundle(
            onboardingAnalyticsLogger: onboardingAnalyticsLogger ?? OSLogOnboardingAnalyticsLogger(),
            todayAnalyticsLogger: todayAnalyticsLogger ?? OSLogTodayAnalyticsLogger(),
            planAnalyticsLogger: planAnalyticsLogger ?? OSLogPlanAnalyticsLogger(),
            journeyAnalyticsLogger: journeyAnalyticsLogger ?? OSLogJourneyAnalyticsLogger(),
            weeklyProgressAnalyticsLogger: weeklyProgressAnalyticsLogger ?? OSLogWeeklyProgressAnalyticsLogger(),
            publicEntryAnalyticsLogger: publicEntryAnalyticsLogger ?? OSLogPublicEntryAnalyticsLogger(),
            themeAnalyticsLogger: themeAnalyticsLogger ?? OSLogThemeAnalyticsLogger(),
            settingsAnalyticsLogger: settingsAnalyticsLogger ?? OSLogSettingsAnalyticsLogger(),
            healthIntelligenceAnalyticsLogger: healthIntelligenceAnalyticsLogger
                ?? OSLogHealthIntelligenceAnalyticsLogger()
        )
        #else
        return AnalyticsBundle(
            onboardingAnalyticsLogger: onboardingAnalyticsLogger ?? NoOpOnboardingAnalyticsLogger(),
            todayAnalyticsLogger: todayAnalyticsLogger ?? NoOpTodayAnalyticsLogger(),
            planAnalyticsLogger: planAnalyticsLogger ?? NoOpPlanAnalyticsLogger(),
            journeyAnalyticsLogger: journeyAnalyticsLogger ?? NoOpJourneyAnalyticsLogger(),
            weeklyProgressAnalyticsLogger: weeklyProgressAnalyticsLogger ?? NoOpWeeklyProgressAnalyticsLogger(),
            publicEntryAnalyticsLogger: publicEntryAnalyticsLogger ?? NoOpPublicEntryAnalyticsLogger(),
            themeAnalyticsLogger: themeAnalyticsLogger ?? NoOpThemeAnalyticsLogger(),
            settingsAnalyticsLogger: settingsAnalyticsLogger ?? NoOpSettingsAnalyticsLogger(),
            healthIntelligenceAnalyticsLogger: healthIntelligenceAnalyticsLogger
                ?? NoOpHealthIntelligenceAnalyticsLogger()
        )
        #endif
    }
}

// MARK: - Health

extension AppContainer {

    static func buildHealth(
        session: SessionBundle,
        inMemory: Bool
    ) -> HealthBundle {
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
        let healthSyncService = HealthSyncService(
            repository: healthDataRepository,
            cacheStore: healthCacheStore
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
                : nil
        )
        let trainingInsightsModel = TrainingInsightsModel(workoutReader: workoutReader)

        HealthTrainingDebugLogger.event(
            "Training integration wired",
            fields: [
                "bundleId": Bundle.main.bundleIdentifier ?? "unknown",
                "initialDataSource": trainingInsightsStore.dataSource.rawValue
            ]
        )

        return HealthBundle(
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

// MARK: - Persistence & sync core

extension AppContainer {

    static func buildPersistence(
        session: SessionBundle,
        inMemory: Bool,
        accountDataRemoteStore: (any AccountDataRemoteStore)?
    ) throws -> PersistenceBundle {
        let modelContainer = try FormaModelContainer.makeContainer(inMemory: inMemory)
        let store = SwiftDataStore(container: modelContainer)
        let authManager = session.authManager

        let accountSyncOutboxStore = SwiftDataAccountSyncOutboxStore(store: store)
        let accountLocalMutationTracker = AccountLocalMutationTracker(
            outbox: accountSyncOutboxStore,
            ownerUIDProvider: { [weak authManager] in authManager?.currentUID }
        )

        let userProfileService = UserProfileService(store: store)
        let cloudUserProfileStore: CloudUserProfileStoring = inMemory
            ? NoOpCloudUserProfileStore()
            : FirestoreCloudUserProfileStore()

        let resolvedRemoteStore: any AccountDataRemoteStore
        if let accountDataRemoteStore {
            resolvedRemoteStore = accountDataRemoteStore
        } else if inMemory || !AccountPersistenceFeatureFlags.cloudSchemaEnabled {
            resolvedRemoteStore = InMemoryAccountDataRemoteStore()
        } else {
            resolvedRemoteStore = FirestoreAccountDataRemoteStore()
        }

        let accountSyncUploader = AccountSyncUploader(
            outbox: accountSyncOutboxStore,
            payloadBuilder: SwiftDataAccountSyncPayloadBuilder(store: store),
            remoteStore: resolvedRemoteStore,
            store: store
        )
        let accountSyncPuller = AccountSyncPuller(
            remoteStore: resolvedRemoteStore,
            store: store
        )
        let accountSyncDiagnostics = AccountSyncDiagnostics()
        let accountDeletionGuard = AccountDeletionGuard()
        let accountSyncCoordinator = AccountSyncCoordinator(
            uploader: accountSyncUploader,
            puller: accountSyncPuller,
            currentUIDProvider: { [weak authManager] in authManager?.currentUID },
            diagnostics: accountSyncDiagnostics,
            deletionGuard: accountDeletionGuard
        )

        let profileCloudSyncStore = ProfileCloudSyncStore(userDefaults: session.onboardingUserDefaults)
        let dailyLogService = DailyLogService(
            store: store,
            userProfileService: userProfileService,
            mutationTracker: accountLocalMutationTracker
        )
        let profileBootstrapService = ProfileBootstrapService(
            userProfileService: userProfileService,
            cloudStore: cloudUserProfileStore,
            cloudSyncStore: profileCloudSyncStore,
            dailyLogService: dailyLogService
        )
        let profileBootstrapCoordinatorService = ProfileBootstrapCoordinatorService(
            profileBootstrapService: profileBootstrapService,
            cloudSyncStore: profileCloudSyncStore
        )
        let cloudUploadFailureNotifier = ProfileCloudUploadFailureNotifier(
            syncStore: profileCloudSyncStore
        )
        let targetService = TargetService(
            userProfileService: userProfileService,
            dailyLogService: dailyLogService
        )
        let foodLogService = FoodLogService(
            store: store,
            dailyLogService: dailyLogService,
            mutationTracker: accountLocalMutationTracker
        )
        let waterLogService = WaterLogService(
            store: store,
            dailyLogService: dailyLogService,
            mutationTracker: accountLocalMutationTracker
        )
        let weightLogService = WeightLogService(
            store: store,
            dailyLogService: dailyLogService,
            mutationTracker: accountLocalMutationTracker
        )

        return PersistenceBundle(
            modelContainer: modelContainer,
            store: store,
            accountSyncOutboxStore: accountSyncOutboxStore,
            accountLocalMutationTracker: accountLocalMutationTracker,
            userProfileService: userProfileService,
            cloudUserProfileStore: cloudUserProfileStore,
            accountDataRemoteStore: resolvedRemoteStore,
            accountSyncUploader: accountSyncUploader,
            accountSyncPuller: accountSyncPuller,
            accountSyncDiagnostics: accountSyncDiagnostics,
            accountDeletionGuard: accountDeletionGuard,
            accountSyncCoordinator: accountSyncCoordinator,
            profileCloudSyncStore: profileCloudSyncStore,
            dailyLogService: dailyLogService,
            profileBootstrapService: profileBootstrapService,
            profileBootstrapCoordinatorService: profileBootstrapCoordinatorService,
            cloudUploadFailureNotifier: cloudUploadFailureNotifier,
            targetService: targetService,
            foodLogService: foodLogService,
            waterLogService: waterLogService,
            weightLogService: weightLogService
        )
    }
}

// MARK: - Health Intelligence

extension AppContainer {

    static func buildHealthIntelligence(
        health: HealthBundle,
        persistence: PersistenceBundle
    ) -> HealthIntelligenceBundle {
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

        return HealthIntelligenceBundle(
            healthIntelligenceContextBuilder: healthIntelligenceContextBuilder,
            healthIntelligenceEngine: healthIntelligenceEngine,
            healthIntelligenceSnapshotService: healthIntelligenceSnapshotService,
            weeklyReviewService: weeklyReviewService
        )
    }
}

// MARK: - Coach platform

extension AppContainer {

    static func buildCoachPlatform(
        session: SessionBundle,
        persistence: PersistenceBundle,
        health: HealthBundle
    ) -> CoachPlatformBundle {
        let authManager = session.authManager
        let coachTimelineStore = SwiftDataCoachTimelineStore(
            store: persistence.store,
            userIdProvider: { [weak authManager] in authManager?.currentUID }
        )
        let coachChatTranscriptStore = SwiftDataCoachChatTranscriptStore(
            store: persistence.store,
            userIdProvider: { [weak authManager] in authManager?.currentUID }
        )
        let coachTimelineBackfillService = CoachTimelineBackfillService(
            timelineStore: coachTimelineStore,
            foodLogService: persistence.foodLogService,
            waterLogService: persistence.waterLogService,
            weightLogService: persistence.weightLogService,
            healthActivityQuery: health.healthActivityQueryService
        )
        let coachTimelineRecorder = DefaultCoachTimelineRecorder(store: coachTimelineStore)

        Task { @MainActor [coachTimelineBackfillService] in
            await coachTimelineBackfillService.runBackfill()
        }

        return CoachPlatformBundle(
            coachTimelineStore: coachTimelineStore,
            coachChatTranscriptStore: coachChatTranscriptStore,
            coachTimelineBackfillService: coachTimelineBackfillService,
            coachTimelineRecorder: coachTimelineRecorder
        )
    }
}

// MARK: - AI

extension AppContainer {

    static func buildAI(
        session: SessionBundle,
        inMemory: Bool
    ) -> AIBundle {
        #if DEBUG
        let wiring: (clientType: String, baseURL: URL?, authAttached: Bool)
        #endif

        let authManager = session.authManager
        let llmClient: LLMClient
        if inMemory {
            llmClient = MockLLMClient()
            #if DEBUG
            wiring = ("MockLLMClient", nil, false)
            #endif
        } else if let backendURL = AIBackendConfiguration.backendURL() {
            llmClient = FallbackLLMClient(
                primary: FormaAIBackendClient(
                    baseURL: backendURL,
                    authTokenProvider: { try await authManager.idToken() }
                )
            )
            #if DEBUG
            wiring = ("FallbackLLMClient+FormaAIBackendClient", backendURL, true)
            #endif
        } else {
            llmClient = UnavailableLLMClient(
                reason: AIBackendConfiguration.unavailableReason()
            )
            #if DEBUG
            wiring = ("UnavailableLLMClient", nil, false)
            #endif
        }

        return AIBundle(
            llmClient: llmClient,
            aiService: AIService(llmClient: llmClient),
            aiCommandParsingEnabled: FormaAbTest.Coach.aiCommandParsingEnabled
            #if DEBUG
            , wiring: wiring
            #endif
        )
    }
}

// MARK: - Account lifecycle (restore / cross-device / deletion)

extension AppContainer {

    static func buildAccountLifecycle(
        session: SessionBundle,
        persistence: PersistenceBundle,
        health: HealthBundle,
        inMemory: Bool
    ) -> AccountLifecycleBundle {
        let authManager = session.authManager

        let accountRestoreStateStore = AccountRestoreStateStore(
            userDefaults: session.onboardingUserDefaults
        )
        let accountLocalDataInspector = AccountLocalDataInspector(
            store: persistence.store,
            userProfileService: persistence.userProfileService,
            outboxStore: persistence.accountSyncOutboxStore
        )
        let accountSyncCursorStore = AccountSyncCursorStore(
            userDefaults: session.onboardingUserDefaults
        )
        let accountIncrementalPuller = AccountIncrementalPuller(
            remoteStore: persistence.accountDataRemoteStore,
            mergePuller: persistence.accountSyncPuller,
            cursorStore: accountSyncCursorStore,
            profileBootstrapService: persistence.profileBootstrapService,
            userProfileService: persistence.userProfileService,
            profileCloudSyncStore: persistence.profileCloudSyncStore,
            localInspector: accountLocalDataInspector,
            currentUIDProvider: { [weak authManager] in authManager?.currentUID }
        )
        let accountDataRefreshEventBus = AccountDataRefreshEventBus()
        let crossDeviceSyncCoordinator = CrossDeviceSyncCoordinator(
            syncCoordinator: persistence.accountSyncCoordinator,
            incrementalPuller: accountIncrementalPuller,
            cursorStore: accountSyncCursorStore,
            uidProvider: ClosureAccountUIDProvider { [weak authManager] in authManager?.currentUID },
            refreshCenter: session.refreshCenter,
            refreshEventBus: accountDataRefreshEventBus,
            deletionGuard: persistence.accountDeletionGuard
        )

        let accountRealtimeChangeListener: AccountRealtimeChangeListening = if inMemory {
            NoOpAccountRealtimeChangeListener()
        } else {
            FirestoreAccountRealtimeChangeListener(
                deletionGuard: persistence.accountDeletionGuard
            )
        }
        AccountRealtimeChangeListenerLifecycle.connect(
            listener: accountRealtimeChangeListener,
            crossDeviceCoordinator: crossDeviceSyncCoordinator,
            deletionGuard: persistence.accountDeletionGuard
        )

        let accountRemoteDataInspector = AccountRemoteDataInspector(
            cloudProfileStore: persistence.cloudUserProfileStore,
            remoteStore: persistence.accountDataRemoteStore
        )
        let accountDataNamespaceService = AccountDataNamespaceService(
            store: persistence.store,
            healthCacheStore: health.healthCacheStore,
            userDefaults: session.onboardingUserDefaults,
            syncCoordinator: persistence.accountSyncCoordinator
        )
        let accountMigrationService = AccountMigrationService(
            store: persistence.store,
            userProfileService: persistence.userProfileService,
            uidProvider: AuthAccountUIDProvider(authManager: authManager)
        )
        let accountInitialRestoreService = AccountInitialRestoreService(
            profileBootstrapService: persistence.profileBootstrapService,
            puller: persistence.accountSyncPuller,
            localInspector: accountLocalDataInspector,
            remoteInspector: accountRemoteDataInspector,
            stateStore: accountRestoreStateStore,
            syncCoordinator: persistence.accountSyncCoordinator,
            dailyLogService: persistence.dailyLogService,
            currentUIDProvider: { [weak authManager] in authManager?.currentUID }
        )
        let accountRestoreDiagnostics = AccountRestoreDiagnostics()
        let accountRestoreCoordinator = AccountRestoreCoordinator(
            namespaceService: accountDataNamespaceService,
            migrationService: accountMigrationService,
            localInspector: accountLocalDataInspector,
            remoteInspector: accountRemoteDataInspector,
            initialRestoreService: accountInitialRestoreService,
            stateStore: accountRestoreStateStore,
            syncCoordinator: persistence.accountSyncCoordinator,
            deletionGuard: persistence.accountDeletionGuard,
            diagnostics: accountRestoreDiagnostics,
            currentUIDProvider: { [weak authManager] in authManager?.currentUID },
            onBackgroundBackfillFinished: { [refreshCenter = session.refreshCenter] _ in
                refreshCenter.notifyBackgroundBackfillDidComplete()
            }
        )

        let accountDeletionBackendURL =
            AccountDeletionBackendConfiguration.backendURL()
            ?? URL(string: AccountDeletionBackendConfiguration.productionURLString)!
        let accountDeletionRemoteClient: any AccountDeletionRemoteDeleting = AccountDeletionRemoteClient(
            baseURL: accountDeletionBackendURL,
            authTokenProvider: { [weak authManager] in
                guard let authManager else { throw AuthManagerError.notSignedIn }
                return try await authManager.idToken()
            }
        )
        let localAccountDataWipeService = LocalAccountDataWipeService(
            store: persistence.store,
            healthCacheStore: health.healthCacheStore,
            userDefaults: session.onboardingUserDefaults,
            restoreStateStore: accountRestoreStateStore,
            syncCursorStore: accountSyncCursorStore,
            healthConsentStore: health.healthSummarySyncConsentStorage,
            healthSyncStateStore: UserDefaultsHealthSummaryRemoteSyncStateStore(
                userDefaults: session.onboardingUserDefaults
            ),
            profileCloudSyncStore: persistence.profileCloudSyncStore,
            currentSessionUIDProvider: { [weak authManager] in authManager?.currentUID }
        )
        let accountDeletionRouter = DeferredAccountDeletionRouter()
        let accountDeletionCoordinator = AccountDeletionCoordinator(
            uidProvider: AuthAccountUIDProvider(authManager: authManager),
            crossDeviceCoordinator: crossDeviceSyncCoordinator,
            realtimeListener: accountRealtimeChangeListener,
            accountSyncCoordinator: persistence.accountSyncCoordinator,
            restoreCoordinator: accountRestoreCoordinator,
            remoteDeletionClient: accountDeletionRemoteClient,
            authDeleting: authManager,
            localWiper: localAccountDataWipeService,
            deletionGuard: persistence.accountDeletionGuard,
            router: accountDeletionRouter,
            signOutCurrentSession: { [weak authManager] in authManager?.signOut() }
        )
        let accountDataExportService = AccountDataExportService(
            store: persistence.store,
            accountSyncOutboxStore: persistence.accountSyncOutboxStore,
            profileCloudSyncStore: persistence.profileCloudSyncStore,
            accountSyncCursorStore: accountSyncCursorStore,
            accountRestoreStateStore: accountRestoreStateStore,
            currentSessionUIDProvider: { [weak authManager] in authManager?.currentUID }
        )

        return AccountLifecycleBundle(
            accountRestoreStateStore: accountRestoreStateStore,
            accountLocalDataInspector: accountLocalDataInspector,
            accountSyncCursorStore: accountSyncCursorStore,
            accountIncrementalPuller: accountIncrementalPuller,
            accountDataRefreshEventBus: accountDataRefreshEventBus,
            crossDeviceSyncCoordinator: crossDeviceSyncCoordinator,
            accountRealtimeChangeListener: accountRealtimeChangeListener,
            accountRemoteDataInspector: accountRemoteDataInspector,
            accountDataNamespaceService: accountDataNamespaceService,
            accountMigrationService: accountMigrationService,
            accountInitialRestoreService: accountInitialRestoreService,
            accountRestoreDiagnostics: accountRestoreDiagnostics,
            accountRestoreCoordinator: accountRestoreCoordinator,
            accountDeletionRemoteClient: accountDeletionRemoteClient,
            localAccountDataWipeService: localAccountDataWipeService,
            accountDeletionRouter: accountDeletionRouter,
            accountDeletionCoordinator: accountDeletionCoordinator,
            accountDataExportService: accountDataExportService
        )
    }
}

// MARK: - Shared utilities

extension AppContainer {

    static func makeOnboardingUserDefaults(
        inMemory: Bool,
        override: UserDefaults?
    ) -> UserDefaults {
        if let override {
            return override
        }
        if inMemory {
            let suiteName = "FitnessCoach.onboarding.inMemory.\(UUID().uuidString)"
            return UserDefaults(suiteName: suiteName) ?? .standard
        }
        return .standard
    }

    #if DEBUG
    static func logAIBackendURLDetection() {
        if let backendURL = AIBackendConfiguration.backendURL() {
            FormaPipelineTracer.event(
                stage: .appWiring,
                level: .info,
                message: "AI gateway URL configured",
                fields: [
                    "detected": "true",
                    "gatewayURL": backendURL.absoluteString
                ]
            )
            return
        }

        switch FormaEnvironment.aiBackendURLDetection() {
        case .notDetected:
            FormaPipelineTracer.event(
                stage: .appWiring,
                level: .info,
                message: "FORMA_AI_BACKEND_URL not detected",
                fields: ["detected": "false"]
            )
        case .detected(let source):
            FormaPipelineTracer.event(
                stage: .appWiring,
                level: .info,
                message: "FORMA_AI_BACKEND_URL rejected or invalid",
                fields: [
                    "detected": "false",
                    "source": source.rawValue
                ]
            )
        }
    }

    static func logLLMClientWiring(clientType: String, baseURL: URL?, authAttached: Bool) {
        var fields: [String: String] = [
            "clientType": clientType,
            "authAttached": String(authAttached),
            "traceEnabled": String(FormaPipelineTracer.isEnabled),
            "traceVerbose": String(FormaPipelineTracer.isVerbose)
        ]
        if let baseURL {
            fields["baseURL"] = baseURL.absoluteString
        }
        FormaPipelineTracer.event(
            stage: .appWiring,
            level: .info,
            message: "LLM client wired",
            fields: fields
        )
    }
    #endif
}
