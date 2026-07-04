//
//  AppContainer.swift
//  Fitness Coach
//
//  FitPilot AI — Minimal dependency container for the current app shell.
//

import Foundation
import SwiftData

@MainActor
final class AppContainer {

    let modelContainer: ModelContainer
    let store: SwiftDataStore

    /// Phase 3 durable sync outbox — enqueues mutations; drained by `accountSyncUploader`.
    let accountSyncOutboxStore: SwiftDataAccountSyncOutboxStore
    let accountLocalMutationTracker: AccountLocalMutationTracker
    let accountSyncUploader: AccountSyncUploader
    let accountSyncPuller: AccountSyncPuller
    let accountSyncCoordinator: AccountSyncCoordinator
    let accountSyncDiagnostics: AccountSyncDiagnostics
    let accountSyncCursorStore: AccountSyncCursorStore
    let accountIncrementalPuller: AccountIncrementalPuller
    let crossDeviceSyncCoordinator: CrossDeviceSyncCoordinator
    let accountDataRefreshEventBus: AccountDataRefreshEventBus
    let accountRealtimeChangeListener: AccountRealtimeChangeListening

    let accountRestoreStateStore: AccountRestoreStateStore
    let accountLocalDataInspector: AccountLocalDataInspector
    let accountRemoteDataInspector: AccountRemoteDataInspector
    let accountDataNamespaceService: AccountDataNamespaceService
    let accountMigrationService: AccountMigrationService
    let accountInitialRestoreService: AccountInitialRestoreService
    let accountRestoreCoordinator: AccountRestoreCoordinator
    let accountRestoreDiagnostics: AccountRestoreDiagnostics
    let accountRestoreSessionState: AccountRestoreSessionState

    let userProfileService: UserProfileService
    let targetService: TargetService
    let dailyLogService: DailyLogService
    let foodLogService: FoodLogService
    let waterLogService: WaterLogService
    let weightLogService: WeightLogService
    let reviewService: ReviewService
    let actionCenter: FitnessActionCenter

    let authManager: AuthManager
    let cloudUserProfileStore: CloudUserProfileStoring
    /// Phase 2 cloud log store — constructed and injectable; not wired to log mutations yet.
    let accountDataRemoteStore: any AccountDataRemoteStore
    let profileBootstrapService: ProfileBootstrapService
    let profileCloudSyncStore: ProfileCloudSyncStore
    let profileBootstrapCoordinatorService: ProfileBootstrapCoordinatorService
    let cloudUploadFailureNotifier: ProfileCloudUploadFailureNotifier
    let llmClient: LLMClient
    let aiService: AIService
    let aiCommandParsingEnabled: Bool
    let refreshCenter: AppRefreshCenter
    let healthTrainingService: HealthTrainingService
    let trainingInsightsStore: TrainingInsightsStore
    let trainingInsightsModel: TrainingInsightsModel
    let healthKitWorkoutReader: HealthKitWorkoutReading
    let healthKitStepReader: HealthKitStepReading
    let healthActivityQueryService: HealthActivityQueryService
    let healthCacheStore: LocalHealthCacheStore
    let healthDataRepository: HealthDataRepository
    let healthBaselineService: HealthBaselineService
    let trainingLoadEngine: TrainingLoadEngine
    let workoutIntelligenceEngine: WorkoutIntelligenceEngine
    let recoveryEngine: RecoveryEngine
    let adaptiveNutritionEngine: AdaptiveNutritionEngine
    let nextBestActionEngine: HealthNextBestActionEngine
    let weeklyReviewEngine: WeeklyReviewEngine
    let healthIntelligenceContextBuilder: HealthIntelligenceContextBuilder
    let healthIntelligenceEngine: any HealthIntelligenceEngineing
    let healthIntelligenceSnapshotService: any HealthIntelligenceSnapshotServing
    let weeklyReviewService: any WeeklyReviewServing
    let healthSyncService: HealthSyncService
    let healthSyncStateStore: HealthSyncStateStore
    let healthSummaryRemoteSyncClient: any HealthSummaryRemoteSyncing
    let healthSummarySyncService: HealthSummarySyncService
    let healthSummarySyncConsentStore: HealthSummarySyncConsentStore
    private let healthSummarySyncConsentStorage: any HealthSummarySyncConsentStoring
    let coachTimelineStore: SwiftDataCoachTimelineStore
    let coachChatTranscriptStore: SwiftDataCoachChatTranscriptStore
    let coachTimelineBackfillService: CoachTimelineBackfillService
    let coachTimelineRecorder: DefaultCoachTimelineRecorder
    private let authUIDCache: AuthUIDCache

