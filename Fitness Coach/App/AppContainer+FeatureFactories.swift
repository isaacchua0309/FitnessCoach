//
//  AppContainer+FeatureFactories.swift
//  Fitness Coach
//
//  Feature model and coordinator factories for AppContainer.
//  Grouped by tab/domain; domain bundles live under App/Dependencies/.
//

import Foundation

// MARK: - Health Intelligence dependencies

extension AppContainer {

    func makeHealthIntelligenceEngine() -> any HealthIntelligenceEngineing {
        healthIntelligenceEngine
    }

    func refreshHealthIntelligenceSnapshotIfNeeded() async {
        guard HealthIntelligenceFeatureFlags.healthIntelligenceEnginesEnabled else { return }
        await healthIntelligenceSnapshotService.refreshTodaySnapshot(calendar: .current)
    }

    func makeHealthIntelligenceAnalyticsCoordinator() -> HealthIntelligenceAnalyticsCoordinator {
        HealthIntelligenceAnalyticsCoordinator(analyticsLogger: healthIntelligenceAnalyticsLogger)
    }
}

// MARK: - Today dependencies

extension AppContainer {

    func makeTodayActionCoordinator(
        healthIntelligenceAnalyticsCoordinator: HealthIntelligenceAnalyticsCoordinator? = nil,
        weeklyProgressAnalyticsCoordinator: WeeklyProgressAnalyticsCoordinator? = nil
    ) -> TodayActionCoordinator {
        TodayActionCoordinator(
            actionCenter: actionCenter,
            analyticsLogger: todayAnalyticsLogger,
            healthIntelligenceAnalyticsCoordinator: healthIntelligenceAnalyticsCoordinator,
            weeklyProgressAnalyticsCoordinator: weeklyProgressAnalyticsCoordinator
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
            connectionRecordProvider: { [weak self] in
                self?.healthIntegrationConnectionStore.load() ?? .empty
            },
            accountDataRefreshEventBus: accountDataRefreshEventBus,
            crossDeviceSyncCoordinator: crossDeviceSyncCoordinator
        )
    }
}

// MARK: - Coach dependencies

extension AppContainer {

    func makeCoachServices() -> CoachServices {
        CoachServices(
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
            userProfileReader: userProfileService,
            trainingInsightsStore: trainingInsightsStore
        )
    }

    func makeCoachDependencies(
        healthIntelligenceAnalyticsCoordinator: HealthIntelligenceAnalyticsCoordinator? = nil
    ) -> CoachDependencies {
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
            timelineRecorder: coachTimelineRecorder,
            foodCorrectionMemoryStore: foodCorrectionMemoryStore
        )

        return CoachDependencies(
            aiService: aiService,
            aiCommandParsingEnabled: aiCommandParsingEnabled,
            contextPacketBuilder: contextPacketBuilder,
            timelineRecorder: coachTimelineRecorder,
            transcriptStore: coachChatTranscriptStore,
            timelineStore: coachTimelineStore,
            foodCorrectionMemoryStore: foodCorrectionMemoryStore,
            healthIntelligenceAnalyticsCoordinator: healthIntelligenceAnalyticsCoordinator
        )
    }

    func makeCoachModel(
        healthIntelligenceAnalyticsCoordinator: HealthIntelligenceAnalyticsCoordinator? = nil
    ) -> CoachModel {
        CoachModel(
            services: makeCoachServices(),
            dependencies: makeCoachDependencies(
                healthIntelligenceAnalyticsCoordinator: healthIntelligenceAnalyticsCoordinator
            )
        )
    }
}

// MARK: - Journey dependencies

extension AppContainer {

    func makeJourneyAnalyticsCoordinator() -> JourneyAnalyticsCoordinator {
        JourneyAnalyticsCoordinator(analyticsLogger: journeyAnalyticsLogger)
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
            crossDeviceSyncCoordinator: crossDeviceSyncCoordinator,
            accountSyncCursorStore: accountSyncCursorStore,
            accountSyncOutboxStore: accountSyncOutboxStore,
            accountRestoreStateStore: accountRestoreStateStore
        )
    }
}

// MARK: - Plan dependencies

extension AppContainer {

    func makeWeeklyProgressAnalyticsCoordinator() -> WeeklyProgressAnalyticsCoordinator {
        WeeklyProgressAnalyticsCoordinator(analyticsLogger: weeklyProgressAnalyticsLogger)
    }

    func makePlanAnalyticsCoordinator(
        weeklyProgressAnalyticsCoordinator: WeeklyProgressAnalyticsCoordinator
    ) -> PlanAnalyticsCoordinator {
        PlanAnalyticsCoordinator(
            weeklyProgressAnalyticsCoordinator: weeklyProgressAnalyticsCoordinator
        )
    }

    func makePlanModel(
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

// MARK: - Settings dependencies

extension AppContainer {

    func makeSettingsPrivacyDataEnvironment() -> SettingsPrivacyDataEnvironment {
        let provider = SettingsPrivacyDataStatusProvider(
            authManager: authManager,
            accountRestoreStateStore: accountRestoreStateStore,
            accountRestoreSessionState: accountRestoreSessionState,
            accountSyncDiagnostics: accountSyncDiagnostics,
            accountSyncOutboxStore: accountSyncOutboxStore,
            profileCloudSyncStore: profileCloudSyncStore,
            accountSyncCursorStore: accountSyncCursorStore
        )
        return SettingsPrivacyDataEnvironment {
            await provider.snapshot()
        }
    }

    func makeSettingsAnalyticsCoordinator() -> SettingsAnalyticsCoordinator {
        SettingsAnalyticsCoordinator(analyticsLogger: settingsAnalyticsLogger)
    }
}

// MARK: - App shell / onboarding

extension AppContainer {

    func makeRootModel() -> RootModel {
        RootModel(profileBootstrapService: profileBootstrapService)
    }

    func makeOnboardingModel(
        entry: OnboardingAnalyticsEntry = .preAuth,
        onCompletion: @escaping () -> Void
    ) -> OnboardingModel {
        OnboardingModel(
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
}

#if DEBUG
// MARK: - Debug actions

extension AppContainer {

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
            pendingMutationCount: { [accountSyncOutboxStore, authManager, accountSyncDiagnostics] in
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

    func makeAccountDeletionDebugActions() -> AccountDeletionDebugActions {
        AccountDeletionDebugActions(
            verifyDeleteEndpointDryRun: { [accountDeletionRemoteClient] in
                guard let client = accountDeletionRemoteClient as? AccountDeletionRemoteClient else {
                    throw AccountDeletionRemoteError.unknown("client_unavailable")
                }
                return try await client.verifyDeleteEndpointDryRun()
            }
        )
    }
}
#endif
