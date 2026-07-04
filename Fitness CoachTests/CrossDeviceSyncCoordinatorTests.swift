//
//  CrossDeviceSyncCoordinatorTests.swift
//  Fitness CoachTests
//
//  Forma — Cross-device sync coordinator tests (Phase 5).
//

import Combine
import XCTest
@testable import Fitness_Coach

@MainActor
final class CrossDeviceSyncCoordinatorTests: XCTestCase {

    private let ownerUID = "user-a"
    private let referenceDate = ProfileTestFixtures.referenceDate

    private var syncCoordinator: TrackingAccountSyncCoordinator!
    private var incrementalPuller: TrackingAccountIncrementalPuller!
    private var cursorStore: AccountSyncCursorStore!
    private var defaults: UserDefaults!
    private var networkChecker: CrossDeviceSyncNetworkCheckerMock!
    private var refreshCenter: AppRefreshCenter!
    private var refreshEventBus: AccountDataRefreshEventBus!
    private var sessionUID: String!
    private var coordinator: CrossDeviceSyncCoordinator!

    override func setUp() async throws {
        try await super.setUp()
        syncCoordinator = TrackingAccountSyncCoordinator()
        incrementalPuller = TrackingAccountIncrementalPuller()
        defaults = UserDefaults(suiteName: "CrossDeviceSyncCoordinatorTests.\(UUID().uuidString)")!
        cursorStore = AccountSyncCursorStore(userDefaults: defaults)
        networkChecker = CrossDeviceSyncNetworkCheckerMock()
        refreshCenter = AppRefreshCenter(now: referenceDate)
        refreshEventBus = AccountDataRefreshEventBus(nowProvider: { self.referenceDate })
        sessionUID = ownerUID
        coordinator = CrossDeviceSyncCoordinator(
            syncCoordinator: syncCoordinator,
            incrementalPuller: incrementalPuller,
            cursorStore: cursorStore,
            networkChecker: networkChecker,
            currentUIDProvider: { [weak self] in self?.sessionUID },
            refreshCenter: refreshCenter,
            refreshEventBus: refreshEventBus,
            nowProvider: { self.referenceDate }
        )
    }

    override func tearDown() async throws {
        coordinator.cancelPendingWork()
        coordinator = nil
        refreshEventBus = nil
        refreshCenter = nil
        networkChecker = nil
        cursorStore = nil
        defaults.removePersistentDomain(forName: defaults.suiteName!)
        defaults = nil
        incrementalPuller = nil
        syncCoordinator = nil
        try await super.tearDown()
    }

    func testRefreshNowUploadsBeforePull() async {
        let summary = await coordinator.refreshNow(
            uid: ownerUID,
            mode: .manualRefresh,
            reason: .manualPullToRefresh
        )

        XCTAssertEqual(syncCoordinator.events, ["upload"])
        XCTAssertEqual(incrementalPuller.events, ["pull"])
        XCTAssertEqual(summary.status, .completed)
        XCTAssertFalse(summary.didRefreshUI)
    }

    func testRefreshNowPreventsConcurrentRunsForSameUID() async {
        syncCoordinator.uploadDelayNanoseconds = 200_000_000

        async let first = coordinator.refreshNow(
            uid: ownerUID,
            mode: .manualRefresh,
            reason: .manualPullToRefresh
        )
        try? await Task.sleep(nanoseconds: 10_000_000)
        let second = await coordinator.refreshNow(
            uid: ownerUID,
            mode: .manualRefresh,
            reason: .manualPullToRefresh
        )
        let firstSummary = await first

        XCTAssertEqual(firstSummary.status, .completed)
        XCTAssertEqual(second.status, .cancelled)
        XCTAssertEqual(syncCoordinator.uploadCallCount, 1)
        XCTAssertEqual(incrementalPuller.pullCallCount, 1)
    }

    func testRefreshNowIgnoresResultWhenUIDChangesMidRun() async {
        syncCoordinator.onUploadStarted = { [weak self] in
            self?.sessionUID = "user-b"
        }

        let summary = await coordinator.refreshNow(
            uid: ownerUID,
            mode: .manualRefresh,
            reason: .manualPullToRefresh
        )

        XCTAssertEqual(summary.status, .cancelled)
        XCTAssertEqual(incrementalPuller.pullCallCount, 0)
        XCTAssertFalse(summary.didRefreshUI)
    }

