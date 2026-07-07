//
//  AccountSyncOutboxStoreTests.swift
//  Fitness CoachTests
//
//  Forma — Account sync outbox store tests (Phase 3).
//

import XCTest
import SwiftData
@testable import Fitness_Coach

@MainActor
final class AccountSyncOutboxStoreTests: XCTestCase {

    private var storeURL: URL!
    private var container: ModelContainer!
    private var swiftDataStore: SwiftDataStore!
    private var outbox: SwiftDataAccountSyncOutboxStore!

    private let ownerUID = "user-abc"
    private let otherOwnerUID = "user-xyz"
    private let entityId = "food-entry-1"
    private let localDate = "2026-07-04"
    private let referenceDate = FormaSwiftDataMigrationTestSupport.referenceDate

    override func setUp() async throws {
        try await super.setUp()
        FormaSwiftDataMigrationGate.resetForTesting()
        storeURL = FormaSwiftDataMigrationTestSupport.makeTemporaryStoreURL()
        container = try FormaModelContainer.makeContainer(inMemory: false, storeURL: storeURL, markMigrationComplete: true)
        swiftDataStore = SwiftDataStore(container: container)
        outbox = SwiftDataAccountSyncOutboxStore(
            store: swiftDataStore,
            remotePresenceChecker: { _ in false }
        )
    }

    override func tearDown() async throws {
        outbox = nil
        swiftDataStore = nil
        container = nil
        FormaSwiftDataMigrationTestSupport.removeStore(at: storeURL)
        storeURL = nil
        FormaSwiftDataMigrationGate.resetForTesting()
        try await super.tearDown()
    }

    func testEnqueueUpsertCreatesPendingMutation() async throws {
        try await outbox.enqueue(
            ownerUID: ownerUID,
            entityType: .foodEntry,
            entityId: entityId,
            localDate: localDate,
            operation: .upsert,
            mutationGroupId: nil
        )

        let due = try await outbox.fetchDueMutations(ownerUID: ownerUID, limit: 10, now: referenceDate)
        XCTAssertEqual(due.count, 1)
        XCTAssertEqual(due.first?.ownerUID, ownerUID)
        XCTAssertEqual(due.first?.entityType, .foodEntry)
        XCTAssertEqual(due.first?.entityId, entityId)
        XCTAssertEqual(due.first?.localDate, localDate)
        XCTAssertEqual(due.first?.operation, .upsert)
        XCTAssertEqual(due.first?.attemptCount, 0)
    }

    func testEnqueueScopesMutationByOwnerUID() async throws {
        try await outbox.enqueue(
            ownerUID: ownerUID,
            entityType: .foodEntry,
            entityId: entityId,
            localDate: localDate,
            operation: .upsert,
            mutationGroupId: nil
        )

        let dueForOwner = try await outbox.fetchDueMutations(ownerUID: ownerUID, limit: 10, now: referenceDate)
        let dueForOther = try await outbox.fetchDueMutations(ownerUID: otherOwnerUID, limit: 10, now: referenceDate)

        XCTAssertEqual(dueForOwner.count, 1)
        XCTAssertEqual(dueForOwner.first?.ownerUID, ownerUID)
        XCTAssertTrue(dueForOther.isEmpty)
    }

    func testUpsertCoalescesWithPreviousPendingUpsert() async throws {
        try await outbox.enqueue(
            ownerUID: ownerUID,
            entityType: .foodEntry,
            entityId: entityId,
            localDate: localDate,
            operation: .upsert,
            mutationGroupId: nil
        )

        try await outbox.enqueue(
            ownerUID: ownerUID,
            entityType: .foodEntry,
            entityId: entityId,
            localDate: localDate,
            operation: .upsert,
            mutationGroupId: "group-1"
        )

        let due = try await outbox.fetchDueMutations(ownerUID: ownerUID, limit: 10, now: referenceDate)
        XCTAssertEqual(due.count, 1)
    }

    func testDeleteAfterNeverUploadedUpsertDiscardsBoth() async throws {
        try await outbox.enqueue(
            ownerUID: ownerUID,
            entityType: .foodEntry,
            entityId: entityId,
            localDate: localDate,
            operation: .upsert,
            mutationGroupId: nil
        )

        try await outbox.enqueue(
            ownerUID: ownerUID,
            entityType: .foodEntry,
            entityId: entityId,
            localDate: localDate,
            operation: .delete,
            mutationGroupId: nil
        )

        let due = try await outbox.fetchDueMutations(ownerUID: ownerUID, limit: 10, now: referenceDate)
        XCTAssertTrue(due.isEmpty)
    }

