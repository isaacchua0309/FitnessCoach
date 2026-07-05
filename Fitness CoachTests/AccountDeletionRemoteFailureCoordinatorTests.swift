//
//  AccountDeletionRemoteFailureCoordinatorTests.swift
//  Fitness CoachTests
//
//  Forma — Remote deletion failures must stop before Auth delete, local wipe, and routing.
//

import XCTest
@testable import Fitness_Coach

@MainActor
final class AccountDeletionRemoteFailureCoordinatorTests: XCTestCase {

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
    private var coordinator: AccountDeletionCoordinator!

    override func setUp() async throws {
        try await super.setUp()
        sessionUID = ownerUID
        deletionGuard = AccountDeletionGuard()
        remoteClient = MockAccountDeletionRemoteClient()
        authDeleting = InMemoryAccountAuthDeleting()
        localWiper = MockLocalAccountDataWiper()
        router = RecordingAccountDeletionRouter()

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
                userDefaults: UserDefaults(suiteName: "AccountDeletionRemoteFailureTests.\(UUID().uuidString)")!
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
            nowProvider: { self.referenceDate }
        )
    }

    func testRemoteNotFoundStopsBeforeAuthDelete() async {
        let summary = await runRemoteFailure(.notFound)

        assertRemoteFailureStoppedDestructiveSteps(summary: summary)
        XCTAssertEqual(summary.failureCategory, .remoteServiceNotFound)
        XCTAssertEqual(
            AccountDeletionErrorFormatting.userFacingMessage(for: summary),
            FormaProductCopy.Settings.PrivacyData.deletionRemoteNotFoundErrorMessage
        )
    }

    func testRemoteUnauthorizedStopsBeforeAuthDelete() async {
        let summary = await runRemoteFailure(.unauthorized)

        assertRemoteFailureStoppedDestructiveSteps(summary: summary)
        XCTAssertEqual(summary.failureCategory, .unauthenticated)
        XCTAssertEqual(
            AccountDeletionErrorFormatting.userFacingMessage(for: summary),
            FormaProductCopy.Settings.PrivacyData.deletionRemoteUnauthorizedErrorMessage
        )
    }

    func testRemoteForbiddenStopsBeforeAuthDelete() async {
        let summary = await runRemoteFailure(.forbidden)

        assertRemoteFailureStoppedDestructiveSteps(summary: summary)
        XCTAssertEqual(summary.failureCategory, .permissionDenied)
        XCTAssertEqual(
            AccountDeletionErrorFormatting.userFacingMessage(for: summary),
            FormaProductCopy.Settings.PrivacyData.deletionRemoteForbiddenErrorMessage
        )
    }

    func testRemoteRateLimitedStopsBeforeAuthDelete() async {
        let summary = await runRemoteFailure(.rateLimited)

        assertRemoteFailureStoppedDestructiveSteps(summary: summary)
        XCTAssertEqual(summary.failureCategory, .rateLimited)
        XCTAssertEqual(
            AccountDeletionErrorFormatting.userFacingMessage(for: summary),
            FormaProductCopy.Settings.PrivacyData.deletionRemoteRateLimitedErrorMessage
        )
    }

    func testRemoteServerUnavailableStopsBeforeAuthDelete() async {
        let summary = await runRemoteFailure(.serverUnavailable)

        assertRemoteFailureStoppedDestructiveSteps(summary: summary)
        XCTAssertEqual(summary.failureCategory, .remoteDataDeleteFailed)
        XCTAssertEqual(
            AccountDeletionErrorFormatting.userFacingMessage(for: summary),
            FormaProductCopy.Settings.PrivacyData.deletionRemoteTimeoutErrorMessage
        )
    }

    func testRemoteTimeoutStopsBeforeAuthDelete() async {
        let summary = await runRemoteFailure(.timeout)

        assertRemoteFailureStoppedDestructiveSteps(summary: summary)
        XCTAssertEqual(summary.failureCategory, .remoteDataDeleteFailed)
        XCTAssertEqual(
            AccountDeletionErrorFormatting.userFacingMessage(for: summary),
            FormaProductCopy.Settings.PrivacyData.deletionRemoteTimeoutErrorMessage
        )
    }

    func testRemoteOfflineStopsBeforeAuthDelete() async {
        let summary = await runRemoteFailure(.offline)

        assertRemoteFailureStoppedDestructiveSteps(summary: summary)
        XCTAssertEqual(summary.status, .offline)
        XCTAssertEqual(summary.failureCategory, .offline)
        XCTAssertEqual(
            AccountDeletionErrorFormatting.userFacingMessage(for: summary),
            FormaProductCopy.Settings.PrivacyData.deletionRemoteOfflineErrorMessage
        )
    }

    func testRemoteFailureAllowsRetry() async {
        let summary = await runRemoteFailure(.serverUnavailable)

        XCTAssertTrue(summary.status.allowsRetry)
        XCTAssertTrue(AccountDeletionRemoteError.serverUnavailable.isRetryable)
    }

    private func runRemoteFailure(_ error: AccountDeletionRemoteError) async -> AccountDeletionSummary {
        remoteClient.configuredError = error
        return await coordinator.deleteAccount(confirmation: "DELETE")
    }

    private func assertRemoteFailureStoppedDestructiveSteps(summary: AccountDeletionSummary) {
        XCTAssertFalse(summary.isSuccessful)
        XCTAssertFalse(summary.authAccountDeleted)
        XCTAssertFalse(summary.didDeleteAnyLocalData)
        XCTAssertFalse(summary.didDeleteAnyRemoteData)
        XCTAssertEqual(authDeleting.deleteCallCount, 0)
        XCTAssertEqual(localWiper.callCount, 0)
        XCTAssertEqual(router.fullDeletionRouteCount, 0)
        XCTAssertFalse(coordinator.isDeletionInProgress(for: ownerUID))
    }
}

@MainActor
private final class MockAccountDeletionRemoteClient: AccountDeletionRemoteDeleting, @unchecked Sendable {

    var configuredError: AccountDeletionRemoteError?

    func deleteRemoteAccountData(confirmation: String) async throws -> RemoteAccountDeletionResult {
        if let configuredError {
            throw configuredError
        }
        throw AccountDeletionRemoteError.unknown("not_configured")
    }
}

@MainActor
private final class MockLocalAccountDataWiper: LocalAccountDataWiping {

    private(set) var callCount = 0

    func wipeLocalData(
        for uid: String,
        scope: AccountDeletionScope,
        authorization: LocalAccountDataWipeAuthorization
    ) async -> AccountDeletionSummary {
        callCount += 1
        return AccountDeletionSummary(
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
            localFoodEntriesDeleted: 0,
            localWaterEntriesDeleted: 0,
            localWeightEntriesDeleted: 0,
            localDailyReviewsDeleted: 0,
            localCoachMessagesDeleted: 0,
            localTimelineEventsDeleted: 0,
            localHealthCacheDeleted: true,
            localPreferencesDeleted: true,
            pendingMutationsDeleted: 0,
            failureCategory: nil,
            userFacingMessage: nil
        )
    }
}

@MainActor
private final class RecordingAccountDeletionRouter: AccountDeletionRouting {

    private(set) var fullDeletionRouteCount = 0

    func routeToSignedOutAfterFullAccountDeletion() async {
        fullDeletionRouteCount += 1
    }

    func routeToSignedOutAfterLocalDeviceOnlyWipe() async {}
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
