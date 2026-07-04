//
//  AccountSyncOutboxStore.swift
//  Fitness Coach
//
//  Forma — Durable account sync mutation outbox (Phase 3).
//
//  Records identity-only mutations for later upload. Does not call Firestore.
//

import Foundation
import SwiftData

protocol AccountSyncOutboxStore: AnyObject {

    func enqueue(
        ownerUID: String,
        entityType: AccountSyncEntityType,
        entityId: String,
        localDate: String?,
        operation: AccountSyncOperation,
        mutationGroupId: String?
    ) async throws

    func fetchDueMutations(
        ownerUID: String,
        limit: Int,
        now: Date
    ) async throws -> [AccountSyncMutation]

    func markInFlight(_ mutationIds: [String], ownerUID: String) async throws
    func markSucceeded(_ mutationId: String, ownerUID: String) async throws
    func markFailed(_ mutationId: String, ownerUID: String, error: Error, now: Date) async throws
    func cancel(_ mutationId: String, ownerUID: String) async throws
    func pruneSucceeded(ownerUID: String, olderThan date: Date) async throws
}

enum AccountSyncRetryPolicy {

    static func nextRetryDate(afterFailureWithAttemptCount attemptCount: Int, from now: Date) -> Date {
        let delay: TimeInterval
        switch attemptCount {
        case 1:
            delay = 30
        case 2:
            delay = 2 * 60
        case 3:
            delay = 10 * 60
        default:
            delay = 60 * 60
        }
        return now.addingTimeInterval(delay)
    }
}

typealias AccountSyncRemotePresenceChecking = (AccountSyncMutationKey) -> Bool

@MainActor
final class SwiftDataAccountSyncOutboxStore: AccountSyncOutboxStore {

    private let store: SwiftDataStore
    private let remotePresenceChecker: AccountSyncRemotePresenceChecking

    init(
        store: SwiftDataStore,
        remotePresenceChecker: AccountSyncRemotePresenceChecking? = nil
    ) {
        self.store = store
        self.remotePresenceChecker = remotePresenceChecker ?? Self.makeDefaultRemotePresenceChecker(store: store)
    }

    func enqueue(
        ownerUID: String,
        entityType: AccountSyncEntityType,
        entityId: String,
        localDate: String?,
        operation: AccountSyncOperation,
        mutationGroupId: String?
    ) async throws {
        let now = Date()
        let normalizedOwnerUID = try AccountSyncMutationValidation.normalizedOwnerUID(ownerUID)
        let normalizedEntityId = try AccountSyncMutationValidation.normalizedEntityId(entityId)
        let normalizedLocalDate = try AccountSyncMutationValidation.normalizedLocalDate(localDate)

        let request = AccountSyncMutationRequest(
            ownerUID: normalizedOwnerUID,
            entityType: entityType,
            entityId: normalizedEntityId,
            localDate: normalizedLocalDate,
            operation: operation,
            mutationGroupId: mutationGroupId
        )

        let coalescable = try fetchCoalescableMutations(for: request.key)
        let remoteMayExist = remoteMayExist(for: request.key, coalescable: coalescable)
        let result = AccountSyncMutationCoalescing.apply(
            to: coalescable,
            incoming: request,
            remoteMayExist: remoteMayExist,
            now: now
        )

        switch result {
        case .persisted(let mutation):
            if !coalescable.contains(where: { $0.id == mutation.id }) {
                store.modelContext.insert(mutation)
            }
            try store.save()
        case .discarded:
            try store.save()
        }
    }

