//
//  PipelineTracePersistence.swift
//  Fitness Coach
//
//  Legacy bridge from `FormaPipelineTracer` to `DebugRecordEntity` (v1 schema only).
//  Disk persistence remains disabled; in-memory trace buffers are the source of truth.
//

import Foundation

enum PipelineTracePersistence {

    static func install(on store: SwiftDataStore) {
        _ = store
    }
}
