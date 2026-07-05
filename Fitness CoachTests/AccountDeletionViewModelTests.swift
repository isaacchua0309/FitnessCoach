//
//  AccountDeletionViewModelTests.swift
//  Fitness CoachTests
//
//  Forma — Account deletion confirmation UI state tests (Phase 6).
//

import XCTest
@testable import Fitness_Coach

@MainActor
final class AccountDeletionViewModelTests: XCTestCase {

    private let ownerUID = "user-a"
    private let referenceDate = ProfileTestFixtures.referenceDate

    private var sessionUID: String?
    private var remoteClient: MockAccountDeletionViewModelRemoteClient!
    private var authDeleting: InMemoryAccountAuthDeleting!
    private var localWiper: MockAccountDeletionViewModelLocalWiper!
    private var router: RecordingAccountDeletionViewModelRouter!
    private var coordinator: AccountDeletionCoordinator!
    private var viewModel: AccountDeletionViewModel!

    override func setUp() async throws {
        try await super.setUp()
        sessionUID = ownerUID
        remoteClient = MockAccountDeletionViewModelRemoteClient()
        authDeleting = InMemoryAccountAuthDeleting()
        localWiper = MockAccountDeletionViewModelLocalWiper()
        router = RecordingAccountDeletionViewModelRouter()

        let deletionGuard = AccountDeletionGuard()
        let syncCoordinator = AccountSyncCoordinator(
            uploader: DelayedMockAccountSyncUploader(),
            puller: DelayedMockAccountSyncPuller(),
            currentUIDProvider: { [weak self] in self?.sessionUID },
            nowProvider: { self.referenceDate },
            deletionGuard: deletionGuard
        )
        let crossDeviceCoordinator = CrossDeviceSyncCoordinator(
            syncCoordinator: syncCoordinator,
            incrementalPuller: TrackingAccountIncrementalPuller(),
            cursorStore: AccountSyncCursorStore(
                userDefaults: UserDefaults(suiteName: "AccountDeletionViewModelTests.\(UUID().uuidString)")!
            ),
            uidProvider: ClosureAccountUIDProvider { [weak self] in self?.sessionUID },
            refreshCenter: AppRefreshCenter(now: referenceDate),
            deletionGuard: deletionGuard
        )

        coordinator = AccountDeletionCoordinator(
            uidProvider: ClosureAccountUIDProvider { [weak self] in self?.sessionUID },
            crossDeviceCoordinator: crossDeviceCoordinator,
            realtimeListener: RecordingAccountRealtimeChangeListener(),
            accountSyncCoordinator: syncCoordinator,
            restoreCoordinator: RecordingAccountRestoreCoordinator(),
            remoteDeletionClient: remoteClient,
            authDeleting: authDeleting,
            localWiper: localWiper,
            deletionGuard: deletionGuard,
            router: router
        )

        viewModel = AccountDeletionViewModel()
        viewModel.configure(coordinator: coordinator)
    }

    func testConfirmationPhraseRequired() {
        viewModel.beginConfirmation(scope: .fullAccount)

        XCTAssertFalse(viewModel.canConfirmDeletion)

        viewModel.confirmationText = "DELETE"
        XCTAssertTrue(viewModel.canConfirmDeletion)
    }

    func testWrongConfirmationDisablesDelete() {
        viewModel.beginConfirmation(scope: .fullAccount)
        viewModel.confirmationText = "delete"

        XCTAssertFalse(viewModel.canConfirmDeletion)

        viewModel.confirmDeletion()

        if case .performing = viewModel.phase {
            XCTFail("Deletion should not start without exact confirmation phrase.")
        } else if case .finished = viewModel.phase {
            XCTFail("Deletion should not finish without exact confirmation phrase.")
        }
    }

    func testDeleteAccountShowsProgressStates() async {
        remoteClient.configuredResult = Self.remoteResult(uid: ownerUID)
        localWiper.configuredSummary = Self.completedLocalSummary(uid: ownerUID)
        remoteClient.delayNanoseconds = 50_000_000

        viewModel.beginConfirmation(scope: .fullAccount)
        viewModel.confirmationText = "DELETE"
        viewModel.confirmDeletion()

        try? await Task.sleep(nanoseconds: 5_000_000)
        XCTAssertTrue(viewModel.isPerformingDeletion || viewModel.showsProgress)

        try? await Task.sleep(nanoseconds: 200_000_000)

        XCTAssertFalse(viewModel.isPerformingDeletion)
        if case .finished(_, let summary) = viewModel.phase {
            XCTAssertTrue(summary.isSuccessful)
        } else {
            XCTFail("Expected finished phase after deletion.")
        }
    }

