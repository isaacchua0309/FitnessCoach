//
//  AccountSyncMutationModels.swift
//  Fitness Coach
//
//  Forma — Account sync outbox domain models (Phase 3).
//
//  Mutation rows store identity and operation only. Payloads are reconstructed
//  from local entities at upload time — never food names, weights, or image bytes.
//

import Foundation

enum AccountSyncEntityType: String, Codable, CaseIterable, Sendable {
    case dailyLog
    case foodEntry
    case waterEntry
    case weightEntry
    case dailyReview
}

enum AccountSyncOperation: String, Codable, CaseIterable, Sendable {
    case upsert
    case delete
}

enum AccountSyncMutationStatus: String, Codable, CaseIterable, Sendable {
    case pending
    case inFlight
    case succeeded
    case failed
    case cancelled
}

extension AccountSyncMutationStatus {

    var isTerminal: Bool {
        switch self {
        case .succeeded, .cancelled:
            return true
        case .pending, .inFlight, .failed:
            return false
        }
    }

    var isEligibleForCoalescing: Bool {
        switch self {
        case .pending, .failed:
            return true
        case .inFlight, .succeeded, .cancelled:
            return false
        }
    }
}

/// Identity for a syncable entity within an owner namespace.
struct AccountSyncMutationKey: Hashable, Sendable {
    let ownerUID: String
    let entityType: AccountSyncEntityType
    let entityId: String

    init(ownerUID: String, entityType: AccountSyncEntityType, entityId: String) {
        self.ownerUID = ownerUID.trimmingCharacters(in: .whitespacesAndNewlines)
        self.entityType = entityType
        self.entityId = entityId.trimmingCharacters(in: .whitespacesAndNewlines)
    }
}

/// Enqueue request — no sensitive payload fields.
struct AccountSyncMutationRequest: Sendable, Equatable {
    let ownerUID: String
    let entityType: AccountSyncEntityType
    let entityId: String
    let localDate: String?
    let operation: AccountSyncOperation
    let mutationGroupId: String?

    var key: AccountSyncMutationKey {
        AccountSyncMutationKey(ownerUID: ownerUID, entityType: entityType, entityId: entityId)
    }

    init(
        ownerUID: String,
        entityType: AccountSyncEntityType,
        entityId: String,
        localDate: String? = nil,
        operation: AccountSyncOperation,
        mutationGroupId: String? = nil
    ) {
        self.ownerUID = ownerUID
        self.entityType = entityType
        self.entityId = entityId
        self.localDate = localDate
        self.operation = operation
        self.mutationGroupId = mutationGroupId
    }
}

/// Durable outbox row mapped from `AccountSyncMutationEntity`.
struct AccountSyncMutation: Identifiable, Equatable, Sendable {
    let id: String
    let ownerUID: String
    let entityType: AccountSyncEntityType
    let entityId: String
    let localDate: String?
    let operation: AccountSyncOperation
    let createdAt: Date
    let attemptCount: Int
}

enum AccountSyncMutationValidation {

    static func normalizedOwnerUID(_ ownerUID: String) throws -> String {
        let trimmed = ownerUID.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else {
            throw AccountSyncOutboxError.missingOwnerUID
        }
        return trimmed
    }

    static func normalizedEntityId(_ entityId: String) throws -> String {
        let trimmed = entityId.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else {
            throw AccountSyncOutboxError.invalidEntityIdentity
        }
        return trimmed
    }

    static func normalizedLocalDate(_ localDate: String?) throws -> String? {
        guard let localDate else { return nil }
        let trimmed = localDate.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return nil }
        guard CloudAccountDataDateCodec.date(
            fromLocalDateString: trimmed,
            calendar: Calendar(identifier: .gregorian)
        ) != nil else {
            throw AccountSyncOutboxError.invalidLocalDate
        }
        return trimmed
    }
}

enum AccountSyncOutboxError: Error, Equatable, Sendable {
    case missingOwnerUID
    case invalidEntityIdentity
    case invalidLocalDate
    case mutationNotFound
}

extension AccountSyncOutboxError: LocalizedError {

    var errorDescription: String? {
        switch self {
        case .missingOwnerUID:
            return "Sync mutation requires a non-empty owner UID."
        case .invalidEntityIdentity:
            return "Sync mutation requires a non-empty entity id."
        case .invalidLocalDate:
            return "Sync mutation local date is invalid."
        case .mutationNotFound:
            return "Sync mutation was not found in the outbox."
        }
    }
}

