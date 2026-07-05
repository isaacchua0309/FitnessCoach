//
//  AccountDeletionCoordinatorTests.swift
//  Fitness CoachTests
//
//  Forma — Account deletion coordinator orchestration tests (Phase 6).
//

import XCTest
@testable import Fitness_Coach

@MainActor
final class AccountDeletionCoordinatorTests: XCTestCase {

    private let ownerUID = "user-a"
    private let referenceDate = ProfileFixtures.referenceDate

    private var sessionUID: String?
    private var deletionGuard: AccountDeletionGuard!
    private var syncCoordinator: AccountSyncCoordinator!
    private var crossDeviceCoordinator: CrossDeviceSyncCoordinator!
    private var realtimeListener: RecordingAccountRealtimeChangeListener!
    private var restoreCoordinator: RecordingAccountRestoreCoordinator!
    private var remoteClient: MockAccountDeletionRemoteClient!
    private var authDeleting: InMemoryAccountAuthDeleting!
    private var localWiper: MockLocalAccountDataWiper!
    private var router: RecordingAccountDeletionRouter!
    private var signOutCallCount = 0
    private var coordinator: AccountDeletionCoordinator!

    override func setUp() async throws {
        try await super.setUp()
        sessionUID = ownerUID
        deletionGuard = AccountDeletionGuard()
        remoteClient = MockAccountDeletionRemoteClient()
        authDeleting = InMemoryAccountAuthDeleting()
        localWiper = MockLocalAccountDataWiper()
        router = RecordingAccountDeletionRouter()
        signOutCallCount = 0

        syncCoordinator = AccountSyncCoordinator(
            uploader: DelayedMockAccountSyncUploader(),
            puller: DelayedMockAccountSyncPuller(),
            currentUIDProvider: { [weak self] in self?.sessionUID },
            nowProvider: { self.referenceDate },
            deletionGuard: deletionGuard
        )

        crossDeviceCoordinator = CrossDeviceSyncCoordinator(
            syncCoordinator: syncCoordinator,
            incrementalPuller: TrackingAccountIncrementalPuller(),
            cursorStore: AccountSyncCursorStore(
                userDefaults: UserDefaults(suiteName: "AccountDeletionCoordinatorTests.\(UUID().uuidString)")!
            ),
            uidProvider: ClosureAccountUIDProvider { [weak self] in self?.sessionUID },
            refreshCenter: AppRefreshCenter(now: referenceDate),
            deletionGuard: deletionGuard
        )

        realtimeListener = RecordingAccountRealtimeChangeListener()
        restoreCoordinator = RecordingAccountRestoreCoordinator()

        coordinator = AccountDeletionCoordinator(
            uidProvider: ClosureAccountUIDProvider { [weak self] in self?.sessionUID },
            crossDeviceCoordinator: crossDeviceCoordinator,
            realtimeListener: realtimeListener,
            accountSyncCoordinator: syncCoordinator,
            restoreCoordinator: restoreCoordinator,
            remoteDeletionClient: remoteClient,
            authDeleting: authDeleting,
            localWiper: localWiper,
            deletionGuard: deletionGuard,
            router: router,
            signOutCurrentSession: { [weak self] in self?.signOutCallCount += 1 },
            nowProvider: { self.referenceDate }
        )
    }

    func testFullDeletionStopsSyncBeforeRemoteDelete() async {
        remoteClient.configuredResult = Self.remoteResult(uid: ownerUID)
        localWiper.configuredSummary = Self.completedLocalSummary(uid: ownerUID)

        remoteClient.onWillDelete = { [weak self] in
            guard let self else { return }
            XCTAssertEqual(self.realtimeListener.stoppedUIDs, [self.ownerUID])
            XCTAssertTrue(self.deletionGuard.isDeletionInProgress(for: self.ownerUID))
        }

        _ = await coordinator.deleteAccount(confirmation: "DELETE")

        XCTAssertEqual(remoteClient.callCount, 1)
        XCTAssertEqual(realtimeListener.stoppedUIDs, [ownerUID])
    }

