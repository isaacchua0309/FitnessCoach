//
//  WeightLogService.swift
//  Fitness Coach
//
//  FitPilot AI — Owns weight logging and weight trend access.
//

import Foundation
import SwiftData

@MainActor
final class WeightLogService {

    private let store: SwiftDataStore
    private let dailyLogService: DailyLogService
    private let dateProvider: DateProviding
    private let mutationTracker: AccountLocalMutationTracker?

    init(
        store: SwiftDataStore,
        dailyLogService: DailyLogService,
        dateProvider: DateProviding? = nil,
        mutationTracker: AccountLocalMutationTracker? = nil
    ) {
        self.store = store
        self.dailyLogService = dailyLogService
        self.dateProvider = dateProvider ?? SystemDateProvider()
        self.mutationTracker = mutationTracker
    }

    // MARK: Create

    func logWeight(_ weightKg: Double, date: Date) throws -> WeightEntry {
        guard weightKg > 0 else { throw ServiceError.invalidInput("Weight must be greater than zero.") }

        let dayStart = dateProvider.startOfDay(for: date)
        let mutationGroupId = mutationTracker?.makeMutationGroupId()

        if let existing = try weightEntity(forDayStart: dayStart) {
            existing.weightKg = weightKg
            try save()
            let dailyLogUpdated = try updateDailyLogWeightIfPresent(date: dayStart, weightKg: weightKg, mutationGroupId: mutationGroupId)
            try trackWeightUpsert(existing, mutationGroupId: mutationGroupId)
            if dailyLogUpdated, let log = try dailyLogService.dailyLogEntity(for: dayStart) {
                try mutationTracker?.trackDailyLogUpsert(log, mutationGroupId: mutationGroupId)
                try save()
            }
            return existing.toModel()
        }

        let model = WeightEntry(
            id: UUID(),
            date: dayStart,
            weightKg: weightKg,
            note: nil,
            createdAt: dateProvider.now
        )
        let entity = WeightEntryEntity(model: model)
        try store.insert(entity)
        let dailyLogUpdated = try updateDailyLogWeightIfPresent(date: dayStart, weightKg: weightKg, mutationGroupId: mutationGroupId)
        try trackWeightUpsert(entity, mutationGroupId: mutationGroupId)
        if dailyLogUpdated, let log = try dailyLogService.dailyLogEntity(for: dayStart) {
            try mutationTracker?.trackDailyLogUpsert(log, mutationGroupId: mutationGroupId)
            try save()
        }
        return entity.toModel()
    }

    func logWeight(_ draft: WeightDraft, date: Date) throws -> WeightEntry {
        guard draft.weightKg > 0 else { throw ServiceError.invalidInput("Weight must be greater than zero.") }

        let dayStart = dateProvider.startOfDay(for: date)
        let mutationGroupId = mutationTracker?.makeMutationGroupId()

        if let existing = try weightEntity(forDayStart: dayStart) {
            existing.weightKg = draft.weightKg
            existing.note = draft.note
            try save()
            let dailyLogUpdated = try updateDailyLogWeightIfPresent(date: dayStart, weightKg: draft.weightKg, mutationGroupId: mutationGroupId)
            try trackWeightUpsert(existing, mutationGroupId: mutationGroupId)
            if dailyLogUpdated, let log = try dailyLogService.dailyLogEntity(for: dayStart) {
                try mutationTracker?.trackDailyLogUpsert(log, mutationGroupId: mutationGroupId)
                try save()
            }
            return existing.toModel()
        }

        let model = WeightEntry(
            id: UUID(),
            date: dayStart,
            weightKg: draft.weightKg,
            note: draft.note,
            createdAt: dateProvider.now
        )
        let entity = WeightEntryEntity(model: model)
        try store.insert(entity)
        let dailyLogUpdated = try updateDailyLogWeightIfPresent(date: dayStart, weightKg: draft.weightKg, mutationGroupId: mutationGroupId)
        try trackWeightUpsert(entity, mutationGroupId: mutationGroupId)
        if dailyLogUpdated, let log = try dailyLogService.dailyLogEntity(for: dayStart) {
            try mutationTracker?.trackDailyLogUpsert(log, mutationGroupId: mutationGroupId)
            try save()
        }
        return entity.toModel()
    }

    // MARK: Read

    func getLatestWeight() throws -> WeightEntry? {
        var descriptor = FetchDescriptor<WeightEntryEntity>(
            sortBy: [SortDescriptor(\.date, order: .reverse)]
        )
        return try store.fetch(descriptor)
            .first(where: AccountDataSyncReadFilter.isVisible)?
            .toModel()
    }

    func getWeightEntries(from startDate: Date?, to endDate: Date?) throws -> [WeightEntry] {
        let descriptor = FetchDescriptor<WeightEntryEntity>(
            sortBy: [SortDescriptor(\.date, order: .forward)]
        )
        var entries = try store.fetch(descriptor)
            .filter(AccountDataSyncReadFilter.isVisible)
            .map { $0.toModel() }
        if let startDate {
            entries = entries.filter { $0.date >= startDate }
        }
        if let endDate {
            entries = entries.filter { $0.date <= endDate }
        }
        return entries
    }

    func getWeightTrend(days: Int, endingOn date: Date) throws -> WeightTrend {
        let windowStart = Calendar.current.date(byAdding: .day, value: -max(days, 0), to: date)
        let entries = try getWeightEntries(from: windowStart, to: date)
        return WeightTrendCalculator.trend(from: entries, endingOn: date)
    }

    // MARK: Helpers

    private func weightEntity(forDayStart dayStart: Date) throws -> WeightEntryEntity? {
        var descriptor = FetchDescriptor<WeightEntryEntity>(
            predicate: #Predicate { $0.date == dayStart }
        )
        descriptor.fetchLimit = 1
        guard let entity = try store.fetch(descriptor).first else { return nil }
        guard AccountDataSyncReadFilter.isVisible(entity) else { return nil }
        return entity
    }

    @discardableResult
    private func updateDailyLogWeightIfPresent(
        date: Date,
        weightKg: Double,
        mutationGroupId: String?
    ) throws -> Bool {
        guard let log = try dailyLogService.dailyLogEntity(for: date) else { return false }
        log.weightKg = weightKg
        log.updatedAt = dateProvider.now
        try save()
        return true
    }

    private func trackWeightUpsert(_ entity: WeightEntryEntity, mutationGroupId: String?) throws {
        guard let mutationTracker else { return }
        let localDate = mutationTracker.dailyLogCloudID(for: entity.date)
        try mutationTracker.trackUpsert(
            entity: entity,
            entityType: .weightEntry,
            entityId: entity.id.uuidString,
            localDate: localDate,
            mutationGroupId: mutationGroupId
        )
        try save()
    }

    private func save() throws {
        do {
            try store.save()
        } catch {
            throw ServiceError.persistenceFailed("Could not save the weight entry.")
        }
    }
}
