//
//  AccountSyncUploader.swift
//  Fitness Coach
//
//  Forma — Drains the sync outbox through AccountDataRemoteStore (Phase 3).
//

import Foundation
import SwiftData

struct AccountSyncUploadSummary: Equatable, Sendable {
    let uid: String
    let attempted: Int
    let succeeded: Int
    let failed: Int
    let cancelled: Int
}

protocol AccountSyncUploading: AnyObject {
    func uploadDueMutations(for uid: String, limit: Int) async -> AccountSyncUploadSummary
}

enum AccountSyncUploaderError: Error, Equatable, Sendable {
    case ownerMismatch(expected: String, actual: String)
    case missingUploadDocument(entityType: AccountSyncEntityType)
    case missingDeleteLocalDate(entityType: AccountSyncEntityType)
    case deferredDailyLogDelete
}

/// Post-upload local entity metadata updates.
enum AccountSyncPostUploadStamping {

    static func markSynced(
        on entity: AccountDataSyncMetadataEntity,
        cloudId: String,
        now: Date = Date()
    ) {
        entity.syncStatusRawValue = AccountDataSyncStatus.synced.rawValue
        entity.lastSyncedAt = now
        entity.cloudUpdatedAt = now
        entity.cloudId = cloudId
        entity.lastSyncError = nil
        entity.syncAttemptCount = 0
        entity.nextRetryAt = nil
    }

    static func markFailed(on entity: AccountDataSyncMetadataEntity, error: Error, now: Date = Date()) {
        entity.syncStatusRawValue = AccountDataSyncStatus.failed.rawValue
        entity.lastSyncError = AccountDataSyncMetadataSupport.sanitizedSyncError(from: error)
        entity.syncAttemptCount += 1
        entity.nextRetryAt = AccountSyncRetryPolicy.nextRetryDate(
            afterFailureWithAttemptCount: entity.syncAttemptCount,
            from: now
        )
    }
}

/// After a successful remote delete, tombstoned entry rows are hard-deleted locally.
/// Daily log deletes are not performed in Phase 3.
enum AccountSyncDeleteRetentionPolicy {
    static let hardDeleteLocalRowAfterSuccessfulRemoteDelete = true
}

@MainActor
final class AccountSyncUploader: AccountSyncUploading {

    private let outbox: AccountSyncOutboxStore
    private let payloadBuilder: AccountSyncPayloadBuilding
    private let remoteStore: any AccountDataRemoteStore
    private let store: SwiftDataStore
    private let calendar: Calendar
    private let nowProvider: () -> Date

    init(
        outbox: AccountSyncOutboxStore,
        payloadBuilder: AccountSyncPayloadBuilding,
        remoteStore: any AccountDataRemoteStore,
        store: SwiftDataStore,
        calendar: Calendar = AccountSyncUploader.defaultCalendar,
        nowProvider: @escaping () -> Date = Date.init
    ) {
        self.outbox = outbox
        self.payloadBuilder = payloadBuilder
        self.remoteStore = remoteStore
        self.store = store
        self.calendar = calendar
        self.nowProvider = nowProvider
    }

    func uploadDueMutations(for uid: String, limit: Int) async -> AccountSyncUploadSummary {
        let normalizedUID: String
        do {
            normalizedUID = try AccountSyncMutationValidation.normalizedOwnerUID(uid)
        } catch {
            return AccountSyncUploadSummary(
                uid: uid.trimmingCharacters(in: .whitespacesAndNewlines),
                attempted: 0,
                succeeded: 0,
                failed: 0,
                cancelled: 0
            )
        }

        let now = nowProvider()
        let due: [AccountSyncMutation]
        do {
            due = try await outbox.fetchDueMutations(ownerUID: normalizedUID, limit: limit, now: now)
        } catch {
            return AccountSyncUploadSummary(
                uid: normalizedUID,
                attempted: 0,
                succeeded: 0,
                failed: 0,
                cancelled: 0
            )
        }

        var succeeded = 0
        var failed = 0
        var cancelled = 0
        let batchId = String(UUID().uuidString.prefix(8))

        for mutation in due {
            guard mutation.ownerUID == normalizedUID else {
                continue
            }

            do {
                try await outbox.markInFlight([mutation.id], ownerUID: normalizedUID)
                let outcome = try await processMutation(mutation, uid: normalizedUID, now: now)
                switch outcome {
                case .succeeded:
                    succeeded += 1
                    AccountSyncLogger.mutationProcessed(
                        batchId: batchId,
                        entityType: mutation.entityType,
                        operation: mutation.operation,
                        outcome: "succeeded"
                    )
                case .cancelled:
                    cancelled += 1
                    AccountSyncLogger.mutationProcessed(
                        batchId: batchId,
                        entityType: mutation.entityType,
                        operation: mutation.operation,
                        outcome: "cancelled"
                    )
                }
            } catch {
                failed += 1
                AccountSyncLogger.mutationFailed(
                    batchId: batchId,
                    entityType: mutation.entityType,
                    operation: mutation.operation,
                    error: error
                )
                try? applyEntityFailure(for: mutation, error: error)
                try? await outbox.markFailed(
                    mutation.id,
                    ownerUID: normalizedUID,
                    error: error,
                    now: now
                )
            }
        }

        return AccountSyncUploadSummary(
            uid: normalizedUID,
            attempted: due.count,
            succeeded: succeeded,
            failed: failed,
            cancelled: cancelled
        )
    }