    func testDeleteAfterUpsertEnqueuesDeleteWhenRemoteMayExist() async throws {
        let remoteOutbox = SwiftDataAccountSyncOutboxStore(
            store: swiftDataStore,
            remotePresenceChecker: { _ in true }
        )

        try await remoteOutbox.enqueue(
            ownerUID: ownerUID,
            entityType: .foodEntry,
            entityId: entityId,
            localDate: localDate,
            operation: .upsert,
            mutationGroupId: nil
        )

        try await remoteOutbox.enqueue(
            ownerUID: ownerUID,
            entityType: .foodEntry,
            entityId: entityId,
            localDate: localDate,
            operation: .delete,
            mutationGroupId: nil
        )

        let due = try await remoteOutbox.fetchDueMutations(ownerUID: ownerUID, limit: 10, now: referenceDate)
        XCTAssertEqual(due.count, 1)
        XCTAssertEqual(due.first?.operation, .delete)
    }

    func testUpsertAfterDeleteWithMutationGroupRecreatesPendingUpsert() async throws {
        let remoteOutbox = SwiftDataAccountSyncOutboxStore(
            store: swiftDataStore,
            remotePresenceChecker: { _ in true }
        )

        try await remoteOutbox.enqueue(
            ownerUID: ownerUID,
            entityType: .foodEntry,
            entityId: entityId,
            localDate: localDate,
            operation: .delete,
            mutationGroupId: nil
        )

        try await remoteOutbox.enqueue(
            ownerUID: ownerUID,
            entityType: .foodEntry,
            entityId: entityId,
            localDate: localDate,
            operation: .upsert,
            mutationGroupId: "recreated-group"
        )

        let due = try await remoteOutbox.fetchDueMutations(ownerUID: ownerUID, limit: 10, now: referenceDate)
        XCTAssertEqual(due.count, 1)
        XCTAssertEqual(due.first?.operation, .upsert)
    }

    func testMutationsSurviveContainerReopen() async throws {
        try await outbox.enqueue(
            ownerUID: ownerUID,
            entityType: .waterEntry,
            entityId: "water-1",
            localDate: localDate,
            operation: .upsert,
            mutationGroupId: nil
        )

        let dueBefore = try await outbox.fetchDueMutations(ownerUID: ownerUID, limit: 10, now: referenceDate)
        let mutationID = try XCTUnwrap(dueBefore.first?.id)

        outbox = nil
        swiftDataStore = nil
        container = nil

        let reopenedContainer = try FormaModelContainer.makeContainer(inMemory: false, storeURL: storeURL, markMigrationComplete: true)
        let reopenedOutbox = SwiftDataAccountSyncOutboxStore(store: SwiftDataStore(container: reopenedContainer))

        let dueAfter = try await reopenedOutbox.fetchDueMutations(ownerUID: ownerUID, limit: 10, now: referenceDate)
        XCTAssertEqual(dueAfter.count, 1)
        XCTAssertEqual(dueAfter.first?.id, mutationID)
    }

    func testDeleteDoesNotCoalesceAcrossDifferentUsers() async throws {
        let remoteOutbox = SwiftDataAccountSyncOutboxStore(
            store: swiftDataStore,
            remotePresenceChecker: { _ in true }
        )

        try await remoteOutbox.enqueue(
            ownerUID: ownerUID,
            entityType: .foodEntry,
            entityId: entityId,
            localDate: localDate,
            operation: .delete,
            mutationGroupId: nil
        )

        try await remoteOutbox.enqueue(
            ownerUID: otherOwnerUID,
            entityType: .foodEntry,
            entityId: entityId,
            localDate: localDate,
            operation: .delete,
            mutationGroupId: nil
        )

        let ownerDue = try await remoteOutbox.fetchDueMutations(ownerUID: ownerUID, limit: 10, now: referenceDate)
        let otherDue = try await remoteOutbox.fetchDueMutations(ownerUID: otherOwnerUID, limit: 10, now: referenceDate)

        XCTAssertEqual(ownerDue.count, 1)
        XCTAssertEqual(otherDue.count, 1)
        XCTAssertEqual(ownerDue.first?.ownerUID, ownerUID)
        XCTAssertEqual(otherDue.first?.ownerUID, otherOwnerUID)
        XCTAssertNotEqual(ownerDue.first?.id, otherDue.first?.id)
    }

    func testFetchDueMutationsDoesNotReturnOtherUserMutations() async throws {
        try await outbox.enqueue(
            ownerUID: ownerUID,
            entityType: .foodEntry,
            entityId: entityId,
            localDate: localDate,
            operation: .upsert,
            mutationGroupId: nil
        )

        try await outbox.enqueue(
            ownerUID: otherOwnerUID,
            entityType: .foodEntry,
            entityId: entityId,
            localDate: localDate,
            operation: .upsert,
            mutationGroupId: nil
        )

        let due = try await outbox.fetchDueMutations(ownerUID: ownerUID, limit: 10, now: referenceDate)
        XCTAssertEqual(due.count, 1)
        XCTAssertEqual(due.first?.ownerUID, ownerUID)
    }

