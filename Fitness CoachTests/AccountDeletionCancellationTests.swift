//
//  AccountDeletionCancellationTests.swift
//  Fitness CoachTests
//
//  Forma — Race-safety tests for sync/listener cancellation during account deletion (Phase 6).
//

import XCTest
@testable import Fitness_Coach

@MainActor
final class AccountDeletionCancellationTests: XCTestCase {

    private let ownerUID = "user-a"
    private let otherUID = "user-b"
    private let referenceDate = ProfileTestFixtures.referenceDate

    private var deletionGuard: AccountDeletionGuard!
    private var syncCoordinator: AccountSyncCoordinator!
    private var incrementalPuller: TrackingAccountIncrementalPuller!
    private var uploader: DelayedMockAccountSyncUploader!
    private var puller: DelayedMockAccountSyncPuller!
    private var networkChecker: CrossDeviceSyncNetworkCheckerMock!
    private var refreshCenter: AppRefreshCenter!
    private var crossDeviceCoordinator: CrossDeviceSyncCoordinator!
    private var realtimeListener: RecordingAccountRealtimeChangeListener!
    private var restoreCoordinator: RecordingAccountRestoreCoordinator!
    private var accountDeletionShutdownCoordinator: AccountDeletionShutdownCoordinator!
    private var sessionUID: String?

    override func setUp() async throws {
        try await super.setUp()
        deletionGuard = AccountDeletionGuard()
        uploader = DelayedMockAccountSyncUploader()
        puller = DelayedMockAccountSyncPuller()
        networkChecker = CrossDeviceSyncNetworkCheckerMock()
        incrementalPuller = TrackingAccountIncrementalPuller()
        sessionUID = ownerUID

        syncCoordinator = AccountSyncCoordinator(
            uploader: uploader,
            puller: puller,
            networkChecker: networkChecker,
            currentUIDProvider: { [weak self] in self?.sessionUID },
            nowProvider: { self.referenceDate },
            debounceInterval: .milliseconds(50),
            deletionGuard: deletionGuard
        )

        refreshCenter = AppRefreshCenter(now: referenceDate)
        crossDeviceCoordinator = CrossDeviceSyncCoordinator(
            syncCoordinator: syncCoordinator,
            incrementalPuller: incrementalPuller,
            cursorStore: AccountSyncCursorStore(
                userDefaults: UserDefaults(suiteName: "AccountDeletionCancellationTests.\(UUID().uuidString)")!
            ),
            networkChecker: networkChecker,
            uidProvider: ClosureAccountUIDProvider { [weak self] in self?.sessionUID },
            refreshCenter: refreshCenter,
            deletionGuard: deletionGuard
        )

        realtimeListener = RecordingAccountRealtimeChangeListener()
        restoreCoordinator = RecordingAccountRestoreCoordinator()
        accountDeletionShutdownCoordinator = AccountDeletionShutdownCoordinator(
            deletionGuard: deletionGuard,
            realtimeListener: realtimeListener,
            crossDeviceCoordinator: crossDeviceCoordinator,
            accountSyncCoordinator: syncCoordinator,
            restoreCoordinator: restoreCoordinator
        )

        AccountRealtimeChangeListenerLifecycle.connect(
            listener: realtimeListener,
            crossDeviceCoordinator: crossDeviceCoordinator,
            deletionGuard: deletionGuard
        )
    }

    func testInFlightSyncResultIgnoredAfterDeletionStarted() async {
        uploader.delayNanoseconds = 200_000_000

        async let syncTask = syncCoordinator.syncNow(for: ownerUID, reason: .manual)
        deletionGuard.beginDeletion(for: ownerUID)
        await syncCoordinator.cancelAllWork(for: ownerUID)

        let summary = await syncTask

        XCTAssertTrue(summary.didSkip)
        XCTAssertEqual(summary.skipReason, AccountSyncCoordinatorSkipReason.deletionInProgress)
    }

    func testNewSyncRequestsRejectedWhileDeletionInProgress() async {
        deletionGuard.beginDeletion(for: ownerUID)

        let summary = await syncCoordinator.syncNow(for: ownerUID, reason: .manual)

        XCTAssertTrue(summary.didSkip)
        XCTAssertEqual(summary.skipReason, AccountSyncCoordinatorSkipReason.deletionInProgress)
        XCTAssertEqual(uploader.uploadCallCount, 0)
    }

    func testCrossDeviceRefreshIgnoredDuringDeletion() async {
        deletionGuard.beginDeletion(for: ownerUID)
        incrementalPuller.nextSummary = CrossDeviceSyncTestSupport.makePullSummary(
            uid: ownerUID,
            referenceDate: referenceDate,
            inserted: 3
        )

        let summary = await crossDeviceCoordinator.refreshNow(
            uid: ownerUID,
            mode: .manualRefresh,
            reason: .manualPullToRefresh
        )

        XCTAssertEqual(summary.status, .cancelled)
        XCTAssertEqual(summary.userFacingMessage, CrossDeviceSyncCoordinatorSupport.deletionInProgressMessage)
        XCTAssertEqual(incrementalPuller.pullCallCount, 0)
    }