    // MARK: - Mutation processing

    private enum MutationOutcome {
        case succeeded
        case cancelled
    }

    private func processMutation(
        _ mutation: AccountSyncMutation,
        uid: String,
        now: Date
    ) async throws -> MutationOutcome {
        guard mutation.ownerUID == uid else {
            throw AccountSyncUploaderError.ownerMismatch(expected: uid, actual: mutation.ownerUID)
        }

        if mutation.entityType == .dailyLog && mutation.operation == .delete {
            try await outbox.cancel(mutation.id, ownerUID: uid)
            return .cancelled
        }

        let payload: AccountSyncPayload
        do {
            payload = try await payloadBuilder.buildPayload(for: mutation)
        } catch let error as AccountSyncPayloadBuilderError {
            if case .missingLocalEntity = error, mutation.operation == .upsert {
                try await outbox.cancel(mutation.id, ownerUID: uid)
                return .cancelled
            }
            throw error
        }

        guard payload.mutation.ownerUID == uid else {
            throw AccountSyncUploaderError.ownerMismatch(
                expected: uid,
                actual: payload.mutation.ownerUID
            )
        }

        if mutation.operation == .delete, mutation.entityType != .dailyLog {
            _ = try fetchSyncMetadataEntity(for: mutation, ownerUID: uid)
        }

        try await upload(payload, uid: uid)
        try applyUploadSuccess(payload: payload, uid: uid, now: now)
        try await outbox.markSucceeded(mutation.id, ownerUID: uid)
        return .succeeded
    }

    private func upload(_ payload: AccountSyncPayload, uid: String) async throws {
        switch (payload.entityType, payload.operation) {
        case (.dailyLog, .upsert):
            guard let document = payload.dailyLog else {
                throw AccountSyncUploaderError.missingUploadDocument(entityType: .dailyLog)
            }
            try AccountDataRemoteStoreSupport.validateWrite(document, uid: uid)
            try await remoteStore.saveDailyLog(document, uid: uid)

        case (.foodEntry, .upsert):
            guard let document = payload.foodEntry else {
                throw AccountSyncUploaderError.missingUploadDocument(entityType: .foodEntry)
            }
            try AccountDataRemoteStoreSupport.validateWrite(document, uid: uid)
            try await remoteStore.saveFoodEntry(document, uid: uid)

        case (.waterEntry, .upsert):
            guard let document = payload.waterEntry else {
                throw AccountSyncUploaderError.missingUploadDocument(entityType: .waterEntry)
            }
            try AccountDataRemoteStoreSupport.validateWrite(document, uid: uid)
            try await remoteStore.saveWaterEntry(document, uid: uid)

        case (.weightEntry, .upsert):
            guard let document = payload.weightEntry else {
                throw AccountSyncUploaderError.missingUploadDocument(entityType: .weightEntry)
            }
            try AccountDataRemoteStoreSupport.validateWrite(document, uid: uid)
            try await remoteStore.saveWeightEntry(document, uid: uid)

        case (.dailyReview, .upsert):
            guard let document = payload.dailyReview else {
                throw AccountSyncUploaderError.missingUploadDocument(entityType: .dailyReview)
            }
            try AccountDataRemoteStoreSupport.validateWrite(document, uid: uid)
            try await remoteStore.saveDailyReview(document, uid: uid)

        case (.foodEntry, .delete):
            let localDate = try requiredDeleteLocalDate(payload)
            try await remoteStore.deleteFoodEntry(
                uid: uid,
                localDate: localDate,
                entryId: payload.mutation.entityId
            )

        case (.waterEntry, .delete):
            let localDate = try requiredDeleteLocalDate(payload)
            try await remoteStore.deleteWaterEntry(
                uid: uid,
                localDate: localDate,
                entryId: payload.mutation.entityId
            )

        case (.weightEntry, .delete):
            try await remoteStore.deleteWeightEntry(
                uid: uid,
                entryId: payload.mutation.entityId
            )

        case (.dailyReview, .delete):
            let localDate = try requiredDeleteLocalDate(payload)
            try await remoteStore.deleteDailyReview(uid: uid, localDate: localDate)

        case (.dailyLog, .delete):
            throw AccountSyncUploaderError.deferredDailyLogDelete
        }
    }

