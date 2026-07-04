//
//  FoodLogService.swift
//  Fitness Coach
//
//  FitPilot AI — Owns food entry creation, editing, deletion, and undo.
//

import Foundation
import SwiftData

@MainActor
final class FoodLogService {

    private let store: SwiftDataStore
    private let dailyLogService: DailyLogService
    private let mutationTracker: AccountLocalMutationTracker?

    init(
        store: SwiftDataStore,
        dailyLogService: DailyLogService,
        mutationTracker: AccountLocalMutationTracker? = nil
    ) {
        self.store = store
        self.dailyLogService = dailyLogService
        self.mutationTracker = mutationTracker
    }

    // MARK: Create

    func addFoodEntry(_ draft: FoodDraft, date: Date) throws -> FoodEntry {
        try addFoodEntry(FoodLogDraftMapper.fromLegacyDraft(draft), date: date)
    }

    func addFoodEntry(_ meal: FoodLogDraft, date: Date) throws -> FoodEntry {
        try validate(meal)

        let log = try dailyLogService.getOrCreateLogEntity(for: date)
        let now = Date()
        let model = FoodLogDraftMapper.toFoodEntry(meal, dailyLogId: log.id, createdAt: now, updatedAt: now)

        let entity = FoodEntryEntity(model: model)
        entity.dailyLog = log
        try store.insert(entity)

        let mutationGroupId = mutationTracker?.makeMutationGroupId()
        try dailyLogService.recalculateDailyTotals(for: log.date, mutationGroupId: mutationGroupId)
        try trackFoodUpsert(entity, dailyLog: log, mutationGroupId: mutationGroupId)
        return entity.toModel()
    }

    // MARK: Update

    func editFoodEntry(id: UUID, update: FoodEntryUpdate) throws -> FoodEntry {
        guard let entity = try foodEntity(id: id) else {
            throw ServiceError.foodEntryNotFound
        }

        if let mealType = update.mealType { entity.mealTypeRawValue = mealType.rawValue }
        if let name = update.name {
            let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !trimmed.isEmpty else { throw ServiceError.invalidInput("Food name cannot be empty.") }
            entity.name = name
        }
        if let quantity = update.quantity { entity.quantity = quantity }
        if let unit = update.unit { entity.unit = unit }
        if let calories = update.calories {
            guard calories >= 0 else { throw ServiceError.invalidInput("Calories cannot be negative.") }
            entity.calories = calories
        }
        if let protein = update.protein {
            guard protein >= 0 else { throw ServiceError.invalidInput("Protein cannot be negative.") }
            entity.protein = protein
        }
        if let carbs = update.carbs {
            guard carbs >= 0 else { throw ServiceError.invalidInput("Carbs cannot be negative.") }
            entity.carbs = carbs
        }
        if let fat = update.fat {
            guard fat >= 0 else { throw ServiceError.invalidInput("Fat cannot be negative.") }
            entity.fat = fat
        }
        if let fiber = update.fiber { entity.fiber = fiber }
        if let sodium = update.sodium { entity.sodium = sodium }
        if let source = update.source { entity.sourceRawValue = source.rawValue }
        if let confidence = update.confidence { entity.confidenceRawValue = confidence.rawValue }
        if let imageUrl = update.imageUrl { entity.imageUrl = imageUrl }
        if let notes = update.notes { entity.notes = notes }
        if let components = update.components {
            entity.componentsJSON = components.count > 1
                ? encodeComponents(components)
                : nil
        }

        entity.updatedAt = Date()
        try save()

        if let log = entity.dailyLog {
            let mutationGroupId = mutationTracker?.makeMutationGroupId()
            try dailyLogService.recalculateDailyTotals(for: log.date, mutationGroupId: mutationGroupId)
            try trackFoodUpsert(entity, dailyLog: log, mutationGroupId: mutationGroupId)
        }
        return entity.toModel()
    }

    // MARK: Delete

    func deleteFoodEntry(id: UUID) throws {
        guard let entity = try foodEntity(id: id) else {
            throw ServiceError.foodEntryNotFound
        }
        let log = entity.dailyLog
        let logDate = log?.date
        let localDate = log.map { mutationTracker?.dailyLogCloudID(for: $0.date) }

        if let mutationTracker {
            try mutationTracker.trackDelete(
                entity: entity,
                entityType: .foodEntry,
                entityId: entity.id.uuidString,
                localDate: localDate,
                hardDelete: { [store] in
                    store.delete(entity)
                }
            )
        } else {
            try store.delete(entity)
        }
        try save()

        if let logDate {
            let mutationGroupId = mutationTracker?.makeMutationGroupId()
            try dailyLogService.recalculateDailyTotals(for: logDate, mutationGroupId: mutationGroupId)
        }
    }

