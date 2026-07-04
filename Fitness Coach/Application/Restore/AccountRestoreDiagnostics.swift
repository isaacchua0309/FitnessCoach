//
//  AccountRestoreDiagnostics.swift
//  Fitness Coach
//
//  Forma — In-memory account restore observability (Phase 4).
//

import Foundation

@MainActor
final class AccountRestoreDiagnostics {

    private(set) var lastSnapshot: AccountRestoreDiagnosticsSnapshot?

    func recordRun(
        traceId: String,
        summary: AccountRestoreSummary,
        errorCategory: String? = nil
    ) {
        let snapshot = AccountRestoreDiagnosticsSnapshot.make(
            traceId: traceId,
            summary: summary,
            errorCategory: errorCategory
        )
        lastSnapshot = snapshot
        AccountRestoreLogger.runCompleted(snapshot)
    }

    func restoreState(
        for uid: String,
        stateStore: AccountRestoreStateStoring
    ) -> AccountRestoreStoredState {
        stateStore.loadState(uid: uid)
    }

    #if DEBUG
    func triggerManualRetry(
        coordinator: AccountRestoreCoordinating,
        uid: String
    ) async -> AccountRestoreDiagnosticsSnapshot? {
        _ = await coordinator.retryRestore(uid: uid)
        return lastSnapshot
    }

    func resetRestoreMetadata(
        stateStore: AccountRestoreStateStoring,
        uid: String
    ) {
        stateStore.clear(uid: uid)
        AccountRestoreLogger.event(
            "restore_metadata_reset",
            fields: ["uid": uid]
        )
    }
    #endif
}
