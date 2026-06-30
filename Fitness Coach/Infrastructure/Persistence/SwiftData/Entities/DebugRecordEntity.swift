//
//  DebugRecordEntity.swift
//  Fitness Coach
//
//  DORMANT — registered in `FormaModelContainer.schema` only.
//
//  Pipeline diagnostics use in-memory `FormaPipelineTracer` buffers.
//  Disk persistence via `PipelineTracePersistence` is disabled (Stage 14) because
//  no UI reads stored rows. Context is stored as JSON to avoid SwiftData
//  dictionary edge cases when persistence is re-enabled.
//
//  TODO(migration): Re-enable persistence + Settings UI, or remove entity. See
//  `Docs/PersistenceCleanupNotes.md`.
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
