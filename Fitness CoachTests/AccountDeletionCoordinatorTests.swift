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
    private let referenceDate = ProfileTestFixtures.referenceDate

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

    func testDeleteAccountRequiresConfirmationPhrase() async {
        let summary = await coordinator.deleteAccount(confirmation: "delete")

        XCTAssertEqual(summary.status, .failed)
        XCTAssertEqual(summary.failureCategory, .unknown)
        XCTAssertEqual(remoteClient.callCount, 0)
        XCTAssertEqual(authDeleting.deleteCallCount, 0)
    }

    func testDeleteAccountRunsRemoteAuthAndLocalPhasesInOrder() async {
        remoteClient.configuredResult = Self.remoteResult(uid: ownerUID)
        localWiper.configuredSummary = Self.completedLocalSummary(uid: ownerUID)

        let summary = await coordinator.deleteAccount(confirmation: "DELETE")

        XCTAssertEqual(summary.status, .completed)
        XCTAssertTrue(summary.remoteProfileDeleted)
        XCTAssertTrue(summary.authAccountDeleted)
        XCTAssertTrue(summary.localProfileDeleted)
        XCTAssertEqual(remoteClient.callCount, 1)
        XCTAssertEqual(authDeleting.deleteCallCount, 1)
        XCTAssertEqual(localWiper.callCount, 1)
        XCTAssertEqual(router.fullDeletionRouteCount, 1)
        XCTAssertFalse(coordinator.isDeletionInProgress(for: ownerUID))
    }

    func testDeleteAccountReturnsReauthenticationRequiredWithoutLocalWipe() async {
        remoteClient.configuredResult = Self.remoteResult(uid: ownerUID)
        authDeleting.configuredDeleteError = .reauthenticationRequired

        let summary = await coordinator.deleteAccount(confirmation: "DELETE")

        XCTAssertEqual(summary.status, .reauthenticationRequired)
        XCTAssertEqual(summary.failureCategory, .reauthenticationRequired)
        XCTAssertTrue(summary.remoteProfileDeleted)
        XCTAssertFalse(summary.authAccountDeleted)
        XCTAssertFalse(summary.localProfileDeleted)
        XCTAssertEqual(localWiper.callCount, 0)
        XCTAssertTrue(coordinator.isDeletionInProgress(for: ownerUID))
    }

    func testRetryAfterReauthenticationCompletesDeletion() async {
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

    func testRemoteFailureDoesNotDeleteAuthOrLocalData() async {
        remoteClient.configuredError = .offline

        let summary = await coordinator.deleteAccount(confirmation: "DELETE")

        XCTAssertEqual(summary.status, .offline)
        XCTAssertEqual(summary.failureCategory, .offline)
        XCTAssertEqual(authDeleting.deleteCallCount, 0)
        XCTAssertEqual(localWiper.callCount, 0)
        XCTAssertFalse(coordinator.isDeletionInProgress(for: ownerUID))
    }

    func testAuthFailureAfterRemoteDeleteReturnsPartial() async {
        remoteClient.configuredResult = Self.remoteResult(uid: ownerUID)
        authDeleting.configuredDeleteError = .network

        let summary = await coordinator.deleteAccount(confirmation: "DELETE")

        XCTAssertEqual(summary.status, .partial)
        XCTAssertEqual(summary.failureCategory, .authDeleteFailed)
        XCTAssertTrue(summary.remoteProfileDeleted)
        XCTAssertFalse(summary.authAccountDeleted)
        XCTAssertEqual(localWiper.callCount, 0)
    }

    func testDeleteLocalDeviceDataOnlyWipesLocalAndSignsOut() async {
        localWiper.configuredSummary = Self.completedLocalSummary(
            uid: ownerUID,
            scope: .localDeviceOnly
        )

        let summary = await coordinator.deleteLocalDeviceDataOnly(confirmation: "DELETE")

        XCTAssertEqual(summary.scope, .localDeviceOnly)
        XCTAssertEqual(summary.status, .completed)
        XCTAssertFalse(summary.authAccountDeleted)
        XCTAssertTrue(summary.localProfileDeleted)
        XCTAssertEqual(remoteClient.callCount, 0)
        XCTAssertEqual(authDeleting.deleteCallCount, 0)
        XCTAssertEqual(signOutCallCount, 1)
        XCTAssertEqual(router.localOnlyRouteCount, 1)
    }

    func testAccountSwitchDuringDeletionReturnsAccountSwitched() async {
        remoteClient.delayNanoseconds = 200_000_000
        remoteClient.configuredResult = Self.remoteResult(uid: ownerUID)

        async let deletionTask = coordinator.deleteAccount(confirmation: "DELETE")
        try? await Task.sleep(nanoseconds: 20_000_000)
        sessionUID = "user-b"

        let summary = await deletionTask

        XCTAssertEqual(summary.status, .partial)
        XCTAssertEqual(summary.failureCategory, .accountSwitched)
        XCTAssertEqual(authDeleting.deleteCallCount, 0)
    }

    func testCancelDeletionClearsPendingReauthentication() async {
        remoteClient.configuredResult = Self.remoteResult(uid: ownerUID)
        authDeleting.configuredDeleteError = .reauthenticationRequired

        _ = await coordinator.deleteAccount(confirmation: "DELETE")
        coordinator.cancelDeletion()

        let retry = await coordinator.retryAfterReauthentication(confirmation: "DELETE")
        XCTAssertEqual(retry.status, .failed)
        XCTAssertFalse(coordinator.isDeletionInProgress(for: ownerUID))
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

    private static func completedLocalSummary(
        uid: String,
        scope: AccountDeletionScope = .fullAccount
    ) -> AccountDeletionSummary {
        AccountDeletionSummary(
            uid: uid,
            scope: scope,
            status: .completed,
            startedAt: Date(),
            endedAt: Date(),
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
}

@MainActor
private final class MockAccountDeletionRemoteClient: AccountDeletionRemoteDeleting, @unchecked Sendable {

    var callCount = 0
    var configuredResult: RemoteAccountDeletionResult?
    var configuredError: AccountDeletionRemoteError?
    var delayNanoseconds: UInt64 = 0

    func deleteRemoteAccountData(confirmation: String) async throws -> RemoteAccountDeletionResult {
        callCount += 1
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

    func wipeLocalData(
        for uid: String,
        scope: AccountDeletionScope,
        authorization: LocalAccountDataWipeAuthorization
    ) async -> AccountDeletionSummary {
        callCount += 1
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
