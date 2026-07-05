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
    let healthIntegrationConnectionStore: any HealthIntegrationConnectionStoring
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
    let foodCorrectionMemoryStore: FileFoodCorrectionMemoryStore

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
        let auth = Self.buildAuthDependencies(
            inMemory: inMemory,
            onboardingUserDefaults: onboardingUserDefaults,
            onboardingRoutingConfiguration: onboardingRoutingConfiguration
        )
        let analytics = Self.buildAnalyticsDependencies(
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
        let health = Self.buildHealth(session: auth, inMemory: inMemory)
        let persistence = try Self.buildPersistenceDependencies(
            session: auth,
            inMemory: inMemory,
            accountDataRemoteStore: accountDataRemoteStore
        )
        let healthIntelligence = Self.buildHealthIntelligenceDependencies(
            health: health,
            persistence: persistence
        )
        let coach = Self.buildCoachDependencies(
            session: auth,
            persistence: persistence,
            health: health
        )
        let ai = Self.buildAI(session: auth, inMemory: inMemory)
        let sync = Self.buildSyncDependencies(
            session: auth,
            persistence: persistence,
            health: health,
            inMemory: inMemory
        )
        let settings = Self.buildSettingsDependencies(analytics: analytics)
        let today = Self.buildTodayDependencies(
            auth: auth,
            persistence: persistence,
            health: health,
            ai: ai,
            refreshCenter: auth.refreshCenter
        )

        // App shell
        refreshCenter = auth.refreshCenter

        // Persistence & sync core
        modelContainer = persistence.modelContainer
        store = persistence.store
        accountSyncOutboxStore = persistence.accountSyncOutboxStore
        accountLocalMutationTracker = persistence.accountLocalMutationTracker
        accountSyncUploader = persistence.accountSyncUploader
        accountSyncPuller = persistence.accountSyncPuller
        accountSyncCoordinator = persistence.accountSyncCoordinator
        accountSyncDiagnostics = persistence.accountSyncDiagnostics
        accountSyncCursorStore = sync.accountSyncCursorStore
        accountIncrementalPuller = sync.accountIncrementalPuller
        crossDeviceSyncCoordinator = sync.crossDeviceSyncCoordinator
        accountDataRefreshEventBus = sync.accountDataRefreshEventBus
        accountRealtimeChangeListener = sync.accountRealtimeChangeListener

        // Account lifecycle
        accountRestoreStateStore = sync.accountRestoreStateStore
        accountLocalDataInspector = sync.accountLocalDataInspector
        accountRemoteDataInspector = sync.accountRemoteDataInspector
        accountDataNamespaceService = sync.accountDataNamespaceService
        accountMigrationService = sync.accountMigrationService
        accountInitialRestoreService = sync.accountInitialRestoreService
        accountRestoreCoordinator = sync.accountRestoreCoordinator
        accountRestoreDiagnostics = sync.accountRestoreDiagnostics
        accountRestoreSessionState = auth.accountRestoreSessionState
        accountDeletionGuard = persistence.accountDeletionGuard
        accountDeletionRemoteClient = sync.accountDeletionRemoteClient
        localAccountDataWipeService = sync.localAccountDataWipeService
        accountDeletionRouter = sync.accountDeletionRouter
        accountDeletionCoordinator = sync.accountDeletionCoordinator
        accountDataExportService = sync.accountDataExportService

        // Domain services
        userProfileService = persistence.userProfileService
        targetService = persistence.targetService
        dailyLogService = persistence.dailyLogService
        foodLogService = persistence.foodLogService
        waterLogService = persistence.waterLogService
        weightLogService = persistence.weightLogService

        // Auth & profile bootstrap
        authManager = auth.authManager
        cloudUserProfileStore = persistence.cloudUserProfileStore
        self.accountDataRemoteStore = persistence.accountDataRemoteStore
        profileBootstrapService = persistence.profileBootstrapService
        profileCloudSyncStore = persistence.profileCloudSyncStore
        profileBootstrapCoordinatorService = persistence.profileBootstrapCoordinatorService
        cloudUploadFailureNotifier = persistence.cloudUploadFailureNotifier
        authUIDCache = auth.authUIDCache

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
        healthIntegrationConnectionStore = health.healthIntegrationConnectionStore
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
        foodCorrectionMemoryStore = coach.foodCorrectionMemoryStore

        // Onboarding & session preferences
        self.onboardingUserDefaults = auth.onboardingUserDefaults
        onboardingDraftStore = auth.onboardingDraftStore
        publicEntrySessionStore = auth.publicEntrySessionStore
        onboardingCoachingContextStore = auth.onboardingCoachingContextStore
        self.onboardingRoutingConfiguration = auth.onboardingRoutingConfiguration

        // Analytics
        self.onboardingAnalyticsLogger = analytics.onboardingAnalyticsLogger
        self.todayAnalyticsLogger = analytics.todayAnalyticsLogger
        self.planAnalyticsLogger = analytics.planAnalyticsLogger
        self.journeyAnalyticsLogger = analytics.journeyAnalyticsLogger
        self.weeklyProgressAnalyticsLogger = analytics.weeklyProgressAnalyticsLogger
        self.publicEntryAnalyticsLogger = analytics.publicEntryAnalyticsLogger
        self.themeAnalyticsLogger = analytics.themeAnalyticsLogger
        self.settingsAnalyticsLogger = analytics.settingsAnalyticsLogger
        self.healthIntelligenceAnalyticsLogger = analytics.healthIntelligenceAnalyticsLogger

        // Settings / theme
        themeStore = settings.themeStore

        reviewService = today.reviewService
        actionCenter = today.actionCenter

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