    func undoLastFoodEntry(date: Date) throws -> FoodEntry? {
        guard let log = try dailyLogService.dailyLogEntity(for: date) else {
            return nil
        }
        guard let last = visibleFoodEntries(in: log).max(by: { $0.createdAt < $1.createdAt }) else {
            return nil
        }
        let model = last.toModel()
        let mutationGroupId = mutationTracker?.makeMutationGroupId()
        if let mutationTracker {
            try mutationTracker.trackDelete(
                entity: last,
                entityType: .foodEntry,
                entityId: last.id.uuidString,
                localDate: mutationTracker.dailyLogCloudID(for: log.date),
                mutationGroupId: mutationGroupId,
                hardDelete: { [store] in
                    store.delete(last)
                }
            )
        } else {
            try store.delete(last)
        }
        try save()
        try dailyLogService.recalculateDailyTotals(for: log.date, mutationGroupId: mutationGroupId)
        return model
    }

    // MARK: Read

    func getFoodEntries(for date: Date) throws -> [FoodEntry] {
        guard let log = try dailyLogService.dailyLogEntity(for: date) else {
            return []
        }
        return visibleFoodEntries(in: log)
            .sorted { $0.createdAt < $1.createdAt }
            .map { $0.toModel() }
    }

    /// Returns food entries across an inclusive local-day range using one daily-log fetch.
    func getFoodEntries(
        from startDate: Date,
        to endDate: Date,
        calendar: Calendar = .current
    ) throws -> [FoodEntry] {
        let lowerBound = calendar.startOfDay(for: startDate)
        let upperBound = calendar.startOfDay(for: endDate)
        let descriptor = FetchDescriptor<DailyLogEntity>(
            predicate: #Predicate { $0.date >= lowerBound && $0.date <= upperBound },
            sortBy: [SortDescriptor(\.date, order: .forward)]
        )
        let logs = try store.fetch(descriptor)
        return logs.flatMap { log in
            visibleFoodEntries(in: log)
                .sorted { $0.createdAt < $1.createdAt }
                .map { $0.toModel() }
        }
    }

    // MARK: Helpers

    private func foodEntity(id: UUID) throws -> FoodEntryEntity? {
        var descriptor = FetchDescriptor<FoodEntryEntity>(
            predicate: #Predicate { $0.id == id }
        )
        descriptor.fetchLimit = 1
        return try store.fetch(descriptor).first
    }

    private func visibleFoodEntries(in log: DailyLogEntity) -> [FoodEntryEntity] {
        log.foodEntries.filter(AccountDataSyncReadFilter.isVisible)
    }

    private func trackFoodUpsert(
        _ entity: FoodEntryEntity,
        dailyLog: DailyLogEntity,
        mutationGroupId: String?
    ) throws {
        guard let mutationTracker else { return }
        try save()
        try mutationTracker.trackUpsert(
            entity: entity,
            entityType: .foodEntry,
            entityId: entity.id.uuidString,
            localDate: mutationTracker.dailyLogCloudID(for: dailyLog.date),
            mutationGroupId: mutationGroupId
        )
        try save()
    }

    private func validate(_ meal: FoodLogDraft) throws {
        let trimmed = meal.displayName.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { throw ServiceError.invalidInput("Food name cannot be empty.") }
        guard !meal.components.isEmpty else {
            throw ServiceError.invalidInput("At least one food component is required.")
        }
        guard meal.totalCalories >= 0 else { throw ServiceError.invalidInput("Calories cannot be negative.") }
        guard meal.totalProtein >= 0, meal.totalCarbs >= 0, meal.totalFat >= 0 else {
            throw ServiceError.invalidInput("Macros cannot be negative.")
        }
        for component in meal.components {
            guard component.calories >= 0 else {
                throw ServiceError.invalidInput("Calories cannot be negative.")
            }
            guard component.protein >= 0, component.carbs >= 0, component.fat >= 0 else {
                throw ServiceError.invalidInput("Macros cannot be negative.")
            }
        }
    }

    private func encodeComponents(_ components: [FoodComponent]) -> String? {
        guard let data = try? JSONEncoder().encode(components) else { return nil }
        return String(data: data, encoding: .utf8)
    }

    private func save() throws {
        do {
            try store.save()
        } catch {
            throw ServiceError.persistenceFailed("Could not save the food entry.")
        }
    }
}
