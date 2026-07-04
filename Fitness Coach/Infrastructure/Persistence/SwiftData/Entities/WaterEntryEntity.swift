//
//  WaterEntryEntity.swift
//  Fitness Coach
//
//  FitPilot AI — SwiftData persistence entity.
//

import Foundation
import SwiftData

@Model
final class WaterEntryEntity {

    @Attribute(.unique) var id: UUID
    /// Firebase UID that owns this water entry, when known.
    var ownerUID: String?
    var dailyLogId: UUID
    var amountMl: Int
    var createdAt: Date

    // MARK: Account persistence sync metadata (Phase 3)

    var cloudId: String?
    var cloudUpdatedAt: Date?
    var lastSyncedAt: Date?
    var syncStatusRawValue: String = AccountDataSyncStatus.localOnly.rawValue
    var lastSyncError: String?
    var deletedAt: Date?
    var lastMutationId: String?
    var syncAttemptCount: Int = 0
    var nextRetryAt: Date?
    var localUpdatedAt: Date?

    // MARK: Relationships

    var dailyLog: DailyLogEntity?

    init(
        id: UUID,
        ownerUID: String? = nil,
        dailyLogId: UUID,
        amountMl: Int,
        createdAt: Date
    ) {
        self.id = id
        self.ownerUID = ownerUID
        self.dailyLogId = dailyLogId
        self.amountMl = amountMl
        self.createdAt = createdAt
    }
}
