//
//  WaterLogService.swift
//  Fitness Coach
//
//  FitPilot AI — Owns water entry creation, undo, and hydration totals.
//

import Foundation
import SwiftData

@MainActor
final class WaterLogService {

    /// Sanity ceiling for a single water log to catch obvious input mistakes.
    private static let maxSingleEntryMl = 5000

    private let store: SwiftDataStore
    private let dailyLogService: DailyLogService

    init(store: SwiftDataStore, dailyLogService: DailyLogService) {
        self.store = store
        self.dailyLogService = dailyLogService
    }

    // MARK: Create

    func addWater(amountMl: Int, date: Date) throws -> WaterEntry {
        try validate(amountMl: amountMl)

        let log = try dailyLogService.getOrCreateLogEntity(for: date)
        let model = WaterEntry(
            id: UUID(),
            dailyLogId: log.id,
            amountMl: amountMl,
            createdAt: Date()
        )

        let entity = WaterEntryEntity(model: model)
        entity.dailyLog = log
        try store.insert(entity)
        try dailyLogService.recalculateDailyTotals(for: log.date)
        return entity.toModel()
    }

    func addWater(_ draft: WaterDraft, date: Date) throws -> WaterEntry {
        try addWater(amountMl: draft.amountMl, date: date)
    }

    // MARK: Undo

    func undoLastWaterEntry(date: Date) throws -> WaterEntry? {
        guard let log = try dailyLogService.dailyLogEntity(for: date) else {
            return nil
        }
        guard let last = log.waterEntries.max(by: { $0.createdAt < $1.createdAt }) else {
            return nil
        }
        let model = last.toModel()
        try store.delete(last)
        try dailyLogService.recalculateDailyTotals(for: log.date)
        return model
    }

    func deleteWaterEntry(id: UUID) throws {
        guard let entity = try waterEntity(id: id) else {
            throw ServiceError.waterEntryNotFound
        }
        let logDate = entity.dailyLog?.date
        try store.delete(entity)
        if let logDate {
            try dailyLogService.recalculateDailyTotals(for: logDate)
        }
    }

    // MARK: Read

    func getWaterEntries(for date: Date) throws -> [WaterEntry] {
        guard let log = try dailyLogService.dailyLogEntity(for: date) else {
            return []
        }
        return log.waterEntries
            .sorted { $0.createdAt < $1.createdAt }
            .map { $0.toModel() }
    }

    func getWaterTotal(for date: Date) throws -> Int {
        guard let log = try dailyLogService.dailyLogEntity(for: date) else {
            return 0
        }
        return log.waterEntries.reduce(0) { $0 + $1.amountMl }
    }

    // MARK: Helpers

    private func waterEntity(id: UUID) throws -> WaterEntryEntity? {
        var descriptor = FetchDescriptor<WaterEntryEntity>(
            predicate: #Predicate { $0.id == id }
        )
        descriptor.fetchLimit = 1
        return try store.fetch(descriptor).first
    }

    private func validate(amountMl: Int) throws {
        guard amountMl > 0 else { throw ServiceError.invalidInput("Water amount must be greater than zero.") }
        guard amountMl <= Self.maxSingleEntryMl else {
            throw ServiceError.invalidInput("That water amount looks too large for a single entry.")
        }
    }
}
