//
//  AccountDataExportModels.swift
//  Fitness Coach
//
//  Forma — Account data export models (Phase 6).
//
//  JSON export bundle for user-initiated download. Excludes raw meal images,
//  HealthKit samples, auth tokens, and internal diagnostics.
//

import Foundation

// MARK: - Bundle

struct AccountDataExportBundle: Codable, Equatable, Sendable {
    let exportedAt: Date
    let uid: String
    let profile: ExportedProfile?
    let dailyLogs: [ExportedDailyLog]
    let foodEntries: [ExportedFoodEntry]
    let waterEntries: [ExportedWaterEntry]
    let weightEntries: [ExportedWeightEntry]
    let dailyReviews: [ExportedDailyReview]
    let syncMetadata: ExportedSyncMetadataSummary
}

// MARK: - Profile

struct ExportedProfile: Codable, Equatable, Sendable {
    let id: UUID
    let name: String?
    let birthDate: Date?
    let age: Int
    let sex: String
    let heightCm: Double
    let currentWeightKg: Double
    let goalWeightKg: Double
    let estimatedBodyFatPercentage: Double?
    let activityLevel: String
    let trainingFrequencyPerWeek: Int
    let averageSteps: Int
    let dietPreference: String?
    let unitSystem: String
    let targets: ExportedPlanTargets
    let createdAt: Date
    let updatedAt: Date
    let lastPlanUpdateReason: String?
}

struct ExportedPlanTargets: Codable, Equatable, Sendable {
    let calorieTarget: Int
    let proteinTarget: Double
    let carbTarget: Double
    let fatTarget: Double
    let waterTargetMl: Int
    let expectedWeeklyWeightLossKg: Double?
    let aggressiveness: String
}

// MARK: - Logs

struct ExportedDailyLog: Codable, Equatable, Sendable {
    let id: UUID
    let date: Date
    let weightKg: Double?
    let targets: ExportedPlanTargets
    let totals: ExportedMacroTotals
    let waterConsumedMl: Int
    let steps: Int?
    let workoutCaloriesBurned: Int
    let dailyReviewId: UUID?
    let createdAt: Date
    let updatedAt: Date
}

struct ExportedMacroTotals: Codable, Equatable, Sendable {
    let calories: Int
    let protein: Double
    let carbs: Double
    let fat: Double
    let fiber: Double?
    let sodium: Double?
}

struct ExportedFoodEntry: Codable, Equatable, Sendable {
    let id: UUID
    let dailyLogId: UUID
    let mealType: String?
    let name: String
    let quantity: Double?
    let unit: String?
    let calories: Int
    let protein: Double
    let carbs: Double
    let fat: Double
    let fiber: Double?
    let sodium: Double?
    let source: String
    let confidence: String
    let notes: String?
    let components: [ExportedFoodComponent]?
    let createdAt: Date
    let updatedAt: Date
    let syncStatus: String?
    let lastSyncedAt: Date?
}

struct ExportedFoodComponent: Codable, Equatable, Sendable {
    let name: String
    let quantity: Double?
    let unit: String?
    let calories: Int
    let protein: Double
    let carbs: Double
    let fat: Double
}

struct ExportedWaterEntry: Codable, Equatable, Sendable {
    let id: UUID
    let dailyLogId: UUID
    let amountMl: Int
    let createdAt: Date
    let syncStatus: String?
    let lastSyncedAt: Date?
}

struct ExportedWeightEntry: Codable, Equatable, Sendable {
    let id: UUID
    let date: Date
    let weightKg: Double
    let note: String?
    let createdAt: Date
    let syncStatus: String?
    let lastSyncedAt: Date?
}

struct ExportedDailyReview: Codable, Equatable, Sendable {
    let id: UUID
    let dailyLogId: UUID
    let summaryText: String
    let caloriesSummary: String
    let proteinSummary: String
    let hydrationSummary: String
    let workoutSummary: String?
    let weightSummary: String?
    let tomorrowRecommendation: String
    let createdAt: Date
    let syncStatus: String?
    let lastSyncedAt: Date?
}

// MARK: - Sync metadata

