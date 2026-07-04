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
