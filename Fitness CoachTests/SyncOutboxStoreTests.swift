//
//  SyncOutboxStoreTests.swift
//  Fitness CoachTests
//
//  Forma — Account sync outbox durability and coalescing tests (Phase 3).
//

import XCTest
import SwiftData
@testable import Fitness_Coach

@MainActor
final class SyncOutboxStoreTests: XCTestCase {

    private var storeURL: URL!
    private var container: ModelContainer!
    private var outbox: SyncOutboxStore!

    private let ownerUID = "user-abc"
    private let entityId = "food-entry-1"
    private let localDate = "2026-07-04"
    private let referenceDate = FormaSwiftDataMigrationTestSupport.referenceDate

    override func setUp() async throws {
        try await super.setUp()
        FormaSwiftDataMigrationGate.resetForTesting()
        storeURL = FormaSwiftDataMigrationTestSupport.makeTemporaryStoreURL()
        container = try FormaModelContainer.makeContainer(inMemory: false, storeURL: storeURL, markMigrationComplete: true)
        outbox = SyncOutboxStore(store: SwiftDataStore(container: container))
    }

    override func tearDown() async throws {
        outbox = nil
        container = nil
        FormaSwiftDataMigrationTestSupport.removeStore(at: storeURL)
        storeURL = nil
        FormaSwiftDataMigrationGate.resetForTesting()
        try await super.tearDown()
    }

    func testEnqueuePersistsIdentityOnlyMutation() throws {
        let mutation = try outbox.enqueue(
            AccountSyncMutationRequest(
                ownerUID: ownerUID,
                entityType: .foodEntry,
                entityId: entityId,
                localDate: localDate,
                operation: .upsert
            ),
            now: referenceDate
        )

        XCTAssertEqual(mutation.ownerUID, ownerUID)
        XCTAssertEqual(mutation.entityType, .foodEntry)
        XCTAssertEqual(mutation.entityId, entityId)
        XCTAssertEqual(mutation.localDate, localDate)
        XCTAssertEqual(mutation.operation, .upsert)
        XCTAssertEqual(mutation.status, .pending)
        XCTAssertEqual(mutation.attemptCount, 0)
        XCTAssertEqual(mutation.payloadVersion, AccountDataCloudSchema.currentSchemaVersion)

        let pending = try outbox.pendingMutations(ownerUID: ownerUID, now: referenceDate)
        XCTAssertEqual(pending.count, 1)
        XCTAssertEqual(pending.first?.id, mutation.id)
    }

    func testDeleteDominatesPendingUpsert() throws {
        let upsert = try outbox.enqueue(
            AccountSyncMutationRequest(
                ownerUID: ownerUID,
                entityType: .foodEntry,
                entityId: entityId,
                localDate: localDate,
                operation: .upsert
            ),
            now: referenceDate
        )

        let delete = try outbox.enqueue(
            AccountSyncMutationRequest(
                ownerUID: ownerUID,
                entityType: .foodEntry,
                entityId: entityId,
                localDate: localDate,
                operation: .delete
            ),
            now: referenceDate.addingTimeInterval(1)
        )

        XCTAssertNotEqual(upsert.id, delete.id)
        XCTAssertEqual(delete.operation, .delete)
        XCTAssertEqual(delete.status, .pending)

        let pending = try outbox.pendingMutations(ownerUID: ownerUID, now: referenceDate.addingTimeInterval(2))
        XCTAssertEqual(pending.count, 1)
        XCTAssertEqual(pending.first?.id, delete.id)

        let cancelledUpsert = try XCTUnwrap(try outbox.mutation(id: upsert.id))
        XCTAssertEqual(cancelledUpsert.status, .cancelled)
    }

    func testUpsertCoalescesIntoSinglePendingMutation() throws {
        let first = try outbox.enqueue(
            AccountSyncMutationRequest(
                ownerUID: ownerUID,
                entityType: .foodEntry,
                entityId: entityId,
                localDate: localDate,
                operation: .upsert
            ),
            now: referenceDate
        )

        let second = try outbox.enqueue(
            AccountSyncMutationRequest(
                ownerUID: ownerUID,
                entityType: .foodEntry,
                entityId: entityId,
                localDate: localDate,
                operation: .upsert,
                mutationGroupId: "group-1"
            ),
            now: referenceDate.addingTimeInterval(1)
        )

        XCTAssertEqual(first.id, second.id)
        XCTAssertEqual(second.mutationGroupId, "group-1")

        let pending = try outbox.pendingMutations(ownerUID: ownerUID, now: referenceDate.addingTimeInterval(2))
        XCTAssertEqual(pending.count, 1)
    }

