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
    private let otherUID = "user-b"
    private let referenceDate = ProfileFixtures.referenceDate

    private var syncCoordinator: TrackingAccountSyncCoordinator!
    private var incrementalPuller: TrackingAccountIncrementalPuller!
    private var cursorStore: AccountSyncCursorStore!
    private var defaultsSuiteName: String!
    private var defaults: UserDefaults!
    private var networkChecker: CrossDeviceSyncNetworkCheckerMock!
    private var refreshCenter: AppRefreshCenter!
    private var refreshEventBus: AccountDataRefreshEventBus!
    private var sessionUID: String?
    private var coordinator: CrossDeviceSyncCoordinator!

    override func setUp() async throws {
        try await super.setUp()
        syncCoordinator = TrackingAccountSyncCoordinator()
        incrementalPuller = TrackingAccountIncrementalPuller()
        defaultsSuiteName = "CrossDeviceSyncCoordinatorTests.\(UUID().uuidString)"
        defaults = UserDefaults(suiteName: defaultsSuiteName)!
        cursorStore = AccountSyncCursorStore(userDefaults: defaults)
        networkChecker = CrossDeviceSyncNetworkCheckerMock()
        refreshCenter = AppRefreshCenter(now: referenceDate)
        refreshEventBus = AccountDataRefreshEventBus(nowProvider: { self.referenceDate })
        sessionUID = ownerUID
        coordinator = makeCoordinator()
    }

    override func tearDown() async throws {
        coordinator.cancelPendingWork()
        coordinator = nil
        refreshEventBus = nil
        refreshCenter = nil
        networkChecker = nil
        cursorStore = nil
        defaults.removePersistentDomain(forName: defaultsSuiteName)
        defaultsSuiteName = nil
        defaults = nil
        incrementalPuller = nil
        syncCoordinator = nil
        try await super.tearDown()
    }

    func testRefreshUploadsPendingBeforePullingRemote() async {
        let summary = await coordinator.refreshNow(
            uid: ownerUID,
            mode: .manualRefresh,
            reason: .manualPullToRefresh
        )

        XCTAssertEqual(syncCoordinator.events, ["upload"])
        XCTAssertEqual(incrementalPuller.events, ["pull"])
        XCTAssertGreaterThan(syncCoordinator.uploadCallCount, 0)
        XCTAssertEqual(incrementalPuller.pullCallCount, 1)
        XCTAssertEqual(summary.status, .completed)
    }

    func testRefreshSkipsWhenUIDMissing() async {
        sessionUID = nil

        let summary = await coordinator.refreshNow(
            uid: ownerUID,
            mode: .foregroundRefresh,
            reason: .appForeground
        )

        XCTAssertEqual(summary.status, .cancelled)
        XCTAssertEqual(syncCoordinator.uploadCallCount, 0)
        XCTAssertEqual(incrementalPuller.pullCallCount, 0)
    }

    func testRefreshPreventsConcurrentRunsForSameUID() async {
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

    func testRefreshAllowsDifferentUIDOnlyAfterAccountSwitchHandled() async {
        syncCoordinator.uploadDelayNanoseconds = 200_000_000
        sessionUID = ownerUID

        async let first = coordinator.refreshNow(
            uid: ownerUID,
            mode: .manualRefresh,
            reason: .manualPullToRefresh
        )
        try? await Task.sleep(nanoseconds: 10_000_000)

        let blocked = await coordinator.refreshNow(
            uid: otherUID,
            mode: .manualRefresh,
            reason: .manualPullToRefresh
        )
        XCTAssertEqual(blocked.status, .cancelled)

        sessionUID = otherUID
        let allowed = await coordinator.refreshNow(
            uid: otherUID,
            mode: .manualRefresh,
            reason: .manualPullToRefresh
        )
        let firstSummary = await first

        XCTAssertEqual(firstSummary.status, .cancelled)
        XCTAssertEqual(allowed.status, .completed)
        XCTAssertEqual(allowed.uid, otherUID)
    }

    func testForegroundRefreshIsThrottled() async {
        cursorStore.updateForegroundRefresh(uid: ownerUID, date: referenceDate)

        let summary = await coordinator.foregroundRefreshIfNeeded(uid: ownerUID)

        XCTAssertNil(summary)
        try? await Task.sleep(nanoseconds: 50_000_000)
        XCTAssertEqual(syncCoordinator.uploadCallCount, 0)
        XCTAssertEqual(incrementalPuller.pullCallCount, 0)
    }

    func testManualRefreshBypassesForegroundThrottle() async {
        cursorStore.updateForegroundRefresh(uid: ownerUID, date: referenceDate)

        let summary = await coordinator.manualRefresh(uid: ownerUID)

        XCTAssertEqual(summary.mode, .manualRefresh)
        XCTAssertEqual(summary.status, .completed)
        XCTAssertEqual(syncCoordinator.uploadCallCount, 1)
        XCTAssertEqual(incrementalPuller.pullCallCount, 1)
    }

    func testOfflineRefreshKeepsLocalData() async {
        networkChecker.isNetworkAvailable = false
        incrementalPuller.nextSummary = CrossDeviceSyncTestSupport.makePullSummary(
            uid: ownerUID,
            referenceDate: referenceDate,
            inserted: 99
        )

        let summary = await coordinator.refreshNow(
            uid: ownerUID,
            mode: .foregroundRefresh,
            reason: .appForeground
        )

        XCTAssertEqual(summary.status, .offline)
        XCTAssertEqual(syncCoordinator.uploadCallCount, 0)
        XCTAssertEqual(incrementalPuller.pullCallCount, 0)
        XCTAssertFalse(summary.didRefreshUI)
        XCTAssertEqual(summary.userFacingMessage, CrossDeviceSyncCoordinatorSupport.offlineMessage)
    }

    func testRefreshPublishesEventWhenDataChanged() async {
        incrementalPuller.nextSummary = CrossDeviceSyncTestSupport.makePullSummary(
            uid: ownerUID,
            referenceDate: referenceDate,
            inserted: 2,
            pulledFoodEntries: 1
        )
        let initialToken = refreshCenter.refreshToken
        var received: AccountDataRefreshEvent?
        let cancellable = refreshEventBus.events.sink { received = $0 }

        let summary = await coordinator.refreshNow(
            uid: ownerUID,
            mode: .manualRefresh,
            reason: .manualPullToRefresh
        )
        refreshEventBus.flushImmediately()

        XCTAssertTrue(summary.didRefreshUI)
        XCTAssertEqual(refreshCenter.refreshToken, initialToken + 1)
        XCTAssertEqual(received?.uid, ownerUID)
        XCTAssertTrue(received?.domains.contains(.food) == true)
        XCTAssertTrue(received?.domains.contains(.today) == true)
        cancellable.cancel()
    }

    func testRefreshDoesNotPublishEventWhenNothingChanged() async {
        let initialToken = refreshCenter.refreshToken
        var received: AccountDataRefreshEvent?
        let cancellable = refreshEventBus.events.sink { received = $0 }

        let summary = await coordinator.refreshNow(
            uid: ownerUID,
            mode: .manualRefresh,
            reason: .manualPullToRefresh
        )
        refreshEventBus.flushImmediately()

        XCTAssertFalse(summary.didRefreshUI)
        XCTAssertEqual(refreshCenter.refreshToken, initialToken)
        XCTAssertNil(received)
        cancellable.cancel()
    }

    func testOldUIDResultIgnoredAfterAccountSwitch() async {
        syncCoordinator.onUploadStarted = { [weak self] in
            self?.sessionUID = self?.otherUID
        }

        let summary = await coordinator.refreshNow(
            uid: ownerUID,
            mode: .manualRefresh,
            reason: .manualPullToRefresh
        )

        XCTAssertEqual(summary.status, .cancelled)
        XCTAssertEqual(incrementalPuller.pullCallCount, 0)
        XCTAssertFalse(summary.didRefreshUI)
        XCTAssertEqual(summary.userFacingMessage, CrossDeviceSyncCoordinatorSupport.uidChangedMessage)
    }

    // MARK: - Helpers

    private func makeCoordinator() -> CrossDeviceSyncCoordinator {
        CrossDeviceSyncCoordinator(
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
}
