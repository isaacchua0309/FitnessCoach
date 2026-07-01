//
//  DebugRecordEntity.swift
//  Fitness Coach
//
//  V1 MIGRATION ONLY — listed in `FormaSchemaV1` for lightweight migration to v2.
//  Removed from active `FormaSchemaV2` schema. Diagnostics use in-memory
//  `FormaPipelineTracer` buffers. See `Docs/PersistenceCleanupNotes.md`.
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