    private func applyUploadSuccess(payload: AccountSyncPayload, uid: String, now: Date) throws {
        switch payload.operation {
        case .upsert:
            let cloudId = try cloudId(for: payload)
            if let entity = try fetchSyncMetadataEntity(for: payload.mutation, ownerUID: uid) {
                AccountSyncPostUploadStamping.markSynced(on: entity, cloudId: cloudId, now: now)
                try store.save()
            }
        case .delete:
            if AccountSyncDeleteRetentionPolicy.hardDeleteLocalRowAfterSuccessfulRemoteDelete {
                if let entity = try fetchPersistentEntityForDelete(for: payload.mutation, ownerUID: uid) {
                    store.modelContext.delete(entity)
                    try store.save()
                }
            }
        }
    }

    private func applyEntityFailure(for mutation: AccountSyncMutation, error: Error) throws {
        guard let entity = try fetchSyncMetadataEntity(for: mutation, ownerUID: mutation.ownerUID) else {
            return
        }
        AccountSyncPostUploadStamping.markFailed(on: entity, error: error, now: nowProvider())
        try store.save()
    }

    // MARK: - Identity helpers

    private func cloudId(for payload: AccountSyncPayload) throws -> String {
        switch payload.entityType {
        case .dailyLog:
            return try requiredNonEmpty(payload.dailyLog?.id ?? payload.mutation.localDate ?? payload.mutation.entityId)
        case .foodEntry:
            return try requiredNonEmpty(payload.foodEntry?.id ?? payload.mutation.entityId)
        case .waterEntry:
            return try requiredNonEmpty(payload.waterEntry?.id ?? payload.mutation.entityId)
        case .weightEntry:
            return try requiredNonEmpty(payload.weightEntry?.id ?? payload.mutation.entityId)
        case .dailyReview:
            return try requiredNonEmpty(
                payload.dailyReview?.localDate ?? payload.mutation.localDate ?? payload.mutation.entityId
            )
        }
    }

    private func requiredNonEmpty(_ value: String?) throws -> String {
        guard let value, !value.isEmpty else {
            throw AccountSyncUploaderError.missingUploadDocument(entityType: .dailyLog)
        }
        return value
    }

    private func requiredDeleteLocalDate(_ payload: AccountSyncPayload) throws -> String {
        if let localDate = payload.mutation.localDate,
           let normalized = try? AccountSyncMutationValidation.normalizedLocalDate(localDate) {
            return normalized
        }
        if payload.entityType == .dailyReview || payload.entityType == .dailyLog {
            let trimmed = payload.mutation.entityId.trimmingCharacters(in: .whitespacesAndNewlines)
            if (try? AccountSyncMutationValidation.normalizedLocalDate(trimmed)) != nil {
                return trimmed
            }
        }
        throw AccountSyncUploaderError.missingDeleteLocalDate(entityType: payload.entityType)
    }

    // MARK: - Entity fetch

