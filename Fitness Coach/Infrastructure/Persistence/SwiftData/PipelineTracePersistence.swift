//
//  PipelineTracePersistence.swift
//  Fitness Coach
//
//  Optional bridge from `FormaPipelineTracer` to `DebugRecordEntity`.
//
//  Disk persistence is disabled (Stage 14): Settings diagnostics read in-memory
//  trace buffers only, so writing SwiftData rows created unreachable data.
//  `DebugRecordEntity` remains in schema until a migration decision. See
//  `Docs/PersistenceCleanupNotes.md`.
//
//  TODO(migration): Re-enable `persist` when Settings can load stored records,
//  or remove `DebugRecordEntity` from schema.
//

import Foundation

enum PipelineTracePersistence {

    static func install(on store: SwiftDataStore) {
        _ = store
        // In-memory `FormaPipelineTracer` remains the diagnostics source of truth.
    }
}
