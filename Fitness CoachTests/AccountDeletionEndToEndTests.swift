//
//  AccountDeletionEndToEndTests.swift
//  Fitness CoachTests
//
//  Forma — End-to-end account deletion simulations (Phase 6).
//
//  Uses in-memory SwiftData, fake remote/auth clients, and recording sync/listener/router
//  fakes wired through the real AccountDeletionCoordinator + LocalAccountDataWipeService.
//

import SwiftData
import XCTest
@testable import Fitness_Coach

@MainActor
final class AccountDeletionEndToEndTests: XCTestCase {

    private let referenceDate = ProfileTestFixtures.referenceDate

    // MARK: - 1. Full success

    func testFullAccountDeletionSuccess() async throws {
        let harness = try AccountDeletionEndToEndHarness.make(
            sessionUID: AccountDeletionEndToEndHarness.userA,
            referenceDate: referenceDate
        )
        try harness.seedFullLocalAccount(for: AccountDeletionEndToEndHarness.userA)

        harness.remoteClient.configuredResult = harness.remoteSuccess(for: AccountDeletionEndToEndHarness.userA)

        let summary = await harness.coordinator.deleteAccount(confirmation: "DELETE")

        XCTAssertEqual(summary.status, .completed)
        XCTAssertTrue(summary.isSuccessful)
        XCTAssertTrue(summary.remoteProfileDeleted)
        XCTAssertTrue(summary.authAccountDeleted)
        XCTAssertTrue(summary.localProfileDeleted)
        XCTAssertEqual(harness.remoteClient.callCount, 1)
        XCTAssertEqual(harness.authDeleting.deleteCallCount, 1)
        XCTAssertEqual(harness.router.fullDeletionRouteCount, 1)
        try harness.assertLocalAccountAbsent(for: AccountDeletionEndToEndHarness.userA)
        XCTAssertFalse(harness.healthCacheDirectoryExists(for: AccountDeletionEndToEndHarness.userA))
    }

    // MARK: - 2. Remote failure

    func testRemoteDeleteFailsBeforeAuthDelete() async throws {
        let harness = try AccountDeletionEndToEndHarness.make(
            sessionUID: AccountDeletionEndToEndHarness.userA,
            referenceDate: referenceDate
        )
        try harness.seedFullLocalAccount(for: AccountDeletionEndToEndHarness.userA)
        harness.remoteClient.configuredError = .offline

        let summary = await harness.coordinator.deleteAccount(confirmation: "DELETE")

        XCTAssertEqual(summary.status, .offline)
        XCTAssertFalse(summary.authAccountDeleted)
        XCTAssertEqual(harness.authDeleting.deleteCallCount, 0)
        XCTAssertEqual(harness.router.fullDeletionRouteCount, 0)
        XCTAssertEqual(harness.signOutCallCount, 0)
        XCTAssertEqual(harness.sessionUID, AccountDeletionEndToEndHarness.userA)
        try harness.assertLocalAccountPresent(for: AccountDeletionEndToEndHarness.userA)
    }

    // MARK: - 3. Reauth

    func testAuthDeleteRequiresReauth() async throws {
        let harness = try AccountDeletionEndToEndHarness.make(
            sessionUID: AccountDeletionEndToEndHarness.userA,
            referenceDate: referenceDate
        )
        try harness.seedFullLocalAccount(for: AccountDeletionEndToEndHarness.userA)
        harness.remoteClient.configuredResult = harness.remoteSuccess(for: AccountDeletionEndToEndHarness.userA)
        harness.authDeleting.configuredDeleteError = .reauthenticationRequired

        let first = await harness.coordinator.deleteAccount(confirmation: "DELETE")

        XCTAssertEqual(first.status, .reauthenticationRequired)
        XCTAssertTrue(first.remoteProfileDeleted)
        XCTAssertFalse(first.authAccountDeleted)
        XCTAssertEqual(harness.router.fullDeletionRouteCount, 0)
        try harness.assertLocalAccountPresent(for: AccountDeletionEndToEndHarness.userA)

        harness.authDeleting.configuredDeleteError = nil
        let second = await harness.coordinator.retryAfterReauthentication(confirmation: "DELETE")

        XCTAssertEqual(second.status, .completed)
        XCTAssertTrue(second.authAccountDeleted)
        XCTAssertEqual(harness.authDeleting.reauthCallCount, 1)
        XCTAssertEqual(harness.remoteClient.callCount, 1)
        XCTAssertEqual(harness.router.fullDeletionRouteCount, 1)
        try harness.assertLocalAccountAbsent(for: AccountDeletionEndToEndHarness.userA)
    }