    let onboardingUserDefaults: UserDefaults
    let onboardingDraftStore: OnboardingDraftStore
    let publicEntrySessionStore: PublicEntrySessionStore
    let onboardingCoachingContextStore: OnboardingCoachingContextStore
    let onboardingAnalyticsLogger: any OnboardingAnalyticsLogging
    let todayAnalyticsLogger: any TodayAnalyticsLogging
    let planAnalyticsLogger: any PlanAnalyticsLogging
    let journeyAnalyticsLogger: any JourneyAnalyticsLogging
    let publicEntryAnalyticsLogger: any PublicEntryAnalyticsLogging
    let themeAnalyticsLogger: any ThemeAnalyticsLogging
    let settingsAnalyticsLogger: any SettingsAnalyticsLogging
    let onboardingRoutingConfiguration: OnboardingRoutingConfiguration

    let themeStore: ThemeStore

    init(
        inMemory: Bool = false,
        onboardingUserDefaults: UserDefaults? = nil,
        onboardingAnalyticsLogger: (any OnboardingAnalyticsLogging)? = nil,
        todayAnalyticsLogger: (any TodayAnalyticsLogging)? = nil,
        planAnalyticsLogger: (any PlanAnalyticsLogging)? = nil,
        journeyAnalyticsLogger: (any JourneyAnalyticsLogging)? = nil,
        publicEntryAnalyticsLogger: (any PublicEntryAnalyticsLogging)? = nil,
        themeAnalyticsLogger: (any ThemeAnalyticsLogging)? = nil,
        settingsAnalyticsLogger: (any SettingsAnalyticsLogging)? = nil,
        onboardingRoutingConfiguration: OnboardingRoutingConfiguration? = nil,
        accountDataRemoteStore: (any AccountDataRemoteStore)? = nil
    ) throws {
        let resolvedOnboardingRoutingConfiguration = onboardingRoutingConfiguration ?? .production
        refreshCenter = AppRefreshCenter()
        accountRestoreSessionState = AccountRestoreSessionState()
        let authManager = AuthManager()
        self.authManager = authManager
        self.authUIDCache = AuthUIDCache()
        authUIDCache.update(uid: authManager.currentUID)

        self.onboardingUserDefaults = Self.makeOnboardingUserDefaults(
            inMemory: inMemory,
            override: onboardingUserDefaults
        )
        onboardingDraftStore = OnboardingDraftStore(userDefaults: self.onboardingUserDefaults)
        publicEntrySessionStore = PublicEntrySessionStore(userDefaults: self.onboardingUserDefaults)
        onboardingCoachingContextStore = OnboardingCoachingContextStore(
            userDefaults: self.onboardingUserDefaults
        )
        #if DEBUG
        self.onboardingAnalyticsLogger = onboardingAnalyticsLogger ?? OSLogOnboardingAnalyticsLogger()
        self.todayAnalyticsLogger = todayAnalyticsLogger ?? OSLogTodayAnalyticsLogger()
        self.planAnalyticsLogger = planAnalyticsLogger ?? OSLogPlanAnalyticsLogger()
        self.journeyAnalyticsLogger = journeyAnalyticsLogger ?? OSLogJourneyAnalyticsLogger()
        self.publicEntryAnalyticsLogger = publicEntryAnalyticsLogger ?? OSLogPublicEntryAnalyticsLogger()
        self.themeAnalyticsLogger = themeAnalyticsLogger ?? OSLogThemeAnalyticsLogger()
        self.settingsAnalyticsLogger = settingsAnalyticsLogger ?? OSLogSettingsAnalyticsLogger()
        #else
        self.onboardingAnalyticsLogger = onboardingAnalyticsLogger ?? NoOpOnboardingAnalyticsLogger()
        self.todayAnalyticsLogger = todayAnalyticsLogger ?? NoOpTodayAnalyticsLogger()
        self.planAnalyticsLogger = planAnalyticsLogger ?? NoOpPlanAnalyticsLogger()
        self.journeyAnalyticsLogger = journeyAnalyticsLogger ?? NoOpJourneyAnalyticsLogger()
        self.publicEntryAnalyticsLogger = publicEntryAnalyticsLogger ?? NoOpPublicEntryAnalyticsLogger()
        self.themeAnalyticsLogger = themeAnalyticsLogger ?? NoOpThemeAnalyticsLogger()
        self.settingsAnalyticsLogger = settingsAnalyticsLogger ?? NoOpSettingsAnalyticsLogger()
        #endif
        self.onboardingRoutingConfiguration = resolvedOnboardingRoutingConfiguration

        themeStore = ThemeStore(analyticsLogger: self.themeAnalyticsLogger)

        healthTrainingService = HealthTrainingService()
        let sharedHealthKitManager = HealthKitManager()
        let workoutReader = HealthTrainingReaderFactory.makeWorkoutReader(
            healthKitManager: sharedHealthKitManager
        )
        let stepReader = HealthTrainingReaderFactory.makeStepReader(
            healthKitManager: sharedHealthKitManager
        )
        healthKitWorkoutReader = workoutReader
        healthKitStepReader = stepReader
        healthCacheStore = LocalHealthCacheStore(userProvider: authUIDCache)
        healthDataRepository = HealthDataRepository(
            healthKitManager: sharedHealthKitManager,
            cacheStore: healthCacheStore
        )
        healthBaselineService = HealthBaselineService(repository: healthDataRepository)
        trainingLoadEngine = TrainingLoadEngine()
        workoutIntelligenceEngine = WorkoutIntelligenceEngine()
        recoveryEngine = RecoveryEngine()
        adaptiveNutritionEngine = AdaptiveNutritionEngine()
        nextBestActionEngine = HealthNextBestActionEngine()
        weeklyReviewEngine = WeeklyReviewEngine()
        healthActivityQueryService = HealthActivityQueryService(
            workoutReader: workoutReader,
            stepReader: stepReader,
            healthDataRepository: healthDataRepository
        )
        healthSyncService = HealthSyncService(
            repository: healthDataRepository,
            cacheStore: healthCacheStore
        )
        let remoteSummarySyncCapable = HealthIntelligenceFeatureFlags.healthSummaryRemoteSyncEnabled
        healthSummarySyncConsentStorage = inMemory
            ? LockedHealthSummarySyncConsentStore()
            : UserDefaultsHealthSummarySyncConsentStore()
        healthSummarySyncConsentStore = HealthSummarySyncConsentStore(
            storage: healthSummarySyncConsentStorage,
            userProvider: authUIDCache
        )
        let remoteSyncActiveProvider: @Sendable () -> Bool = { [authUIDCache, healthSummarySyncConsentStorage] in
            HealthSummarySyncConsentResolver.isRemoteSyncActive(
                storage: healthSummarySyncConsentStorage,
                userProvider: authUIDCache,
                featureFlagEnabled: remoteSummarySyncCapable
            )
        }
        healthSummaryRemoteSyncClient = (inMemory || !remoteSummarySyncCapable)
            ? NoopHealthSummaryRemoteSyncClient()
            : FirestoreHealthSummaryRemoteSyncClient(userProvider: authUIDCache)
        healthSummarySyncService = HealthSummarySyncService(
            remoteSyncClient: healthSummaryRemoteSyncClient,
            cacheStore: healthCacheStore,
            repository: healthDataRepository,
            userProvider: authUIDCache,
            localHealthSyncService: healthSyncService,
            remoteSyncEnabled: remoteSyncActiveProvider
        )
        healthSyncStateStore = HealthSyncStateStore(
            syncService: healthSyncService,
            remoteSummarySyncService: remoteSummarySyncCapable ? healthSummarySyncService : nil,
            syncEnabled: HealthIntelligenceFeatureFlags.isSyncEnabled,
            remoteSummarySyncEnabled: remoteSyncActiveProvider
        )
        if HealthIntelligenceFeatureFlags.isSyncEnabled {
            refreshCenter.healthDayChangeHandler = { [healthSyncStateStore] in
                healthSyncStateStore.refreshOnDayChange()
            }
        }
        trainingInsightsStore = TrainingInsightsStore(
            integration: healthTrainingService,
            healthSyncStateStore: HealthIntelligenceFeatureFlags.isSyncEnabled
                ? healthSyncStateStore
                : nil
        )
        trainingInsightsModel = TrainingInsightsModel(workoutReader: workoutReader)
        HealthTrainingDebugLogger.event(
            "Training integration wired",
            fields: [
                "bundleId": Bundle.main.bundleIdentifier ?? "unknown",
                "initialDataSource": trainingInsightsStore.dataSource.rawValue
            ]
        )

        modelContainer = try FormaModelContainer.makeContainer(inMemory: inMemory)
        store = SwiftDataStore(container: modelContainer)

        accountSyncOutboxStore = SwiftDataAccountSyncOutboxStore(store: store)
        accountLocalMutationTracker = AccountLocalMutationTracker(
            outbox: accountSyncOutboxStore,
            ownerUIDProvider: { [weak authManager] in authManager?.currentUID }
        )

        userProfileService = UserProfileService(store: store)
        cloudUserProfileStore = inMemory
            ? NoOpCloudUserProfileStore()
            : FirestoreCloudUserProfileStore()
        if let accountDataRemoteStore {
            self.accountDataRemoteStore = accountDataRemoteStore
        } else if inMemory || !AccountPersistenceFeatureFlags.cloudSchemaEnabled {
            self.accountDataRemoteStore = InMemoryAccountDataRemoteStore()
        } else {
            self.accountDataRemoteStore = FirestoreAccountDataRemoteStore()
        }
        accountSyncUploader = AccountSyncUploader(
            outbox: accountSyncOutboxStore,
            payloadBuilder: SwiftDataAccountSyncPayloadBuilder(store: store),
            remoteStore: accountDataRemoteStore,
            store: store
        )
        accountSyncPuller = AccountSyncPuller(
            remoteStore: accountDataRemoteStore,
            store: store
        )
        accountSyncDiagnostics = AccountSyncDiagnostics()
        accountSyncCoordinator = AccountSyncCoordinator(
            uploader: accountSyncUploader,
            puller: accountSyncPuller,
            currentUIDProvider: { [weak authManager] in authManager?.currentUID },
            diagnostics: accountSyncDiagnostics
        )
        profileCloudSyncStore = ProfileCloudSyncStore(userDefaults: self.onboardingUserDefaults)
        profileBootstrapService = ProfileBootstrapService(
            userProfileService: userProfileService,
            cloudStore: cloudUserProfileStore,
            cloudSyncStore: profileCloudSyncStore
        )
        profileBootstrapCoordinatorService = ProfileBootstrapCoordinatorService(
            profileBootstrapService: profileBootstrapService,
            cloudSyncStore: profileCloudSyncStore
        )
        cloudUploadFailureNotifier = ProfileCloudUploadFailureNotifier(
            syncStore: profileCloudSyncStore
        )
        dailyLogService = DailyLogService(
            store: store,
            userProfileService: userProfileService,
            mutationTracker: accountLocalMutationTracker
        )
        targetService = TargetService(
            userProfileService: userProfileService,
            dailyLogService: dailyLogService
        )
        foodLogService = FoodLogService(
            store: store,
            dailyLogService: dailyLogService,
            mutationTracker: accountLocalMutationTracker
        )
        waterLogService = WaterLogService(
            store: store,
            dailyLogService: dailyLogService,
            mutationTracker: accountLocalMutationTracker
        )
        weightLogService = WeightLogService(
            store: store,
            dailyLogService: dailyLogService,
            mutationTracker: accountLocalMutationTracker
        )

        let healthIntelligenceContextBuilder = HealthIntelligenceContextBuilder(
            repository: healthDataRepository,
            nutritionProvider: DailyLogNutritionProvider(reader: dailyLogService),
            weightProvider: WeightLogWeightProvider(reader: weightLogService),
            userPlanProvider: UserProfilePlanProvider(profileService: userProfileService)
        )
        self.healthIntelligenceContextBuilder = healthIntelligenceContextBuilder
        healthIntelligenceEngine = HealthIntelligenceEngine(
            contextBuilder: healthIntelligenceContextBuilder,
            dependencies: HealthIntelligenceEngineDependencies(
                trainingLoad: trainingLoadEngine,
                workout: workoutIntelligenceEngine,
                recovery: recoveryEngine,
                adaptiveNutrition: adaptiveNutritionEngine,
                nextBestAction: nextBestActionEngine,
                weeklyReview: weeklyReviewEngine
            )
        )
        healthIntelligenceSnapshotService = HealthIntelligenceSnapshotService(
            engine: healthIntelligenceEngine,
            cacheStore: healthCacheStore,
            enginesEnabled: HealthIntelligenceFeatureFlags.healthIntelligenceEnginesEnabled
        )
        healthSyncStateStore.setSnapshotService(healthIntelligenceSnapshotService)
        weeklyReviewService = WeeklyReviewService(
            contextBuilder: healthIntelligenceContextBuilder,
            weeklyReviewEngine: weeklyReviewEngine,
            recoveryEngine: recoveryEngine,
            trainingLoadEngine: trainingLoadEngine,
            cacheStore: healthCacheStore,
            enginesEnabled: HealthIntelligenceFeatureFlags.healthIntelligenceEnginesEnabled,
            weeklyReviewEnabled: HealthIntelligenceFeatureFlags.healthIntelligenceWeeklyReviewEnabled
        )

        coachTimelineStore = SwiftDataCoachTimelineStore(
            store: store,
            userIdProvider: { [weak authManager] in authManager?.currentUID }
        )
        coachChatTranscriptStore = SwiftDataCoachChatTranscriptStore(
            store: store,
            userIdProvider: { [weak authManager] in authManager?.currentUID }
        )
        coachTimelineBackfillService = CoachTimelineBackfillService(
            timelineStore: coachTimelineStore,
            foodLogService: foodLogService,
            waterLogService: waterLogService,
            weightLogService: weightLogService,
            healthActivityQuery: healthActivityQueryService
        )
        coachTimelineRecorder = DefaultCoachTimelineRecorder(store: coachTimelineStore)

        Task { @MainActor [coachTimelineBackfillService] in
            await coachTimelineBackfillService.runBackfill()
        }

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

        // All builds call the hosted Firebase aiGateway. Provider keys stay in Secret Manager.
        // Previews and in-memory containers use MockLLMClient; production wiring requires auth.
        #if DEBUG
        let wiring: (clientType: String, baseURL: URL?, authAttached: Bool)
        #endif
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
        aiService = AIService(llmClient: llmClient)
        aiCommandParsingEnabled = FormaAbTest.Coach.aiCommandParsingEnabled

        reviewService = ReviewService(
            store: store,
            dailyLogService: dailyLogService,
            foodLogService: foodLogService,
            waterLogService: waterLogService,
            weightLogService: weightLogService,
            healthActivityQuery: healthActivityQueryService,
            userProfileService: userProfileService,
            aiService: aiService,
            mutationTracker: accountLocalMutationTracker
        )

        accountRestoreStateStore = AccountRestoreStateStore(userDefaults: onboardingUserDefaults)
        accountLocalDataInspector = AccountLocalDataInspector(
            store: store,
            userProfileService: userProfileService,
            outboxStore: accountSyncOutboxStore
        )
        accountSyncCursorStore = AccountSyncCursorStore(userDefaults: onboardingUserDefaults)
        accountIncrementalPuller = AccountIncrementalPuller(
            remoteStore: accountDataRemoteStore,
            mergePuller: accountSyncPuller,
            cursorStore: accountSyncCursorStore,
            profileBootstrapService: profileBootstrapService,
            userProfileService: userProfileService,
            profileCloudSyncStore: profileCloudSyncStore,
            localInspector: accountLocalDataInspector,
            currentUIDProvider: { [weak authManager] in authManager?.currentUID }
        )
        accountDataRefreshEventBus = AccountDataRefreshEventBus()
        crossDeviceSyncCoordinator = CrossDeviceSyncCoordinator(
            syncCoordinator: accountSyncCoordinator,
            incrementalPuller: accountIncrementalPuller,
            cursorStore: accountSyncCursorStore,
            uidProvider: ClosureAccountUIDProvider { [weak authManager] in authManager?.currentUID },
            refreshCenter: refreshCenter,
            refreshEventBus: accountDataRefreshEventBus
        )
        if inMemory {
            accountRealtimeChangeListener = NoOpAccountRealtimeChangeListener()
        } else {
            accountRealtimeChangeListener = FirestoreAccountRealtimeChangeListener()
        }
        AccountRealtimeChangeListenerLifecycle.connect(
            listener: accountRealtimeChangeListener,
            crossDeviceCoordinator: crossDeviceSyncCoordinator
        )
        accountRemoteDataInspector = AccountRemoteDataInspector(
            cloudProfileStore: cloudUserProfileStore,
            remoteStore: accountDataRemoteStore
        )
        accountDataNamespaceService = AccountDataNamespaceService(
            store: store,
            healthCacheStore: healthCacheStore,
            userDefaults: onboardingUserDefaults,
            syncCoordinator: accountSyncCoordinator
        )
        accountMigrationService = AccountMigrationService(
            store: store,
            userProfileService: userProfileService
        )
        accountInitialRestoreService = AccountInitialRestoreService(
            profileBootstrapService: profileBootstrapService,
            puller: accountSyncPuller,
            localInspector: accountLocalDataInspector,
            remoteInspector: accountRemoteDataInspector,
            stateStore: accountRestoreStateStore,
            syncCoordinator: accountSyncCoordinator,
            dailyLogService: dailyLogService,
            currentUIDProvider: { [weak authManager] in authManager?.currentUID }
        )
        accountRestoreDiagnostics = AccountRestoreDiagnostics()
        accountRestoreCoordinator = AccountRestoreCoordinator(
            namespaceService: accountDataNamespaceService,
            migrationService: accountMigrationService,
            localInspector: accountLocalDataInspector,
            remoteInspector: accountRemoteDataInspector,
            initialRestoreService: accountInitialRestoreService,
            stateStore: accountRestoreStateStore,
            syncCoordinator: accountSyncCoordinator,
            diagnostics: accountRestoreDiagnostics,
            currentUIDProvider: { [weak authManager] in authManager?.currentUID },
            onBackgroundBackfillFinished: { [weak self] _ in
                self?.refreshCenter.notifyBackgroundBackfillDidComplete()
            }
        )

        actionCenter = FitnessActionCenter(
            foodLogService: foodLogService,
            waterLogService: waterLogService,
            weightLogService: weightLogService,
            dailyLogService: dailyLogService,
            targetService: targetService,
            userProfileService: userProfileService,
            reviewService: reviewService,
            refreshCenter: refreshCenter,
            profileBootstrapService: profileBootstrapService,
            cloudUploadFailureNotifier: cloudUploadFailureNotifier,
            currentUIDProvider: { [weak authManager] in authManager?.currentUID },
            scheduleAccountSyncAfterMutation: { [authManager, accountSyncCoordinator] in
                AccountSyncLifecycle.scheduleAfterLocalMutation(
                    coordinator: accountSyncCoordinator,
                    uidProvider: { authManager.currentUID }
                )
            }
        )

        #if DEBUG
        Self.logAIBackendURLDetection()
        Self.logLLMClientWiring(
            clientType: wiring.clientType,
            baseURL: wiring.baseURL,
            authAttached: wiring.authAttached
        )
        #endif
    }

