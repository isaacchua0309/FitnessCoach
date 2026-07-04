//
//  AccountRealtimeChangeListenerTests.swift
//  Fitness CoachTests
//
//  Forma — Realtime change listener abstraction tests (Phase 5).
//

import XCTest
@testable import Fitness_Coach

@MainActor
final class AccountRealtimeChangeListenerTests: XCTestCase {

    private let ownerUID = "user-a"

    func testLifecycleConnectsHintToCrossDeviceCoordinator() async {
        let listener = RecordingAccountRealtimeChangeListener()
        let coordinator = RecordingCrossDeviceSyncCoordinator()
        AccountRealtimeChangeListenerLifecycle.connect(
            listener: listener,
            crossDeviceCoordinator: coordinator
        )

        listener.onRemoteChangeHint?(ownerUID)
        try? await Task.sleep(nanoseconds: 20_000_000)

        XCTAssertEqual(coordinator.hintedUIDs, [ownerUID])
    }

    func testStopOnAccountSwitchStopsAllListeners() async {
        let listener = RecordingAccountRealtimeChangeListener()
        await listener.startListening(uid: ownerUID)

        AccountRealtimeChangeListenerLifecycle.stopOnAccountSwitch(listener: listener)
        try? await Task.sleep(nanoseconds: 20_000_000)

        XCTAssertEqual(listener.stopAllCallCount, 1)
    }

    func testHintDebouncerCoalescesRapidEvents() async {
        let debouncer = AccountRealtimeChangeHintDebouncer(debounceInterval: .milliseconds(100))
        var hintedUIDs: [String] = []
        let lock = NSLock()

        for _ in 0..<5 {
            debouncer.schedule(uid: ownerUID) { uid in
                lock.lock()
                hintedUIDs.append(uid)
                lock.unlock()
            }
        }

        try? await Task.sleep(nanoseconds: 200_000_000)

        lock.lock()
        let results = hintedUIDs
        lock.unlock()
        XCTAssertEqual(results, [ownerUID])
    }

    func testNoOpListenerDoesNotRetainHints() async {
        let listener = NoOpAccountRealtimeChangeListener()
        var hintCount = 0
        listener.onRemoteChangeHint = { _ in hintCount += 1 }

        await listener.startListening(uid: ownerUID)
        listener.onRemoteChangeHint?(ownerUID)
        await listener.stopAll()

        XCTAssertEqual(hintCount, 1)
    }

    func testSupportListsOnlyPhaseFiveHintCollections() {
        XCTAssertEqual(
            AccountRealtimeChangeListenerSupport.hintedCollectionSegments,
            [
                AccountDataCloudPaths.Segment.dailyLogs,
                AccountDataCloudPaths.Segment.weightEntries,
                AccountDataCloudPaths.Segment.dailyReviews
            ]
        )
        XCTAssertEqual(
            AccountRealtimeChangeListenerSupport.profileDocumentSegment,
            AccountDataCloudPaths.Segment.profile
        )
    }
}

@MainActor
private final class RecordingCrossDeviceSyncCoordinator: CrossDeviceSyncCoordinating {

    var hintedUIDs: [String] = []

    func refreshNow(
        uid: String,
        mode: CrossDeviceSyncMode,
        reason: CrossDeviceSyncReason
    ) async -> CrossDeviceSyncSummary {
        emptySummary(uid: uid, mode: mode, reason: reason)
    }

    func foregroundRefreshIfNeeded(uid: String) async -> CrossDeviceSyncSummary? { nil }

    func manualRefresh(uid: String) async -> CrossDeviceSyncSummary {
        emptySummary(uid: uid, mode: .manualRefresh, reason: .manualPullToRefresh)
    }

    func handleRealtimeHint(uid: String) async -> CrossDeviceSyncSummary? {
        hintedUIDs.append(uid)
        return nil
    }

    private func emptySummary(
        uid: String,
        mode: CrossDeviceSyncMode,
        reason: CrossDeviceSyncReason
    ) -> CrossDeviceSyncSummary {
        CrossDeviceSyncSummary(
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

private final class RecordingAccountRealtimeChangeListener: AccountRealtimeChangeListening, @unchecked Sendable {

    var onRemoteChangeHint: ((String) -> Void)?
    private(set) var stopAllCallCount = 0

    func startListening(uid: String) async {}
    func stopListening(uid: String) async {}
    func stopAll() async { stopAllCallCount += 1 }
}