    func fetchDueMutations(
        ownerUID: String,
        limit: Int,
        now: Date
    ) async throws -> [AccountSyncMutation] {
        let normalizedUID = try AccountSyncMutationValidation.normalizedOwnerUID(ownerUID)
        let pending = AccountSyncMutationStatus.pending.rawValue
        let failed = AccountSyncMutationStatus.failed.rawValue

        var descriptor = FetchDescriptor<AccountSyncMutationEntity>(
            predicate: #Predicate { mutation in
                mutation.ownerUID == normalizedUID
                    && (mutation.statusRawValue == pending || mutation.statusRawValue == failed)
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

    func markInFlight(_ mutationIds: [String], ownerUID: String) async throws {
        let normalizedUID = try AccountSyncMutationValidation.normalizedOwnerUID(ownerUID)
        let now = Date()
        for mutationId in mutationIds {
            let entity = try requiredEntity(id: mutationId, ownerUID: normalizedUID)
            entity.status = .inFlight
            entity.updatedAt = now
        }
        try store.save()
    }

    func markSucceeded(_ mutationId: String, ownerUID: String) async throws {
        let normalizedUID = try AccountSyncMutationValidation.normalizedOwnerUID(ownerUID)
        let entity = try requiredEntity(id: mutationId, ownerUID: normalizedUID)
        entity.status = .succeeded
        entity.updatedAt = Date()
        entity.lastError = nil
        entity.nextRetryAt = nil
        try store.save()
    }

    func markFailed(_ mutationId: String, ownerUID: String, error: Error, now: Date) async throws {
        let normalizedUID = try AccountSyncMutationValidation.normalizedOwnerUID(ownerUID)
        let entity = try requiredEntity(id: mutationId, ownerUID: normalizedUID)
        entity.status = .failed
        entity.updatedAt = now
        entity.attemptCount += 1
        entity.nextRetryAt = AccountSyncRetryPolicy.nextRetryDate(
            afterFailureWithAttemptCount: entity.attemptCount,
            from: now
        )
        entity.lastError = AccountDataSyncMetadataSupport.sanitizedSyncError(from: error)
        try store.save()
    }

    func cancel(_ mutationId: String, ownerUID: String) async throws {
        let normalizedUID = try AccountSyncMutationValidation.normalizedOwnerUID(ownerUID)
        let entity = try requiredEntity(id: mutationId, ownerUID: normalizedUID)
        entity.status = .cancelled
        entity.updatedAt = Date()
        try store.save()
    }

    func pruneSucceeded(ownerUID: String, olderThan date: Date) async throws {
        let normalizedUID = try AccountSyncMutationValidation.normalizedOwnerUID(ownerUID)
        let succeeded = AccountSyncMutationStatus.succeeded.rawValue
        let descriptor = FetchDescriptor<AccountSyncMutationEntity>(
            predicate: #Predicate { mutation in
                mutation.ownerUID == normalizedUID
                    && mutation.statusRawValue == succeeded
                    && mutation.updatedAt < date
            }
        )
        let rows = try store.fetch(descriptor)
        for row in rows {
            store.modelContext.delete(row)
        }
        try store.save()
    }

    // MARK: - Helpers

    private func remoteMayExist(
        for key: AccountSyncMutationKey,
        coalescable: [AccountSyncMutationEntity]
    ) -> Bool {
        if remotePresenceChecker(key) {
            return true
        }
        return AccountSyncRemotePresenceResolver.mayExistRemotely(
            key: key,
            coalescable: coalescable,
            entitySyncStatus: nil
        )
    }

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

    private func requiredEntity(id: String, ownerUID: String) throws -> AccountSyncMutationEntity {
        var descriptor = FetchDescriptor<AccountSyncMutationEntity>(
            predicate: #Predicate { mutation in
                mutation.id == id && mutation.ownerUID == ownerUID
            }
        )
        descriptor.fetchLimit = 1
        guard let entity = try store.fetchOne(descriptor) else {
            throw AccountSyncOutboxError.mutationNotFound
        }
        return entity
    }

    private static func makeDefaultRemotePresenceChecker(
        store: SwiftDataStore
    ) -> AccountSyncRemotePresenceChecking {
        { key in
            AccountSyncRemotePresenceResolver.mayExistRemotely(
                key: key,
                in: store.modelContext
            )
        }
    }
}

enum AccountSyncRemotePresenceResolver {

    static func mayExistRemotely(
        key: AccountSyncMutationKey,
        in context: ModelContext
    ) -> Bool {
        if let status = entitySyncStatus(for: key, in: context) {
            return statusIndicatesRemotePresence(status)
        }
        return false
    }

    static func mayExistRemotely(
        key: AccountSyncMutationKey,
        coalescable: [AccountSyncMutationEntity],
        entitySyncStatus: AccountDataSyncStatus?
    ) -> Bool {
        if let entitySyncStatus, statusIndicatesRemotePresence(entitySyncStatus) {
            return true
        }
        return coalescable.contains { mutation in
            mutation.operation == .upsert && mutation.attemptCount > 0
        }
    }