    func testMutationsSurviveContainerReopen() throws {
        let mutation = try outbox.enqueue(
            AccountSyncMutationRequest(
                ownerUID: ownerUID,
                entityType: .waterEntry,
                entityId: "water-1",
                localDate: localDate,
                operation: .upsert
            ),
            now: referenceDate
        )

        outbox = nil
        container = nil

        let reopenedContainer = try FormaModelContainer.makeContainer(inMemory: false, storeURL: storeURL, markMigrationComplete: true)
        let reopenedOutbox = SyncOutboxStore(store: SwiftDataStore(container: reopenedContainer))

        let restored = try XCTUnwrap(try reopenedOutbox.mutation(id: mutation.id))
        XCTAssertEqual(restored.entityType, .waterEntry)
        XCTAssertEqual(restored.status, .pending)

        let pending = try reopenedOutbox.pendingMutations(ownerUID: ownerUID, now: referenceDate)
        XCTAssertEqual(pending.count, 1)
    }

    func testMarkInFlightSucceededAndFailed() throws {
        let mutation = try outbox.enqueue(
            AccountSyncMutationRequest(
                ownerUID: ownerUID,
                entityType: .dailyLog,
                entityId: localDate,
                localDate: localDate,
                operation: .upsert
            ),
            now: referenceDate
        )

        let inFlight = try outbox.markInFlight(id: mutation.id, now: referenceDate.addingTimeInterval(1))
        XCTAssertEqual(inFlight.status, .inFlight)

        let failed = try outbox.markFailed(
            id: mutation.id,
            error: AccountSyncOutboxError.mutationNotFound,
            nextRetryAt: referenceDate.addingTimeInterval(60),
            now: referenceDate.addingTimeInterval(2)
        )
        XCTAssertEqual(failed.status, .failed)
        XCTAssertEqual(failed.attemptCount, 1)
        XCTAssertNotNil(failed.nextRetryAt)

        let pendingBeforeRetry = try outbox.pendingMutations(ownerUID: ownerUID, now: referenceDate.addingTimeInterval(30))
        XCTAssertTrue(pendingBeforeRetry.isEmpty)

        let pendingAfterRetry = try outbox.pendingMutations(ownerUID: ownerUID, now: referenceDate.addingTimeInterval(120))
        XCTAssertEqual(pendingAfterRetry.count, 1)

        let succeeded = try outbox.markSucceeded(id: mutation.id, now: referenceDate.addingTimeInterval(121))
        XCTAssertEqual(succeeded.status, .succeeded)
        XCTAssertNil(succeeded.lastError)
    }

    func testMissingEntityResolverPolicies() {
        XCTAssertEqual(
            AccountSyncMissingEntityResolver.policy(operation: .delete, entityType: .foodEntry),
            .deleteRemoteByIdentity
        )

        if case .cancelMutation(let reason) = AccountSyncMissingEntityResolver.policy(operation: .upsert, entityType: .foodEntry) {
            XCTAssertTrue(reason.contains("foodEntry"))
        } else {
            XCTFail("Expected cancel policy for missing upsert source entity.")
        }
    }

    func testMutationsAreScopedByOwnerUID() throws {
        _ = try outbox.enqueue(
            AccountSyncMutationRequest(
                ownerUID: ownerUID,
                entityType: .foodEntry,
                entityId: entityId,
                localDate: localDate,
                operation: .upsert
            ),
            now: referenceDate
        )

        _ = try outbox.enqueue(
            AccountSyncMutationRequest(
                ownerUID: "other-user",
                entityType: .foodEntry,
                entityId: entityId,
                localDate: localDate,
                operation: .upsert
            ),
            now: referenceDate
        )

        XCTAssertEqual(try outbox.pendingMutations(ownerUID: ownerUID, now: referenceDate).count, 1)
        XCTAssertEqual(try outbox.pendingMutations(ownerUID: "other-user", now: referenceDate).count, 1)
    }
}