    func testRefreshNowReturnsOfflineSummaryWithoutPulling() async {
        networkChecker.isNetworkAvailable = false

        let summary = await coordinator.refreshNow(
            uid: ownerUID,
            mode: .foregroundRefresh,
            reason: .appForeground
        )

        XCTAssertEqual(summary.status, .offline)
        XCTAssertEqual(syncCoordinator.uploadCallCount, 0)
        XCTAssertEqual(incrementalPuller.pullCallCount, 0)
        XCTAssertEqual(summary.userFacingMessage, CrossDeviceSyncCoordinatorSupport.offlineMessage)
    }

    func testRefreshNowNotifiesRefreshCenterWhenRemoteDataChanges() async {
        incrementalPuller.nextSummary = makePullSummary(inserted: 2)
        let initialToken = refreshCenter.refreshToken

        let summary = await coordinator.refreshNow(
            uid: ownerUID,
            mode: .manualRefresh,
            reason: .manualPullToRefresh
        )

        XCTAssertTrue(summary.didRefreshUI)
        XCTAssertEqual(refreshCenter.refreshToken, initialToken + 1)
    }

    func testRefreshNowNotifiesRefreshCenterWhenUploadSucceeds() async {
        syncCoordinator.uploadSucceededCount = 1
        let initialToken = refreshCenter.refreshToken

        let summary = await coordinator.refreshNow(
            uid: ownerUID,
            mode: .manualRefresh,
            reason: .manualPullToRefresh
        )

        XCTAssertTrue(summary.didRefreshUI)
        XCTAssertEqual(summary.uploadedMutations, 1)
        XCTAssertEqual(refreshCenter.refreshToken, initialToken + 1)
    }

    func testForegroundRefreshIfNeededReturnsNilWhenThrottled() async {
        cursorStore.updateForegroundRefresh(uid: ownerUID, date: referenceDate)

        let summary = await coordinator.foregroundRefreshIfNeeded(uid: ownerUID)

        XCTAssertNil(summary)
        XCTAssertEqual(syncCoordinator.uploadCallCount, 0)
        XCTAssertEqual(incrementalPuller.pullCallCount, 0)
    }

    func testForegroundRefreshIfNeededSchedulesNonBlockingRefresh() async {
        let summary = await coordinator.foregroundRefreshIfNeeded(uid: ownerUID)

        XCTAssertNil(summary)
        try? await Task.sleep(nanoseconds: 50_000_000)
        XCTAssertEqual(syncCoordinator.uploadCallCount, 1)
        XCTAssertEqual(incrementalPuller.pullCallCount, 1)
    }

    func testHandleRealtimeHintDebouncesRapidHints() async {
        _ = await coordinator.handleRealtimeHint(uid: ownerUID)
        _ = await coordinator.handleRealtimeHint(uid: ownerUID)
        _ = await coordinator.handleRealtimeHint(uid: ownerUID)

        try? await Task.sleep(nanoseconds: 700_000_000)

        XCTAssertEqual(syncCoordinator.uploadCallCount, 1)
        XCTAssertEqual(incrementalPuller.pullCallCount, 1)
    }

    func testRefreshNowPublishesDomainRefreshEventWhenRemoteDataChanges() async {
        incrementalPuller.nextSummary = makePullSummary(
            inserted: 2,
            pulledFoodEntries: 1
        )
        var received: AccountDataRefreshEvent?
        let cancellable = refreshEventBus.events.sink { received = $0 }

        _ = await coordinator.refreshNow(
            uid: ownerUID,
            mode: .manualRefresh,
            reason: .manualPullToRefresh
        )
        refreshEventBus.flushImmediately()

        XCTAssertEqual(received?.uid, ownerUID)
        XCTAssertTrue(received?.domains.contains(.food) == true)
        XCTAssertTrue(received?.domains.contains(.today) == true)
        XCTAssertTrue(received?.domains.contains(.coachContext) == true)
        XCTAssertEqual(received?.reason, .manualPullToRefresh)
        cancellable.cancel()
    }

    func testRefreshNowPublishesPlanDomainWhenProfileChanges() async {
        incrementalPuller.nextSummary = makePullSummary(pulledProfile: true)
        var received: AccountDataRefreshEvent?
        let cancellable = refreshEventBus.events.sink { received = $0 }

        _ = await coordinator.refreshNow(
            uid: ownerUID,
            mode: .manualRefresh,
            reason: .realtimeSnapshot
        )
        refreshEventBus.flushImmediately()

        XCTAssertTrue(received?.domains.contains(.profile) == true)
        XCTAssertTrue(received?.domains.contains(.plan) == true)
        XCTAssertTrue(received?.domains.contains(.today) == true)
        XCTAssertTrue(received?.domains.contains(.journey) == true)
        cancellable.cancel()
    }

