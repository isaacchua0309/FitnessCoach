//
//  AccountSyncPayloadBuilder.swift
//  Fitness Coach
//
//  Forma — Reconstructs cloud upload payloads from local SwiftData (Phase 3).
//
//  Uses Phase 2 DTO mappers only. No raw images or HealthKit data.
//

import Foundation
import SwiftData

struct AccountSyncPayload: Equatable, Sendable {
    let mutation: AccountSyncMutation
    let entityType: AccountSyncEntityType
    let operation: AccountSyncOperation
    let dailyLog: CloudDailyLogDocument?
    let foodEntry: CloudFoodEntryDocument?
    let waterEntry: CloudWaterEntryDocument?
    let weightEntry: CloudWeightEntryDocument?
    let dailyReview: CloudDailyReviewDocument?
}

protocol AccountSyncPayloadBuilding: AnyObject {
    func buildPayload(for mutation: AccountSyncMutation) async throws -> AccountSyncPayload
}

enum AccountSyncPayloadBuilderError: Error, Equatable, Sendable {
    case missingOwnerUID
    case missingLocalEntity(entityType: AccountSyncEntityType, entityId: String)
    case missingLocalDate(entityType: AccountSyncEntityType, entityId: String)
    case invalidEntityId(entityType: AccountSyncEntityType, entityId: String)
}

extension AccountSyncPayloadBuilderError: LocalizedError {

    var errorDescription: String? {
        switch self {
        case .missingOwnerUID:
            return "Sync payload requires a non-empty owner UID."
        case .missingLocalEntity(let entityType, let entityId):
            return "Local \(entityType.rawValue) \(entityId) was not found for payload build."
        case .missingLocalDate(let entityType, let entityId):
            return "Sync payload for \(entityType.rawValue) \(entityId) requires a local date."
        case .invalidEntityId(let entityType, let entityId):
            return "Sync payload entity id is invalid for \(entityType.rawValue): \(entityId)."
        }
    }
}

@MainActor
final class SwiftDataAccountSyncPayloadBuilder: AccountSyncPayloadBuilding {

    private let store: SwiftDataStore
    private let calendar: Calendar

    init(
        store: SwiftDataStore,
        calendar: Calendar = SwiftDataAccountSyncPayloadBuilder.defaultCalendar
    ) {
        self.store = store
        self.calendar = calendar
    }

    func buildPayload(for mutation: AccountSyncMutation) async throws -> AccountSyncPayload {
        let ownerUID = try AccountSyncMutationValidation.normalizedOwnerUID(mutation.ownerUID)

        switch mutation.operation {
        case .delete:
            return AccountSyncPayload(
                mutation: mutation,
                entityType: mutation.entityType,
                operation: .delete,
                dailyLog: nil,
                foodEntry: nil,
                waterEntry: nil,
                weightEntry: nil,
                dailyReview: nil
            )
        case .upsert:
            return try buildUpsertPayload(for: mutation, ownerUID: ownerUID)
        }
    }

    // MARK: - Upsert

    private func buildUpsertPayload(
        for mutation: AccountSyncMutation,
        ownerUID: String
    ) throws -> AccountSyncPayload {
        let context = mappingContext(ownerUID: ownerUID, mutation: mutation)

        switch mutation.entityType {
        case .dailyLog:
            let localDate = try resolvedLocalDate(for: mutation)
            let entity = try requiredDailyLogEntity(localDate: localDate, ownerUID: ownerUID)
            let document = try CloudAccountDataMappers.cloudDocument(from: entity, context: context)
            return emptyPayload(mutation: mutation, dailyLog: document)

        case .foodEntry:
            let entity = try requiredFoodEntryEntity(id: mutation.entityId, ownerUID: ownerUID)
            let logDate = try resolvedLogDate(for: mutation, entity: entity)
            let document = try CloudAccountDataMappers.cloudDocument(
                from: entity,
                logDate: logDate,
                context: context
            )
            return emptyPayload(mutation: mutation, foodEntry: document)

        case .waterEntry:
            let entity = try requiredWaterEntryEntity(id: mutation.entityId, ownerUID: ownerUID)
            let logDate = try resolvedLogDate(for: mutation, entity: entity)
            let document = try CloudAccountDataMappers.cloudDocument(
                from: entity,
                logDate: logDate,
                context: context
            )
            return emptyPayload(mutation: mutation, waterEntry: document)

        case .weightEntry:
            let entity = try requiredWeightEntryEntity(id: mutation.entityId, ownerUID: ownerUID)
            let document = try CloudAccountDataMappers.cloudDocument(from: entity, context: context)
            return emptyPayload(mutation: mutation, weightEntry: document)

        case .dailyReview:
            let localDate = try resolvedLocalDate(for: mutation)
            let (review, log) = try requiredDailyReviewEntities(
                localDate: localDate,
                ownerUID: ownerUID
            )
            let document = try CloudAccountDataMappers.cloudDocument(
                from: review,
                logDate: log.date,
                context: context
            )
            return emptyPayload(mutation: mutation, dailyReview: document)
        }
    }

