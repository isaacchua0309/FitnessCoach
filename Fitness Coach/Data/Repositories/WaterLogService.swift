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

    func addWater(amountMl: Int, date: Date) throws -> WaterEntry {
        try validate(amountMl: amountMl)

        let ownerUID = try UserDataOwnerScope.requiredSessionUID(
            currentUIDProvider(),
            operation: "log water"
        )
        let log = try dailyLogService.getOrCreateLogEntity(for: date)
        try UserDataOwnerScope.requireMatchingDailyLogOwner(log, sessionUID: ownerUID)

        let now = Date()
        let model = WaterEntry(
            id: UUID(),
            dailyLogId: log.id,
            amountMl: amountMl,
            createdAt: now
        )

        let entity = WaterEntryEntity(model: model)
        UserDataOwnerScope.stampNewNutritionWrite(on: entity, ownerUID: ownerUID, now: now)
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
        let sessionUID = currentUIDProvider()
        guard let last = log.waterEntries
            .filter({ UserDataOwnerScope.isVisible(entityOwnerUID: $0.ownerUID, sessionUID: sessionUID) })
            .max(by: { $0.createdAt < $1.createdAt }) else {
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
        let sessionUID = currentUIDProvider()
        return log.waterEntries
            .filter { UserDataOwnerScope.isVisible(entityOwnerUID: $0.ownerUID, sessionUID: sessionUID) }
            .sorted { $0.createdAt < $1.createdAt }
            .map { $0.toModel() }
    }

    func getWaterTotal(for date: Date) throws -> Int {
        guard let log = try dailyLogService.dailyLogEntity(for: date) else {
            return 0
        }
        let sessionUID = currentUIDProvider()
        return log.waterEntries
            .filter { UserDataOwnerScope.isVisible(entityOwnerUID: $0.ownerUID, sessionUID: sessionUID) }
            .reduce(0) { $0 + $1.amountMl }
    }

    // MARK: Helpers

    private func waterEntity(id: UUID) throws -> WaterEntryEntity? {
        guard let entity = try fetchWaterEntity(id: id) else { return nil }
        guard UserDataOwnerScope.isVisible(
            entityOwnerUID: entity.ownerUID,
            sessionUID: currentUIDProvider()
        ) else {
            return nil
        }
        return entity
    }

    private func fetchWaterEntity(id: UUID) throws -> WaterEntryEntity? {
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