    func testManualRefreshAwaitsFullRun() async {
        let summary = await coordinator.manualRefresh(uid: ownerUID)

        XCTAssertEqual(summary.mode, .manualRefresh)
        XCTAssertEqual(summary.reason, .manualPullToRefresh)
        XCTAssertEqual(syncCoordinator.uploadCallCount, 1)
        XCTAssertEqual(incrementalPuller.pullCallCount, 1)
    }

    private func makePullSummary(
        inserted: Int = 0,
        pulledProfile: Bool = false,
        pulledFoodEntries: Int = 0
    ) -> CrossDeviceSyncSummary {
        CrossDeviceSyncSummary(
            uid: ownerUID,
            mode: .manualRefresh,
            reason: .manualPullToRefresh,
            status: .completed,
            startedAt: referenceDate,
            endedAt: referenceDate,
            uploadedMutations: 0,
            pulledDailyLogs: 0,
            pulledFoodEntries: pulledFoodEntries,
            pulledWaterEntries: 0,
            pulledWeightEntries: 0,
            pulledDailyReviews: 0,
            pulledProfile: pulledProfile,
            inserted: inserted,
            updated: 0,
            deleted: 0,
            skippedLocalNewer: 0,
            conflicts: 0,
            failed: 0,
            didRefreshUI: false,
            userFacingMessage: nil
        )
    }
}

@MainActor
private final class CrossDeviceSyncNetworkCheckerMock: AccountSyncNetworkChecking, @unchecked Sendable {

    var isNetworkAvailable = true
}

@MainActor
private final class TrackingAccountSyncCoordinator: AccountSyncCoordinating {

    var events: [String] = []
    var uploadCallCount = 0
    var uploadDelayNanoseconds: UInt64 = 0
    var uploadSucceededCount = 0
    var onUploadStarted: (() -> Void)?

    func syncNow(for uid: String, reason: AccountSyncReason) async -> AccountSyncRunSummary {
        await uploadPendingOnly(for: uid, reason: reason)
    }

    func uploadPendingOnly(for uid: String, reason: AccountSyncReason) async -> AccountSyncRunSummary {
        uploadCallCount += 1
        events.append("upload")
        onUploadStarted?()
        if uploadDelayNanoseconds > 0 {
            try? await Task.sleep(nanoseconds: uploadDelayNanoseconds)
        }
        let uploadSummary = AccountSyncUploadSummary(
            uid: uid,
            attempted: uploadSucceededCount,
            succeeded: uploadSucceededCount,
            failed: 0,
            cancelled: 0
        )
        return AccountSyncRunSummary(
            uid: uid,
            reason: reason,
            startedAt: Date(),
            endedAt: Date(),
            uploadSummary: uploadSummary,
            pullSummary: nil,
            didSkip: false,
            skipReason: nil
        )
    }

    func pullRecentOnly(for uid: String, reason: AccountSyncReason) async -> AccountSyncRunSummary {
        AccountSyncRunSummary(
            uid: uid,
            reason: reason,
            startedAt: Date(),
            endedAt: Date(),
            uploadSummary: nil,
            pullSummary: nil,
            didSkip: true,
            skipReason: nil
        )
    }

    func cancelPendingWork() {}
}

@MainActor
private final class TrackingAccountIncrementalPuller: AccountIncrementalPulling {

    var events: [String] = []
    var pullCallCount = 0
    var nextSummary: CrossDeviceSyncSummary?

    func pullChanges(
        for uid: String,
        mode: CrossDeviceSyncMode,
        reason: CrossDeviceSyncReason
    ) async -> CrossDeviceSyncSummary {
        pullCallCount += 1
        events.append("pull")
        if let nextSummary {
            return nextSummary
        }
        return CrossDeviceSyncSummary(
            uid: uid,
            mode: mode,
            reason: reason,
            status: .completed,
            startedAt: Date(),
            endedAt: Date(),
            uploadedMutations: 0,
            pulledDailyLogs: 0,
            pulledFoodEntries: 0,
            pulledWaterEntries: 0,
            pulledWeightEntries: 0,
            pulledDailyReviews: 0,
            pulledProfile: false,
            inserted: 0,
            updated: 0,
            deleted: 0,
            skippedLocalNewer: 0,
            conflicts: 0,
            failed: 0,
            didRefreshUI: false,
            userFacingMessage: nil
        )
    }
}