    static func statusIndicatesRemotePresence(_ status: AccountDataSyncStatus) -> Bool {
        switch status {
        case .localOnly, .pendingUpload:
            return false
        case .synced, .pendingDelete, .failed, .conflict:
            return true
        }
    }

    private static func entitySyncStatus(
        for key: AccountSyncMutationKey,
        in context: ModelContext
    ) -> AccountDataSyncStatus? {
        switch key.entityType {
        case .foodEntry:
            return syncStatus(forFoodEntryId: key.entityId, in: context)
        case .waterEntry:
            return syncStatus(forWaterEntryId: key.entityId, in: context)
        case .weightEntry:
            return syncStatus(forWeightEntryId: key.entityId, in: context)
        case .dailyLog:
            return syncStatus(forDailyLogId: key.entityId, in: context)
        case .dailyReview:
            return syncStatus(forDailyReviewId: key.entityId, in: context)
        }
    }

    private static func syncStatus(forFoodEntryId entityId: String, in context: ModelContext) -> AccountDataSyncStatus? {
        guard let uuid = UUID(uuidString: entityId) else { return nil }
        var descriptor = FetchDescriptor<FoodEntryEntity>(
            predicate: #Predicate { $0.id == uuid }
        )
        descriptor.fetchLimit = 1
        return try? context.fetch(descriptor).first?.syncStatus
    }

    private static func syncStatus(forWaterEntryId entityId: String, in context: ModelContext) -> AccountDataSyncStatus? {
        guard let uuid = UUID(uuidString: entityId) else { return nil }
        var descriptor = FetchDescriptor<WaterEntryEntity>(
            predicate: #Predicate { $0.id == uuid }
        )
        descriptor.fetchLimit = 1
        return try? context.fetch(descriptor).first?.syncStatus
    }

    private static func syncStatus(forWeightEntryId entityId: String, in context: ModelContext) -> AccountDataSyncStatus? {
        guard let uuid = UUID(uuidString: entityId) else { return nil }
        var descriptor = FetchDescriptor<WeightEntryEntity>(
            predicate: #Predicate { $0.id == uuid }
        )
        descriptor.fetchLimit = 1
        return try? context.fetch(descriptor).first?.syncStatus
    }

    private static func syncStatus(forDailyLogId entityId: String, in context: ModelContext) -> AccountDataSyncStatus? {
        if let uuid = UUID(uuidString: entityId) {
            var descriptor = FetchDescriptor<DailyLogEntity>(
                predicate: #Predicate { $0.id == uuid }
            )
            descriptor.fetchLimit = 1
            if let status = try? context.fetch(descriptor).first?.syncStatus {
                return status
            }
        }

        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(secondsFromGMT: 0)!
        guard let date = CloudAccountDataDateCodec.date(
            fromLocalDateString: entityId,
            calendar: calendar
        ) else {
            return nil
        }
        let start = calendar.startOfDay(for: date)
        guard let end = calendar.date(byAdding: .day, value: 1, to: start) else {
            return nil
        }
        var descriptor = FetchDescriptor<DailyLogEntity>(
            predicate: #Predicate { log in
                log.date >= start && log.date < end
            }
        )
        descriptor.fetchLimit = 1
        return try? context.fetch(descriptor).first?.syncStatus
    }

    private static func syncStatus(forDailyReviewId entityId: String, in context: ModelContext) -> AccountDataSyncStatus? {
        if let uuid = UUID(uuidString: entityId) {
            var descriptor = FetchDescriptor<DailyReviewEntity>(
                predicate: #Predicate { $0.id == uuid }
            )
            descriptor.fetchLimit = 1
            if let status = try? context.fetch(descriptor).first?.syncStatus {
                return status
            }
        }

        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(secondsFromGMT: 0)!
        guard let date = CloudAccountDataDateCodec.date(
            fromLocalDateString: entityId,
            calendar: calendar
        ) else {
            return nil
        }
        let start = calendar.startOfDay(for: date)
        guard let end = calendar.date(byAdding: .day, value: 1, to: start) else {
            return nil
        }
        var logDescriptor = FetchDescriptor<DailyLogEntity>(
            predicate: #Predicate { log in
                log.date >= start && log.date < end
            }
        )
        logDescriptor.fetchLimit = 1
        guard let dailyLog = try? context.fetch(logDescriptor).first else {
            return nil
        }
        return dailyLog.dailyReview?.syncStatus
    }
}