    func syncHealthCacheUserID() {
        let uidChanged = authUIDCache.updateIfChanged(uid: authManager.currentUID)
        healthSummarySyncConsentStore.refresh()
        if uidChanged {
            healthSyncStateStore.cancelActiveSync()
            AccountSyncLifecycle.cancelOnAccountSwitch(coordinator: accountSyncCoordinator)
            accountRestoreCoordinator.cancelOnAccountSwitch()
            CrossDeviceSyncLifecycle.cancelOnAccountSwitch(
                crossDeviceCoordinator: crossDeviceSyncCoordinator,
                realtimeListener: accountRealtimeChangeListener
            )
        }
    }

    func handleAccountDataSyncOnAppForeground() {
        guard let uid = authManager.currentUID else { return }
        if AccountRestoreCoordinatorSupport.isRestoreEnabled {
            Task {
                _ = await accountRestoreCoordinator.prepareAccountOnAppLaunch(uid: uid)
            }
        } else {
            AccountSyncLifecycle.handleAppForeground(
                coordinator: accountSyncCoordinator,
                uidProvider: { [authManager] in authManager.currentUID }
            )
        }
        CrossDeviceSyncLifecycle.handleAppForeground(
            coordinator: crossDeviceSyncCoordinator,
            uidProvider: { [authManager] in authManager.currentUID }
        )
    }

