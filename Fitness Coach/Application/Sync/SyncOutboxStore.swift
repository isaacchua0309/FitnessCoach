//
//  SyncOutboxStore.swift
//  Fitness Coach
//
//  Forma — Durable account sync mutation outbox (Phase 3).
//
//  Records identity-only mutations for later upload. Does not call Firestore.
//

import Foundation
import SwiftData

@MainActor
final class SyncOutboxStore {

    private let store: SwiftDataStore

    init(store: SwiftDataStore) {
        self.store = store
    }

    @discardableResult
    func enqueue(
        _ request: AccountSyncMutationRequest,
        now: Date = Date()
    ) throws -> AccountSyncMutation {
        let ownerUID = try AccountSyncMutationValidation.normalizedOwnerUID(request.ownerUID)
        let entityId = try AccountSyncMutationValidation.normalizedEntityId(request.entityId)
        let localDate = try AccountSyncMutationValidation.normalizedLocalDate(request.localDate)

        let normalizedRequest = AccountSyncMutationRequest(
            ownerUID: ownerUID,
            entityType: request.entityType,
            entityId: entityId,
            localDate: localDate,
            operation: request.operation,
            mutationGroupId: request.mutationGroupId
        )

        let coalescable = try fetchCoalescableMutations(for: normalizedRequest.key)
        let mutation = AccountSyncMutationCoalescing.apply(
            to: coalescable,
            incoming: normalizedRequest,
            now: now
        )

        if coalescable.contains(where: { $0.id == mutation.id }) {
            try store.save()
            return mutation.toModel()
        }

        store.modelContext.insert(mutation)
        try store.save()
        return mutation.toModel()
    }

    func pendingMutations(
        ownerUID: String,
        limit: Int = 100,
        now: Date = Date()
    ) throws -> [AccountSyncMutation] {
        let normalizedUID = try AccountSyncMutationValidation.normalizedOwnerUID(ownerUID)
        var descriptor = FetchDescriptor<AccountSyncMutationEntity>(
            predicate: #Predicate { mutation in
                mutation.ownerUID == normalizedUID
                    && (mutation.statusRawValue == "pending" || mutation.statusRawValue == "failed")
                    && (mutation.nextRetryAt == nil || mutation.nextRetryAt! <= now)
            },
            sortBy: [
                SortDescriptor(\.createdAt, order: .forward),
                SortDescriptor(\.updatedAt, order: .forward)
            ]
        )
        descriptor.fetchLimit = limit
        return try store.fetch(descriptor).map { $0.toModel() }
    }

    func mutation(id: String) throws -> AccountSyncMutation? {
        var descriptor = FetchDescriptor<AccountSyncMutationEntity>(
            predicate: #Predicate { $0.id == id }
        )
        descriptor.fetchLimit = 1
        return try store.fetchOne(descriptor)?.toModel()
    }

    func markInFlight(id: String, now: Date = Date()) throws -> AccountSyncMutation {
        let entity = try requiredEntity(id: id)
        entity.status = .inFlight
        entity.updatedAt = now
        try store.save()
        return entity.toModel()
    }

    func markSucceeded(id: String, now: Date = Date()) throws -> AccountSyncMutation {
        let entity = try requiredEntity(id: id)
        entity.status = .succeeded
        entity.updatedAt = now
        entity.lastError = nil
        entity.nextRetryAt = nil
        try store.save()
        return entity.toModel()
    }

    func markFailed(
        id: String,
        error: Error,
        nextRetryAt: Date?,
        now: Date = Date()
    ) throws -> AccountSyncMutation {
        let entity = try requiredEntity(id: id)
        entity.status = .failed
        entity.updatedAt = now
        entity.attemptCount += 1
        entity.nextRetryAt = nextRetryAt
        entity.lastError = AccountDataSyncMetadataSupport.sanitizedSyncError(from: error)
        try store.save()
        return entity.toModel()
    }

    func markCancelled(id: String, reason: String? = nil, now: Date = Date()) throws -> AccountSyncMutation {
        let entity = try requiredEntity(id: id)
        entity.status = .cancelled
        entity.updatedAt = now
        if let reason {
            entity.lastError = reason
        }
        try store.save()
        return entity.toModel()
    }

    // MARK: - Helpers

    private func fetchCoalescableMutations(
        for key: AccountSyncMutationKey
    ) throws -> [AccountSyncMutationEntity] {
        let ownerUID = key.ownerUID
        let entityId = key.entityId
        let entityTypeRawValue = key.entityType.rawValue
        let pending = AccountSyncMutationStatus.pending.rawValue
        let failed = AccountSyncMutationStatus.failed.rawValue

        let descriptor = FetchDescriptor<AccountSyncMutationEntity>(
            predicate: #Predicate { mutation in
                mutation.ownerUID == ownerUID
                    && mutation.entityId == entityId
                    && mutation.entityTypeRawValue == entityTypeRawValue
                    && (mutation.statusRawValue == pending || mutation.statusRawValue == failed)
            },
            sortBy: [SortDescriptor(\.createdAt, order: .forward)]
        )
        return try store.fetch(descriptor)
    }

    private func requiredEntity(id: String) throws -> AccountSyncMutationEntity {
        var descriptor = FetchDescriptor<AccountSyncMutationEntity>(
            predicate: #Predicate { $0.id == id }
        )
        descriptor.fetchLimit = 1
        guard let entity = try store.fetchOne(descriptor) else {
            throw AccountSyncOutboxError.mutationNotFound
        }
        return entity
    }
}