    func testFullDeletionDeletesRemoteBeforeAuth() async {
        var phaseOrder: [String] = []
        remoteClient.configuredResult = Self.remoteResult(uid: ownerUID)
        localWiper.configuredSummary = Self.completedLocalSummary(uid: ownerUID)
        remoteClient.onWillDelete = { phaseOrder.append("remote") }
        authDeleting.onDeleteCalled = { phaseOrder.append("auth") }
        localWiper.onWipeCalled = { phaseOrder.append("local") }

        _ = await coordinator.deleteAccount(confirmation: "DELETE")

        XCTAssertEqual(phaseOrder, ["remote", "auth", "local"])
    }

    func testFullDeletionDeletesAuthBeforeLocalWipeOrAccordingToChosenPolicy() async {
        remoteClient.configuredResult = Self.remoteResult(uid: ownerUID)
        localWiper.configuredSummary = Self.completedLocalSummary(uid: ownerUID)

        var authDeletedBeforeLocal = false
        authDeleting.onDeleteCalled = { [weak self] in
            guard let self else { return }
            authDeletedBeforeLocal = self.localWiper.callCount == 0
        }

        _ = await coordinator.deleteAccount(confirmation: "DELETE")

        XCTAssertTrue(authDeletedBeforeLocal)
        XCTAssertEqual(authDeleting.deleteCallCount, 1)
        XCTAssertEqual(localWiper.callCount, 1)
    }

    func testFullDeletionWipesLocalAfterAuthDeleteSuccess() async {
        remoteClient.configuredResult = Self.remoteResult(uid: ownerUID)
        localWiper.configuredSummary = Self.completedLocalSummary(uid: ownerUID)

        let summary = await coordinator.deleteAccount(confirmation: "DELETE")

        XCTAssertEqual(summary.status, .completed)
        XCTAssertTrue(summary.authAccountDeleted)
        XCTAssertTrue(summary.localProfileDeleted)
        XCTAssertEqual(localWiper.lastAuthorization, .deletionInProgress(uid: ownerUID))
    }

    func testRemoteDeleteFailureDoesNotDeleteAuth() async {
        remoteClient.configuredError = .offline

        let summary = await coordinator.deleteAccount(confirmation: "DELETE")

        XCTAssertEqual(summary.status, .offline)
        XCTAssertEqual(authDeleting.deleteCallCount, 0)
        XCTAssertEqual(localWiper.callCount, 0)
        XCTAssertFalse(coordinator.isDeletionInProgress(for: ownerUID))
    }

    func testAuthReauthRequiredReturnsReauthState() async {
        remoteClient.configuredResult = Self.remoteResult(uid: ownerUID)
        authDeleting.configuredDeleteError = .reauthenticationRequired

        let summary = await coordinator.deleteAccount(confirmation: "DELETE")

        XCTAssertEqual(summary.status, .reauthenticationRequired)
        XCTAssertTrue(summary.remoteProfileDeleted)
        XCTAssertFalse(summary.authAccountDeleted)
        XCTAssertEqual(localWiper.callCount, 0)
        XCTAssertTrue(coordinator.isDeletionInProgress(for: ownerUID))
    }

    func testRetryAfterReauthContinuesDeletion() async {
        remoteClient.configuredResult = Self.remoteResult(uid: ownerUID)
        authDeleting.configuredDeleteError = .reauthenticationRequired

        _ = await coordinator.deleteAccount(confirmation: "DELETE")

        authDeleting.configuredDeleteError = nil
        localWiper.configuredSummary = Self.completedLocalSummary(uid: ownerUID)

        let summary = await coordinator.retryAfterReauthentication(confirmation: "DELETE")

        XCTAssertEqual(summary.status, .completed)
        XCTAssertTrue(summary.authAccountDeleted)
        XCTAssertEqual(authDeleting.reauthCallCount, 1)
        XCTAssertEqual(authDeleting.deleteCallCount, 2)
        XCTAssertEqual(remoteClient.callCount, 1)
        XCTAssertEqual(router.fullDeletionRouteCount, 1)
    }