    // MARK: - 4. Partial local wipe

    func testLocalWipeFailsAfterRemoteAndAuthDelete() async throws {
        let harness = try AccountDeletionEndToEndHarness.make(
            sessionUID: AccountDeletionEndToEndHarness.userA,
            referenceDate: referenceDate,
            blockHealthCacheRemoval: true
        )
        try harness.seedFullLocalAccount(for: AccountDeletionEndToEndHarness.userA)
        harness.remoteClient.configuredResult = harness.remoteSuccess(for: AccountDeletionEndToEndHarness.userA)

        let summary = await harness.coordinator.deleteAccount(confirmation: "DELETE")

        XCTAssertEqual(summary.status, .partial)
        XCTAssertEqual(summary.failureCategory, .localWipeFailed)
        XCTAssertTrue(summary.remoteProfileDeleted)
        XCTAssertTrue(summary.authAccountDeleted)
        XCTAssertTrue(summary.status.allowsRetry)
        XCTAssertEqual(harness.router.fullDeletionRouteCount, 1)
        try harness.assertLocalSwiftDataAbsent(for: AccountDeletionEndToEndHarness.userA)
        XCTAssertTrue(harness.healthCacheDirectoryExists(for: AccountDeletionEndToEndHarness.userA))
    }

    // MARK: - 5. Local device only

    func testLocalDeviceOnlyWipe() async throws {
        let harness = try AccountDeletionEndToEndHarness.make(
            sessionUID: AccountDeletionEndToEndHarness.userA,
            referenceDate: referenceDate
        )
        try harness.seedFullLocalAccount(for: AccountDeletionEndToEndHarness.userA)
        try harness.seedFullLocalAccount(for: AccountDeletionEndToEndHarness.userB)

        let summary = await harness.coordinator.deleteLocalDeviceDataOnly(confirmation: "DELETE")

        XCTAssertEqual(summary.scope, .localDeviceOnly)
        XCTAssertEqual(summary.status, .completed)
        XCTAssertFalse(summary.authAccountDeleted)
        XCTAssertFalse(summary.remoteProfileDeleted)
        XCTAssertEqual(harness.remoteClient.callCount, 0)
        XCTAssertEqual(harness.authDeleting.deleteCallCount, 0)
        XCTAssertEqual(harness.signOutCallCount, 1)
        XCTAssertEqual(harness.router.localOnlyRouteCount, 1)
        try harness.assertLocalAccountAbsent(for: AccountDeletionEndToEndHarness.userA)
        try harness.assertLocalAccountPresent(for: AccountDeletionEndToEndHarness.userB)
    }

    // MARK: - 6. Account switch