    func testMarkFailedAppliesRetryBackoff() async throws {
        try await outbox.enqueue(
            ownerUID: ownerUID,
            entityType: .dailyLog,
            entityId: localDate,
            localDate: localDate,
            operation: .upsert,
            mutationGroupId: nil
        )

        let dueMutations = try await outbox.fetchDueMutations(ownerUID: ownerUID, limit: 1, now: referenceDate)
        let mutationID = try XCTUnwrap(dueMutations.first?.id)
        try await outbox.markInFlight([mutationID], ownerUID: ownerUID)

        try await outbox.markFailed(
            mutationID,
            ownerUID: ownerUID,
            error: AccountSyncOutboxError.mutationNotFound,
            now: referenceDate
        )

        let failedEntity = try XCTUnwrap(fetchMutationEntity(id: mutationID))
        XCTAssertEqual(failedEntity.status, .failed)
        XCTAssertEqual(failedEntity.attemptCount, 1)
        XCTAssertEqual(
            failedEntity.nextRetryAt,
            AccountSyncRetryPolicy.nextRetryDate(afterFailureWithAttemptCount: 1, from: referenceDate)
        )
        XCTAssertNotNil(failedEntity.lastError)

        let beforeBackoff = try await outbox.fetchDueMutations(
            ownerUID: ownerUID,
            limit: 10,
            now: referenceDate.addingTimeInterval(10)
        )
        XCTAssertTrue(beforeBackoff.isEmpty)

        let afterBackoff = try await outbox.fetchDueMutations(
            ownerUID: ownerUID,
            limit: 10,
            now: referenceDate.addingTimeInterval(31)
        )
        XCTAssertEqual(afterBackoff.count, 1)
    }

    func testMarkInFlightSucceededFailedAndCancelRequireOwnerUID() async throws {
        try await outbox.enqueue(
            ownerUID: ownerUID,
            entityType: .dailyLog,
            entityId: localDate,
            localDate: localDate,
            operation: .upsert,
            mutationGroupId: nil
        )

        let dueMutations = try await outbox.fetchDueMutations(ownerUID: ownerUID, limit: 1, now: referenceDate)
        let mutationID = try XCTUnwrap(dueMutations.first?.id)

        await XCTAssertThrowsErrorAsync {
            try await self.outbox.markInFlight([mutationID], ownerUID: self.otherOwnerUID)
        }

        try await outbox.markInFlight([mutationID], ownerUID: ownerUID)

        let beforeRetry = try await outbox.fetchDueMutations(ownerUID: ownerUID, limit: 10, now: referenceDate)
        XCTAssertTrue(beforeRetry.isEmpty)

        try await outbox.markFailed(
            mutationID,
            ownerUID: ownerUID,
            error: AccountSyncOutboxError.mutationNotFound,
            now: referenceDate
        )

        let failedEntity = try XCTUnwrap(fetchMutationEntity(id: mutationID))
        XCTAssertEqual(failedEntity.status, .failed)
        XCTAssertEqual(failedEntity.attemptCount, 1)
        XCTAssertEqual(
            failedEntity.nextRetryAt,
            AccountSyncRetryPolicy.nextRetryDate(afterFailureWithAttemptCount: 1, from: referenceDate)
        )
        XCTAssertNotNil(failedEntity.lastError)

        let beforeBackoff = try await outbox.fetchDueMutations(
            ownerUID: ownerUID,
            limit: 10,
            now: referenceDate.addingTimeInterval(10)
        )
        XCTAssertTrue(beforeBackoff.isEmpty)

        let afterBackoff = try await outbox.fetchDueMutations(
            ownerUID: ownerUID,
            limit: 10,
            now: referenceDate.addingTimeInterval(31)
        )
        XCTAssertEqual(afterBackoff.count, 1)

        try await outbox.markSucceeded(mutationID, ownerUID: ownerUID)
        let succeededEntity = try XCTUnwrap(fetchMutationEntity(id: mutationID))
        XCTAssertEqual(succeededEntity.status, .succeeded)
        XCTAssertNil(succeededEntity.lastError)

        try await outbox.enqueue(
            ownerUID: ownerUID,
            entityType: .weightEntry,
            entityId: "weight-1",
            localDate: localDate,
            operation: .upsert,
            mutationGroupId: nil
        )
        let cancellableDueMutations = try await outbox.fetchDueMutations(ownerUID: ownerUID, limit: 1, now: referenceDate)
        let cancellableID = try XCTUnwrap(cancellableDueMutations.first?.id)
        try await outbox.cancel(cancellableID, ownerUID: ownerUID)
        let cancelledEntity = try XCTUnwrap(fetchMutationEntity(id: cancellableID))
        XCTAssertEqual(cancelledEntity.status, .cancelled)
    }

