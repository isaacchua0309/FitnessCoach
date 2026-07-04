//
//  AccountMigrationService.swift
//  Fitness Coach
//
//  Forma — Backfills local user-data ownership after schema upgrades (Phase 1).
//

import Foundation
import SwiftData

@MainActor
final class AccountMigrationService {

    private let store: SwiftDataStore
    private let userProfileService: UserProfileService

    init(store: SwiftDataStore, userProfileService: UserProfileService) {
        self.store = store
        self.userProfileService = userProfileService
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
}
