//
//  CrossDeviceSyncTestSupport.swift
//  Fitness CoachTests
//
//  Forma — Shared fakes for Phase 5 cross-device sync tests.
//

import Foundation
@testable import Fitness_Coach

@MainActor
final class CrossDeviceSyncNetworkCheckerMock: AccountSyncNetworkChecking, @unchecked Sendable {

    var isNetworkAvailable = true
}

@MainActor
final class TrackingAccountSyncCoordinator: AccountSyncCoordinating {

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
final class TrackingAccountIncrementalPuller: AccountIncrementalPulling {

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

@MainActor
final class RecordingCrossDeviceSyncCoordinator: CrossDeviceSyncCoordinating {

    var hintedUIDs: [String] = []
    var refreshCallCount = 0

    func refreshNow(
        uid: String,
        mode: CrossDeviceSyncMode,
        reason: CrossDeviceSyncReason
    ) async -> CrossDeviceSyncSummary {
        refreshCallCount += 1
        return emptySummary(uid: uid, mode: mode, reason: reason)
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

final class RecordingAccountRealtimeChangeListener: AccountRealtimeChangeListening, @unchecked Sendable {

    var onRemoteChangeHint: ((String) -> Void)?
    private(set) var startedUIDs: [String] = []
    private(set) var stoppedUIDs: [String] = []
    private(set) var stopAllCallCount = 0

    func startListening(uid: String) async {
        startedUIDs.append(uid)
    }

    func stopListening(uid: String) async {
        stoppedUIDs.append(uid)
    }

    func stopAll() async {
        stopAllCallCount += 1
    }
}

enum CrossDeviceSyncTestSupport {

    static func makePullSummary(
        uid: String,
        referenceDate: Date,
        inserted: Int = 0,
        updated: Int = 0,
        deleted: Int = 0,
        pulledProfile: Bool = false,
        pulledFoodEntries: Int = 0
    ) -> CrossDeviceSyncSummary {
        CrossDeviceSyncSummary(
            uid: uid,
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
            updated: updated,
            deleted: deleted,
            skippedLocalNewer: 0,
            conflicts: 0,
            failed: 0,
            didRefreshUI: false,
            userFacingMessage: nil
        )
    }
}

@MainActor
final class FeatureCrossDeviceSyncCoordinator: CrossDeviceSyncCoordinating {

    var manualRefreshCallCount = 0
    var manualRefreshDelayNanoseconds: UInt64 = 0

    func refreshNow(
        uid: String,
        mode: CrossDeviceSyncMode,
        reason: CrossDeviceSyncReason
    ) async -> CrossDeviceSyncSummary {
        CrossDeviceSyncTestSupport.makePullSummary(
            uid: uid,
            referenceDate: Date()
        )
    }

    func foregroundRefreshIfNeeded(uid: String) async -> CrossDeviceSyncSummary? { nil }

    func manualRefresh(uid: String) async -> CrossDeviceSyncSummary {
        manualRefreshCallCount += 1
        if manualRefreshDelayNanoseconds > 0 {
            try? await Task.sleep(nanoseconds: manualRefreshDelayNanoseconds)
        }
        return CrossDeviceSyncTestSupport.makePullSummary(
            uid: uid,
            referenceDate: Date()
        )
    }

    func handleRealtimeHint(uid: String) async -> CrossDeviceSyncSummary? { nil }
}
