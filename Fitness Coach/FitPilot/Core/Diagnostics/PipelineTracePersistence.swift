//
//  PipelineTracePersistence.swift
//  Fitness Coach
//
//  Persists pipeline error traces to SwiftData (DEBUG only).
//

#if DEBUG
import Foundation
import SwiftData

@MainActor
enum PipelineTracePersistence {

    private static let maxStoredRecords = 50

    static func install(on store: SwiftDataStore) {
        FitPilotPipelineTracer.debugRecordHandler = { record in
            persist(record, store: store)
        }
    }

    private static func persist(_ record: DebugRecord, store: SwiftDataStore) {
        do {
            let entity = DebugRecordEntity(model: record)
            try store.insert(entity)
            pruneOldRecords(store: store)
        } catch {
            // Tracing must never break the app.
        }
    }

    private static func pruneOldRecords(store: SwiftDataStore) {
        let descriptor = FetchDescriptor<DebugRecordEntity>(
            sortBy: [SortDescriptor(\.createdAt, order: .reverse)]
        )
        guard let all = try? store.fetch(descriptor), all.count > maxStoredRecords else {
            return
        }
        for entity in all.dropFirst(maxStoredRecords) {
            try? store.delete(entity)
        }
    }
}

#else

enum PipelineTracePersistence {
    static func install(on store: SwiftDataStore) {}
}

#endif
