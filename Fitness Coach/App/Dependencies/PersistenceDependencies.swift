//
//  PersistenceDependencies.swift
//  Fitness Coach
//
//  SwiftData, account sync core, and log service construction for AppContainer.
//  See Docs/Architecture/DependencyInjectionMap.md
//

import Foundation
import SwiftData

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
