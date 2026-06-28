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
    let workoutLogService: WorkoutLogService
    let reviewService: ReviewService
    let actionCenter: FitnessActionCenter

    let authManager: AuthManager
    let cloudUserProfileStore: CloudUserProfileStoring
    let profileBootstrapService: ProfileBootstrapService
    let profileCloudSyncStore: ProfileCloudSyncStore
    let profileBootstrapCoordinatorService: ProfileBootstrapCoordinatorService
    let llmClient: LLMClient
    let aiService: AIService
    let aiCommandParsingEnabled: Bool
    let refreshCenter: AppRefreshCenter
    let healthTrainingService: HealthTrainingService
    let trainingInsightsStore: TrainingInsightsStore
    let trainingInsightsModel: TrainingInsightsModel

    let onboardingUserDefaults: UserDefaults
    let onboardingDraftStore: OnboardingDraftStore
    let onboardingCoachingContextStore: OnboardingCoachingContextStore
    let onboardingAnalyticsLogger: any OnboardingAnalyticsLogging
    let onboardingRoutingConfiguration: OnboardingRoutingConfiguration

    init(
        inMemory: Bool = false,
        onboardingUserDefaults: UserDefaults? = nil,
        onboardingAnalyticsLogger: (any OnboardingAnalyticsLogging)? = nil,
        onboardingRoutingConfiguration: OnboardingRoutingConfiguration = .production
    ) throws {
        refreshCenter = AppRefreshCenter()
        let authManager = AuthManager()
        self.authManager = authManager

        self.onboardingUserDefaults = Self.makeOnboardingUserDefaults(
            inMemory: inMemory,
            override: onboardingUserDefaults
        )
        onboardingDraftStore = OnboardingDraftStore(userDefaults: self.onboardingUserDefaults)
        onboardingCoachingContextStore = OnboardingCoachingContextStore(
            userDefaults: self.onboardingUserDefaults
        )
        #if DEBUG
        self.onboardingAnalyticsLogger = onboardingAnalyticsLogger ?? OSLogOnboardingAnalyticsLogger()
        #else
        self.onboardingAnalyticsLogger = onboardingAnalyticsLogger ?? NoOpOnboardingAnalyticsLogger()
        #endif
        self.onboardingRoutingConfiguration = onboardingRoutingConfiguration

        healthTrainingService = HealthTrainingService()
        trainingInsightsStore = TrainingInsightsStore(integration: healthTrainingService)
        trainingInsightsModel = TrainingInsightsModel()
        HealthTrainingDebugLogger.event(
            "Training integration wired",
            fields: [
                "bundleId": Bundle.main.bundleIdentifier ?? "unknown",
                "initialDataSource": trainingInsightsStore.dataSource.rawValue
            ]
        )

        modelContainer = try FitPilotModelContainer.makeContainer(inMemory: inMemory)
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
        workoutLogService = WorkoutLogService(
            store: store,
            dailyLogService: dailyLogService,
            userProfileService: userProfileService
        )

        // Debug builds use the local backend gateway when available. The
        // gateway reads .env on the Mac and calls OpenAI, so provider keys still
        // do not live in the iOS app bundle.
        // Set FITPILOT_USE_MOCK_LLM=1 in the scheme to skip the backend entirely.
        // Physical device: set FITPILOT_AI_BACKEND_URL in the scheme or DeveloperLocal.plist.
        #if DEBUG
        let wiring: (clientType: String, baseURL: URL?, authAttached: Bool)
        if ProcessInfo.processInfo.environment["FITPILOT_USE_MOCK_LLM"] == "1" {
            llmClient = MockLLMClient()
            wiring = ("MockLLMClient", nil, false)
        } else if let backendURL = LocalAIBackendConfiguration.debugBackendURL() {
            llmClient = FallbackLLMClient(
                primary: FitPilotAIBackendClient(
                    baseURL: backendURL,
                    authTokenProvider: { try await authManager.idToken() }
                )
            )
            wiring = ("FallbackLLMClient+FitPilotAIBackendClient", backendURL, true)
        } else {
            llmClient = MockLLMClient()
            wiring = ("MockLLMClient", nil, false)
        }
        PipelineTracePersistence.install(on: store)
        #else
        if let backendURL = ReleaseAIBackendConfiguration.releaseBackendURL() {
            llmClient = FallbackLLMClient(
                primary: FitPilotAIBackendClient(
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
            workoutLogService: workoutLogService,
            userProfileService: userProfileService,
            aiService: aiService
        )

        actionCenter = FitnessActionCenter(
            foodLogService: foodLogService,
            waterLogService: waterLogService,
            weightLogService: weightLogService,
            workoutLogService: workoutLogService,
            dailyLogService: dailyLogService,
            targetService: targetService,
            userProfileService: userProfileService,
            reviewService: reviewService,
            refreshCenter: refreshCenter,
            profileBootstrapService: profileBootstrapService,
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

    func makeTodayModel() -> TodayModel {
        TodayModel(
            dailyLogService: dailyLogService,
            foodLogService: foodLogService,
            workoutLogService: workoutLogService,
            weightLogService: weightLogService,
            reviewService: reviewService,
            userProfileService: userProfileService
        )
    }

    func makeCoachModel() -> CoachModel {
        CoachModel(
            actionCenter: actionCenter,
            dailyLogService: dailyLogService,
            workoutLogService: workoutLogService,
            weightLogService: weightLogService,
            aiService: aiService,
            userProfileService: userProfileService,
            aiCommandParsingEnabled: aiCommandParsingEnabled,
            trainingInsightsStore: trainingInsightsStore
        )
    }

    func makeProgressModel() -> ProgressModel {
        ProgressModel(
            dailyLogService: dailyLogService,
            weightLogService: weightLogService,
            workoutLogService: workoutLogService,
            userProfileService: userProfileService,
            trainingInsightsStore: trainingInsightsStore,
            workoutReader: trainingInsightsModel.workoutReaderForToday
        )
    }

    func makeTrainingModel() -> TrainingModel {
        TrainingModel(
            workoutLogService: workoutLogService,
            dailyLogService: dailyLogService
        )
    }

    func makeTrainingInsightsView() -> TrainingInsightsView {
        TrainingInsightsView(
            insightsStore: trainingInsightsStore,
            insightsModel: trainingInsightsModel
        )
    }

    func makeProfileModel() -> ProfileModel {
        ProfileModel(
            actionCenter: actionCenter,
            userProfileService: userProfileService,
            targetService: targetService
        )
    }

    func makeRootModel() -> RootModel {
        RootModel(profileBootstrapService: profileBootstrapService)
    }

    func makeOnboardingModel(
        entry: OnboardingAnalyticsEntry = .preAuth,
        onCompletion: @escaping () -> Void
    ) -> OnboardingModel {
        let flowScope = OnboardingFlowScope.resolve(
            routingMode: onboardingRoutingConfiguration.routingMode,
            entry: entry,
            isV2Enabled: onboardingRoutingConfiguration.isV2Enabled
        )
        return OnboardingModel(
            userProfileService: userProfileService,
            targetService: targetService,
            onCompletion: onCompletion,
            draftStore: onboardingDraftStore,
            coachingContextStore: onboardingCoachingContextStore,
            analyticsLogger: onboardingAnalyticsLogger,
            analyticsEntry: entry,
            flowScope: flowScope,
            allowsLocalOnlyContinuation: onboardingRoutingConfiguration.allowsLocalOnlyContinuation
        )
    }

    func resolveAppShellRoute(
        authState: AuthState,
        rootState: RootViewState = .loading,
        isOnboardingModelReady: Bool = false,
        awaitingCloudSync: Bool = false
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
            isOnboardingV2Enabled: onboardingRoutingConfiguration.isV2Enabled,
            signedOutWithProfilePolicy: onboardingRoutingConfiguration.signedOutWithProfilePolicy
        )
    }

    func resolveOnboardingShellRoute(
        authState: AuthState,
        hasLocalProfile: Bool,
        rootState: RootViewState = .loading,
        isOnboardingModelReady: Bool = false,
        awaitingCloudSync: Bool = false
    ) -> OnboardingShellRoute {
        OnboardingShellRouting.resolve(
            OnboardingShellRouteInput(
                authState: authState,
                hasLocalProfile: hasLocalProfile,
                rootState: rootState,
                isOnboardingModelReady: isOnboardingModelReady,
                awaitingCloudSync: awaitingCloudSync
            ),
            configuration: onboardingRoutingConfiguration
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
            "traceEnabled": String(FitPilotPipelineTracer.isEnabled),
            "traceVerbose": String(FitPilotPipelineTracer.isVerbose)
        ]
        if let baseURL {
            fields["baseURL"] = baseURL.absoluteString
        }
        FitPilotPipelineTracer.event(
            stage: .appWiring,
            level: .info,
            message: "LLM client wired",
            fields: fields
        )
    }
}
