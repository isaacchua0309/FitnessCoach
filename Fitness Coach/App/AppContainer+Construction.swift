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

    struct PersistenceDependenciesBundle {
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

    struct HealthIntelligenceDependenciesBundle {
        let healthIntelligenceContextBuilder: HealthIntelligenceContextBuilder
        let healthIntelligenceEngine: any HealthIntelligenceEngineing
        let healthIntelligenceSnapshotService: any HealthIntelligenceSnapshotServing
        let weeklyReviewService: any WeeklyReviewServing
    }

    struct CoachDependenciesBundle {
        let coachTimelineStore: SwiftDataCoachTimelineStore
        let coachChatTranscriptStore: SwiftDataCoachChatTranscriptStore
        let coachTimelineBackfillService: CoachTimelineBackfillService
        let coachTimelineRecorder: DefaultCoachTimelineRecorder
        let foodCorrectionMemoryStore: FileFoodCorrectionMemoryStore
    }

    struct AIBundle {
        let llmClient: LLMClient
        let aiService: AIService
        let aiCommandParsingEnabled: Bool
        #if DEBUG
        let wiring: (clientType: String, baseURL: URL?, authAttached: Bool)
        #endif
    }

    struct SyncDependenciesBundle {
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

    struct SettingsDependenciesBundle {
        let themeStore: ThemeStore
    }

    struct TodayDependenciesBundle {
        let reviewService: ReviewService
        let actionCenter: FitnessActionCenter
    }
}

// MARK: - Auth dependencies

extension AppContainer {

    typealias AuthDependenciesBundle = AuthDependencies

    static func buildAuthDependencies(
        inMemory: Bool,
        onboardingUserDefaults: UserDefaults?,
        onboardingRoutingConfiguration: OnboardingRoutingConfiguration?
    ) -> AuthDependencies {
        AuthDependencies.build(
            inMemory: inMemory,
            onboardingUserDefaults: onboardingUserDefaults,
            onboardingRoutingConfiguration: onboardingRoutingConfiguration
        )
    }
}

// MARK: - Analytics dependencies

extension AppContainer {

    typealias AnalyticsDependenciesBundle = AnalyticsDependencies

    static func buildAnalyticsDependencies(
        onboardingAnalyticsLogger: (any OnboardingAnalyticsLogging)?,
        todayAnalyticsLogger: (any TodayAnalyticsLogging)?,
        planAnalyticsLogger: (any PlanAnalyticsLogging)?,
        journeyAnalyticsLogger: (any JourneyAnalyticsLogging)?,
        weeklyProgressAnalyticsLogger: (any WeeklyProgressAnalyticsLogging)?,
        publicEntryAnalyticsLogger: (any PublicEntryAnalyticsLogging)?,
        themeAnalyticsLogger: (any ThemeAnalyticsLogging)?,
        settingsAnalyticsLogger: (any SettingsAnalyticsLogging)?,
        healthIntelligenceAnalyticsLogger: (any HealthIntelligenceAnalyticsLogging)?
    ) -> AnalyticsDependencies {
        AnalyticsDependencies.build(
            onboardingAnalyticsLogger: onboardingAnalyticsLogger,
            todayAnalyticsLogger: todayAnalyticsLogger,
            planAnalyticsLogger: planAnalyticsLogger,
            journeyAnalyticsLogger: journeyAnalyticsLogger,
            weeklyProgressAnalyticsLogger: weeklyProgressAnalyticsLogger,
            publicEntryAnalyticsLogger: publicEntryAnalyticsLogger,
            themeAnalyticsLogger: themeAnalyticsLogger,
            settingsAnalyticsLogger: settingsAnalyticsLogger,
            healthIntelligenceAnalyticsLogger: healthIntelligenceAnalyticsLogger
        )
    }
}

// MARK: - Health & training (shared infrastructure)

extension AppContainer {

    typealias HealthBundle = HealthDependencies

    static func buildHealth(
        session: AuthDependenciesBundle,
        inMemory: Bool
    ) -> HealthDependencies {
        HealthDependencies.build(session: session, inMemory: inMemory)
    }
}

// MARK: - Persistence dependencies

extension AppContainer {

    static func buildPersistenceDependencies(
        session: AuthDependenciesBundle,
        inMemory: Bool,
        accountDataRemoteStore: (any AccountDataRemoteStore)?
    ) throws -> PersistenceDependenciesBundle {
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

        return PersistenceDependenciesBundle(
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

// MARK: - Health Intelligence dependencies

extension AppContainer {

    static func buildHealthIntelligenceDependencies(
        health: HealthBundle,
        persistence: PersistenceDependenciesBundle
    ) -> HealthIntelligenceDependenciesBundle {
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

        return HealthIntelligenceDependenciesBundle(
            healthIntelligenceContextBuilder: healthIntelligenceContextBuilder,
            healthIntelligenceEngine: healthIntelligenceEngine,
            healthIntelligenceSnapshotService: healthIntelligenceSnapshotService,
            weeklyReviewService: weeklyReviewService
        )
    }
}

// MARK: - Coach dependencies

extension AppContainer {

    static func buildCoachDependencies(
        session: AuthDependenciesBundle,
        persistence: PersistenceDependenciesBundle,
        health: HealthBundle
    ) -> CoachDependenciesBundle {
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
        let foodCorrectionMemoryStore = FileFoodCorrectionMemoryStore(
            userIdProvider: { [weak authManager] in authManager?.currentUID }
        )

        Task { @MainActor [coachTimelineBackfillService] in
            await coachTimelineBackfillService.runBackfill()
        }

        return CoachDependenciesBundle(
            coachTimelineStore: coachTimelineStore,
            coachChatTranscriptStore: coachChatTranscriptStore,
            coachTimelineBackfillService: coachTimelineBackfillService,
            coachTimelineRecorder: coachTimelineRecorder,
            foodCorrectionMemoryStore: foodCorrectionMemoryStore
        )
    }
}

// MARK: - AI (Coach / onboarding)

extension AppContainer {

    static func buildAI(
        session: AuthDependenciesBundle,
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

        #if DEBUG
        return AIBundle(
            llmClient: llmClient,
            aiService: AIService(llmClient: llmClient),
            aiCommandParsingEnabled: FormaAbTest.Coach.aiCommandParsingEnabled,
            wiring: wiring
        )
        #else
        return AIBundle(
            llmClient: llmClient,
            aiService: AIService(llmClient: llmClient),
            aiCommandParsingEnabled: FormaAbTest.Coach.aiCommandParsingEnabled
        )
        #endif
    }
}

// MARK: - Sync dependencies (account restore / cross-device / deletion)

extension AppContainer {

    static func buildSyncDependencies(
        session: AuthDependenciesBundle,
        persistence: PersistenceDependenciesBundle,
        health: HealthBundle,
        inMemory: Bool
    ) -> SyncDependenciesBundle {
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

        return SyncDependenciesBundle(
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

// MARK: - Settings dependencies

extension AppContainer {

    static func buildSettingsDependencies(
        analytics: AnalyticsDependenciesBundle
    ) -> SettingsDependenciesBundle {
        SettingsDependenciesBundle(
            themeStore: ThemeStore(analyticsLogger: analytics.themeAnalyticsLogger)
        )
    }
}

// MARK: - Today dependencies (shared action surface)

extension AppContainer {

    static func buildTodayDependencies(
        auth: AuthDependenciesBundle,
        persistence: PersistenceDependenciesBundle,
        health: HealthBundle,
        ai: AIBundle,
        refreshCenter: AppRefreshCenter
    ) -> TodayDependenciesBundle {
        let reviewService = ReviewService(
            store: persistence.store,
            dailyLogService: persistence.dailyLogService,
            foodLogService: persistence.foodLogService,
            waterLogService: persistence.waterLogService,
            weightLogService: persistence.weightLogService,
            healthActivityQuery: health.healthActivityQueryService,
            userProfileService: persistence.userProfileService,
            aiService: ai.aiService,
            mutationTracker: persistence.accountLocalMutationTracker
        )

        let actionCenter = FitnessActionCenter(
            foodLogService: persistence.foodLogService,
            waterLogService: persistence.waterLogService,
            weightLogService: persistence.weightLogService,
            dailyLogService: persistence.dailyLogService,
            targetService: persistence.targetService,
            userProfileService: persistence.userProfileService,
            reviewService: reviewService,
            refreshCenter: refreshCenter,
            profileBootstrapService: persistence.profileBootstrapService,
            cloudUploadFailureNotifier: persistence.cloudUploadFailureNotifier,
            currentUIDProvider: { [authManager = auth.authManager] in authManager.currentUID },
            scheduleAccountSyncAfterMutation: { [authManager = auth.authManager, accountSyncCoordinator = persistence.accountSyncCoordinator] in
                AccountSyncLifecycle.scheduleAfterLocalMutation(
                    coordinator: accountSyncCoordinator,
                    uidProvider: { authManager.currentUID }
                )
            }
        )

        return TodayDependenciesBundle(
            reviewService: reviewService,
            actionCenter: actionCenter
        )
    }
}

// MARK: - Journey dependencies (feature wiring)

extension AppContainer {

    func buildJourneyDependencies(
        healthIntelligenceAnalyticsCoordinator: HealthIntelligenceAnalyticsCoordinator? = nil
    ) -> JourneyModel {
        JourneyModel(
            dailyLogReader: dailyLogService,
            weightLogReader: weightLogService,
            userProfileReader: userProfileService,
            trainingInsightsStore: trainingInsightsStore,
            workoutReader: healthKitWorkoutReader,
            healthIntelligenceSnapshotProvider: healthIntelligenceSnapshotService,
            weeklyReviewService: weeklyReviewService,
            healthIntelligenceEngine: healthIntelligenceEngine,
            healthCacheStore: healthCacheStore,
            healthActivityQuery: healthActivityQueryService,
            healthDataRepository: healthDataRepository,
            healthIntelligenceAnalyticsCoordinator: healthIntelligenceAnalyticsCoordinator,
            healthSyncPhaseProvider: { [weak self] in
                self?.healthSyncStateStore.state.phase
            },
            lastSuccessfulLocalSyncAtProvider: { [weak self] in
                self?.healthSyncStateStore.state.lastSuccessfulSyncAt
            },
            remoteSyncConsentDecisionProvider: { [weak self] in
                self?.healthSummarySyncConsentStore.state.decision ?? .notDetermined
            },
            isRemoteSyncCapabilityEnabled: {
                HealthSummaryRemoteSyncGate.isCapabilityEnabled()
            },
            restoreSessionState: accountRestoreSessionState,
            localDataInspector: accountLocalDataInspector,
            ownerUIDProvider: { [weak authManager] in authManager?.currentUID },
            accountDataRefreshEventBus: accountDataRefreshEventBus,
            crossDeviceSyncCoordinator: crossDeviceSyncCoordinator,
            accountSyncCursorStore: accountSyncCursorStore,
            accountSyncOutboxStore: accountSyncOutboxStore,
            accountRestoreStateStore: accountRestoreStateStore
        )
    }
}

// MARK: - Plan dependencies (feature wiring)

extension AppContainer {

    func buildPlanDependencies(
        healthIntelligenceAnalyticsCoordinator: HealthIntelligenceAnalyticsCoordinator? = nil,
        planAnalyticsCoordinator: PlanAnalyticsCoordinator? = nil
    ) -> PlanModel {
        PlanModel(
            actionCenter: actionCenter,
            userProfileReader: userProfileService,
            planTargetCalculator: targetService,
            dailyLogReader: dailyLogService,
            weightLogReader: weightLogService,
            trainingInsightsStore: trainingInsightsStore,
            analyticsLogger: planAnalyticsLogger,
            planAnalyticsCoordinator: planAnalyticsCoordinator,
            healthBaselineService: healthBaselineService,
            healthIntelligenceSnapshotProvider: healthIntelligenceSnapshotService,
            healthDataRepository: healthDataRepository,
            healthIntelligenceAnalyticsCoordinator: healthIntelligenceAnalyticsCoordinator,
            healthSyncPhaseProvider: { [weak self] in
                self?.healthSyncStateStore.state.phase
            },
            lastSuccessfulLocalSyncAtProvider: { [weak self] in
                self?.healthSyncStateStore.state.lastSuccessfulSyncAt
            },
            remoteSyncConsentDecisionProvider: { [weak self] in
                self?.healthSummarySyncConsentStore.state.decision ?? .notDetermined
            },
            isRemoteSyncCapabilityEnabled: {
                HealthSummaryRemoteSyncGate.isCapabilityEnabled()
            },
            ownerUIDProvider: { [weak authManager] in authManager?.currentUID },
            accountDataRefreshEventBus: accountDataRefreshEventBus,
            crossDeviceSyncCoordinator: crossDeviceSyncCoordinator
        )
    }
}

// MARK: - Shared utilities

extension AppContainer {

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
