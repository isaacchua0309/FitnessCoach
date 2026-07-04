//
//  CloudNutritionDocumentMapping.swift
//  Fitness Coach
//
//  Forma — Maps local nutrition models to Firestore DTOs (Phase 2).
//

import Foundation
#if canImport(UIKit)
import UIKit
#endif

struct CloudNutritionSyncMappingContext: Sendable {
    var userId: String
    var calendar: Calendar
    var timeZoneIdentifier: String
    var deviceId: String
    var appVersion: String
    var now: Date
    var mutationId: String?

    init(
        userId: String,
        calendar: Calendar = .current,
        timeZoneIdentifier: String? = nil,
        deviceId: String = CloudNutritionSyncMappingContext.defaultDeviceId,
        appVersion: String = CloudNutritionSyncMappingContext.defaultAppVersion,
        now: Date = Date(),
        mutationId: String? = nil
    ) {
        self.userId = userId
        self.calendar = calendar
        self.timeZoneIdentifier = timeZoneIdentifier ?? calendar.timeZone.identifier
        self.deviceId = deviceId
        self.appVersion = appVersion
        self.now = now
        self.mutationId = mutationId
    }

    static var defaultDeviceId: String {
        #if canImport(UIKit)
        return "ios-\(UIDevice.current.identifierForVendor?.uuidString ?? "unknown")"
        #else
        return "unknown-device"
        #endif
    }

    static var defaultAppVersion: String {
        Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "unknown"
    }

    func localDateString(for date: Date) -> String {
        CloudNutritionDateCodec.localDateString(from: date, calendar: calendar)
    }

    func dayDocumentID(for date: Date) -> String {
        localDateString(for: date)
    }
}

enum CloudNutritionDateCodec {

    static func localDateString(from date: Date, calendar: Calendar) -> String {
        let components = calendar.dateComponents([.year, .month, .day], from: date)
        guard let year = components.year, let month = components.month, let day = components.day else {
            return ISO8601DateFormatter().string(from: date)
        }
        return String(format: "%04d-%02d-%02d", year, month, day)
    }

    static func date(fromLocalDateString value: String, calendar: Calendar) -> Date? {
        let parts = value.split(separator: "-")
        guard parts.count == 3,
              let year = Int(parts[0]),
              let month = Int(parts[1]),
              let day = Int(parts[2]) else {
            return nil
        }
        return calendar.date(from: DateComponents(year: year, month: month, day: day))
    }
}

enum CloudNutritionDocumentMapping {

    // MARK: - Sync metadata

    static func makeSyncMetadataDocument(context: CloudNutritionSyncMappingContext) -> CloudSyncMetadataDocument {
        CloudSyncMetadataDocument(
            userId: context.userId,
            schemaVersion: AccountDataCloudSchema.currentSchemaVersion,
            lastFullPullAt: nil,
            lastSuccessfulPushAt: nil,
            lastSuccessfulPullAt: nil,
            lastKnownServerUpdatedAt: nil,
            lastMigrationAt: nil,
            lastDeviceId: context.deviceId,
            clientVersion: context.appVersion,
            updatedAt: context.now
        )
    }

    // MARK: - Daily log

    static func makeCloudDailyLogDocument(
        from log: DailyLog,
        context: CloudNutritionSyncMappingContext
    ) -> CloudDailyLogDocument {
        let localDate = context.localDateString(for: log.date)
        return CloudDailyLogDocument(
            id: localDate,
            userId: context.userId,
            localDate: localDate,
            timezone: context.timeZoneIdentifier,
            calorieTarget: log.targets.calorieTarget,
            proteinTarget: log.targets.proteinTarget,
            carbTarget: log.targets.carbTarget,
            fatTarget: log.targets.fatTarget,
            waterTargetMl: log.targets.waterTargetMl,
            expectedWeeklyWeightLossKg: log.targets.expectedWeeklyWeightLossKg,
            aggressiveness: log.targets.aggressiveness.rawValue,
            caloriesConsumed: log.totals.calories,
            proteinConsumed: log.totals.protein,
            carbsConsumed: log.totals.carbs,
            fatConsumed: log.totals.fat,
            fiberConsumed: log.totals.fiber,
            sodiumConsumed: log.totals.sodium,
            waterConsumedMl: log.waterConsumedMl,
            steps: log.steps,
            workoutCaloriesBurned: log.workoutCaloriesBurned,
            weightKg: log.weightKg,
            dailyReviewId: log.dailyReviewId?.uuidString,
            schemaVersion: AccountDataCloudSchema.currentSchemaVersion,
            updatedAt: log.updatedAt,
            createdAt: log.createdAt,
            deletedAt: nil,
            mutationId: context.mutationId,
            deviceId: context.deviceId,
            source: AccountDataCloudSchema.clientSource
        )
    }