    func handleSignedInSessionReady(uid: String) {
        CrossDeviceSyncLifecycle.startRealtimeListenerIfEnabled(
            listener: accountRealtimeChangeListener,
            uid: uid
        )
    }

    func stopCrossDeviceSyncSession() {
        crossDeviceSyncCoordinator.cancelPendingWork()
        Task {
            await CrossDeviceSyncLifecycle.stopRealtimeListener(listener: accountRealtimeChangeListener)
        }
    }

    @discardableResult
    func performManualCrossDeviceRefresh() async -> CrossDeviceSyncSummary? {
        guard let uid = authManager.currentUID else { return nil }
        return await CrossDeviceSyncLifecycle.handleManualRefresh(
            coordinator: crossDeviceSyncCoordinator,
            uid: uid
        )
    }

    /// Prepares UID namespace and legacy ownerUID backfill before profile bootstrap.
    func prepareSignedInAccountNamespace(uid: String) async {
        try? await profileBootstrapService.prepareSignedInAccountNamespace(
            uid: uid,
            namespaceService: accountDataNamespaceService,
            migrationService: accountMigrationService
        )
    }

    /// Runs blocking account restore; timeout policy is enforced by the coordinator.
    func runAccountRestoreAfterSignIn(
        uid: String,
        reason: AccountRestoreReason
    ) async -> AccountRestoreSummary {
        await accountRestoreCoordinator.prepareAccountAfterSignIn(
            uid: uid,
            reason: reason
        )
    }

