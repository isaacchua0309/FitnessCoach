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
    var dailyLogId: UUID
    var amountMl: Int
    var createdAt: Date

    // MARK: Relationships

    var dailyLog: DailyLogEntity?

    init(
        id: UUID,
        dailyLogId: UUID,
        amountMl: Int,
        createdAt: Date
    ) {
        self.id = id
        self.dailyLogId = dailyLogId
        self.amountMl = amountMl
        self.createdAt = createdAt
    }
}