    // MARK: - Entity loading

    private func requiredDailyLogEntity(
        localDate: String,
        ownerUID: String
    ) throws -> DailyLogEntity {
        guard let entity = try fetchDailyLogEntity(localDate: localDate) else {
            throw AccountSyncPayloadBuilderError.missingLocalEntity(
                entityType: .dailyLog,
                entityId: localDate
            )
        }
        try validateStoredOwner(entity, expected: ownerUID, entityName: "DailyLogEntity", id: localDate)
        return entity
    }

    private func requiredFoodEntryEntity(id: String, ownerUID: String) throws -> FoodEntryEntity {
        guard let uuid = UUID(uuidString: id) else {
            throw AccountSyncPayloadBuilderError.invalidEntityId(entityType: .foodEntry, entityId: id)
        }
        var descriptor = FetchDescriptor<FoodEntryEntity>(
            predicate: #Predicate { $0.id == uuid }
        )
        descriptor.fetchLimit = 1
        guard let entity = try store.fetchOne(descriptor) else {
            throw AccountSyncPayloadBuilderError.missingLocalEntity(entityType: .foodEntry, entityId: id)
        }
        try validateStoredOwner(entity, expected: ownerUID, entityName: "FoodEntryEntity", id: id)
        return entity
    }

    private func requiredWaterEntryEntity(id: String, ownerUID: String) throws -> WaterEntryEntity {
        guard let uuid = UUID(uuidString: id) else {
            throw AccountSyncPayloadBuilderError.invalidEntityId(entityType: .waterEntry, entityId: id)
        }
        var descriptor = FetchDescriptor<WaterEntryEntity>(
            predicate: #Predicate { $0.id == uuid }
        )
        descriptor.fetchLimit = 1
        guard let entity = try store.fetchOne(descriptor) else {
            throw AccountSyncPayloadBuilderError.missingLocalEntity(entityType: .waterEntry, entityId: id)
        }
        try validateStoredOwner(entity, expected: ownerUID, entityName: "WaterEntryEntity", id: id)
        return entity
    }

    private func requiredWeightEntryEntity(id: String, ownerUID: String) throws -> WeightEntryEntity {
        guard let uuid = UUID(uuidString: id) else {
            throw AccountSyncPayloadBuilderError.invalidEntityId(entityType: .weightEntry, entityId: id)
        }
        var descriptor = FetchDescriptor<WeightEntryEntity>(
            predicate: #Predicate { $0.id == uuid }
        )
        descriptor.fetchLimit = 1
        guard let entity = try store.fetchOne(descriptor) else {
            throw AccountSyncPayloadBuilderError.missingLocalEntity(entityType: .weightEntry, entityId: id)
        }
        try validateStoredOwner(entity, expected: ownerUID, entityName: "WeightEntryEntity", id: id)
        return entity
    }

    private func requiredDailyReviewEntities(
        localDate: String,
        ownerUID: String
    ) throws -> (DailyReviewEntity, DailyLogEntity) {
        guard let log = try fetchDailyLogEntity(localDate: localDate) else {
            throw AccountSyncPayloadBuilderError.missingLocalEntity(
                entityType: .dailyReview,
                entityId: localDate
            )
        }
        try validateStoredOwner(log, expected: ownerUID, entityName: "DailyLogEntity", id: localDate)
        guard let review = log.dailyReview else {
            throw AccountSyncPayloadBuilderError.missingLocalEntity(
                entityType: .dailyReview,
                entityId: localDate
            )
        }
        try validateStoredOwner(
            review,
            expected: ownerUID,
            entityName: "DailyReviewEntity",
            id: review.id.uuidString
        )
        return (review, log)
    }

