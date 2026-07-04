//
//  DailyLogService.swift
//  Fitness Coach
//
//  FitPilot AI — Owns the daily log lifecycle and summary state.
//

import Foundation
import SwiftData

@MainActor
final class DailyLogService {

    private let store: SwiftDataStore
    private let userProfileService: UserProfileService
    private let dateProvider: DateProviding
    private let currentUIDProvider: () -> String?

    init(
        store: SwiftDataStore,
        userProfileService: UserProfileService,
        dateProvider: DateProviding? = nil,
        currentUIDProvider: @escaping () -> String? = { nil }
    ) {
        self.store = store
        self.userProfileService = userProfileService
        self.dateProvider = dateProvider ?? SystemDateProvider()
        self.currentUIDProvider = currentUIDProvider
    }

    // MARK: Read

    func getTodayLog() throws -> DailyLog {
        try getOrCreateLog(for: dateProvider.now)
    }

    func getLog(for date: Date) throws -> DailyLog? {
        guard let entity = try dailyLogEntity(for: date) else { return nil }
        if isToday(date) {
            try syncTargetsFromProfile(to: entity)
        }
        return entity.toModel()
    }

    func getOrCreateLog(for date: Date) throws -> DailyLog {
        try getOrCreateLogEntity(for: date).toModel()
    }