struct ExportedSyncMetadataSummary: Codable, Equatable, Sendable {
    let pendingUploadCount: Int
    let failedUploadCount: Int
    let lastSuccessfulProfileSyncAt: Date?
    let lastForegroundRefreshAt: Date?
    let lastManualRefreshAt: Date?
    let lastSuccessfulRestoreAt: Date?
    let restoreStatus: String?
}

// MARK: - Errors

enum AccountDataExportError: Error, Equatable, Sendable {
    case featureDisabled
    case unauthenticated
    case uidMismatch
    case exportDirectoryUnavailable
    case encodingFailed
}

// MARK: - Mapping

enum AccountDataExportMapping {

    static func exportedProfile(from profile: UserProfile) -> ExportedProfile {
        ExportedProfile(
            id: profile.id,
            name: profile.name,
            birthDate: profile.birthDate,
            age: profile.age,
            sex: profile.sex.rawValue,
            heightCm: profile.heightCm,
            currentWeightKg: profile.currentWeightKg,
            goalWeightKg: profile.goalWeightKg,
            estimatedBodyFatPercentage: profile.estimatedBodyFatPercentage,
            activityLevel: profile.activityLevel.rawValue,
            trainingFrequencyPerWeek: profile.trainingFrequencyPerWeek,
            averageSteps: profile.averageSteps,
            dietPreference: profile.dietPreference,
            unitSystem: profile.unitSystem.rawValue,
            targets: exportedTargets(from: profile.targets),
            createdAt: profile.createdAt,
            updatedAt: profile.updatedAt,
            lastPlanUpdateReason: profile.lastPlanUpdateReason?.rawValue
        )
    }

    static func exportedDailyLog(from log: DailyLog) -> ExportedDailyLog {
        ExportedDailyLog(
            id: log.id,
            date: log.date,
            weightKg: log.weightKg,
            targets: exportedTargets(from: log.targets),
            totals: ExportedMacroTotals(
                calories: log.totals.calories,
                protein: log.totals.protein,
                carbs: log.totals.carbs,
                fat: log.totals.fat,
                fiber: log.totals.fiber,
                sodium: log.totals.sodium
            ),
            waterConsumedMl: log.waterConsumedMl,
            steps: log.steps,
            workoutCaloriesBurned: log.workoutCaloriesBurned,
            dailyReviewId: log.dailyReviewId,
            createdAt: log.createdAt,
            updatedAt: log.updatedAt
        )
    }

    static func exportedFoodEntry(from entry: FoodEntry) -> ExportedFoodEntry {
        ExportedFoodEntry(
            id: entry.id,
            dailyLogId: entry.dailyLogId,
            mealType: entry.mealType?.rawValue,
            name: entry.name,
            quantity: entry.quantity,
            unit: entry.unit,
            calories: entry.calories,
            protein: entry.protein,
            carbs: entry.carbs,
            fat: entry.fat,
            fiber: entry.fiber,
            sodium: entry.sodium,
            source: entry.source.rawValue,
            confidence: entry.confidence.rawValue,
            notes: entry.notes,
            components: entry.components?.map(exportedFoodComponent),
            createdAt: entry.createdAt,
            updatedAt: entry.updatedAt,
            syncStatus: nil,
            lastSyncedAt: nil
        )
    }

    static func exportedFoodEntry(
        from entity: FoodEntryEntity,
        allowedDailyLogIDs: Set<UUID>
    ) -> ExportedFoodEntry? {
        guard allowedDailyLogIDs.contains(entity.dailyLogId) else { return nil }
        guard AccountDataSyncReadFilter.isVisible(entity) else { return nil }

        let model = entity.toModel()
        return ExportedFoodEntry(
            id: model.id,
            dailyLogId: model.dailyLogId,
            mealType: model.mealType?.rawValue,
            name: model.name,
            quantity: model.quantity,
            unit: model.unit,
            calories: model.calories,
            protein: model.protein,
            carbs: model.carbs,
            fat: model.fat,
            fiber: model.fiber,
            sodium: model.sodium,
            source: model.source.rawValue,
            confidence: model.confidence.rawValue,
            notes: model.notes,
            components: model.components?.map(exportedFoodComponent),
            createdAt: model.createdAt,
            updatedAt: model.updatedAt,
            syncStatus: safeSyncStatus(from: entity),
            lastSyncedAt: entity.lastSyncedAt
        )
    }

