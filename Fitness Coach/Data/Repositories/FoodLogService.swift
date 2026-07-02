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

    init(store: SwiftDataStore, dailyLogService: DailyLogService) {
        self.store = store
        self.dailyLogService = dailyLogService
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
        try dailyLogService.recalculateDailyTotals(for: log.date)
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

        if let logDate = entity.dailyLog?.date {
            try dailyLogService.recalculateDailyTotals(for: logDate)
        }
        return entity.toModel()
    }

    // MARK: Delete

    func deleteFoodEntry(id: UUID) throws {
        guard let entity = try foodEntity(id: id) else {
            throw ServiceError.foodEntryNotFound
        }
        let logDate = entity.dailyLog?.date
        try store.delete(entity)
        if let logDate {
            try dailyLogService.recalculateDailyTotals(for: logDate)
        }
    }

    func undoLastFoodEntry(date: Date) throws -> FoodEntry? {
        guard let log = try dailyLogService.dailyLogEntity(for: date) else {
            return nil
        }
        guard let last = log.foodEntries.max(by: { $0.createdAt < $1.createdAt }) else {
            return nil
        }
        let model = last.toModel()
        try store.delete(last)
        try dailyLogService.recalculateDailyTotals(for: log.date)
        return model
    }

    // MARK: Read

    func getFoodEntries(for date: Date) throws -> [FoodEntry] {
        guard let log = try dailyLogService.dailyLogEntity(for: date) else {
            return []
        }
        return log.foodEntries
            .sorted { $0.createdAt < $1.createdAt }
            .map { $0.toModel() }
    }

    // MARK: Helpers

    private func foodEntity(id: UUID) throws -> FoodEntryEntity? {
        var descriptor = FetchDescriptor<FoodEntryEntity>(
            predicate: #Predicate { $0.id == id }
        )
        descriptor.fetchLimit = 1
        return try store.fetch(descriptor).first
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
