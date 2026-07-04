//
//  WeightEntryEntity.swift
//  Fitness Coach
//
//  FitPilot AI — SwiftData persistence entity.
//

import Foundation
import SwiftData

@Model
final class WeightEntryEntity {

    @Attribute(.unique) var id: UUID
    /// Firebase UID that owns this weight entry, when known.
    var ownerUID: String?

    // MARK: Account persistence (Phase 1)

    /// Local mutation timestamp for account persistence bookkeeping.
    var localUpdatedAt: Date?
    /// Per-entity schema version for future lightweight migrations.
    var entitySchemaVersion: Int = UserDataEntitySchema.currentEntitySchemaVersion

    var date: Date
    var weightKg: Double
    var note: String?
    var createdAt: Date

    init(
        id: UUID,
        ownerUID: String? = nil,
        date: Date,
        weightKg: Double,
        note: String?,
        createdAt: Date,
        localUpdatedAt: Date? = nil,
        entitySchemaVersion: Int = UserDataEntitySchema.currentEntitySchemaVersion
    ) {
        self.id = id
        self.ownerUID = ownerUID
        self.date = date
        self.weightKg = weightKg
        self.note = note
        self.createdAt = createdAt
        self.localUpdatedAt = localUpdatedAt ?? createdAt
        self.entitySchemaVersion = entitySchemaVersion
    }
}