    func testLocalWipeFailureReturnsPartial() async {
        remoteClient.configuredResult = Self.remoteResult(uid: ownerUID)
        localWiper.configuredSummary = Self.partialLocalSummary(uid: ownerUID)

        let summary = await coordinator.deleteAccount(confirmation: "DELETE")

        XCTAssertEqual(summary.status, .partial)
        XCTAssertEqual(summary.failureCategory, .localWipeFailed)
        XCTAssertTrue(summary.authAccountDeleted)
        XCTAssertTrue(summary.remoteProfileDeleted)
        XCTAssertEqual(router.fullDeletionRouteCount, 1)
    }

    func testAccountSwitchCancelsOldDeletion() async {
        remoteClient.delayNanoseconds = 200_000_000
        remoteClient.configuredResult = Self.remoteResult(uid: ownerUID)

        async let deletionTask = coordinator.deleteAccount(confirmation: "DELETE")
        let deletionStarted = await AsyncTestSupport.waitUntilWallClock(timeout: 0.15) {
            coordinator.isDeletionInProgress(for: ownerUID) || remoteClient.callCount > 0
        }
        XCTAssertTrue(deletionStarted)
        sessionUID = "user-b"

        let summary = await deletionTask

        XCTAssertEqual(summary.failureCategory, .accountSwitched)
        XCTAssertEqual(authDeleting.deleteCallCount, 0)
        XCTAssertEqual(localWiper.callCount, 0)
    }

    func testCancelDeletionStopsBeforeDestructiveStep() async {
        remoteClient.delayNanoseconds = 300_000_000
        remoteClient.configuredResult = Self.remoteResult(uid: ownerUID)

        async let deletionTask = coordinator.deleteAccount(confirmation: "DELETE")
        let deletionStarted = await AsyncTestSupport.waitUntilWallClock(timeout: 0.15) {
            coordinator.isDeletionInProgress(for: ownerUID) || remoteClient.callCount > 0
        }
        XCTAssertTrue(deletionStarted)
        coordinator.cancelDeletion()

        let summary = await deletionTask

        XCTAssertEqual(authDeleting.deleteCallCount, 0)
        XCTAssertEqual(localWiper.callCount, 0)
        XCTAssertFalse(coordinator.isDeletionInProgress(for: ownerUID))
        XCTAssertNotEqual(summary.status, .completed)
    }

    func testLocalDeviceOnlyWipeDoesNotDeleteRemoteOrAuth() async {
        localWiper.configuredSummary = Self.completedLocalSummary(
            uid: ownerUID,
            scope: .localDeviceOnly
        )

        let summary = await coordinator.deleteLocalDeviceDataOnly(confirmation: "DELETE")

        XCTAssertEqual(summary.scope, .localDeviceOnly)
        XCTAssertEqual(summary.status, .completed)
        XCTAssertEqual(remoteClient.callCount, 0)
        XCTAssertEqual(authDeleting.deleteCallCount, 0)
        XCTAssertEqual(signOutCallCount, 1)
        XCTAssertEqual(router.localOnlyRouteCount, 1)
        XCTAssertEqual(localWiper.lastAuthorization, .activeSession)
    }

