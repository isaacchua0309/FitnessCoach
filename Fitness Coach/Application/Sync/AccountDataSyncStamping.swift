//
//  AccountDataSyncStamping.swift
//  Fitness Coach
//
//  Forma — Local sync metadata stamping for account-backed entities (Phase 3).
//

import Foundation

protocol AccountDataSyncOwnable: AnyObject {
    var ownerUID: String? { get set }
}

enum AccountDataSyncDeletionPolicy {

    static func shouldTombstone(_ entity: AccountDataSyncMetadataEntity) -> Bool {
        if entity.deletedAt != nil {
            return true
        }
        if let cloudId = entity.cloudId, !cloudId.isEmpty {
            return true
        }
        if entity.lastSyncedAt != nil {
            return true
        }
        return AccountSyncRemotePresenceResolver.statusIndicatesRemotePresence(entity.syncStatus)
    }
}

enum AccountDataSyncStamping {

    @discardableResult
    static func stampPendingUpload(
        on entity: AccountDataSyncMetadataEntity,
        ownerUID: String,
        now: Date = Date()
    ) -> String {
        let mutationId = UUID().uuidString
        if let ownable = entity as? AccountDataSyncOwnable {
            ownable.ownerUID = ownerUID
        }
        entity.syncStatusRawValue = AccountDataSyncStatus.pendingUpload.rawValue
        entity.localUpdatedAt = now
        entity.lastMutationId = mutationId
        entity.lastSyncError = nil
        entity.deletedAt = nil
        return mutationId
    }

    @discardableResult
    static func stampPendingDelete(
        on entity: AccountDataSyncMetadataEntity,
        ownerUID: String,
        now: Date = Date()
    ) -> String {
        let mutationId = UUID().uuidString
        if let ownable = entity as? AccountDataSyncOwnable {
            ownable.ownerUID = ownerUID
        }
        entity.deletedAt = now
        entity.syncStatusRawValue = AccountDataSyncStatus.pendingDelete.rawValue
        entity.localUpdatedAt = now
        entity.lastMutationId = mutationId
        entity.lastSyncError = nil
        return mutationId
    }
}

enum AccountDataSyncReadFilter {

    static func isVisible(_ entity: AccountDataSyncMetadataEntity) -> Bool {
        entity.deletedAt == nil
    }
}

extension DailyLogEntity: AccountDataSyncOwnable {}
extension FoodEntryEntity: AccountDataSyncOwnable {}
extension WaterEntryEntity: AccountDataSyncOwnable {}
extension WeightEntryEntity: AccountDataSyncOwnable {}
extension DailyReviewEntity: AccountDataSyncOwnable {}