    private func fetchDailyLogEntity(localDate: String) throws -> DailyLogEntity? {
        guard let date = CloudAccountDataDateCodec.date(fromLocalDateString: localDate, calendar: calendar) else {
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
        return try store.fetchOne(descriptor)
    }

    // MARK: - Validation

    private func validateStoredOwner(
        _ entity: any CloudAccountDataOwnerEntity,
        expected ownerUID: String,
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

    private func resolvedLocalDate(for mutation: AccountSyncMutation) throws -> String {
        if let localDate = try AccountSyncMutationValidation.normalizedLocalDate(mutation.localDate) {
            return localDate
        }
        if mutation.entityType == .dailyLog || mutation.entityType == .dailyReview {
            let trimmed = mutation.entityId.trimmingCharacters(in: .whitespacesAndNewlines)
            if CloudAccountDataDateCodec.date(fromLocalDateString: trimmed, calendar: calendar) != nil {
                return trimmed
            }
        }
        throw AccountSyncPayloadBuilderError.missingLocalDate(
            entityType: mutation.entityType,
            entityId: mutation.entityId
        )
    }

    private func resolvedLogDate(
        for mutation: AccountSyncMutation,
        entity: FoodEntryEntity
    ) throws -> Date {
        if let localDate = try AccountSyncMutationValidation.normalizedLocalDate(mutation.localDate),
           let date = CloudAccountDataDateCodec.date(fromLocalDateString: localDate, calendar: calendar) {
            return calendar.startOfDay(for: date)
        }
        if let logDate = entity.dailyLog?.date {
            return calendar.startOfDay(for: logDate)
        }
        throw AccountSyncPayloadBuilderError.missingLocalDate(
            entityType: mutation.entityType,
            entityId: mutation.entityId
        )
    }

    private func resolvedLogDate(
        for mutation: AccountSyncMutation,
        entity: WaterEntryEntity
    ) throws -> Date {
        if let localDate = try AccountSyncMutationValidation.normalizedLocalDate(mutation.localDate),
           let date = CloudAccountDataDateCodec.date(fromLocalDateString: localDate, calendar: calendar) {
            return calendar.startOfDay(for: date)
        }
        if let logDate = entity.dailyLog?.date {
            return calendar.startOfDay(for: logDate)
        }
        throw AccountSyncPayloadBuilderError.missingLocalDate(
            entityType: mutation.entityType,
            entityId: mutation.entityId
        )
    }

    private func mappingContext(
        ownerUID: String,
        mutation: AccountSyncMutation
    ) -> CloudAccountDataMappingContext {
        CloudAccountDataMappingContext(
            userId: ownerUID,
            calendar: calendar,
            timeZoneIdentifier: calendar.timeZone.identifier,
            now: Date(),
            mutationId: mutation.id
        )
    }

    private func emptyPayload(
        mutation: AccountSyncMutation,
        dailyLog: CloudDailyLogDocument? = nil,
        foodEntry: CloudFoodEntryDocument? = nil,
        waterEntry: CloudWaterEntryDocument? = nil,
        weightEntry: CloudWeightEntryDocument? = nil,
        dailyReview: CloudDailyReviewDocument? = nil
    ) -> AccountSyncPayload {
        AccountSyncPayload(
            mutation: mutation,
            entityType: mutation.entityType,
            operation: mutation.operation,
            dailyLog: dailyLog,
            foodEntry: foodEntry,
            waterEntry: waterEntry,
            weightEntry: weightEntry,
            dailyReview: dailyReview
        )
    }

    nonisolated private static var defaultCalendar: Calendar {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(secondsFromGMT: 0)!
        return calendar
    }
}

extension AccountSyncPayload {

    /// Identity fields sufficient for remote delete APIs when no DTO is present.
    var deleteIdentity: (ownerUID: String, localDate: String?, entityId: String) {
        (mutation.ownerUID, mutation.localDate ?? mutation.entityId, mutation.entityId)
    }
}