    func testAccountSwitchDuringDeletionCancelsOldResult() async throws {
        let harness = try AccountDeletionEndToEndHarness.make(
            sessionUID: AccountDeletionEndToEndHarness.userA,
            referenceDate: referenceDate
        )
        try harness.seedFullLocalAccount(for: AccountDeletionEndToEndHarness.userA)
        try harness.seedFullLocalAccount(for: AccountDeletionEndToEndHarness.userB)

        harness.remoteClient.delayNanoseconds = 200_000_000
        harness.remoteClient.configuredResult = harness.remoteSuccess(for: AccountDeletionEndToEndHarness.userA)

        async let deletionTask = harness.coordinator.deleteAccount(confirmation: "DELETE")
        let deletionStarted = await AsyncTestSupport.waitUntilWallClock(timeout: 0.15) {
            harness.coordinator.isDeletionInProgress(for: AccountDeletionEndToEndHarness.userA)
                || harness.remoteClient.callCount > 0
        }
        XCTAssertTrue(deletionStarted)
        harness.sessionUID = AccountDeletionEndToEndHarness.userB

        let summary = await deletionTask

        XCTAssertEqual(summary.failureCategory, .accountSwitched)
        XCTAssertFalse(summary.authAccountDeleted)
        XCTAssertEqual(harness.authDeleting.deleteCallCount, 0)
        XCTAssertEqual(harness.router.fullDeletionRouteCount, 0)
        XCTAssertEqual(harness.sessionUID, AccountDeletionEndToEndHarness.userB)
        try harness.assertLocalAccountPresent(for: AccountDeletionEndToEndHarness.userA)
        try harness.assertLocalAccountPresent(for: AccountDeletionEndToEndHarness.userB)
    }

    // MARK: - 7. Sync/listener shutdown

    func testDeletionStopsRealtimeListenerAndSync() async throws {
        let harness = try AccountDeletionEndToEndHarness.make(
            sessionUID: AccountDeletionEndToEndHarness.userA,
            referenceDate: referenceDate
        )
        try harness.seedFullLocalAccount(for: AccountDeletionEndToEndHarness.userA)
        harness.remoteClient.configuredResult = harness.remoteSuccess(for: AccountDeletionEndToEndHarness.userA)

        await harness.realtimeListener.startListening(uid: AccountDeletionEndToEndHarness.userA)
        harness.uploader.delayNanoseconds = 500_000_000
        async let syncTask = harness.syncCoordinator.syncNow(
            for: AccountDeletionEndToEndHarness.userA,
            reason: .manual
        )

        var listenerStoppedBeforeRemote = false
        harness.remoteClient.onWillDelete = { [weak harness] in
            guard let harness else { return }
            listenerStoppedBeforeRemote = harness.realtimeListener.stoppedUIDs
                .contains(AccountDeletionEndToEndHarness.userA)
            XCTAssertTrue(harness.deletionGuard.isDeletionInProgress(for: AccountDeletionEndToEndHarness.userA))
            XCTAssertTrue(harness.restoreCoordinator.cancelledUIDs.contains(AccountDeletionEndToEndHarness.userA))
        }

        _ = await harness.coordinator.deleteAccount(confirmation: "DELETE")
        let syncSummary = await syncTask

        XCTAssertTrue(listenerStoppedBeforeRemote)
        XCTAssertEqual(harness.realtimeListener.stoppedUIDs, [AccountDeletionEndToEndHarness.userA])
        XCTAssertTrue(syncSummary.didSkip)
        XCTAssertEqual(syncSummary.skipReason, AccountSyncCoordinatorSkipReason.deletionInProgress)
    }
}

// MARK: - Harness

@MainActor
private final class EndToEndSessionContext {

    var uid: String?
    var signOutCount = 0
}

@MainActor
private final class AccountDeletionEndToEndHarness {

    static let userA = "user-a"
    static let userB = "user-b"

    private let context: EndToEndSessionContext
    let referenceDate: Date

    let store: SwiftDataStore
    let profileService: UserProfileService
    let foodLogService: FoodLogService
    let defaults: UserDefaults
    let healthCacheRoot: URL
    let healthCacheFileManager: FileManager
    let restoreStateStore: AccountRestoreStateStore

    let remoteClient: EndToEndFakeRemoteDeletionClient
    let authDeleting: InMemoryAccountAuthDeleting
    let localWiper: LocalAccountDataWipeService
    let realtimeListener: RecordingAccountRealtimeChangeListener
    let restoreCoordinator: EndToEndRecordingRestoreCoordinator
    let syncCoordinator: AccountSyncCoordinator
    let crossDeviceCoordinator: CrossDeviceSyncCoordinator
    let deletionGuard: AccountDeletionGuard
    let router: EndToEndRecordingDeletionRouter
    let uploader: EndToEndDelayedSyncUploader

