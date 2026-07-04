//
//  WaterLogService.swift
//  Fitness Coach
//
//  FitPilot AI — Owns water entry creation, undo, and hydration totals.
//
//  Write ownership: user mutations go through FitnessActionCenter only.
//  Cloud merge writes go through AccountSyncPuller (documented bypass).
//  SSOT: Docs/Architecture/SourceOfTruthMap.md §3.
//

import Foundation
import SwiftData

@MainActor
final class WaterLogService {

    /// Sanity ceiling for a single water log to catch obvious input mistakes.
    private static let maxSingleEntryMl = 5000

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

        let mutationGroupId = mutationTracker?.makeMutationGroupId()
        try dailyLogService.recalculateDailyTotals(for: log.date, mutationGroupId: mutationGroupId)
        try trackWaterUpsert(entity, dailyLog: log, mutationGroupId: mutationGroupId)
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
        guard let last = visibleWaterEntries(in: log).max(by: { $0.createdAt < $1.createdAt }) else {
            return nil
        }
        let model = last.toModel()
        let mutationGroupId = mutationTracker?.makeMutationGroupId()
        try deleteWaterEntity(last, dailyLog: log, mutationGroupId: mutationGroupId)
        try save()
        try dailyLogService.recalculateDailyTotals(for: log.date, mutationGroupId: mutationGroupId)
        return model
    }

    func deleteWaterEntry(id: UUID) throws {
        guard let entity = try waterEntity(id: id) else {
            throw ServiceError.waterEntryNotFound
        }
        let logDate = entity.dailyLog?.date
        let mutationGroupId = mutationTracker?.makeMutationGroupId()
        try deleteWaterEntity(entity, dailyLog: entity.dailyLog, mutationGroupId: mutationGroupId)
        try save()
        if let logDate {
            try dailyLogService.recalculateDailyTotals(for: logDate, mutationGroupId: mutationGroupId)
        }
    }

    // MARK: Read

    func getWaterEntries(for date: Date) throws -> [WaterEntry] {
        guard let log = try dailyLogService.dailyLogEntity(for: date) else {
            return []
        }
        return visibleWaterEntries(in: log)
            .sorted { $0.createdAt < $1.createdAt }
            .map { $0.toModel() }
    }

    func getWaterTotal(for date: Date) throws -> Int {
        guard let log = try dailyLogService.dailyLogEntity(for: date) else {
            return 0
        }
        return visibleWaterEntries(in: log).reduce(0) { $0 + $1.amountMl }
    }

    // MARK: Helpers

    private func waterEntity(id: UUID) throws -> WaterEntryEntity? {
        var descriptor = FetchDescriptor<WaterEntryEntity>(
            predicate: #Predicate { $0.id == id }
        )
        descriptor.fetchLimit = 1
        return try store.fetch(descriptor).first
    }

    private func visibleWaterEntries(in log: DailyLogEntity) -> [WaterEntryEntity] {
        log.waterEntries.filter(AccountDataSyncReadFilter.isVisible)
    }

    private func deleteWaterEntity(
        _ entity: WaterEntryEntity,
        dailyLog: DailyLogEntity?,
        mutationGroupId: String?
    ) throws {
        let localDate = dailyLog.flatMap { mutationTracker?.dailyLogCloudID(for: $0.date) }
        if let mutationTracker {
            try mutationTracker.trackDelete(
                entity: entity,
                entityType: .waterEntry,
                entityId: entity.id.uuidString,
                localDate: localDate,
                mutationGroupId: mutationGroupId,
                hardDelete: { [store] in
                    try store.delete(entity)
                }
            )
        } else {
            try store.delete(entity)
        }
    }

    private func trackWaterUpsert(
        _ entity: WaterEntryEntity,
        dailyLog: DailyLogEntity,
        mutationGroupId: String?
    ) throws {
        guard let mutationTracker else { return }
        try save()
        try mutationTracker.trackUpsert(
            entity: entity,
            entityType: .waterEntry,
            entityId: entity.id.uuidString,
            localDate: mutationTracker.dailyLogCloudID(for: dailyLog.date),
            mutationGroupId: mutationGroupId
        )
        try save()
    }

    private func validate(amountMl: Int) throws {
        guard amountMl > 0 else { throw ServiceError.invalidInput("Water amount must be greater than zero.") }
        guard amountMl <= Self.maxSingleEntryMl else {
            throw ServiceError.invalidInput("That water amount looks too large for a single entry.")
        }
    }

    private func save() throws {
        do {
            try store.save()
        } catch {
            throw ServiceError.persistenceFailed("Could not save the water entry.")
        }
    }
}
