//
//  SwiftDataStore.swift
//  Fitness Coach
//
//  FitPilot AI — Lightweight local persistence wrapper.
//
//  This is intentionally generic. Domain-specific actions (addFoodEntry,
//  startNewDay, logWeight, etc.) belong in services added in later steps.
//

import Foundation
import SwiftData

@MainActor
final class SwiftDataStore {

    let modelContext: ModelContext

    init(modelContext: ModelContext) {
        self.modelContext = modelContext
    }

    convenience init(container: ModelContainer) {
        self.init(modelContext: ModelContext(container))
    }

    // MARK: Persistence

    func save() throws {
        guard modelContext.hasChanges else { return }
        do {
            try modelContext.save()
        } catch {
            throw SwiftDataError.saveFailed
        }
    }

    func insert<T: PersistentModel>(_ entity: T) throws {
        modelContext.insert(entity)
        try save()
    }

    func delete<T: PersistentModel>(_ entity: T) throws {
        modelContext.delete(entity)
        do {
            try save()
        } catch {
            throw SwiftDataError.deleteFailed
        }
    }

    // MARK: Fetching

    func fetch<T: PersistentModel>(_ descriptor: FetchDescriptor<T>) throws -> [T] {
        do {
            return try modelContext.fetch(descriptor)
        } catch {
            throw SwiftDataError.fetchFailed
        }
    }

    func fetchOne<T: PersistentModel>(_ descriptor: FetchDescriptor<T>) throws -> T? {
        var oneItemDescriptor = descriptor
        oneItemDescriptor.fetchLimit = 1
        return try fetch(oneItemDescriptor).first
    }
}
