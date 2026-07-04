//
//  AccountRealtimeChangeListenerTests.swift
//  Fitness CoachTests
//
//  Forma — Realtime change listener tests (Phase 5).
//

import XCTest
@testable import Fitness_Coach

@MainActor
final class AccountRealtimeChangeListenerTests: XCTestCase {

    private let ownerUID = "user-a"
    private let otherUID = "user-b"

    func testListenerStartsForCurrentUID() async {
        let listener = RecordingAccountRealtimeChangeListener()

        CrossDeviceSyncLifecycle.startRealtimeListenerIfEnabled(listener: listener, uid: ownerUID)
        try? await Task.sleep(nanoseconds: 50_000_000)

        XCTAssertEqual(listener.startedUIDs, [ownerUID])
    }

    func testListenerStopsOnLogout() async {
        let listener = RecordingAccountRealtimeChangeListener()
        await listener.startListening(uid: ownerUID)

        await CrossDeviceSyncLifecycle.stopRealtimeListener(listener: listener)

        XCTAssertEqual(listener.stopAllCallCount, 1)
    }

    func testListenerStopsOldUIDOnAccountSwitch() async {
        let listener = RecordingAccountRealtimeChangeListener()
        await listener.startListening(uid: ownerUID)

        AccountRealtimeChangeListenerLifecycle.stopOnAccountSwitch(listener: listener)
        try? await Task.sleep(nanoseconds: 50_000_000)

        XCTAssertEqual(listener.stopAllCallCount, 1)
    }

    func testRemoteHintTriggersCoordinator() async {
        let listener = RecordingAccountRealtimeChangeListener()
        let coordinator = RecordingCrossDeviceSyncCoordinator()
        AccountRealtimeChangeListenerLifecycle.connect(
            listener: listener,
            crossDeviceCoordinator: coordinator
        )

        listener.onRemoteChangeHint?(ownerUID)
        try? await Task.sleep(nanoseconds: 600_000_000)

        XCTAssertEqual(coordinator.hintedUIDs, [ownerUID])
    }

    func testRealtimeHintsAreDebounced() async {
        let syncCoordinator = TrackingAccountSyncCoordinator()
        let incrementalPuller = TrackingAccountIncrementalPuller()
        let coordinator = CrossDeviceSyncCoordinator(
            syncCoordinator: syncCoordinator,
            incrementalPuller: incrementalPuller,
            cursorStore: AccountSyncCursorStore(
                userDefaults: UserDefaults(suiteName: "AccountRealtimeChangeListenerTests.\(UUID().uuidString)")!
            ),
            currentUIDProvider: { self.ownerUID },
            refreshCenter: AppRefreshCenter()
        )

        _ = await coordinator.handleRealtimeHint(uid: ownerUID)
        _ = await coordinator.handleRealtimeHint(uid: ownerUID)
        _ = await coordinator.handleRealtimeHint(uid: ownerUID)

        try? await Task.sleep(nanoseconds: 700_000_000)

        XCTAssertEqual(syncCoordinator.uploadCallCount, 1)
        XCTAssertEqual(incrementalPuller.pullCallCount, 1)
    }

    func testListenerDoesNotDirectlyMergeDocuments() async {
        let listener = RecordingAccountRealtimeChangeListener()
        let incrementalPuller = TrackingAccountIncrementalPuller()
        let coordinator = CrossDeviceSyncCoordinator(
            syncCoordinator: TrackingAccountSyncCoordinator(),
            incrementalPuller: incrementalPuller,
            cursorStore: AccountSyncCursorStore(
                userDefaults: UserDefaults(suiteName: "AccountRealtimeChangeListenerTests.\(UUID().uuidString)")!
            ),
            currentUIDProvider: { self.ownerUID },
            refreshCenter: AppRefreshCenter()
        )
        AccountRealtimeChangeListenerLifecycle.connect(
            listener: listener,
            crossDeviceCoordinator: coordinator
        )

        listener.onRemoteChangeHint?(ownerUID)

        XCTAssertEqual(incrementalPuller.pullCallCount, 0)
        XCTAssertFalse(
            Mirror(reflecting: listener).children.contains { $0.label == "incrementalPuller" }
        )
        XCTAssertFalse(
            Mirror(reflecting: FirestoreAccountRealtimeChangeListener()).children.contains {
                $0.label == "mergePuller" || $0.label == "incrementalPuller"
            }
        )
    }
}
