//
//  SyncDependencies.swift
//  Fitness Coach
//
//  Typed account restore, cross-device sync, deletion, and export bundle for AppContainer wiring.
//

import Foundation

/// Resolved account lifecycle sync dependencies for `AppContainer`.
struct SyncDependencies {
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

    /// Builds restore, cross-device sync, deletion, and export dependencies for `AppContainer`.
    static func build(
        session: AuthDependencies,
        persistence: PersistenceDependencies,
        health: HealthDependencies,
        inMemory: Bool
    ) -> SyncDependencies {
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

        return SyncDependencies(
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