    static func exportedWaterEntry(
        from entity: WaterEntryEntity,
        allowedDailyLogIDs: Set<UUID>
    ) -> ExportedWaterEntry? {
        guard allowedDailyLogIDs.contains(entity.dailyLogId) else { return nil }
        guard AccountDataSyncReadFilter.isVisible(entity) else { return nil }

        let model = entity.toModel()
        return ExportedWaterEntry(
            id: model.id,
            dailyLogId: model.dailyLogId,
            amountMl: model.amountMl,
            createdAt: model.createdAt,
            syncStatus: safeSyncStatus(from: entity),
            lastSyncedAt: entity.lastSyncedAt
        )
    }

    static func exportedWeightEntry(from entity: WeightEntryEntity) -> ExportedWeightEntry? {
        guard AccountDataSyncReadFilter.isVisible(entity) else { return nil }

        let model = entity.toModel()
        return ExportedWeightEntry(
            id: model.id,
            date: model.date,
            weightKg: model.weightKg,
            note: model.note,
            createdAt: model.createdAt,
            syncStatus: safeSyncStatus(from: entity),
            lastSyncedAt: entity.lastSyncedAt
        )
    }

    static func exportedDailyReview(
        from entity: DailyReviewEntity,
        allowedDailyLogIDs: Set<UUID>
    ) -> ExportedDailyReview? {
        guard allowedDailyLogIDs.contains(entity.dailyLogId) else { return nil }
        guard AccountDataSyncReadFilter.isVisible(entity) else { return nil }

        let model = entity.toModel()
        return ExportedDailyReview(
            id: model.id,
            dailyLogId: model.dailyLogId,
            summaryText: model.summaryText,
            caloriesSummary: model.caloriesSummary,
            proteinSummary: model.proteinSummary,
            hydrationSummary: model.hydrationSummary,
            workoutSummary: model.workoutSummary,
            weightSummary: model.weightSummary,
            tomorrowRecommendation: model.tomorrowRecommendation,
            createdAt: model.createdAt,
            syncStatus: safeSyncStatus(from: entity),
            lastSyncedAt: entity.lastSyncedAt
        )
    }

    static func exportedSyncMetadata(
        pendingUploadCount: Int,
        failedUploadCount: Int,
        profileCloudSyncStore: ProfileCloudSyncStore,
        uid: String,
        cursor: AccountSyncCursor,
        restoreState: AccountRestoreStoredState
    ) -> ExportedSyncMetadataSummary {
        ExportedSyncMetadataSummary(
            pendingUploadCount: pendingUploadCount,
            failedUploadCount: failedUploadCount,
            lastSuccessfulProfileSyncAt: profileCloudSyncStore.isSyncedForUID(uid)
                ? profileCloudSyncStore.lastSyncedProfileUpdatedAt
                : nil,
            lastForegroundRefreshAt: cursor.lastForegroundRefreshAt,
            lastManualRefreshAt: cursor.lastManualRefreshAt,
            lastSuccessfulRestoreAt: restoreState.lastSuccessfulBlockingRestoreAt
                ?? restoreState.lastSuccessfulBackgroundBackfillAt,
            restoreStatus: restoreState.status == .notStarted ? nil : restoreState.status.rawValue
        )
    }

    private static func exportedTargets(from targets: UserTargets) -> ExportedPlanTargets {
        ExportedPlanTargets(
            calorieTarget: targets.calorieTarget,
            proteinTarget: targets.proteinTarget,
            carbTarget: targets.carbTarget,
            fatTarget: targets.fatTarget,
            waterTargetMl: targets.waterTargetMl,
            expectedWeeklyWeightLossKg: targets.expectedWeeklyWeightLossKg,
            aggressiveness: targets.aggressiveness.rawValue
        )
    }

    private static func exportedFoodComponent(from component: FoodComponent) -> ExportedFoodComponent {
        ExportedFoodComponent(
            name: component.name,
            quantity: component.quantity,
            unit: component.unit,
            calories: component.calories,
            protein: component.protein,
            carbs: component.carbs,
            fat: component.fat
        )
    }

    private static func safeSyncStatus(from entity: AccountDataSyncMetadataEntity) -> String? {
        AccountDataSyncStatus(rawValue: entity.syncStatusRawValue)?.rawValue
    }
}
