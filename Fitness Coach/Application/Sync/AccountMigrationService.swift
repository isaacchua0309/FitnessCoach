//
//  AccountMigrationService.swift
//  Fitness Coach
//
//  Forma — Backfills local user-data ownership after schema upgrades (Phase 1).
//

import Foundation
import SwiftData

@MainActor
private protocol UserDataBookkeepingPersistable: AnyObject {
    var localUpdatedAt: Date? { get set }
    var entitySchemaVersion: Int { get set }
}

extension UserProfileEntity: UserDataBookkeepingPersistable {}
extension DailyLogEntity: UserDataBookkeepingPersistable {}
extension FoodEntryEntity: UserDataBookkeepingPersistable {}
extension WaterEntryEntity: UserDataBookkeepingPersistable {}
extension WeightEntryEntity: UserDataBookkeepingPersistable {}
extension DailyReviewEntity: UserDataBookkeepingPersistable {}
extension CoachTimelineEventEntity: UserDataBookkeepingPersistable {}
extension CoachChatTranscriptMessageEntity: UserDataBookkeepingPersistable {}

@MainActor
final class AccountMigrationService {

    private let store: SwiftDataStore
    private let userProfileService: UserProfileService

    init(store: SwiftDataStore, userProfileService: UserProfileService) {
        self.store = store
        self.userProfileService = userProfileService
    }

    /// Backfills `localUpdatedAt` and `entitySchemaVersion` for rows upgraded to schema V7.
    ///
    /// Safe to call repeatedly; only fills missing bookkeeping metadata.
    func backfillSchemaV7BookkeepingIfNeeded() throws {
        var didChange = false

        for entity in try store.fetch(FetchDescriptor<UserProfileEntity>()) {
            didChange = backfillBookkeeping(on: entity, updatedAt: entity.updatedAt) || didChange
        }
        for entity in try store.fetch(FetchDescriptor<DailyLogEntity>()) {
            didChange = backfillBookkeeping(on: entity, updatedAt: entity.updatedAt) || didChange
        }
        for entity in try store.fetch(FetchDescriptor<FoodEntryEntity>()) {
            didChange = backfillBookkeeping(on: entity, updatedAt: entity.updatedAt) || didChange
        }
        for entity in try store.fetch(FetchDescriptor<WaterEntryEntity>()) {
            didChange = backfillBookkeeping(on: entity, updatedAt: entity.createdAt) || didChange
        }
        for entity in try store.fetch(FetchDescriptor<WeightEntryEntity>()) {
            didChange = backfillBookkeeping(on: entity, updatedAt: entity.createdAt) || didChange
        }
        for entity in try store.fetch(FetchDescriptor<DailyReviewEntity>()) {
            didChange = backfillBookkeeping(on: entity, updatedAt: entity.createdAt) || didChange
        }
        for entity in try store.fetch(FetchDescriptor<CoachTimelineEventEntity>()) {
            didChange = backfillBookkeeping(on: entity, updatedAt: entity.updatedAt) || didChange
        }
        for entity in try store.fetch(FetchDescriptor<CoachChatTranscriptMessageEntity>()) {
            didChange = backfillBookkeeping(on: entity, updatedAt: entity.updatedAt) || didChange
        }

        if didChange {
            try store.save()
        }
    }

    /// Assigns unowned nutrition and coach rows to the signed-in profile owner.
    ///
    /// Safe to call repeatedly; only touches rows with missing ownership metadata.
    func backfillUnownedRows(sessionUID: String) throws {
        guard let profile = try userProfileService.getCurrentProfile(),
              profile.ownerUID == sessionUID else {
            return
        }

        var didChange = false

        for entity in try store.fetch(FetchDescriptor<DailyLogEntity>()) where entity.ownerUID == nil {
            entity.ownerUID = sessionUID
            didChange = true
        }
        for entity in try store.fetch(FetchDescriptor<FoodEntryEntity>()) where entity.ownerUID == nil {
            entity.ownerUID = sessionUID
            didChange = true
        }
        for entity in try store.fetch(FetchDescriptor<WaterEntryEntity>()) where entity.ownerUID == nil {
            entity.ownerUID = sessionUID
            didChange = true
        }
        for entity in try store.fetch(FetchDescriptor<WeightEntryEntity>()) where entity.ownerUID == nil {
            entity.ownerUID = sessionUID
            didChange = true
        }
        for entity in try store.fetch(FetchDescriptor<DailyReviewEntity>()) where entity.ownerUID == nil {
            entity.ownerUID = sessionUID
            didChange = true
        }
        for entity in try store.fetch(FetchDescriptor<CoachTimelineEventEntity>()) where entity.userId == nil {
            entity.userId = sessionUID
            didChange = true
        }
        for entity in try store.fetch(FetchDescriptor<CoachChatTranscriptMessageEntity>()) where entity.userId == nil {
            entity.userId = sessionUID
            didChange = true
        }

        if didChange {
            try store.save()
        }
    }

    private func backfillBookkeeping<T: UserDataBookkeepingPersistable>(
        on entity: T,
        updatedAt: Date
    ) -> Bool {
        var didChange = false
        if entity.localUpdatedAt == nil {
            entity.localUpdatedAt = updatedAt
            didChange = true
        }
        if entity.entitySchemaVersion < UserDataEntitySchema.currentEntitySchemaVersion {
            entity.entitySchemaVersion = UserDataEntitySchema.currentEntitySchemaVersion
            didChange = true
        }
        return didChange
    }
}
