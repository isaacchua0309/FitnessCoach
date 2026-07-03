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
    let healthSyncService: HealthSyncService
    let healthSyncStateStore: HealthSyncStateStore
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
        onboardingRoutingConfiguration: OnboardingRoutingConfiguration? = nil
    ) throws {
        let resolvedOnboardingRoutingConfiguration = onboardingRoutingConfiguration ?? .production
        refreshCenter = AppRefreshCenter()
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
        healthSyncStateStore = HealthSyncStateStore(
            syncService: healthSyncService,
            syncEnabled: HealthIntelligenceFeatureFlags.isSyncEnabled
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

        userProfileService = UserProfileService(store: store)
        cloudUserProfileStore = inMemory
            ? NoOpCloudUserProfileStore()
            : FirestoreCloudUserProfileStore()
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
            userProfileService: userProfileService
        )
        targetService = TargetService(
            userProfileService: userProfileService,
            dailyLogService: dailyLogService
        )
        foodLogService = FoodLogService(
            store: store,
            dailyLogService: dailyLogService
        )
        waterLogService = WaterLogService(
            store: store,
            dailyLogService: dailyLogService
        )
        weightLogService = WeightLogService(
            store: store,
            dailyLogService: dailyLogService
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
        aiCommandParsingEnabled = true

        reviewService = ReviewService(
            store: store,
            dailyLogService: dailyLogService,
            foodLogService: foodLogService,
            waterLogService: waterLogService,
            weightLogService: weightLogService,
            healthActivityQuery: healthActivityQueryService,
            userProfileService: userProfileService,
            aiService: aiService
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
            currentUIDProvider: { [weak authManager] in authManager?.currentUID }
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
        authUIDCache.update(uid: authManager.currentUID)
        healthSyncStateStore.cancelActiveSync()
    }

    func makeHealthIntelligenceEngine() -> any HealthIntelligenceEngineing {
        healthIntelligenceEngine
    }

    func refreshHealthIntelligenceSnapshotIfNeeded() async {
        guard HealthIntelligenceFeatureFlags.healthIntelligenceEnginesEnabled else { return }
        await healthIntelligenceSnapshotService.refreshTodaySnapshot(calendar: .current)
    }

    func makeTodayActionCoordinator() -> TodayActionCoordinator {
        TodayActionCoordinator(
            actionCenter: actionCenter,
            analyticsLogger: todayAnalyticsLogger
        )
    }

    func makeTodayModel() -> TodayModel {
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
            }
        )
    }

    func makeCoachModel() -> CoachModel {
        CoachModel(
            actionCenter: actionCenter,
            dailyLogReader: dailyLogService,
            healthActivityQuery: healthActivityQueryService,
            healthIntelligenceSnapshotProvider: healthIntelligenceSnapshotService,
            weightLogReader: weightLogService,
            aiService: aiService,
            userProfileReader: userProfileService,
            aiCommandParsingEnabled: aiCommandParsingEnabled,
            trainingInsightsStore: trainingInsightsStore
        )
    }

    func makeJourneyAnalyticsCoordinator() -> JourneyAnalyticsCoordinator {
        JourneyAnalyticsCoordinator(analyticsLogger: journeyAnalyticsLogger)
    }

    func makeSettingsAnalyticsCoordinator() -> SettingsAnalyticsCoordinator {
        SettingsAnalyticsCoordinator(analyticsLogger: settingsAnalyticsLogger)
    }

    func makeJourneyModel() -> JourneyModel {
        JourneyModel(
            dailyLogReader: dailyLogService,
            weightLogReader: weightLogService,
            userProfileReader: userProfileService,
            trainingInsightsStore: trainingInsightsStore,
            workoutReader: healthKitWorkoutReader,
            healthIntelligenceSnapshotProvider: healthIntelligenceSnapshotService,
            healthIntelligenceEngine: healthIntelligenceEngine,
            healthCacheStore: healthCacheStore,
            healthActivityQuery: healthActivityQueryService,
            healthDataRepository: healthDataRepository
        )
    }

    func makePlanModel() -> PlanModel {
        PlanModel(
            actionCenter: actionCenter,
            userProfileReader: userProfileService,
            planTargetCalculator: targetService,
            dailyLogReader: dailyLogService,
            weightLogReader: weightLogService,
            trainingInsightsStore: trainingInsightsStore,
            analyticsLogger: planAnalyticsLogger
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