    let coordinator: AccountDeletionCoordinator

    var sessionUID: String? {
        get { context.uid }
        set { context.uid = newValue }
    }

    var signOutCallCount: Int { context.signOutCount }

    static func make(
        sessionUID: String,
        referenceDate: Date,
        blockHealthCacheRemoval: Bool = false
    ) throws -> AccountDeletionEndToEndHarness {
        let context = EndToEndSessionContext()
        context.uid = sessionUID

        let defaults = UserDefaults(suiteName: "AccountDeletionEndToEndTests.\(UUID().uuidString)")!
        let healthCacheRoot = FileManager.default.temporaryDirectory
            .appendingPathComponent("AccountDeletionEndToEndTests.\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: healthCacheRoot, withIntermediateDirectories: true)

        let healthCacheFileManager: FileManager
        if blockHealthCacheRemoval {
            healthCacheFileManager = HealthCacheRemovalBlockingFileManager()
        } else {
            healthCacheFileManager = .default
        }

        let container = try FormaModelContainer.makeContainer(inMemory: true)
        let store = SwiftDataStore(container: container)
        let dateProvider = FixedDailyLogTestDateProvider(now: referenceDate)
        let uidProvider = { context.uid }

        let profileService = UserProfileService(store: store, dateProvider: dateProvider)
        let dailyLogService = DailyLogService(
            store: store,
            userProfileService: profileService,
            dateProvider: dateProvider,
            currentUIDProvider: uidProvider
        )
        let foodLogService = FoodLogService(
            store: store,
            dailyLogService: dailyLogService,
            currentUIDProvider: uidProvider
        )

        let restoreStateStore = AccountRestoreStateStore(userDefaults: defaults)
        let syncCursorStore = AccountSyncCursorStore(userDefaults: defaults)
        let profileCloudSyncStore = ProfileCloudSyncStore(userDefaults: defaults)

        let authUIDCache = AuthUIDCache()
        authUIDCache.update(uid: sessionUID)
        let healthCacheStore = LocalHealthCacheStore(
            userProvider: authUIDCache,
            rootDirectory: healthCacheRoot
        )

        let localWiper = LocalAccountDataWipeService(
            store: store,
            healthCacheStore: healthCacheStore,
            userDefaults: defaults,
            restoreStateStore: restoreStateStore,
            syncCursorStore: syncCursorStore,
            healthConsentStore: UserDefaultsHealthSummarySyncConsentStore(userDefaults: defaults),
            healthSyncStateStore: UserDefaultsHealthSummaryRemoteSyncStateStore(userDefaults: defaults),
            profileCloudSyncStore: profileCloudSyncStore,
            healthCacheRootDirectory: healthCacheRoot,
            currentSessionUIDProvider: uidProvider,
            fileManager: healthCacheFileManager,
            clearPipelineTracer: {},
            clearInMemoryCoachState: {},
            clearSyncDiagnostics: {},
            clearRestoreDiagnostics: {}
        )

        let deletionGuard = AccountDeletionGuard()
        let remoteClient = EndToEndFakeRemoteDeletionClient()
        let authDeleting = InMemoryAccountAuthDeleting()
        let realtimeListener = RecordingAccountRealtimeChangeListener()
        let restoreCoordinator = EndToEndRecordingRestoreCoordinator()
        let router = EndToEndRecordingDeletionRouter()
        let uploader = EndToEndDelayedSyncUploader()

        let syncCoordinator = AccountSyncCoordinator(
            uploader: uploader,
            puller: EndToEndDelayedSyncPuller(),
            currentUIDProvider: uidProvider,
            nowProvider: { referenceDate },
            deletionGuard: deletionGuard
        )

        let crossDeviceCoordinator = CrossDeviceSyncCoordinator(
            syncCoordinator: syncCoordinator,
            incrementalPuller: EndToEndTrackingIncrementalPuller(),
            cursorStore: syncCursorStore,
            uidProvider: ClosureAccountUIDProvider { uidProvider() },
            refreshCenter: AppRefreshCenter(now: referenceDate),
            deletionGuard: deletionGuard
        )

        let coordinator = AccountDeletionCoordinator(
            uidProvider: ClosureAccountUIDProvider { uidProvider() },
            crossDeviceCoordinator: crossDeviceCoordinator,
            realtimeListener: realtimeListener,
            accountSyncCoordinator: syncCoordinator,
            restoreCoordinator: restoreCoordinator,
            remoteDeletionClient: remoteClient,
            authDeleting: authDeleting,
            localWiper: localWiper,
            deletionGuard: deletionGuard,
            router: router,
            signOutCurrentSession: { context.signOutCount += 1 },
            nowProvider: { referenceDate }
        )

        if blockHealthCacheRemoval,
           let blockingManager = healthCacheFileManager as? HealthCacheRemovalBlockingFileManager {
            blockingManager.blockedHealthCacheDirectory = healthCacheRoot
                .appendingPathComponent(Self.userA, isDirectory: true).path
        }

        return AccountDeletionEndToEndHarness(
            context: context,
            referenceDate: referenceDate,
            store: store,
            profileService: profileService,
            foodLogService: foodLogService,
            defaults: defaults,
            healthCacheRoot: healthCacheRoot,
            healthCacheFileManager: healthCacheFileManager,
            restoreStateStore: restoreStateStore,
            remoteClient: remoteClient,
            authDeleting: authDeleting,
            localWiper: localWiper,
            realtimeListener: realtimeListener,
            restoreCoordinator: restoreCoordinator,
            syncCoordinator: syncCoordinator,
            crossDeviceCoordinator: crossDeviceCoordinator,
            deletionGuard: deletionGuard,
            router: router,
            uploader: uploader,
            coordinator: coordinator
        )
    }

    private init(
        context: EndToEndSessionContext,
        referenceDate: Date,
        store: SwiftDataStore,
        profileService: UserProfileService,
        foodLogService: FoodLogService,
        defaults: UserDefaults,
        healthCacheRoot: URL,
        healthCacheFileManager: FileManager,
        restoreStateStore: AccountRestoreStateStore,
        remoteClient: EndToEndFakeRemoteDeletionClient,
        authDeleting: InMemoryAccountAuthDeleting,
        localWiper: LocalAccountDataWipeService,
        realtimeListener: RecordingAccountRealtimeChangeListener,
        restoreCoordinator: EndToEndRecordingRestoreCoordinator,
        syncCoordinator: AccountSyncCoordinator,
        crossDeviceCoordinator: CrossDeviceSyncCoordinator,
        deletionGuard: AccountDeletionGuard,
        router: EndToEndRecordingDeletionRouter,
        uploader: EndToEndDelayedSyncUploader,
        coordinator: AccountDeletionCoordinator
    ) {
        self.context = context
        self.referenceDate = referenceDate
        self.store = store
        self.profileService = profileService
        self.foodLogService = foodLogService
        self.defaults = defaults
        self.healthCacheRoot = healthCacheRoot
        self.healthCacheFileManager = healthCacheFileManager
        self.restoreStateStore = restoreStateStore
        self.remoteClient = remoteClient
        self.authDeleting = authDeleting
        self.localWiper = localWiper
        self.realtimeListener = realtimeListener
        self.restoreCoordinator = restoreCoordinator
        self.syncCoordinator = syncCoordinator
        self.crossDeviceCoordinator = crossDeviceCoordinator
        self.deletionGuard = deletionGuard
        self.router = router
        self.uploader = uploader
        self.coordinator = coordinator
    }

    func remoteSuccess(for uid: String) -> RemoteAccountDeletionResult {
        RemoteAccountDeletionResult(
            uid: uid,
            profileDeleted: true,
            dailyLogsDeleted: 1,
            foodEntriesDeleted: 1,
            waterEntriesDeleted: 1,
            weightEntriesDeleted: 1,
            dailyReviewsDeleted: 1,
            syncMetadataDeleted: true,
            healthSummariesDeleted: true
        )
    }

    func seedFullLocalAccount(for uid: String) throws {
        if try profileFor(ownerUID: uid) == nil {
            _ = try profileService.createProfile(ProfileTestFixtures.sampleDraft, ownerUID: uid)
        }
        if try ownedFoodCount(for: uid) == 0 {
            let previousSession = sessionUID
            sessionUID = uid
            _ = try foodLogService.addFoodEntry(
                DailyLogServiceTestSupport.foodDraft(name: "\(uid)-meal", calories: 420),
                for: referenceDate
            )
            sessionUID = previousSession
        }

        let dailyLogId = try store.fetch(FetchDescriptor<DailyLogEntity>()).first(where: { $0.ownerUID == uid })?.id
            ?? UUID()

        if try ownedEntityCount(WaterEntryEntity.self, uid: uid) == 0 {
            store.modelContext.insert(
                WaterEntryEntity(
                    id: UUID(),
                    ownerUID: uid,
                    dailyLogId: dailyLogId,
                    amountMl: 250,
                    createdAt: referenceDate
                )
            )
        }

        if try ownedEntityCount(WeightEntryEntity.self, uid: uid) == 0 {
            store.modelContext.insert(
                WeightEntryEntity(
                    id: UUID(),
                    ownerUID: uid,
                    date: referenceDate,
                    weightKg: 68.2,
                    note: nil,
                    createdAt: referenceDate
                )
            )
        }

        if try ownedEntityCount(DailyReviewEntity.self, uid: uid) == 0 {
            store.modelContext.insert(
                DailyReviewEntity(
                    id: UUID(),
                    ownerUID: uid,
                    dailyLogId: dailyLogId,
                    summaryText: "Solid day",
                    caloriesSummary: "On target",
                    proteinSummary: "High",
                    hydrationSummary: "Good",
                    workoutSummary: nil,
                    weightSummary: nil,
                    tomorrowRecommendation: "Repeat",
                    createdAt: referenceDate
                )
            )
        }

        let coachMessages = try store.fetch(FetchDescriptor<CoachChatTranscriptMessageEntity>())
        if coachMessages.filter({ $0.userId == uid }).isEmpty {
            store.modelContext.insert(
                CoachChatTranscriptMessageEntity(
                    id: UUID(),
                    userId: uid,
                    roleRawValue: "user",
                    text: "hello-\(uid)",
                    createdAt: referenceDate,
                    relatedDailyLogId: nil,
                    relatedEntryId: nil,
                    hasImageAttachment: false,
                    imageKindRaw: nil,
                    imageSourceRaw: nil,
                    thumbnailJPEG: nil,
                    fullImageJPEG: nil,
                    originalImageByteSize: nil,
                    photoSessionID: nil,
                    relatedUserMessageID: nil,
                    photoAnalysisLinkKindRaw: nil,
                    structuredContentJSON: nil,
                    updatedAt: referenceDate
                )
            )
        }

        if try store.fetch(FetchDescriptor<AccountSyncMutationEntity>()).filter({ $0.ownerUID == uid }).isEmpty {
            store.modelContext.insert(
                AccountSyncMutationEntity(
                    id: "mutation-\(uid)",
                    ownerUID: uid,
                    entityType: .foodEntry,
                    entityId: UUID().uuidString,
                    localDate: "2026-07-04",
                    operation: .upsert,
                    payloadVersion: 1,
                    createdAt: referenceDate,
                    updatedAt: referenceDate
                )
            )
        }

        try store.save()
        try writeHealthCacheMarker(for: uid)
        restoreStateStore.markSkipped(uid: uid, reason: .afterSignIn, now: referenceDate)
    }

    func assertLocalAccountPresent(for uid: String) throws {
        XCTAssertNotNil(try profileFor(ownerUID: uid))
        XCTAssertGreaterThan(try ownedFoodCount(for: uid), 0)
        XCTAssertTrue(healthCacheDirectoryExists(for: uid))
    }

    func assertLocalAccountAbsent(for uid: String) throws {
        try assertLocalSwiftDataAbsent(for: uid)
        XCTAssertFalse(healthCacheDirectoryExists(for: uid))
    }

    func assertLocalSwiftDataAbsent(for uid: String) throws {
        XCTAssertNil(try profileFor(ownerUID: uid))
        XCTAssertEqual(try ownedFoodCount(for: uid), 0)
        XCTAssertEqual(try ownedEntityCount(WaterEntryEntity.self, uid: uid), 0)
        XCTAssertEqual(try ownedEntityCount(WeightEntryEntity.self, uid: uid), 0)
        XCTAssertEqual(try ownedEntityCount(DailyLogEntity.self, uid: uid), 0)
        XCTAssertEqual(try ownedEntityCount(DailyReviewEntity.self, uid: uid), 0)
        XCTAssertEqual(
            try store.fetch(FetchDescriptor<CoachChatTranscriptMessageEntity>()).filter { $0.userId == uid }.count,
            0
        )
        XCTAssertEqual(
            try store.fetch(FetchDescriptor<AccountSyncMutationEntity>()).filter { $0.ownerUID == uid }.count,
            0
        )
    }

    func healthCacheDirectoryExists(for uid: String) -> Bool {
        let directory = healthCacheRoot.appendingPathComponent(uid, isDirectory: true)
        return healthCacheFileManager.fileExists(atPath: directory.path)
    }

    private func writeHealthCacheMarker(for uid: String) throws {
        let directory = healthCacheRoot.appendingPathComponent(uid, isDirectory: true)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        let marker = directory.appendingPathComponent("metadata.json")
        try Data("{}".utf8).write(to: marker)
    }

    private func ownedFoodCount(for uid: String) throws -> Int {
        try ownedEntityCount(FoodEntryEntity.self, uid: uid)
    }

    private func ownedEntityCount<T: PersistentModel>(
        _ type: T.Type,
        uid: String
    ) throws -> Int where T: AccountDataSyncOwnable {
        let descriptor = FetchDescriptor<T>(
            predicate: #Predicate { entity in
                entity.ownerUID == uid
            }
        )
        return try store.fetch(descriptor).count
    }

