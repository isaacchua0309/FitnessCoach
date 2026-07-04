//
//  AccountMigrationService.swift
//  Fitness Coach
//
//  Forma — Safe ownerUID backfill before account restore (Phase 4).
//

import Foundation
import SwiftData

protocol AccountMigrationRunning: AnyObject {
    func runSafeBackfill(for uid: String) async throws
}

@MainActor
final class AccountMigrationService: AccountMigrationRunning {

    private let store: SwiftDataStore
    private let userProfileService: UserProfileService

    init(store: SwiftDataStore, userProfileService: UserProfileService) {
        self.store = store
        self.userProfileService = userProfileService
    }

    func runSafeBackfill(for uid: String) async throws {
        let normalizedUID = try AccountSyncMutationValidation.normalizedOwnerUID(uid)
        guard shouldBackfill(for: normalizedUID) else { return }

        let now = Date()
        try backfillOwnerUID(on: DailyLogEntity.self, uid: normalizedUID, now: now)
        try backfillOwnerUID(on: FoodEntryEntity.self, uid: normalizedUID, now: now)
        try backfillOwnerUID(on: WaterEntryEntity.self, uid: normalizedUID, now: now)
        try backfillOwnerUID(on: WeightEntryEntity.self, uid: normalizedUID, now: now)
        try backfillOwnerUID(on: DailyReviewEntity.self, uid: normalizedUID, now: now)
        try store.save()
    }

    private func shouldBackfill(for uid: String) throws -> Bool {
        guard let profile = try userProfileService.getCurrentProfile() else {
            return false
        }
        guard let ownerUID = profile.ownerUID else {
            return true
        }
        return ownerUID == uid
    }

    private func backfillOwnerUID<T: PersistentModel & AccountDataSyncMetadataEntity & AccountDataSyncOwnable>(
        on type: T.Type,
        uid: String,
        now: Date
    ) throws {
        let descriptor = FetchDescriptor<T>(
            predicate: #Predicate { entity in
                entity.ownerUID == nil
            }
        )
        let rows = try store.fetch(descriptor)
        guard !rows.isEmpty else { return }

        for entity in rows {
            entity.ownerUID = uid
            if entity.syncStatus == .localOnly || entity.syncStatus == .synced {
                entity.syncStatus = .pendingUpload
            }
            entity.localUpdatedAt = now
        }
    }
}