    func getLogs(from startDate: Date, to endDate: Date) throws -> [DailyLog] {
        let lowerBound = dateProvider.startOfDay(for: startDate)
        let upperBound = dateProvider.startOfDay(for: endDate)
        let sessionUID = currentUIDProvider()
        let entities: [DailyLogEntity]

        if let sessionUID {
            let descriptor = FetchDescriptor<DailyLogEntity>(
                predicate: #Predicate {
                    $0.date >= lowerBound && $0.date <= upperBound && $0.ownerUID == sessionUID
                },
                sortBy: [SortDescriptor(\.date, order: .forward)]
            )
            entities = try store.fetch(descriptor)
        } else {
            let descriptor = FetchDescriptor<DailyLogEntity>(
                predicate: #Predicate {
                    $0.date >= lowerBound && $0.date <= upperBound && $0.ownerUID == nil
                },
                sortBy: [SortDescriptor(\.date, order: .forward)]
            )
            entities = try store.fetch(descriptor)
        }

        return entities.map { $0.toModel() }
    }

    // MARK: New Day

    /// Ensures today's log exists. Days are keyed by calendar date and created
    /// automatically when first accessed—there is no manual day reset.
    func ensureTodayLog() throws -> DailyLog {
        try getOrCreateLog(for: dateProvider.now)
    }

    // MARK: Recalculation

    @discardableResult
    func recalculateDailyTotals(for date: Date) throws -> DailyLog {
        guard let entity = try dailyLogEntity(for: date) else {
            throw ServiceError.dailyLogNotFound
        }

        let foodModels = UserDataOwnerScope.filterVisibleNutritionEntities(
            entity.foodEntries,
            sessionUID: currentUIDProvider()
        ).map { $0.toModel() }
        let totals = MacroCalculator.totals(from: foodModels)

        let waterTotal = UserDataOwnerScope.filterVisibleNutritionEntities(
            entity.waterEntries,
            sessionUID: currentUIDProvider()
        ).reduce(0) { $0 + $1.amountMl }
        // Legacy manual workout rows are retired; training reads use Apple Health.
        // Preserve any stored summary value when recalculating food/water totals.
        let workoutCalories = entity.workoutCaloriesBurned

        entity.caloriesConsumed = totals.calories
        entity.proteinConsumed = totals.protein
        entity.carbsConsumed = totals.carbs
        entity.fatConsumed = totals.fat
        entity.fiberConsumed = totals.fiber
        entity.sodiumConsumed = totals.sodium
        entity.waterConsumedMl = waterTotal
        entity.workoutCaloriesBurned = workoutCalories
        let now = dateProvider.now
        entity.updatedAt = now
        UserDataOwnerScope.touchNutritionWrite(on: entity, now: now)

        try save()
        return entity.toModel()
    }

    // MARK: Internal Entity Access

    /// Returns the persistence entity for a date, used internally by sibling
    /// log services to attach relationships. Not exposed to the feature layer.
    func dailyLogEntity(for date: Date) throws -> DailyLogEntity? {
        let dayStart = dateProvider.startOfDay(for: date)
        let sessionUID = currentUIDProvider()

        if let sessionUID {
            var descriptor = FetchDescriptor<DailyLogEntity>(
                predicate: #Predicate {
                    $0.date == dayStart && $0.ownerUID == sessionUID
                }
            )
            descriptor.fetchLimit = 1
            return try store.fetch(descriptor).first
        }

        var descriptor = FetchDescriptor<DailyLogEntity>(
            predicate: #Predicate {
                $0.date == dayStart && $0.ownerUID == nil
            }
        )
        descriptor.fetchLimit = 1
        return try store.fetch(descriptor).first
    }

    func getOrCreateLogEntity(for date: Date) throws -> DailyLogEntity {
        if let existing = try dailyLogEntity(for: date) {
            if isToday(date) {
                try syncTargetsFromProfile(to: existing)
            }
            return existing
        }

        let ownerUID = try UserDataOwnerScope.requiredSessionUID(
            currentUIDProvider(),
            operation: "create daily log"
        )

        guard let profile = try userProfileService.getCurrentProfile() else {
            throw ServiceError.missingUserProfile
        }

        let now = dateProvider.now
        let dayStart = dateProvider.startOfDay(for: date)
        let log = DailyLog(
            id: UUID(),
            date: dayStart,
            weightKg: nil,
            targets: profile.targets,
            totals: MacroTotals(calories: 0, protein: 0, carbs: 0, fat: 0, fiber: nil, sodium: nil),
            waterConsumedMl: 0,
            steps: nil,
            workoutCaloriesBurned: 0,
            dailyReviewId: nil,
            createdAt: now,
            updatedAt: now
        )

        let entity = DailyLogEntity(model: log)
        UserDataOwnerScope.stampNewNutritionWrite(on: entity, ownerUID: ownerUID, now: now)
        try store.insert(entity)
        return entity
    }

    // MARK: Target Sync

    /// Copies the current profile targets onto today's daily log. Past days keep
    /// their snapshot so historical progress stays accurate.
    func syncTodayTargetsFromProfile() throws {
        guard let entity = try dailyLogEntity(for: dateProvider.now) else { return }
        try syncTargetsFromProfile(to: entity)
    }

    private func syncTargetsFromProfile(to entity: DailyLogEntity) throws {
        guard let profile = try userProfileService.getCurrentProfile() else {
            throw ServiceError.missingUserProfile
        }

        let targets = profile.targets
        guard entityTargets(entity) != targets else { return }

        entity.calorieTarget = targets.calorieTarget
        entity.proteinTarget = targets.proteinTarget
        entity.carbTarget = targets.carbTarget
        entity.fatTarget = targets.fatTarget
        entity.waterTargetMl = targets.waterTargetMl
        entity.expectedWeeklyWeightLossKg = targets.expectedWeeklyWeightLossKg
        entity.aggressivenessRawValue = targets.aggressiveness.rawValue
        let now = dateProvider.now
        entity.updatedAt = now
        UserDataOwnerScope.touchNutritionWrite(on: entity, now: now)
        try save()
    }

    private func entityTargets(_ entity: DailyLogEntity) -> UserTargets {
        UserTargets(
            calorieTarget: entity.calorieTarget,
            proteinTarget: entity.proteinTarget,
            carbTarget: entity.carbTarget,
            fatTarget: entity.fatTarget,
            waterTargetMl: entity.waterTargetMl,
            expectedWeeklyWeightLossKg: entity.expectedWeeklyWeightLossKg,
            aggressiveness: CalorieAggressiveness(rawValue: entity.aggressivenessRawValue) ?? .moderate
        )
    }

    private func isToday(_ date: Date) -> Bool {
        dateProvider.startOfDay(for: date) == dateProvider.startOfDay(for: dateProvider.now)
    }

    // MARK: Helpers

    private func save() throws {
        do {
            try store.save()
        } catch {
            throw ServiceError.persistenceFailed("Could not save the daily log.")
        }
    }
}
