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
        onboardingRoutingConfiguration: OnboardingRoutingConfiguration? = nil
    ) throws {
        let resolvedOnboardingRoutingConfiguration = onboardingRoutingConfiguration ?? .production
        refreshCenter = AppRefreshCenter()
        let authManager = AuthManager()
        self.authManager = authManager

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
        #else
        self.onboardingAnalyticsLogger = onboardingAnalyticsLogger ?? NoOpOnboardingAnalyticsLogger()
        self.todayAnalyticsLogger = todayAnalyticsLogger ?? NoOpTodayAnalyticsLogger()
        self.planAnalyticsLogger = planAnalyticsLogger ?? NoOpPlanAnalyticsLogger()
        self.journeyAnalyticsLogger = journeyAnalyticsLogger ?? NoOpJourneyAnalyticsLogger()
        self.publicEntryAnalyticsLogger = publicEntryAnalyticsLogger ?? NoOpPublicEntryAnalyticsLogger()
        self.themeAnalyticsLogger = themeAnalyticsLogger ?? NoOpThemeAnalyticsLogger()
        #endif
        self.onboardingRoutingConfiguration = resolvedOnboardingRoutingConfiguration

        themeStore = ThemeStore(analyticsLogger: self.themeAnalyticsLogger)

        healthTrainingService = HealthTrainingService()
        trainingInsightsStore = TrainingInsightsStore(integration: healthTrainingService)
        let workoutReader = HealthTrainingReaderFactory.makeWorkoutReader()
        let stepReader = HealthTrainingReaderFactory.makeStepReader()
        healthKitWorkoutReader = workoutReader
        healthKitStepReader = stepReader
        healthActivityQueryService = HealthActivityQueryService(
            workoutReader: workoutReader,
            stepReader: stepReader
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
        // Debug builds use the local backend gateway when available. The
        // gateway reads .env on the Mac and calls OpenAI, so provider keys still
        // do not live in the iOS app bundle.
        // Set FORMA_USE_MOCK_LLM=1 (or legacy FITPILOT_USE_MOCK_LLM=1) to skip the backend.
        // Physical device: set FORMA_AI_BACKEND_URL in the scheme or DeveloperLocal.plist.
        #if DEBUG
        let wiring: (clientType: String, baseURL: URL?, authAttached: Bool)
        if FormaEnvironment.isMockLLMEnabled() {
            llmClient = MockLLMClient()
            wiring = ("MockLLMClient", nil, false)
        } else if let backendURL = LocalAIBackendConfiguration.debugBackendURL() {
            llmClient = FallbackLLMClient(
                primary: FormaAIBackendClient(
                    baseURL: backendURL,
                    authTokenProvider: { try await authManager.idToken() }
                )
            )
            wiring = ("FallbackLLMClient+FormaAIBackendClient", backendURL, true)
        } else {
            llmClient = MockLLMClient()
            wiring = ("MockLLMClient", nil, false)
        }
        PipelineTracePersistence.install(on: store)
        #else
        if let backendURL = ReleaseAIBackendConfiguration.releaseBackendURL() {
            llmClient = FallbackLLMClient(
                primary: FormaAIBackendClient(
                    baseURL: backendURL,
                    authTokenProvider: { try await authManager.idToken() }
                )
            )
        } else {
            llmClient = UnavailableLLMClient(
                reason: ReleaseAIBackendConfiguration.unavailableReason()
            )
        }
        #endif
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
        Self.logLLMClientWiring(
            clientType: wiring.clientType,
            baseURL: wiring.baseURL,
            authAttached: wiring.authAttached
        )
        #endif
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
            healthActivityQuery: healthActivityQueryService
        )
    }

    func makeCoachModel() -> CoachModel {
        CoachModel(
            actionCenter: actionCenter,
            dailyLogReader: dailyLogService,
            healthActivityQuery: healthActivityQueryService,
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

    func makeJourneyModel() -> JourneyModel {
        JourneyModel(
            dailyLogReader: dailyLogService,
            weightLogReader: weightLogService,
            userProfileReader: userProfileService,
            trainingInsightsStore: trainingInsightsStore,
            workoutReader: healthKitWorkoutReader
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
            workoutReader: healthKitWorkoutReader,
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
            targetService: targetService,
            onCompletion: onCompletion,
            draftStore: onboardingDraftStore,
            coachingContextStore: onboardingCoachingContextStore,
            analyticsLogger: onboardingAnalyticsLogger,
            analyticsEntry: entry,
            healthTrainingIntegration: healthTrainingService,
            trainingInsightsStore: trainingInsightsStore
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
