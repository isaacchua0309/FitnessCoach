//
//  AppLifecycleCrossDeviceSyncTests.swift
//  Fitness CoachTests
//
//  Forma — App lifecycle cross-device sync wiring tests (Phase 5).
//

import XCTest
@testable import Fitness_Coach

@MainActor
final class AppLifecycleCrossDeviceSyncTests: XCTestCase {

    private let ownerUID = "user-a"
    private let otherUID = "user-b"
    private let referenceDate = ProfileFixtures.referenceDate

    private var syncCoordinator: TrackingAccountSyncCoordinator!
    private var incrementalPuller: TrackingAccountIncrementalPuller!
    private var cursorStore: AccountSyncCursorStore!
    private var suiteName: String!
    private var defaults: UserDefaults!
    private var refreshCenter: AppRefreshCenter!
    private var sessionUID: String?
    private var coordinator: CrossDeviceSyncCoordinator!
    private var listener: RecordingAccountRealtimeChangeListener!

    override func setUp() async throws {
        try await super.setUp()
        syncCoordinator = TrackingAccountSyncCoordinator()
        incrementalPuller = TrackingAccountIncrementalPuller()
        suiteName = "AppLifecycleCrossDeviceSyncTests.\(UUID().uuidString)"
        defaults = UserDefaults(suiteName: suiteName)!
        cursorStore = AccountSyncCursorStore(userDefaults: defaults)
        refreshCenter = AppRefreshCenter(now: referenceDate)
        sessionUID = ownerUID
        coordinator = CrossDeviceSyncCoordinator(
            syncCoordinator: syncCoordinator,
            incrementalPuller: incrementalPuller,
            cursorStore: cursorStore,
            currentUIDProvider: { [weak self] in self?.sessionUID },
            refreshCenter: refreshCenter,
            nowProvider: { self.referenceDate }
        )
        listener = RecordingAccountRealtimeChangeListener()
        AccountRealtimeChangeListenerLifecycle.connect(
            listener: listener,
            crossDeviceCoordinator: coordinator
        )
    }

    override func tearDown() async throws {
        coordinator.cancelPendingWork()
        listener = nil
        coordinator = nil
        refreshCenter = nil
        cursorStore = nil
        defaults.removePersistentDomain(forName: suiteName)
        defaults = nil
        incrementalPuller = nil
        syncCoordinator = nil
        try await super.tearDown()
    }

    func testForegroundTriggersRefreshWhenEnabled() async {
        XCTAssertTrue(CrossDeviceSyncLifecycle.isForegroundRefreshEnabled)

        CrossDeviceSyncLifecycle.handleAppForeground(
            coordinator: coordinator,
            uidProvider: { [weak self] in self?.sessionUID }
        )

        try? await Task.sleep(nanoseconds: 50_000_000)
        XCTAssertEqual(syncCoordinator.uploadCallCount, 1)
        XCTAssertEqual(incrementalPuller.pullCallCount, 1)
    }

    func testForegroundDoesNotBlockUI() async {
        let startedAt = Date()

        let summary = await coordinator.foregroundRefreshIfNeeded(uid: ownerUID)

        XCTAssertNil(summary)
        XCTAssertLessThan(Date().timeIntervalSince(startedAt), 0.2)
    }

    func testForegroundDoesNotRefreshWhenThrottled() async {
        cursorStore.updateForegroundRefresh(uid: ownerUID, date: referenceDate)

        CrossDeviceSyncLifecycle.handleAppForeground(
            coordinator: coordinator,
            uidProvider: { [weak self] in self?.sessionUID }
        )

        try? await Task.sleep(nanoseconds: 50_000_000)
        XCTAssertEqual(syncCoordinator.uploadCallCount, 0)
        XCTAssertEqual(incrementalPuller.pullCallCount, 0)
    }

    func testAfterRestoreStartsRealtimeListener() async {
        CrossDeviceSyncLifecycle.startRealtimeListenerIfEnabled(
            listener: listener,
            uid: ownerUID
        )

        try? await Task.sleep(nanoseconds: 50_000_000)
        XCTAssertEqual(listener.startedUIDs, [ownerUID])
    }

    func testLogoutStopsRealtimeListener() async {
        await listener.startListening(uid: ownerUID)

        await CrossDeviceSyncLifecycle.stopRealtimeListener(listener: listener)

        XCTAssertEqual(listener.stopAllCallCount, 1)
    }

    func testAccountSwitchDoesNotLeakOldUserChanges() async {
        await listener.startListening(uid: ownerUID)
        sessionUID = ownerUID

        CrossDeviceSyncLifecycle.cancelOnAccountSwitch(
            crossDeviceCoordinator: coordinator,
            realtimeListener: listener
        )
        sessionUID = otherUID

        listener.onRemoteChangeHint?(ownerUID)
        try? await Task.sleep(nanoseconds: 700_000_000)

        XCTAssertEqual(incrementalPuller.pullCallCount, 0)
        XCTAssertEqual(listener.stopAllCallCount, 1)
    }
}