    func handleAccountRestoreAfterSignIn(uid: String) {
        Task {
            _ = await runAccountRestoreAfterSignIn(uid: uid, reason: .afterSignIn)
        }
    }

    func handleAccountDataSyncAfterSignIn(uid: String) {
        handleAccountRestoreAfterSignIn(uid: uid)
    }

    #if DEBUG
    func makeAccountRestoreDebugActions() -> AccountRestoreDebugActions {
        AccountRestoreDebugActions(
            lastSnapshot: { [accountRestoreDiagnostics] in
                accountRestoreDiagnostics.lastSnapshot
            },
            restoreStateDescription: { [authManager, accountRestoreDiagnostics, accountRestoreStateStore] in
                guard let uid = authManager.currentUID else {
                    return "No signed-in UID."
                }
                let state = accountRestoreDiagnostics.restoreState(
                    for: uid,
                    stateStore: accountRestoreStateStore
                )
                return AccountRestoreLoggerDebugSupport.redactedRestoreStateDescription(state)
            },
            triggerManualRetry: { [accountRestoreCoordinator, authManager, accountRestoreDiagnostics] in
                guard let uid = authManager.currentUID else { return nil }
                return await accountRestoreDiagnostics.triggerManualRetry(
                    coordinator: accountRestoreCoordinator,
                    uid: uid
                )
            },
            resetRestoreMetadata: { [authManager, accountRestoreDiagnostics, accountRestoreStateStore] in
                guard let uid = authManager.currentUID else { return }
                accountRestoreDiagnostics.resetRestoreMetadata(
                    stateStore: accountRestoreStateStore,
                    uid: uid
                )
            }
        )
    }