/// Upload-time guidance when the local entity row may be missing.
enum AccountSyncMissingEntityPolicy: Equatable, Sendable {
    case deleteRemoteByIdentity
    case cancelMutation(reason: String)
    case failMutation(reason: String)
}

enum AccountSyncMissingEntityResolver {

    static func policy(
        operation: AccountSyncOperation,
        entityType: AccountSyncEntityType
    ) -> AccountSyncMissingEntityPolicy {
        switch operation {
        case .delete:
            return .deleteRemoteByIdentity
        case .upsert:
            return .cancelMutation(
                reason: "Local \(entityType.rawValue) was removed before upload."
            )
        }
    }
}

enum AccountSyncCoalescingResult {
    case persisted(AccountSyncMutationEntity)
    case discarded
}

enum AccountSyncMutationCoalescing {

    /// Applies safe coalescing for pending/failed mutations within the same owner + entity key.
    static func apply(
        to coalescable: [AccountSyncMutationEntity],
        incoming: AccountSyncMutationRequest,
        remoteMayExist: Bool,
        now: Date
    ) -> AccountSyncCoalescingResult {
        switch incoming.operation {
        case .delete:
            return applyDelete(
                to: coalescable,
                incoming: incoming,
                remoteMayExist: remoteMayExist,
                now: now
            )
        case .upsert:
            return applyUpsert(
                to: coalescable,
                incoming: incoming,
                now: now
            )
        }
    }

    private static func applyDelete(
        to coalescable: [AccountSyncMutationEntity],
        incoming: AccountSyncMutationRequest,
        remoteMayExist: Bool,
        now: Date
    ) -> AccountSyncCoalescingResult {
        for mutation in coalescable where mutation.operation == .upsert {
            cancel(mutation, at: now, reason: "Superseded by delete mutation.")
        }

        guard remoteMayExist else {
            for mutation in coalescable where mutation.operation == .delete {
                cancel(mutation, at: now, reason: "Entity was never uploaded; delete not required.")
            }
            return .discarded
        }

        if let existingDelete = coalescable.first(where: { $0.operation == .delete }) {
            refresh(existingDelete, with: incoming, at: now)
            return .persisted(existingDelete)
        }
        return .persisted(makeEntity(from: incoming, now: now))
    }

    private static func applyUpsert(
        to coalescable: [AccountSyncMutationEntity],
        incoming: AccountSyncMutationRequest,
        now: Date
    ) -> AccountSyncCoalescingResult {
        let pendingDeletes = coalescable.filter { $0.operation == .delete }
        if !pendingDeletes.isEmpty {
            if incoming.mutationGroupId != nil {
                for mutation in pendingDeletes {
                    cancel(mutation, at: now, reason: "Superseded by recreated entity upsert.")
                }
            } else {
                for mutation in pendingDeletes {
                    cancel(mutation, at: now, reason: "Superseded by upsert mutation.")
                }
            }
        }

        let upserts = coalescable.filter { $0.operation == .upsert }
        if let primaryUpsert = upserts.first {
            for duplicate in upserts.dropFirst() {
                cancel(duplicate, at: now, reason: "Coalesced into newer upsert.")
            }
            refresh(primaryUpsert, with: incoming, at: now)
            return .persisted(primaryUpsert)
        }
        return .persisted(makeEntity(from: incoming, now: now))
    }

    private static func cancel(_ mutation: AccountSyncMutationEntity, at now: Date, reason: String) {
        mutation.status = .cancelled
        mutation.updatedAt = now
        mutation.lastError = reason
    }

    private static func refresh(
        _ mutation: AccountSyncMutationEntity,
        with incoming: AccountSyncMutationRequest,
        at now: Date
    ) {
        mutation.updatedAt = now
        mutation.localDate = incoming.localDate ?? mutation.localDate
        mutation.mutationGroupId = incoming.mutationGroupId ?? mutation.mutationGroupId
        mutation.attemptCount = 0
        mutation.nextRetryAt = nil
        mutation.lastError = nil
        mutation.status = .pending
    }

    private static func makeEntity(
        from request: AccountSyncMutationRequest,
        now: Date
    ) -> AccountSyncMutationEntity {
        AccountSyncMutationEntity(
            id: UUID().uuidString,
            ownerUID: request.ownerUID,
            entityType: request.entityType,
            entityId: request.entityId,
            localDate: request.localDate,
            operation: request.operation,
            payloadVersion: AccountDataCloudSchema.currentSchemaVersion,
            createdAt: now,
            updatedAt: now,
            status: .pending,
            mutationGroupId: request.mutationGroupId
        )
    }
}