    private func profileFor(ownerUID: String) throws -> UserProfileEntity? {
        let descriptor = FetchDescriptor<UserProfileEntity>(
            predicate: #Predicate { profile in
                profile.ownerUID == ownerUID
            }
        )
        return try store.fetch(descriptor).first
    }
}

// MARK: - Fakes

@MainActor
private final class EndToEndFakeRemoteDeletionClient: AccountDeletionRemoteDeleting, @unchecked Sendable {

    var callCount = 0
    var configuredResult: RemoteAccountDeletionResult?
    var configuredError: AccountDeletionRemoteError?
    var delayNanoseconds: UInt64 = 0
    var onWillDelete: (() -> Void)?

    func deleteRemoteAccountData(confirmation: String) async throws -> RemoteAccountDeletionResult {
        callCount += 1
        onWillDelete?()
        if delayNanoseconds > 0 {
            try await Task.sleep(nanoseconds: delayNanoseconds)
        }
        if let configuredError {
            throw configuredError
        }
        guard let configuredResult else {
            throw AccountDeletionRemoteError.unknown("not_configured")
        }
        return configuredResult
    }
}

@MainActor
private final class EndToEndRecordingDeletionRouter: AccountDeletionRouting {

    private(set) var fullDeletionRouteCount = 0
    private(set) var localOnlyRouteCount = 0

