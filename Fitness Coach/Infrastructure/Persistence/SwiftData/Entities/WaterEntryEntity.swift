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

    // MARK: Account persistence (Phase 1)

    /// Local mutation timestamp for account persistence bookkeeping.
    var localUpdatedAt: Date?
    /// Per-entity schema version for future lightweight migrations.
    var entitySchemaVersion: Int = UserDataEntitySchema.currentEntitySchemaVersion

    var dailyLogId: UUID
    var amountMl: Int
    var createdAt: Date

    // MARK: Relationships

    var dailyLog: DailyLogEntity?

    init(
        id: UUID,
        ownerUID: String? = nil,
        dailyLogId: UUID,
        amountMl: Int,
        createdAt: Date,
        localUpdatedAt: Date? = nil,
        entitySchemaVersion: Int = UserDataEntitySchema.currentEntitySchemaVersion
    ) {
        self.id = id
        self.ownerUID = ownerUID
        self.dailyLogId = dailyLogId
        self.amountMl = amountMl
        self.createdAt = createdAt
        self.localUpdatedAt = localUpdatedAt ?? createdAt
        self.entitySchemaVersion = entitySchemaVersion
    }
}
