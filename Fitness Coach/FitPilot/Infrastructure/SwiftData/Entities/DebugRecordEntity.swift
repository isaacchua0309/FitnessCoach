//
//  DebugRecordEntity.swift
//  Fitness Coach
//
//  FitPilot AI — SwiftData persistence entity.
//
//  The domain DebugRecord.context is [String: String]; it is persisted here as
//  a JSON string to avoid SwiftData dictionary persistence edge cases.
//

import Foundation
import SwiftData

@Model
final class DebugRecordEntity {

    @Attribute(.unique) var id: UUID
    var categoryRawValue: String
    var message: String
    var contextJson: String
    var createdAt: Date

    init(
        id: UUID,
        categoryRawValue: String,
        message: String,
        contextJson: String,
        createdAt: Date
    ) {
        self.id = id
        self.categoryRawValue = categoryRawValue
        self.message = message
        self.contextJson = contextJson
        self.createdAt = createdAt
    }
}