    func testRetryBackoffIntervals() {
        let now = referenceDate
        XCTAssertEqual(
            AccountSyncRetryPolicy.nextRetryDate(afterFailureWithAttemptCount: 1, from: now),
            now.addingTimeInterval(30)
        )
        XCTAssertEqual(
            AccountSyncRetryPolicy.nextRetryDate(afterFailureWithAttemptCount: 2, from: now),
            now.addingTimeInterval(120)
        )
        XCTAssertEqual(
            AccountSyncRetryPolicy.nextRetryDate(afterFailureWithAttemptCount: 3, from: now),
            now.addingTimeInterval(600)
        )
        XCTAssertEqual(
            AccountSyncRetryPolicy.nextRetryDate(afterFailureWithAttemptCount: 4, from: now),
            now.addingTimeInterval(3_600)
        )
    }

    func testSucceededMutationsCanBePruned() async throws {
        let remoteOutbox = SwiftDataAccountSyncOutboxStore(
            store: swiftDataStore,
            remotePresenceChecker: { _ in true }
        )

        try await remoteOutbox.enqueue(
            ownerUID: ownerUID,
            entityType: .foodEntry,
            entityId: entityId,
            localDate: localDate,
            operation: .upsert,
            mutationGroupId: nil
        )
        let ownerDueMutations = try await remoteOutbox.fetchDueMutations(ownerUID: ownerUID, limit: 1, now: referenceDate)
        let ownerMutationID = try XCTUnwrap(ownerDueMutations.first?.id)
        try await remoteOutbox.markInFlight([ownerMutationID], ownerUID: ownerUID)
        try await remoteOutbox.markSucceeded(ownerMutationID, ownerUID: ownerUID)
        if let ownerEntity = fetchMutationEntity(id: ownerMutationID) {
            ownerEntity.updatedAt = referenceDate
            try swiftDataStore.save()
        }

        try await remoteOutbox.enqueue(
            ownerUID: otherOwnerUID,
            entityType: .foodEntry,
            entityId: "food-entry-2",
            localDate: localDate,
            operation: .upsert,
            mutationGroupId: nil
        )
        let otherDueMutations = try await remoteOutbox.fetchDueMutations(ownerUID: otherOwnerUID, limit: 1, now: referenceDate)
        let otherMutationID = try XCTUnwrap(otherDueMutations.first?.id)
        try await remoteOutbox.markInFlight([otherMutationID], ownerUID: otherOwnerUID)
        try await remoteOutbox.markSucceeded(otherMutationID, ownerUID: otherOwnerUID)

        try await remoteOutbox.pruneSucceeded(
            ownerUID: ownerUID,
            olderThan: referenceDate.addingTimeInterval(1)
        )

        XCTAssertNil(fetchMutationEntity(id: ownerMutationID))
        XCTAssertNotNil(fetchMutationEntity(id: otherMutationID))
    }

    func testRemotePresenceResolverUsesEntitySyncStatus() throws {
        let context = ModelContext(container)
        let seeded = try FormaSwiftDataMigrationTestSupport.seedNutritionLogs(in: context)
        let food = try XCTUnwrap(
            try context.fetch(FetchDescriptor<FoodEntryEntity>()).first { $0.id == seeded.foodID }
        )
        food.syncStatus = .synced

        let key = AccountSyncMutationKey(
            ownerUID: ownerUID,
            entityType: .foodEntry,
            entityId: seeded.foodID.uuidString
        )
        XCTAssertTrue(AccountSyncRemotePresenceResolver.mayExistRemotely(key: key, in: context))
        XCTAssertTrue(
            AccountSyncRemotePresenceResolver.statusIndicatesRemotePresence(.synced)
        )
        XCTAssertFalse(
            AccountSyncRemotePresenceResolver.statusIndicatesRemotePresence(.localOnly)
        )
    }

    // MARK: - Helpers

    private func fetchMutationEntity(id: String) -> AccountSyncMutationEntity? {
        var descriptor = FetchDescriptor<AccountSyncMutationEntity>(
            predicate: #Predicate { $0.id == id }
        )
        descriptor.fetchLimit = 1
        return try? swiftDataStore.fetchOne(descriptor)
    }
}

private func XCTAssertThrowsErrorAsync(
    _ expression: @escaping () async throws -> Void,
    file: StaticString = #filePath,
    line: UInt = #line
) async {
    do {
        try await expression()
        XCTFail("Expected error to be thrown.", file: file, line: line)
    } catch {
        // expected
    }
}