    func makeAccountSyncDebugActions() -> AccountSyncDebugActions {
        AccountSyncDebugActions(
            pendingMutationCount: { [accountSyncOutboxStore, authManager] in
                await accountSyncDiagnostics.pendingMutationCount(
                    outbox: accountSyncOutboxStore,
                    ownerUID: authManager.currentUID ?? ""
                )
            },
            lastSnapshot: { [accountSyncDiagnostics] in
                accountSyncDiagnostics.lastSnapshot
            },
            triggerManualSync: { [accountSyncCoordinator, authManager, accountSyncDiagnostics] in
                guard let uid = authManager.currentUID else { return nil }
                return await accountSyncDiagnostics.triggerManualSync(
                    coordinator: accountSyncCoordinator,
                    ownerUID: uid
                )
            },
            triggerManualCrossDeviceRefresh: { [weak self] in
                await self?.performManualCrossDeviceRefresh()
            }
        )
    }
    #endif

    func makeHealthIntelligenceEngine() -> any HealthIntelligenceEngineing {
        healthIntelligenceEngine
    }

    func refreshHealthIntelligenceSnapshotIfNeeded() async {
        guard HealthIntelligenceFeatureFlags.healthIntelligenceEnginesEnabled else { return }
        await healthIntelligenceSnapshotService.refreshTodaySnapshot(calendar: .current)
    }