    private func fetchSyncMetadataEntity(
        for mutation: AccountSyncMutation,
        ownerUID: String
    ) throws -> AccountDataSyncMetadataEntity? {
        switch mutation.entityType {
        case .dailyLog:
            guard let entity = try fetchDailyLogEntity(for: mutation) else { return nil }
            try validateEntityOwner(entity, ownerUID: ownerUID, entityName: "DailyLogEntity", id: mutation.entityId)
            return entity
        case .foodEntry:
            guard let entity = try fetchFoodEntryEntity(id: mutation.entityId) else { return nil }
            try validateEntityOwner(entity, ownerUID: ownerUID, entityName: "FoodEntryEntity", id: mutation.entityId)
            return entity
        case .waterEntry:
            guard let entity = try fetchWaterEntryEntity(id: mutation.entityId) else { return nil }
            try validateEntityOwner(entity, ownerUID: ownerUID, entityName: "WaterEntryEntity", id: mutation.entityId)
            return entity
        case .weightEntry:
            guard let entity = try fetchWeightEntryEntity(id: mutation.entityId) else { return nil }
            try validateEntityOwner(entity, ownerUID: ownerUID, entityName: "WeightEntryEntity", id: mutation.entityId)
            return entity
        case .dailyReview:
            guard let (review, _) = try fetchDailyReviewEntities(for: mutation) else { return nil }
            try validateEntityOwner(
                review,
                ownerUID: ownerUID,
                entityName: "DailyReviewEntity",
                id: review.id.uuidString
            )
            return review
        }
    }

    private func fetchPersistentEntityForDelete(
        for mutation: AccountSyncMutation,
        ownerUID: String
    ) throws -> (any PersistentModel)? {
        switch mutation.entityType {
        case .foodEntry:
            return try fetchFoodEntryEntity(id: mutation.entityId)
        case .waterEntry:
            return try fetchWaterEntryEntity(id: mutation.entityId)
        case .weightEntry:
            return try fetchWeightEntryEntity(id: mutation.entityId)
        case .dailyReview:
            return try fetchDailyReviewEntities(for: mutation)?.0
        case .dailyLog:
            return nil
        }
    }

    private func fetchDailyLogEntity(for mutation: AccountSyncMutation) throws -> DailyLogEntity? {
        let localDate = mutation.localDate ?? mutation.entityId
        guard let date = CloudAccountDataDateCodec.date(fromLocalDateString: localDate, calendar: calendar) else {
            return nil
        }
        let start = calendar.startOfDay(for: date)
        guard let end = calendar.date(byAdding: .day, value: 1, to: start) else { return nil }
        var descriptor = FetchDescriptor<DailyLogEntity>(
            predicate: #Predicate { log in log.date >= start && log.date < end }
        )
        descriptor.fetchLimit = 1
        return try store.fetchOne(descriptor)
    }

    private func fetchFoodEntryEntity(id: String) throws -> FoodEntryEntity? {
        guard let uuid = UUID(uuidString: id) else { return nil }
        var descriptor = FetchDescriptor<FoodEntryEntity>(predicate: #Predicate { $0.id == uuid })
        descriptor.fetchLimit = 1
        return try store.fetchOne(descriptor)
    }

    private func fetchWaterEntryEntity(id: String) throws -> WaterEntryEntity? {
        guard let uuid = UUID(uuidString: id) else { return nil }
        var descriptor = FetchDescriptor<WaterEntryEntity>(predicate: #Predicate { $0.id == uuid })
        descriptor.fetchLimit = 1
        return try store.fetchOne(descriptor)
    }

    private func fetchWeightEntryEntity(id: String) throws -> WeightEntryEntity? {
        guard let uuid = UUID(uuidString: id) else { return nil }
        var descriptor = FetchDescriptor<WeightEntryEntity>(predicate: #Predicate { $0.id == uuid })
        descriptor.fetchLimit = 1
        return try store.fetchOne(descriptor)
    }

    private func fetchDailyReviewEntities(
        for mutation: AccountSyncMutation
    ) throws -> (DailyReviewEntity, DailyLogEntity)? {
        guard let log = try fetchDailyLogEntity(for: mutation),
              let review = log.dailyReview else {
            return nil
        }
        return (review, log)
    }

    private func validateEntityOwner(
        _ entity: any CloudAccountDataOwnerEntity,
        ownerUID: String,
        entityName: String,
        id: String
    ) throws {
        try CloudAccountDataMappers.validateEntityOwnership(
            entity,
            entityName: entityName,
            id: id,
            userId: ownerUID
        )
    }

    private static var defaultCalendar: Calendar {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(secondsFromGMT: 0)!
        return calendar
    }
}