    private static func remoteResult(uid: String) -> RemoteAccountDeletionResult {
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

    fileprivate static func completedLocalSummary(
        uid: String,
        scope: AccountDeletionScope = .fullAccount
    ) -> AccountDeletionSummary {
        AccountDeletionSummary(
            uid: uid,
            scope: scope,
            status: .completed,
            startedAt: TestDateFixtures.referenceEpoch,
            endedAt: TestDateFixtures.referenceEpoch,
            remoteProfileDeleted: false,
            remoteDailyLogsDeleted: 0,
            remoteFoodEntriesDeleted: 0,
            remoteWaterEntriesDeleted: 0,
            remoteWeightEntriesDeleted: 0,
            remoteDailyReviewsDeleted: 0,
            remoteHealthSummariesDeleted: false,
            authAccountDeleted: false,
            localProfileDeleted: true,
            localDailyLogsDeleted: 1,
            localFoodEntriesDeleted: 1,
            localWaterEntriesDeleted: 1,
            localWeightEntriesDeleted: 1,
            localDailyReviewsDeleted: 1,
            localCoachMessagesDeleted: 1,
            localTimelineEventsDeleted: 1,
            localHealthCacheDeleted: true,
            localPreferencesDeleted: true,
            pendingMutationsDeleted: 1,
            failureCategory: nil,
            userFacingMessage: nil
        )
    }

    private static func partialLocalSummary(uid: String) -> AccountDeletionSummary {
        AccountDeletionSummary(
            uid: uid,
            scope: .fullAccount,
            status: .partial,
            startedAt: TestDateFixtures.referenceEpoch,
            endedAt: TestDateFixtures.referenceEpoch,
            remoteProfileDeleted: false,
            remoteDailyLogsDeleted: 0,
            remoteFoodEntriesDeleted: 0,
            remoteWaterEntriesDeleted: 0,
            remoteWeightEntriesDeleted: 0,
            remoteDailyReviewsDeleted: 0,
            remoteHealthSummariesDeleted: false,
            authAccountDeleted: false,
            localProfileDeleted: false,
            localDailyLogsDeleted: 0,
            localFoodEntriesDeleted: 0,
            localWaterEntriesDeleted: 0,
            localWeightEntriesDeleted: 0,
            localDailyReviewsDeleted: 0,
            localCoachMessagesDeleted: 0,
            localTimelineEventsDeleted: 0,
            localHealthCacheDeleted: false,
            localPreferencesDeleted: false,
            pendingMutationsDeleted: 0,
            failureCategory: .localWipeFailed,
            userFacingMessage: "Some on-device data may remain."
        )
    }
}

@MainActor
private final class MockAccountDeletionRemoteClient: AccountDeletionRemoteDeleting, @unchecked Sendable {

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
private final class MockLocalAccountDataWiper: LocalAccountDataWiping {

    var callCount = 0
    var configuredSummary: AccountDeletionSummary?
    var onWipeCalled: (() -> Void)?
    private(set) var lastAuthorization: LocalAccountDataWipeAuthorization?

    func wipeLocalData(
        for uid: String,
        scope: AccountDeletionScope,
        authorization: LocalAccountDataWipeAuthorization
    ) async -> AccountDeletionSummary {
        callCount += 1
        lastAuthorization = authorization
        onWipeCalled?()
        return configuredSummary ?? AccountDeletionCoordinatorTests.completedLocalSummary(
            uid: uid,
            scope: scope
        )
    }
}

@MainActor
private final class RecordingAccountDeletionRouter: AccountDeletionRouting {

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
private final class RecordingAccountRestoreCoordinator: AccountRestoreCoordinating {

    func prepareAccountAfterSignIn(uid: String, reason: AccountRestoreReason) async -> AccountRestoreSummary {
        AccountRestoreSummary(
            uid: uid,
            reason: reason,
            mode: .blockingInitial,
            status: .skipped,
            startedAt: TestDateFixtures.referenceEpoch,
            endedAt: TestDateFixtures.referenceEpoch,
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

    func prepareAccountOnAppLaunch(uid: String) async -> AccountRestoreSummary? { nil }

    func retryRestore(uid: String) async -> AccountRestoreSummary {
        await prepareAccountAfterSignIn(uid: uid, reason: .manualRetry)
    }

    func runBackgroundBackfillIfNeeded(uid: String) async {}

    func cancelOnAccountSwitch() {}

    func cancelAllWork(for uid: String) {}
}