    func makeTodayActionCoordinator(
        healthIntelligenceAnalyticsCoordinator: HealthIntelligenceAnalyticsCoordinator? = nil
    ) -> TodayActionCoordinator {
        TodayActionCoordinator(
            actionCenter: actionCenter,
            analyticsLogger: todayAnalyticsLogger,
            healthIntelligenceAnalyticsCoordinator: healthIntelligenceAnalyticsCoordinator
        )
    }

    func makeTodayModel(
        healthIntelligenceAnalyticsCoordinator: HealthIntelligenceAnalyticsCoordinator? = nil
    ) -> TodayModel {
        TodayModel(
            dailyLogReader: dailyLogService,
            foodLogReader: foodLogService,
            weightLogReader: weightLogService,
            dailyReviewReader: reviewService,
            userProfileReader: userProfileService,
            healthActivityQuery: healthActivityQueryService,
            healthIntelligenceSnapshotProvider: healthIntelligenceSnapshotService,
            hydrationContextProvider: { [weak self] in
                guard let self else { return nil }
                return TodayHydrationGate.resolve(
                    authState: self.authManager.authState,
                    profile: try? self.userProfileService.getCurrentProfile()
                )
            },
            authStateProvider: { [weak self] in
                self?.authManager.authState ?? .unknown
            },
            restoreSessionState: accountRestoreSessionState,
            localDataInspector: accountLocalDataInspector,
            ownerUIDProvider: { [weak authManager] in authManager?.currentUID },
            healthIntelligenceAnalyticsCoordinator: healthIntelligenceAnalyticsCoordinator,
            accountDataRefreshEventBus: accountDataRefreshEventBus,
            crossDeviceSyncCoordinator: crossDeviceSyncCoordinator
        )
    }

    func makeCoachModel(
        healthIntelligenceAnalyticsCoordinator: HealthIntelligenceAnalyticsCoordinator? = nil
    ) -> CoachModel {
        let contextPacketBuilder = CoachContextPacketV2Builder(
            dailyLogService: dailyLogService,
            foodLogService: foodLogService,
            waterLogService: waterLogService,
            weightLogService: weightLogService,
            userProfileService: userProfileService,
            healthActivityQuery: healthActivityQueryService,
            healthIntelligenceSnapshotProvider: healthIntelligenceSnapshotService,
            healthIntelligenceContextBuilder: healthIntelligenceContextBuilder,
            trainingLoadEngine: trainingLoadEngine,
            timelineStore: coachTimelineStore,
            timelineBackfillService: coachTimelineBackfillService,
            timelineRecorder: coachTimelineRecorder
        )

        return CoachModel(
            actionCenter: actionCenter,
            dailyLogReader: dailyLogService,
            healthActivityQuery: healthActivityQueryService,
            healthIntelligenceSnapshotProvider: healthIntelligenceSnapshotService,
            healthDataRepository: healthDataRepository,
            healthIntelligenceLoadEnabled: { HealthIntelligenceFeatureFlags.shouldCoachLoadHealthIntelligence },
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
            weightLogReader: weightLogService,
            aiService: aiService,
            contextPacketBuilder: contextPacketBuilder,
            userProfileReader: userProfileService,
            aiCommandParsingEnabled: aiCommandParsingEnabled,
            trainingInsightsStore: trainingInsightsStore,
            transcriptStore: coachChatTranscriptStore,
            healthIntelligenceAnalyticsCoordinator: healthIntelligenceAnalyticsCoordinator,
            timelineRecorder: coachTimelineRecorder,
            timelineStore: coachTimelineStore
        )
    }