    func routeToSignedOutAfterFullAccountDeletion() async {
        fullDeletionRouteCount += 1
    }

    func routeToSignedOutAfterLocalDeviceOnlyWipe() async {
        localOnlyRouteCount += 1
    }
}

@MainActor
private final class EndToEndRecordingRestoreCoordinator: AccountRestoreCoordinating {

    private(set) var cancelledUIDs: [String] = []

    func prepareAccountAfterSignIn(uid: String, reason: AccountRestoreReason) async -> AccountRestoreSummary {
        skippedSummary(uid: uid, reason: reason)
    }

    func prepareAccountOnAppLaunch(uid: String) async -> AccountRestoreSummary? { nil }

    func retryRestore(uid: String) async -> AccountRestoreSummary {
        skippedSummary(uid: uid, reason: .manualRetry)
    }

    func runBackgroundBackfillIfNeeded(uid: String) async {}

    func cancelOnAccountSwitch() {
        cancelledUIDs.append("*")
    }

    func cancelAllWork(for uid: String) {
        cancelledUIDs.append(uid)
    }

    private func skippedSummary(uid: String, reason: AccountRestoreReason) -> AccountRestoreSummary {
        AccountRestoreSummary(
            uid: uid,
            reason: reason,
            mode: .blockingInitial,
            status: .skipped,
            startedAt: Date(),
            endedAt: Date(),
            profileRestored: false,
            dailyLogsRestored: 0,
            foodEntriesRestored: 0,
            waterEntriesRestored: 0,
            weightEntriesRestored: 0,
            dailyReviewsRestored: 0,
            skippedLocalNewer: 0,
            conflicts: 0,
            failed: 0,
            isPartial: false,
            userFacingMessage: nil
        )
    }
}

