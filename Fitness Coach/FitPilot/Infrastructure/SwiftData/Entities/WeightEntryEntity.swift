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
    var date: Date
    var weightKg: Double
    var note: String?
    var createdAt: Date

    init(
        id: UUID,
        date: Date,
        weightKg: Double,
        note: String?,
        createdAt: Date
    ) {
        self.id = id
        self.date = date
        self.weightKg = weightKg
        self.note = note
        self.createdAt = createdAt
    }
}