    static func makeDailyLog(
        from document: CloudDailyLogDocument,
        calendar: Calendar
    ) -> DailyLog? {
        guard let date = CloudNutritionDateCodec.date(fromLocalDateString: document.localDate, calendar: calendar) else {
            return nil
        }
        return DailyLog(
            id: UUID(),
            date: date,
            weightKg: document.weightKg,
            targets: UserTargets(
                calorieTarget: document.calorieTarget,
                proteinTarget: document.proteinTarget,
                carbTarget: document.carbTarget,
                fatTarget: document.fatTarget,
                waterTargetMl: document.waterTargetMl,
                expectedWeeklyWeightLossKg: document.expectedWeeklyWeightLossKg,
                aggressiveness: CalorieAggressiveness(rawValue: document.aggressiveness) ?? .moderate
            ),
            totals: MacroTotals(
                calories: document.caloriesConsumed,
                protein: document.proteinConsumed,
                carbs: document.carbsConsumed,
                fat: document.fatConsumed,
                fiber: document.fiberConsumed,
                sodium: document.sodiumConsumed
            ),
            waterConsumedMl: document.waterConsumedMl,
            steps: document.steps,
            workoutCaloriesBurned: document.workoutCaloriesBurned,
            dailyReviewId: document.dailyReviewId.flatMap(UUID.init(uuidString:)),
            createdAt: document.createdAt,
            updatedAt: document.updatedAt
        )
    }

    // MARK: - Food

    static func makeCloudFoodEntryDocument(
        from entry: FoodEntry,
        logDate: Date,
        context: CloudNutritionSyncMappingContext
    ) -> CloudFoodEntryDocument {
        let localDate = context.localDateString(for: logDate)
        let componentsJSON: String?
        if entry.isMultiComponent, let components = entry.components {
            componentsJSON = encodeComponents(components)
        } else {
            componentsJSON = nil
        }

        return CloudFoodEntryDocument(
            id: entry.id.uuidString,
            userId: context.userId,
            dailyLogId: entry.dailyLogId.uuidString,
            localDate: localDate,
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
            imageUrl: entry.imageUrl,
            notes: entry.notes,
            componentsJSON: componentsJSON,
            schemaVersion: AccountDataCloudSchema.currentSchemaVersion,
            updatedAt: entry.updatedAt,
            createdAt: entry.createdAt,
            deletedAt: nil,
            deviceId: context.deviceId,
            mutationId: context.mutationId
        )
    }

    static func makeFoodEntry(from document: CloudFoodEntryDocument) -> FoodEntry {
        FoodEntry(
            id: UUID(uuidString: document.id) ?? UUID(),
            dailyLogId: UUID(uuidString: document.dailyLogId) ?? UUID(),
            mealType: document.mealType.flatMap(MealType.init(rawValue:)),
            name: document.name,
            quantity: document.quantity,
            unit: document.unit,
            calories: document.calories,
            protein: document.protein,
            carbs: document.carbs,
            fat: document.fat,
            fiber: document.fiber,
            sodium: document.sodium,
            source: FoodEntrySource(rawValue: document.source) ?? .manual,
            confidence: ConfidenceLevel(rawValue: document.confidence) ?? .low,
            imageUrl: document.imageUrl,
            notes: document.notes,
            components: decodeComponents(document.componentsJSON),
            createdAt: document.createdAt,
            updatedAt: document.updatedAt
        )
    }

    // MARK: - Water

