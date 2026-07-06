//
//  AccountSyncDiagnosticsTests.swift
//  Fitness CoachTests
//
//  Forma — Account sync diagnostics tests (Phase 3).
//

import XCTest
@testable import Fitness_Coach

@MainActor
final class AccountSyncDiagnosticsTests: XCTestCase {

    private let ownerUID = "userA"
    private let referenceDate = ProfileFixtures.referenceDate

    func testRecordsLastSnapshot() {
        let diagnostics = AccountSyncDiagnostics()
        let summary = AccountSyncRunSummary(
            uid: ownerUID,
            reason: .appForeground,
            startedAt: referenceDate,
            endedAt: referenceDate.addingTimeInterval(1),
            uploadSummary: nil,
            pullSummary: nil,
            didSkip: true,
            skipReason: AccountSyncCoordinatorSkipReason.networkUnavailable
        )

        diagnostics.recordRun(traceId: "trace-abc", summary: summary)

        let snapshot = diagnostics.lastSnapshot
        XCTAssertEqual(snapshot?.traceId, "trace-abc")
        XCTAssertEqual(snapshot?.skipReason, AccountSyncCoordinatorSkipReason.networkUnavailable)
        XCTAssertEqual(snapshot?.uidHash, AccountSyncLogger.hashedUID(ownerUID))
    }

    func testPendingMutationCountUsesOutbox() async throws {
        let container = try FormaModelContainer.makeContainer(inMemory: true)
        let store = SwiftDataStore(container: container)
        let outbox = SwiftDataAccountSyncOutboxStore(store: store)
        let diagnostics = AccountSyncDiagnostics()

        try outbox.enqueueLocalMutation(
            ownerUID: ownerUID,
            entityType: .foodEntry,
            entityId: UUID().uuidString,
            localDate: "2026-01-15",
            operation: .upsert,
            mutationGroupId: nil
        )

        let count = await diagnostics.pendingMutationCount(
            outbox: outbox,
            ownerUID: ownerUID,
            now: referenceDate
        )

        XCTAssertEqual(count, 1)
    }
}