    func makeJourneyAnalyticsCoordinator() -> JourneyAnalyticsCoordinator {
        JourneyAnalyticsCoordinator(analyticsLogger: journeyAnalyticsLogger)
    }

    func makeSettingsAnalyticsCoordinator() -> SettingsAnalyticsCoordinator {
        SettingsAnalyticsCoordinator(analyticsLogger: settingsAnalyticsLogger)
    }

    func makeHealthIntelligenceAnalyticsCoordinator() -> HealthIntelligenceAnalyticsCoordinator {
        #if DEBUG
        HealthIntelligenceAnalyticsCoordinator(analyticsLogger: OSLogHealthIntelligenceAnalyticsLogger())
        #else
        HealthIntelligenceAnalyticsCoordinator(analyticsLogger: NoOpHealthIntelligenceAnalyticsLogger())
        #endif
    }

    func makeJourneyModel(
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
            crossDeviceSyncCoordinator: crossDeviceSyncCoordinator
        )
    }

    func makePlanModel(
        healthIntelligenceAnalyticsCoordinator: HealthIntelligenceAnalyticsCoordinator? = nil
    ) -> PlanModel {
        PlanModel(
            actionCenter: actionCenter,
            userProfileReader: userProfileService,
            planTargetCalculator: targetService,
            dailyLogReader: dailyLogService,
            weightLogReader: weightLogService,
            trainingInsightsStore: trainingInsightsStore,
            analyticsLogger: planAnalyticsLogger,
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
            }
        )
    }

    func makeRootModel() -> RootModel {
        RootModel(profileBootstrapService: profileBootstrapService)
    }

    func makeOnboardingModel(
        entry: OnboardingAnalyticsEntry = .preAuth,
        onCompletion: @escaping () -> Void
    ) -> OnboardingModel {
        return OnboardingModel(
            actionCenter: actionCenter,
            userProfileReader: userProfileService,
            planTargetCalculator: targetService,
            onCompletion: onCompletion,
            draftStore: onboardingDraftStore,
            coachingContextStore: onboardingCoachingContextStore,
            analyticsLogger: onboardingAnalyticsLogger,
            analyticsEntry: entry,
            healthTrainingIntegration: healthTrainingService,
            trainingInsightsStore: trainingInsightsStore,
            healthSyncStateStore: HealthIntelligenceFeatureFlags.isSyncEnabled
                ? healthSyncStateStore
                : nil
        )
    }

    func resolveAppShellRoute(
        authState: AuthState,
        rootState: RootViewState = .loading,
        isOnboardingModelReady: Bool = false,
        awaitingCloudSync: Bool = false,
        pendingOnboardingCompletion: Bool = false,
        publicEntryDestination: PublicEntryRoute = .welcome
    ) -> AppShellRoute {
        if awaitingCloudSync,
           AppRouteResolver.isSignedIn(authState),
           rootState == .main {
            return .signedInProfileLoading
        }

        return AppRouteResolver.resolve(
            authState: authState,
            rootState: rootState,
            isOnboardingModelReady: isOnboardingModelReady,
            hasLocalProfile: profileBootstrapService.hasLocalProfile(),
            signedOutWithProfilePolicy: .requireSignIn,
            localProfileAwaitingSignIn: profileBootstrapService.localProfileAwaitingSignIn(),
            pendingOnboardingCompletion: pendingOnboardingCompletion,
            publicEntryDestination: publicEntryDestination,
            hasPersistedOnboardingDraft: onboardingDraftStore.hasDraft,
            suppressAutomaticPublicEntryResume: publicEntrySessionStore.suppressAutomaticPublicEntryResume
        )
    }

    private static func makeOnboardingUserDefaults(
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
    private static func logAIBackendURLDetection() {
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
    #endif

    private static func logLLMClientWiring(clientType: String, baseURL: URL?, authAttached: Bool) {
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
}
