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

    // MARK: - App shell

    let refreshCenter: AppRefreshCenter

    // MARK: - Persistence & sync core

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

    // MARK: - Account lifecycle (restore / cross-device / deletion / export)

    let accountRestoreStateStore: AccountRestoreStateStore
    let accountLocalDataInspector: AccountLocalDataInspector
    let accountRemoteDataInspector: AccountRemoteDataInspector
    let accountDataNamespaceService: AccountDataNamespaceService
    let accountMigrationService: AccountMigrationService
    let accountInitialRestoreService: AccountInitialRestoreService
    let accountRestoreCoordinator: AccountRestoreCoordinator
    let accountRestoreDiagnostics: AccountRestoreDiagnostics
    let accountRestoreSessionState: AccountRestoreSessionState
    let accountDeletionGuard: AccountDeletionGuard
    let accountDeletionRemoteClient: any AccountDeletionRemoteDeleting
    let localAccountDataWipeService: LocalAccountDataWipeService
    let accountDeletionRouter: DeferredAccountDeletionRouter
    let accountDeletionCoordinator: AccountDeletionCoordinator
    let accountDataExportService: AccountDataExportService

    // MARK: - Domain services (profile, logs, reviews, actions)

    let userProfileService: UserProfileService
    let targetService: TargetService
    let dailyLogService: DailyLogService
    let foodLogService: FoodLogService
    let waterLogService: WaterLogService
    let weightLogService: WeightLogService
    let reviewService: ReviewService
    let actionCenter: FitnessActionCenter

    // MARK: - Auth & profile bootstrap

    let authManager: AuthManager
    let cloudUserProfileStore: CloudUserProfileStoring
    /// Phase 2 cloud log store — constructed and injectable; not wired to log mutations yet.
    let accountDataRemoteStore: any AccountDataRemoteStore
    let profileBootstrapService: ProfileBootstrapService
    let profileCloudSyncStore: ProfileCloudSyncStore
    let profileBootstrapCoordinatorService: ProfileBootstrapCoordinatorService
    let cloudUploadFailureNotifier: ProfileCloudUploadFailureNotifier
    private let authUIDCache: AuthUIDCache

    // MARK: - AI

    let llmClient: LLMClient
    let aiService: AIService
    let aiCommandParsingEnabled: Bool

    // MARK: - Health & training

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
    let healthSyncService: HealthSyncService
    let healthSyncStateStore: HealthSyncStateStore
    let healthSummaryRemoteSyncClient: any HealthSummaryRemoteSyncing
    let healthSummarySyncService: HealthSummarySyncService
    let healthSummarySyncConsentStore: HealthSummarySyncConsentStore
    private let healthSummarySyncConsentStorage: any HealthSummarySyncConsentStoring

    // MARK: - Health Intelligence

    let healthIntelligenceContextBuilder: HealthIntelligenceContextBuilder
    let healthIntelligenceEngine: any HealthIntelligenceEngineing
    let healthIntelligenceSnapshotService: any HealthIntelligenceSnapshotServing
    let weeklyReviewService: any WeeklyReviewServing

    // MARK: - Coach platform

    let coachTimelineStore: SwiftDataCoachTimelineStore
    let coachChatTranscriptStore: SwiftDataCoachChatTranscriptStore
    let coachTimelineBackfillService: CoachTimelineBackfillService
    let coachTimelineRecorder: DefaultCoachTimelineRecorder

    // MARK: - Onboarding & session preferences

    let onboardingUserDefaults: UserDefaults
    let onboardingDraftStore: OnboardingDraftStore
    let publicEntrySessionStore: PublicEntrySessionStore
    let onboardingCoachingContextStore: OnboardingCoachingContextStore
    let onboardingRoutingConfiguration: OnboardingRoutingConfiguration

    // MARK: - Analytics

    let onboardingAnalyticsLogger: any OnboardingAnalyticsLogging
    let todayAnalyticsLogger: any TodayAnalyticsLogging
    let planAnalyticsLogger: any PlanAnalyticsLogging
    let journeyAnalyticsLogger: any JourneyAnalyticsLogging
    let weeklyProgressAnalyticsLogger: any WeeklyProgressAnalyticsLogging
    let publicEntryAnalyticsLogger: any PublicEntryAnalyticsLogging
    let themeAnalyticsLogger: any ThemeAnalyticsLogging
    let settingsAnalyticsLogger: any SettingsAnalyticsLogging
    let healthIntelligenceAnalyticsLogger: any HealthIntelligenceAnalyticsLogging

    // MARK: - Settings / theme

    let themeStore: ThemeStore

    init(
        inMemory: Bool = false,
        onboardingUserDefaults: UserDefaults? = nil,
        onboardingAnalyticsLogger: (any OnboardingAnalyticsLogging)? = nil,
        todayAnalyticsLogger: (any TodayAnalyticsLogging)? = nil,
        planAnalyticsLogger: (any PlanAnalyticsLogging)? = nil,
        journeyAnalyticsLogger: (any JourneyAnalyticsLogging)? = nil,
        weeklyProgressAnalyticsLogger: (any WeeklyProgressAnalyticsLogging)? = nil,
        publicEntryAnalyticsLogger: (any PublicEntryAnalyticsLogging)? = nil,
        themeAnalyticsLogger: (any ThemeAnalyticsLogging)? = nil,
        settingsAnalyticsLogger: (any SettingsAnalyticsLogging)? = nil,
        healthIntelligenceAnalyticsLogger: (any HealthIntelligenceAnalyticsLogging)? = nil,
        onboardingRoutingConfiguration: OnboardingRoutingConfiguration? = nil,
        accountDataRemoteStore: (any AccountDataRemoteStore)? = nil
    ) throws {
        let session = Self.buildSession(
            inMemory: inMemory,
            onboardingUserDefaults: onboardingUserDefaults,
            onboardingRoutingConfiguration: onboardingRoutingConfiguration
        )
        let analytics = Self.buildAnalytics(
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
        let health = Self.buildHealth(session: session, inMemory: inMemory)
        let persistence = try Self.buildPersistence(
            session: session,
            inMemory: inMemory,
            accountDataRemoteStore: accountDataRemoteStore
        )
        let healthIntelligence = Self.buildHealthIntelligence(
            health: health,
            persistence: persistence
        )
        let coach = Self.buildCoachPlatform(
            session: session,
            persistence: persistence,
            health: health
        )
        let ai = Self.buildAI(session: session, inMemory: inMemory)
        let accountLifecycle = Self.buildAccountLifecycle(
            session: session,
            persistence: persistence,
            health: health,
            inMemory: inMemory
        )

        // App shell
        refreshCenter = session.refreshCenter

        // Persistence & sync core
        modelContainer = persistence.modelContainer
        store = persistence.store
        accountSyncOutboxStore = persistence.accountSyncOutboxStore
        accountLocalMutationTracker = persistence.accountLocalMutationTracker
        accountSyncUploader = persistence.accountSyncUploader
        accountSyncPuller = persistence.accountSyncPuller
        accountSyncCoordinator = persistence.accountSyncCoordinator
        accountSyncDiagnostics = persistence.accountSyncDiagnostics
        accountSyncCursorStore = accountLifecycle.accountSyncCursorStore
        accountIncrementalPuller = accountLifecycle.accountIncrementalPuller
        crossDeviceSyncCoordinator = accountLifecycle.crossDeviceSyncCoordinator
        accountDataRefreshEventBus = accountLifecycle.accountDataRefreshEventBus
        accountRealtimeChangeListener = accountLifecycle.accountRealtimeChangeListener

        // Account lifecycle
        accountRestoreStateStore = accountLifecycle.accountRestoreStateStore
        accountLocalDataInspector = accountLifecycle.accountLocalDataInspector
        accountRemoteDataInspector = accountLifecycle.accountRemoteDataInspector
        accountDataNamespaceService = accountLifecycle.accountDataNamespaceService
        accountMigrationService = accountLifecycle.accountMigrationService
        accountInitialRestoreService = accountLifecycle.accountInitialRestoreService
        accountRestoreCoordinator = accountLifecycle.accountRestoreCoordinator
        accountRestoreDiagnostics = accountLifecycle.accountRestoreDiagnostics
        accountRestoreSessionState = session.accountRestoreSessionState
        accountDeletionGuard = persistence.accountDeletionGuard
        accountDeletionRemoteClient = accountLifecycle.accountDeletionRemoteClient
        localAccountDataWipeService = accountLifecycle.localAccountDataWipeService
        accountDeletionRouter = accountLifecycle.accountDeletionRouter
        accountDeletionCoordinator = accountLifecycle.accountDeletionCoordinator
        accountDataExportService = accountLifecycle.accountDataExportService

        // Domain services
        userProfileService = persistence.userProfileService
        targetService = persistence.targetService
        dailyLogService = persistence.dailyLogService
        foodLogService = persistence.foodLogService
        waterLogService = persistence.waterLogService
        weightLogService = persistence.weightLogService

        // Auth & profile bootstrap
        authManager = session.authManager
        cloudUserProfileStore = persistence.cloudUserProfileStore
        self.accountDataRemoteStore = persistence.accountDataRemoteStore
        profileBootstrapService = persistence.profileBootstrapService
        profileCloudSyncStore = persistence.profileCloudSyncStore
        profileBootstrapCoordinatorService = persistence.profileBootstrapCoordinatorService
        cloudUploadFailureNotifier = persistence.cloudUploadFailureNotifier
        authUIDCache = session.authUIDCache

        // AI
        llmClient = ai.llmClient
        aiService = ai.aiService
        aiCommandParsingEnabled = ai.aiCommandParsingEnabled

        // Health & training
        healthTrainingService = health.healthTrainingService
        trainingInsightsStore = health.trainingInsightsStore
        trainingInsightsModel = health.trainingInsightsModel
        healthKitWorkoutReader = health.healthKitWorkoutReader
        healthKitStepReader = health.healthKitStepReader
        healthActivityQueryService = health.healthActivityQueryService
        healthCacheStore = health.healthCacheStore
        healthDataRepository = health.healthDataRepository
        healthBaselineService = health.healthBaselineService
        trainingLoadEngine = health.trainingLoadEngine
        workoutIntelligenceEngine = health.workoutIntelligenceEngine
        recoveryEngine = health.recoveryEngine
        adaptiveNutritionEngine = health.adaptiveNutritionEngine
        nextBestActionEngine = health.nextBestActionEngine
        weeklyReviewEngine = health.weeklyReviewEngine
        healthSyncService = health.healthSyncService
        healthSyncStateStore = health.healthSyncStateStore
        healthSummaryRemoteSyncClient = health.healthSummaryRemoteSyncClient
        healthSummarySyncService = health.healthSummarySyncService
        healthSummarySyncConsentStore = health.healthSummarySyncConsentStore
        healthSummarySyncConsentStorage = health.healthSummarySyncConsentStorage

        // Health Intelligence
        healthIntelligenceContextBuilder = healthIntelligence.healthIntelligenceContextBuilder
        healthIntelligenceEngine = healthIntelligence.healthIntelligenceEngine
        healthIntelligenceSnapshotService = healthIntelligence.healthIntelligenceSnapshotService
        weeklyReviewService = healthIntelligence.weeklyReviewService

        // Coach platform
        coachTimelineStore = coach.coachTimelineStore
        coachChatTranscriptStore = coach.coachChatTranscriptStore
        coachTimelineBackfillService = coach.coachTimelineBackfillService
        coachTimelineRecorder = coach.coachTimelineRecorder

        // Onboarding & session preferences
        onboardingUserDefaults = session.onboardingUserDefaults
        onboardingDraftStore = session.onboardingDraftStore
        publicEntrySessionStore = session.publicEntrySessionStore
        onboardingCoachingContextStore = session.onboardingCoachingContextStore
        self.onboardingRoutingConfiguration = session.onboardingRoutingConfiguration

        // Analytics
        onboardingAnalyticsLogger = analytics.onboardingAnalyticsLogger
        todayAnalyticsLogger = analytics.todayAnalyticsLogger
        planAnalyticsLogger = analytics.planAnalyticsLogger
        journeyAnalyticsLogger = analytics.journeyAnalyticsLogger
        weeklyProgressAnalyticsLogger = analytics.weeklyProgressAnalyticsLogger
        publicEntryAnalyticsLogger = analytics.publicEntryAnalyticsLogger
        themeAnalyticsLogger = analytics.themeAnalyticsLogger
        settingsAnalyticsLogger = analytics.settingsAnalyticsLogger
        healthIntelligenceAnalyticsLogger = analytics.healthIntelligenceAnalyticsLogger

        // Settings / theme
        themeStore = ThemeStore(analyticsLogger: analytics.themeAnalyticsLogger)

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
            currentUIDProvider: { [authManager = session.authManager] in authManager.currentUID },
            scheduleAccountSyncAfterMutation: { [authManager = session.authManager, accountSyncCoordinator] in
                AccountSyncLifecycle.scheduleAfterLocalMutation(
                    coordinator: accountSyncCoordinator,
                    uidProvider: { authManager.currentUID }
                )
            }
        )

        #if DEBUG
        Self.logAIBackendURLDetection()
        Self.logLLMClientWiring(
            clientType: ai.wiring.clientType,
            baseURL: ai.wiring.baseURL,
            authAttached: ai.wiring.authAttached
        )
        #endif
    }

    // MARK: - Session lifecycle

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

    /// Phase 1 compatibility — records active local namespace for the signed-in UID.
    func prepareLocalUserDataNamespace(uid: String) async {
        _ = await accountDataNamespaceService.prepareForSignedInUID(uid)
    }

    /// Phase 1 compatibility — clears namespace tracking on sign-out without deleting SwiftData rows.
    func recordSignedOutLocalUserDataNamespace() async {
        await accountDataNamespaceService.prepareForSignOut()
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
}
