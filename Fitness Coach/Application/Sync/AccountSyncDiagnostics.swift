//
//  AccountSyncDiagnostics.swift
//  Fitness Coach
//
//  Forma — In-memory account sync observability (Phase 3).
//

import Foundation

struct AccountSyncDiagnosticsSnapshot: Equatable, Sendable {
    let traceId: String
    let uidHash: String
    let reason: String
    let startedAt: Date
    let endedAt: Date
    let durationMs: Int
    let didSkip: Bool
    let skipReason: String?
    let upload: AccountSyncUploadSummary?
    let pull: AccountSyncPullSummary?

    static func make(
        traceId: String,
        summary: AccountSyncRunSummary,
        durationMs: Int
    ) -> AccountSyncDiagnosticsSnapshot {
        AccountSyncDiagnosticsSnapshot(
            traceId: traceId,
            uidHash: AccountSyncLogger.hashedUID(summary.uid),
            reason: summary.reason.rawValue,
            startedAt: summary.startedAt,
            endedAt: summary.endedAt,
            durationMs: durationMs,
            didSkip: summary.didSkip,
            skipReason: summary.skipReason,
            upload: summary.uploadSummary,
            pull: summary.pullSummary
        )
    }
}

@MainActor
final class AccountSyncDiagnostics {

    private(set) var lastSnapshot: AccountSyncDiagnosticsSnapshot?

    func recordRun(traceId: String, summary: AccountSyncRunSummary) {
        let durationMs = max(
            0,
            Int(summary.endedAt.timeIntervalSince(summary.startedAt) * 1_000)
        )
        let snapshot = AccountSyncDiagnosticsSnapshot.make(
            traceId: traceId,
            summary: summary,
            durationMs: durationMs
        )
        lastSnapshot = snapshot
        AccountSyncLogger.runCompleted(snapshot)
    }

    func pendingMutationCount(
        outbox: AccountSyncOutboxStore,
        ownerUID: String,
        now: Date = Date()
    ) async -> Int {
        guard let normalizedUID = try? AccountSyncMutationValidation.normalizedOwnerUID(ownerUID) else {
            return 0
        }
        do {
            let due = try await outbox.fetchDueMutations(
                ownerUID: normalizedUID,
                limit: 500,
                now: now
            )
            return due.count
        } catch {
            return 0
        }
    }

    #if DEBUG
    func triggerManualSync(
        coordinator: AccountSyncCoordinating,
        ownerUID: String
    ) async -> AccountSyncDiagnosticsSnapshot? {
        let traceId = UUID().uuidString
        AccountSyncLogger.runStarted(traceId: traceId, reason: .manual, uid: ownerUID)
        let summary = await coordinator.syncNow(for: ownerUID, reason: .manual)
        recordRun(traceId: traceId, summary: summary)
        return lastSnapshot
    }
    #endif
}