    func testReauthRequiredShowsReauthCTA() async {
        remoteClient.configuredResult = Self.remoteResult(uid: ownerUID)
        authDeleting.configuredDeleteError = .reauthenticationRequired

        viewModel.beginConfirmation(scope: .fullAccount)
        viewModel.confirmationText = "DELETE"
        viewModel.confirmDeletion()

        try? await Task.sleep(nanoseconds: 150_000_000)

        XCTAssertTrue(viewModel.requiresReauthentication)
        XCTAssertTrue(viewModel.allowsRetry)
        XCTAssertEqual(viewModel.terminalSummary?.status, .reauthenticationRequired)
    }

    func testOfflineShowsSafeMessage() async {
        remoteClient.configuredError = .offline

        viewModel.beginConfirmation(scope: .fullAccount)
        viewModel.confirmationText = "DELETE"
        viewModel.confirmDeletion()

        try? await Task.sleep(nanoseconds: 150_000_000)

        XCTAssertEqual(viewModel.terminalSummary?.status, .offline)
        XCTAssertEqual(
            viewModel.safeErrorMessage,
            FormaProductCopy.Settings.PrivacyData.deletionOfflineErrorMessage
        )
    }

    func testPartialFailureShowsRetry() async {
        remoteClient.configuredResult = Self.remoteResult(uid: ownerUID)
        authDeleting.configuredDeleteError = .network

        viewModel.beginConfirmation(scope: .fullAccount)
        viewModel.confirmationText = "DELETE"
        viewModel.confirmDeletion()

        try? await Task.sleep(nanoseconds: 150_000_000)

        XCTAssertEqual(viewModel.terminalSummary?.status, .partial)
        XCTAssertTrue(viewModel.allowsRetry)
        XCTAssertNotNil(viewModel.safeErrorMessage)
    }

    func testSuccessRoutesToSignedOutState() async {
        remoteClient.configuredResult = Self.remoteResult(uid: ownerUID)
        localWiper.configuredSummary = Self.completedLocalSummary(uid: ownerUID)

        viewModel.beginConfirmation(scope: .fullAccount)
        viewModel.confirmationText = "DELETE"
        viewModel.confirmDeletion()

        try? await Task.sleep(nanoseconds: 200_000_000)

        XCTAssertEqual(router.fullDeletionRouteCount, 1)
        if case .finished(_, let summary) = viewModel.phase {
            XCTAssertEqual(summary.status, .completed)
        } else {
            XCTFail("Expected finished success phase.")
        }
    }

    func testCancelReturnsToSettings() {
        viewModel.beginConfirmation(scope: .fullAccount)
        viewModel.confirmationText = "DELETE"

        viewModel.cancelFlow()

        XCTAssertEqual(viewModel.phase, .idle)
        XCTAssertFalse(viewModel.isPerformingDeletion)
        XCTAssertTrue(viewModel.confirmationText.isEmpty)
    }

    func testReauthCancellationDoesNotLeaveLoadingState() async {
        remoteClient.configuredResult = Self.remoteResult(uid: ownerUID)
        authDeleting.configuredDeleteError = .reauthenticationRequired

        viewModel.beginConfirmation(scope: .fullAccount)
        viewModel.confirmationText = "DELETE"
        viewModel.confirmDeletion()
        try? await Task.sleep(nanoseconds: 150_000_000)

        viewModel.confirmationText = "DELETE"
        viewModel.retryDeletion()
        authDeleting.configuredReauthError = .cancelled
        try? await Task.sleep(nanoseconds: 150_000_000)

        XCTAssertFalse(viewModel.isPerformingDeletion)
        XCTAssertNotNil(viewModel.terminalSummary)
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

    private static func completedLocalSummary(uid: String) -> AccountDeletionSummary {
        AccountDeletionSummary(
            uid: uid,
            scope: .fullAccount,
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
private final class MockAccountDeletionViewModelRemoteClient: AccountDeletionRemoteDeleting, @unchecked Sendable {

    var configuredResult: RemoteAccountDeletionResult?
    var configuredError: AccountDeletionRemoteError?
    var delayNanoseconds: UInt64 = 0

    func deleteRemoteAccountData(confirmation: String) async throws -> RemoteAccountDeletionResult {
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
private final class MockAccountDeletionViewModelLocalWiper: LocalAccountDataWiping {

    var configuredSummary: AccountDeletionSummary?

    func wipeLocalData(
        for uid: String,
        scope: AccountDeletionScope,
        authorization: LocalAccountDataWipeAuthorization
    ) async -> AccountDeletionSummary {
        configuredSummary ?? AccountDeletionViewModelTests.completedLocalSummary(uid: uid)
    }
}

@MainActor
private final class RecordingAccountDeletionViewModelRouter: AccountDeletionRouting {

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
