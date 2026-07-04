//
//  AccountLocalMutationTracker.swift
//  Fitness Coach
//
//  Forma — Stamps local entities and enqueues durable outbox mutations (Phase 3).
//
//  Does not perform remote uploads.
//

import Foundation

@MainActor
final class AccountLocalMutationTracker {

    private let outbox: SwiftDataAccountSyncOutboxStore
    private let ownerUIDProvider: () -> String?
    private let calendar: Calendar

    init(
        outbox: SwiftDataAccountSyncOutboxStore,
        ownerUIDProvider: @escaping () -> String?,
        calendar: Calendar = AccountLocalMutationTracker.defaultCalendar
    ) {
        self.outbox = outbox
        self.ownerUIDProvider = ownerUIDProvider
        self.calendar = calendar
    }

    func makeMutationGroupId() -> String {
        UUID().uuidString
    }

    func trackUpsert(
        entity: AccountDataSyncMetadataEntity,
        entityType: AccountSyncEntityType,
        entityId: String,
        localDate: String?,
        mutationGroupId: String?,
        explicitOwnerUID: String? = nil,
        now: Date = Date()
    ) throws {
        guard let ownerUID = resolvedOwnerUID(explicitOwnerUID, entity: entity) else { return }

        _ = AccountDataSyncStamping.stampPendingUpload(on: entity, ownerUID: ownerUID, now: now)
        try outbox.enqueueLocalMutation(
            ownerUID: ownerUID,
            entityType: entityType,
            entityId: entityId,
            localDate: localDate,
            operation: .upsert,
            mutationGroupId: mutationGroupId
        )
    }

    func trackDailyLogUpsert(
        _ dailyLog: DailyLogEntity,
        mutationGroupId: String?,
        explicitOwnerUID: String? = nil,
        now: Date = Date()
    ) throws {
        try trackUpsert(
            entity: dailyLog,
            entityType: .dailyLog,
            entityId: dailyLogCloudID(for: dailyLog.date),
            localDate: dailyLogCloudID(for: dailyLog.date),
            mutationGroupId: mutationGroupId,
            explicitOwnerUID: explicitOwnerUID,
            now: now
        )
    }

    func trackDailyReviewUpsert(
        _ review: DailyReviewEntity,
        dailyLog: DailyLogEntity,
        mutationGroupId: String? = nil,
        explicitOwnerUID: String? = nil,
        now: Date = Date()
    ) throws {
        let localDate = dailyLogCloudID(for: dailyLog.date)
        try trackUpsert(
            entity: review,
            entityType: .dailyReview,
            entityId: localDate,
            localDate: localDate,
            mutationGroupId: mutationGroupId,
            explicitOwnerUID: explicitOwnerUID,
            now: now
        )
    }

    func trackDelete(
        entity: AccountDataSyncMetadataEntity,
        entityType: AccountSyncEntityType,
        entityId: String,
        localDate: String?,
        mutationGroupId: String? = nil,
        explicitOwnerUID: String? = nil,
        hardDelete: () throws -> Void,
        now: Date = Date()
    ) throws {
        guard let ownerUID = resolvedOwnerUID(explicitOwnerUID, entity: entity) else {
            try hardDelete()
            return
        }

        if AccountDataSyncDeletionPolicy.shouldTombstone(entity) {
            _ = AccountDataSyncStamping.stampPendingDelete(on: entity, ownerUID: ownerUID, now: now)
            try outbox.enqueueLocalMutation(
                ownerUID: ownerUID,
                entityType: entityType,
                entityId: entityId,
                localDate: localDate,
                operation: .delete,
                mutationGroupId: mutationGroupId
            )
            return
        }

        try hardDelete()
        try outbox.enqueueLocalMutation(
            ownerUID: ownerUID,
            entityType: entityType,
            entityId: entityId,
            localDate: localDate,
            operation: .delete,
            mutationGroupId: mutationGroupId
        )
    }

    func dailyLogCloudID(for date: Date) -> String {
        AccountDataSyncMetadataSupport.dailyLogCloudID(for: date, calendar: calendar)
    }

    // MARK: - Helpers

    private func resolvedOwnerUID(
        _ explicitOwnerUID: String?,
        entity: AccountDataSyncMetadataEntity
    ) -> String? {
        if let explicitOwnerUID {
            let trimmed = explicitOwnerUID.trimmingCharacters(in: .whitespacesAndNewlines)
            if !trimmed.isEmpty {
                return trimmed
            }
        }
        if let ownable = entity as? AccountDataSyncOwnable,
           let stored = ownable.ownerUID?.trimmingCharacters(in: .whitespacesAndNewlines),
           !stored.isEmpty {
            return stored
        }
        guard let providerUID = ownerUIDProvider()?.trimmingCharacters(in: .whitespacesAndNewlines),
              !providerUID.isEmpty else {
            return nil
        }
        return providerUID
    }

    nonisolated static var defaultCalendar: Calendar {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(secondsFromGMT: 0)!
        return calendar
    }
}