    static func makeCloudWaterEntryDocument(
        from entry: WaterEntry,
        logDate: Date,
        context: CloudNutritionSyncMappingContext
    ) -> CloudWaterEntryDocument {
        CloudWaterEntryDocument(
            id: entry.id.uuidString,
            userId: context.userId,
            dailyLogId: entry.dailyLogId.uuidString,
            localDate: context.localDateString(for: logDate),
            amountMl: entry.amountMl,
            schemaVersion: AccountDataCloudSchema.currentSchemaVersion,
            updatedAt: entry.createdAt,
            createdAt: entry.createdAt,
            deletedAt: nil,
            deviceId: context.deviceId,
            source: AccountDataCloudSchema.clientSource,
            mutationId: context.mutationId
        )
    }

    static func makeWaterEntry(from document: CloudWaterEntryDocument) -> WaterEntry {
        WaterEntry(
            id: UUID(uuidString: document.id) ?? UUID(),
            dailyLogId: UUID(uuidString: document.dailyLogId) ?? UUID(),
            amountMl: document.amountMl,
            createdAt: document.createdAt
        )
    }

    // MARK: - Weight

    static func makeCloudWeightEntryDocument(
        from entry: WeightEntry,
        context: CloudNutritionSyncMappingContext
    ) -> CloudWeightEntryDocument {
        CloudWeightEntryDocument(
            id: entry.id.uuidString,
            userId: context.userId,
            localDate: context.localDateString(for: entry.date),
            weightKg: entry.weightKg,
            note: entry.note,
            schemaVersion: AccountDataCloudSchema.currentSchemaVersion,
            updatedAt: entry.createdAt,
            createdAt: entry.createdAt,
            deletedAt: nil,
            deviceId: context.deviceId,
            source: AccountDataCloudSchema.clientSource,
            mutationId: context.mutationId
        )
    }

    static func makeWeightEntry(
        from document: CloudWeightEntryDocument,
        calendar: Calendar
    ) -> WeightEntry? {
        guard let date = CloudNutritionDateCodec.date(fromLocalDateString: document.localDate, calendar: calendar) else {
            return nil
        }
        return WeightEntry(
            id: UUID(uuidString: document.id) ?? UUID(),
            date: date,
            weightKg: document.weightKg,
            note: document.note,
            createdAt: document.createdAt
        )
    }

    // MARK: - Daily review

    static func makeCloudDailyReviewDocument(
        from review: DailyReview,
        logDate: Date,
        context: CloudNutritionSyncMappingContext
    ) -> CloudDailyReviewDocument {
        CloudDailyReviewDocument(
            id: review.id.uuidString,
            userId: context.userId,
            dailyLogId: review.dailyLogId.uuidString,
            localDate: context.localDateString(for: logDate),
            summaryText: review.summaryText,
            caloriesSummary: review.caloriesSummary,
            proteinSummary: review.proteinSummary,
            hydrationSummary: review.hydrationSummary,
            workoutSummary: review.workoutSummary,
            weightSummary: review.weightSummary,
            tomorrowRecommendation: review.tomorrowRecommendation,
            schemaVersion: AccountDataCloudSchema.currentSchemaVersion,
            updatedAt: review.createdAt,
            createdAt: review.createdAt,
            deletedAt: nil,
            deviceId: context.deviceId,
            source: AccountDataCloudSchema.clientSource,
            mutationId: context.mutationId
        )
    }

    static func makeDailyReview(from document: CloudDailyReviewDocument) -> DailyReview {
        DailyReview(
            id: UUID(uuidString: document.id) ?? UUID(),
            dailyLogId: UUID(uuidString: document.dailyLogId) ?? UUID(),
            summaryText: document.summaryText,
            caloriesSummary: document.caloriesSummary,
            proteinSummary: document.proteinSummary,
            hydrationSummary: document.hydrationSummary,
            workoutSummary: document.workoutSummary,
            weightSummary: document.weightSummary,
            tomorrowRecommendation: document.tomorrowRecommendation,
            createdAt: document.createdAt
        )
    }

    // MARK: - JSON helpers

    static func encodeComponents(_ components: [FoodComponent]) -> String? {
        guard let data = try? JSONEncoder().encode(components) else { return nil }
        return String(data: data, encoding: .utf8)
    }

    static func decodeComponents(_ json: String?) -> [FoodComponent]? {
        guard let json,
              let data = json.data(using: .utf8),
              let components = try? JSONDecoder().decode([FoodComponent].self, from: data),
              !components.isEmpty else {
            return nil
        }
        return components
    }
}