@MainActor
private final class EndToEndDelayedSyncUploader: AccountSyncUploading {

    var delayNanoseconds: UInt64 = 0

    func uploadDueMutations(for uid: String, limit: Int) async -> AccountSyncUploadSummary {
        if delayNanoseconds > 0 {
            try? await Task.sleep(nanoseconds: delayNanoseconds)
        }
        return AccountSyncUploadSummary(
            uid: uid,
            attempted: 1,
            succeeded: 1,
            failed: 0,
            cancelled: 0
        )
    }
}

@MainActor
private final class EndToEndDelayedSyncPuller: AccountSyncPulling {

    func pullRecentAccountData(
        for uid: String,
        from startDate: String,
        to endDate: String
    ) async -> AccountSyncPullSummary {
        AccountSyncPullSummary(
            uid: uid,
            dailyLogsFetched: 0,
            foodEntriesFetched: 0,
            waterEntriesFetched: 0,
            weightEntriesFetched: 0,
            dailyReviewsFetched: 0,
            inserted: 0,
            updated: 0,
            skippedLocalNewer: 0,
            conflicts: 0,
            failed: 0
        )
    }

    func mergeFetchedDocuments(
        for uid: String,
        dailyLogs: [CloudDailyLogDocument],
        foodEntries: [CloudFoodEntryDocument],
        waterEntries: [CloudWaterEntryDocument],
        weightEntries: [CloudWeightEntryDocument],
        dailyReviews: [CloudDailyReviewDocument]
    ) throws -> AccountSyncMergeBatchResult {
        AccountSyncMergeBatchResult(
            inserted: 0,
            updated: 0,
            deleted: 0,
            skippedLocalNewer: 0,
            conflicts: 0,
            failed: 0
        )
    }
}

@MainActor
private final class EndToEndTrackingIncrementalPuller: AccountIncrementalPulling {

    func pullChanges(
        for uid: String,
        mode: CrossDeviceSyncMode,
        reason: CrossDeviceSyncReason
    ) async -> CrossDeviceSyncSummary {
        CrossDeviceSyncTestSupport.makePullSummary(uid: uid, referenceDate: Date())
    }
}

private final class HealthCacheRemovalBlockingFileManager: FileManager, @unchecked Sendable {

    var blockedHealthCacheDirectory: String?

    override func removeItem(at url: URL) throws {
        if let blocked = blockedHealthCacheDirectory,
           url.path == blocked || url.path.hasPrefix(blocked + "/") {
            throw NSError(domain: NSCocoaErrorDomain, code: NSFileWriteNoPermissionError)
        }
        try super.removeItem(at: url)
    }
}
