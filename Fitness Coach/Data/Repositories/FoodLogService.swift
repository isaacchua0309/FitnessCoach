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
    private let currentUIDProvider: () -> String?

    init(
        store: SwiftDataStore,
        dailyLogService: DailyLogService,
        currentUIDProvider: @escaping () -> String? = { nil }
    ) {
        self.store = store
        self.dailyLogService = dailyLogService
        self.currentUIDProvider = currentUIDProvider
    }

    // MARK: Create

    func addFoodEntry(_ draft: FoodDraft, date: Date) throws -> FoodEntry {
        try addFoodEntry(FoodLogDraftMapper.fromLegacyDraft(draft), date: date)
    }

    func addFoodEntry(_ meal: FoodLogDraft, date: Date) throws -> FoodEntry {
        try validate(meal)

        let ownerUID = try UserDataOwnerScope.requiredSessionUID(
            currentUIDProvider(),
            operation: "log food"
        )
        let log = try dailyLogService.getOrCreateLogEntity(for: date)
        try UserDataOwnerScope.requireMatchingDailyLogOwner(log, sessionUID: ownerUID)

        let now = Date()
        let model = FoodLogDraftMapper.toFoodEntry(meal, dailyLogId: log.id, createdAt: now, updatedAt: now)

        let entity = FoodEntryEntity(model: model)
        UserDataOwnerScope.stampNewNutritionWrite(on: entity, ownerUID: ownerUID, now: now)
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

        let now = Date()
        entity.updatedAt = now
        UserDataOwnerScope.touchNutritionWrite(on: entity, now: now)
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
        let sessionUID = currentUIDProvider()
        guard let last = log.foodEntries
            .filter({ UserDataOwnerScope.isVisible(entityOwnerUID: $0.ownerUID, sessionUID: sessionUID) })
            .max(by: { $0.createdAt < $1.createdAt }) else {
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
        let sessionUID = currentUIDProvider()
        return UserDataOwnerScope.filterVisibleNutritionEntities(log.foodEntries, sessionUID: sessionUID)
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
        let sessionUID = currentUIDProvider()
        let logs = try dailyLogService.getLogs(from: lowerBound, to: upperBound)
        let logIDs = Set(logs.map(\.id))
        guard !logIDs.isEmpty else { return [] }

        let entities: [FoodEntryEntity]
        if let sessionUID {
            let descriptor = FetchDescriptor<FoodEntryEntity>(
                predicate: #Predicate { $0.ownerUID == sessionUID },
                sortBy: [SortDescriptor(\.createdAt, order: .forward)]
            )
            entities = try store.fetch(descriptor)
        } else {
            let descriptor = FetchDescriptor<FoodEntryEntity>(
                predicate: #Predicate { $0.ownerUID == nil },
                sortBy: [SortDescriptor(\.createdAt, order: .forward)]
            )
            entities = try store.fetch(descriptor)
        }

        return entities
            .filter { logIDs.contains($0.dailyLogId) }
            .map { $0.toModel() }
    }

    // MARK: Helpers

    private func foodEntity(id: UUID) throws -> FoodEntryEntity? {
        guard let entity = try fetchFoodEntity(id: id) else { return nil }
        guard UserDataOwnerScope.isVisible(
            entityOwnerUID: entity.ownerUID,
            sessionUID: currentUIDProvider()
        ) else {
            return nil
        }
        return entity
    }

    private func fetchFoodEntity(id: UUID) throws -> FoodEntryEntity? {
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
