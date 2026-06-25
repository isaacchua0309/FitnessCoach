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

    init(
        store: SwiftDataStore,
        dailyLogService: DailyLogService,
        dateProvider: DateProviding = SystemDateProvider()
    ) {
        self.store = store
        self.dailyLogService = dailyLogService
        self.dateProvider = dateProvider
    }

    // MARK: Create

    func logWeight(_ weightKg: Double, date: Date) throws -> WeightEntry {
        guard weightKg > 0 else { throw ServiceError.invalidInput("Weight must be greater than zero.") }

        let dayStart = dateProvider.startOfDay(for: date)

        // Same-day policy: update the existing entry for this day if present,
        // otherwise create a new one.
        if let existing = try weightEntity(forDayStart: dayStart) {
            existing.weightKg = weightKg
            try save()
            try updateDailyLogWeightIfPresent(date: dayStart, weightKg: weightKg)
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
        try updateDailyLogWeightIfPresent(date: dayStart, weightKg: weightKg)
        return entity.toModel()
    }

    func logWeight(_ draft: WeightDraft, date: Date) throws -> WeightEntry {
        guard draft.weightKg > 0 else { throw ServiceError.invalidInput("Weight must be greater than zero.") }

        let dayStart = dateProvider.startOfDay(for: date)

        if let existing = try weightEntity(forDayStart: dayStart) {
            existing.weightKg = draft.weightKg
            existing.note = draft.note
            try save()
            try updateDailyLogWeightIfPresent(date: dayStart, weightKg: draft.weightKg)
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
        try updateDailyLogWeightIfPresent(date: dayStart, weightKg: draft.weightKg)
        return entity.toModel()
    }

    // MARK: Read

    func getLatestWeight() throws -> WeightEntry? {
        var descriptor = FetchDescriptor<WeightEntryEntity>(
            sortBy: [SortDescriptor(\.date, order: .reverse)]
        )
        descriptor.fetchLimit = 1
        return try store.fetch(descriptor).first?.toModel()
    }

    func getWeightEntries(from startDate: Date?, to endDate: Date?) throws -> [WeightEntry] {
        let descriptor = FetchDescriptor<WeightEntryEntity>(
            sortBy: [SortDescriptor(\.date, order: .forward)]
        )
        var entries = try store.fetch(descriptor).map { $0.toModel() }
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
        return try store.fetch(descriptor).first
    }

    /// Updates the day's log weight only if a log already exists; this avoids
    /// requiring a user profile just to log weight.
    private func updateDailyLogWeightIfPresent(date: Date, weightKg: Double) throws {
        guard let log = try dailyLogService.dailyLogEntity(for: date) else { return }
        log.weightKg = weightKg
        log.updatedAt = dateProvider.now
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