    func testInFlightCrossDeviceRefreshDoesNotRefreshUIAfterDeletionStarts() async {
        incrementalPuller.delayNanoseconds = 200_000_000
        incrementalPuller.nextSummary = CrossDeviceSyncTestSupport.makePullSummary(
            uid: ownerUID,
            referenceDate: referenceDate,
            inserted: 5
        )

        let initialRefreshToken = refreshCenter.refreshToken

        async let refreshTask = crossDeviceCoordinator.refreshNow(
            uid: ownerUID,
            mode: .manualRefresh,
            reason: .manualPullToRefresh
        )
        deletionGuard.beginDeletion(for: ownerUID)
        await crossDeviceCoordinator.cancelAllWork(for: ownerUID)

        let summary = await refreshTask

        XCTAssertEqual(summary.status, .cancelled)
        XCTAssertFalse(summary.didRefreshUI)
        XCTAssertEqual(refreshCenter.refreshToken, initialRefreshToken)
    }

    func testRealtimeHintIgnoredDuringDeletion() async {
        deletionGuard.beginDeletion(for: ownerUID)

        _ = await crossDeviceCoordinator.handleRealtimeHint(uid: ownerUID)
        try? await Task.sleep(nanoseconds: 300_000_000)

        XCTAssertEqual(incrementalPuller.pullCallCount, 0)
    }

    func testListenerLifecycleDoesNotRouteHintsDuringDeletion() async {
        deletionGuard.beginDeletion(for: ownerUID)

        realtimeListener.onRemoteChangeHint?(ownerUID)
        try? await Task.sleep(nanoseconds: 300_000_000)

        XCTAssertEqual(incrementalPuller.pullCallCount, 0)
    }

    func testPrepareForDeletionStopsListenerSyncAndRestore() async {
        await accountDeletionShutdownCoordinator.prepareForDeletion(uid: ownerUID)

        XCTAssertTrue(accountDeletionShutdownCoordinator.isDeletionInProgress(for: ownerUID))
        XCTAssertEqual(realtimeListener.stoppedUIDs, [ownerUID])
        XCTAssertEqual(restoreCoordinator.cancelledUIDs, [ownerUID])

        let summary = await syncCoordinator.syncNow(for: ownerUID, reason: .manual)
        XCTAssertTrue(summary.didSkip)
        XCTAssertEqual(summary.skipReason, AccountSyncCoordinatorSkipReason.deletionInProgress)
    }

    func testAccountSwitchDuringDeletionDoesNotApplyOldUIDResults() async {
        uploader.delayNanoseconds = 200_000_000

        async let syncTask = syncCoordinator.syncNow(for: ownerUID, reason: .manual)
        sessionUID = otherUID

        let summary = await syncTask

        XCTAssertTrue(summary.didSkip)
        XCTAssertEqual(summary.skipReason, AccountSyncCoordinatorSkipReason.uidChanged)
    }

    func testAbortDeletionReinstatesSyncScheduling() async {
        deletionGuard.beginDeletion(for: ownerUID)
        await syncCoordinator.cancelAllWork(for: ownerUID)

        accountDeletionShutdownCoordinator.abortDeletion(uid: ownerUID)

        XCTAssertFalse(accountDeletionShutdownCoordinator.isDeletionInProgress(for: ownerUID))
        let summary = await syncCoordinator.syncNow(for: ownerUID, reason: .manual)
        XCTAssertFalse(summary.didSkip)
        XCTAssertEqual(uploader.uploadCallCount, 1)
    }
}

@MainActor
private final class DelayedMockAccountSyncUploader: AccountSyncUploading {

    var uploadCallCount = 0
    var delayNanoseconds: UInt64 = 0

    func uploadDueMutations(for uid: String, limit: Int) async -> AccountSyncUploadSummary {
        uploadCallCount += 1
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
private final class DelayedMockAccountSyncPuller: AccountSyncPulling {

    var pullCallCount = 0

    func pullRecentAccountData(
        for uid: String,
        from startDate: String,
        to endDate: String
    ) async -> AccountSyncPullSummary {
        pullCallCount += 1
        return AccountSyncPullSummary(
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
private final class TrackingAccountIncrementalPuller: AccountIncrementalPulling {

    var pullCallCount = 0
    var delayNanoseconds: UInt64 = 0
    var nextSummary: CrossDeviceSyncSummary?

    func pullChanges(
        for uid: String,
        mode: CrossDeviceSyncMode,
        reason: CrossDeviceSyncReason
    ) async -> CrossDeviceSyncSummary {
        pullCallCount += 1
        if delayNanoseconds > 0 {
            try? await Task.sleep(nanoseconds: delayNanoseconds)
        }
        if let nextSummary {
            return nextSummary
        }
        return CrossDeviceSyncTestSupport.makePullSummary(
            uid: uid,
            referenceDate: Date()
        )
    }
}

@MainActor
private final class RecordingAccountRestoreCoordinator: AccountRestoreCoordinating {

    private(set) var cancelledUIDs: [String] = []

    func prepareAccountAfterSignIn(uid: String, reason: AccountRestoreReason) async -> AccountRestoreSummary {
        emptySummary(uid: uid, reason: reason)
    }

    func prepareAccountOnAppLaunch(uid: String) async -> AccountRestoreSummary? { nil }

    func retryRestore(uid: String) async -> AccountRestoreSummary {
        emptySummary(uid: uid, reason: .manualRetry)
    }

    func runBackgroundBackfillIfNeeded(uid: String) async {}

    func cancelOnAccountSwitch() {
        cancelledUIDs.append("*")
    }

    func cancelAllWork(for uid: String) {
        cancelledUIDs.append(uid)
    }

    private func emptySummary(uid: String, reason: AccountRestoreReason) -> AccountRestoreSummary {
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
