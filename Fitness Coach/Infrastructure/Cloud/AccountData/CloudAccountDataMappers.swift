//
//  CloudAccountDataMappers.swift
//  Fitness Coach
//
//  Forma — Maps local domain/entity models to account data cloud DTOs (Phase 2).
//
//  Mapping only. No Firestore writes or sync engine wiring.
//

import Foundation
#if canImport(UIKit)
import UIKit
#endif

enum CloudAccountDataMappingError: Error, Equatable {
    case missingOwnerUID(entity: String, id: String)
    case ownerMismatch(entity: String, id: String)
    case invalidDate(entity: String, id: String)
    case unsupportedPayload(entity: String, id: String)
}

struct CloudAccountDataMappingContext: Sendable {
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
        deviceId: String = CloudAccountDataMappingContext.defaultDeviceId,
        appVersion: String = CloudAccountDataMappingContext.defaultAppVersion,
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
        CloudAccountDataDateCodec.localDateString(from: date, calendar: calendar)
    }
}

protocol CloudAccountDataOwnerEntity: AnyObject {
    var ownerUID: String? { get }
}

extension DailyLogEntity: CloudAccountDataOwnerEntity {}
extension FoodEntryEntity: CloudAccountDataOwnerEntity {}
extension WaterEntryEntity: CloudAccountDataOwnerEntity {}
extension WeightEntryEntity: CloudAccountDataOwnerEntity {}
extension DailyReviewEntity: CloudAccountDataOwnerEntity {}

enum CloudAccountDataDateCodec {

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

enum CloudAccountDataMappers {

    // MARK: - Validation

    static func normalizedUserId(_ userId: String) throws -> String {
        let trimmed = userId.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else {
            throw CloudAccountDataMappingError.unsupportedPayload(entity: "mappingContext", id: "userId")
        }
        return trimmed
    }

    static func validateEntityOwnership(
        _ entity: any CloudAccountDataOwnerEntity,
        entityName: String,
        id: String,
        userId: String
    ) throws {
        let normalizedUserId = try normalizedUserId(userId)
        guard let ownerUID = entity.ownerUID?.trimmingCharacters(in: .whitespacesAndNewlines),
              !ownerUID.isEmpty else {
            throw CloudAccountDataMappingError.missingOwnerUID(entity: entityName, id: id)
        }
        guard ownerUID == normalizedUserId else {
            throw CloudAccountDataMappingError.ownerMismatch(entity: entityName, id: id)
        }
    }

    static func validateCloudUserId(_ documentUserId: String, context: CloudAccountDataMappingContext) throws -> String {
        let normalizedContextUserId = try normalizedUserId(context.userId)
        let normalizedDocumentUserId = documentUserId.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !normalizedDocumentUserId.isEmpty else {
            throw CloudAccountDataMappingError.unsupportedPayload(entity: "cloudDocument", id: "userId")
        }
        guard normalizedDocumentUserId == normalizedContextUserId else {
            throw CloudAccountDataMappingError.ownerMismatch(entity: "cloudDocument", id: normalizedDocumentUserId)
        }
        return normalizedDocumentUserId
    }

    // MARK: - Daily log (domain)

    static func cloudDocument(
        from log: DailyLog,
        context: CloudAccountDataMappingContext
    ) throws -> CloudDailyLogDocument {
        let userId = try normalizedUserId(context.userId)
        let localDate = context.localDateString(for: log.date)
        return CloudDailyLogDocument(
            id: localDate,
            userId: userId,
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
            createdAt: log.createdAt,
            updatedAt: log.updatedAt,
            deletedAt: nil,
            deviceId: context.deviceId,
            source: AccountDataCloudSchema.clientSource,
            mutationId: context.mutationId
        )
    }

    static func domainModel(
        from document: CloudDailyLogDocument,
        calendar: Calendar
    ) throws -> DailyLog {
        guard let date = CloudAccountDataDateCodec.date(fromLocalDateString: document.localDate, calendar: calendar) else {
            throw CloudAccountDataMappingError.invalidDate(entity: "DailyLog", id: document.id)
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

    // MARK: - Daily log (entity)

    static func cloudDocument(
        from entity: DailyLogEntity,
        context: CloudAccountDataMappingContext
    ) throws -> CloudDailyLogDocument {
        try validateEntityOwnership(
            entity,
            entityName: "DailyLogEntity",
            id: entity.id.uuidString,
            userId: context.userId
        )
        return try cloudDocument(from: entity.toModel(), context: context)
    }

    static func entity(
        from document: CloudDailyLogDocument,
        context: CloudAccountDataMappingContext
    ) throws -> DailyLogEntity {
        let ownerUID = try validateCloudUserId(document.userId, context: context)
        guard let date = CloudAccountDataDateCodec.date(fromLocalDateString: document.localDate, calendar: context.calendar) else {
            throw CloudAccountDataMappingError.invalidDate(entity: "DailyLogEntity", id: document.id)
        }
        return DailyLogEntity(
            id: UUID(),
            ownerUID: ownerUID,
            date: date,
            weightKg: document.weightKg,
            calorieTarget: document.calorieTarget,
            proteinTarget: document.proteinTarget,
            carbTarget: document.carbTarget,
            fatTarget: document.fatTarget,
            waterTargetMl: document.waterTargetMl,
            expectedWeeklyWeightLossKg: document.expectedWeeklyWeightLossKg,
            aggressivenessRawValue: document.aggressiveness,
            caloriesConsumed: document.caloriesConsumed,
            proteinConsumed: document.proteinConsumed,
            carbsConsumed: document.carbsConsumed,
            fatConsumed: document.fatConsumed,
            fiberConsumed: document.fiberConsumed,
            sodiumConsumed: document.sodiumConsumed,
            waterConsumedMl: document.waterConsumedMl,
            steps: document.steps,
            workoutCaloriesBurned: document.workoutCaloriesBurned,
            dailyReviewId: document.dailyReviewId.flatMap(UUID.init(uuidString:)),
            createdAt: document.createdAt,
            updatedAt: document.updatedAt
        )
    }

    // MARK: - Food entry (domain)

    static func cloudDocument(
        from entry: FoodEntry,
        logDate: Date,
        context: CloudAccountDataMappingContext
    ) throws -> CloudFoodEntryDocument {
        let userId = try normalizedUserId(context.userId)
        let localDate = context.localDateString(for: logDate)
        let componentsJSON: String?
        if entry.isMultiComponent, let components = entry.components {
            componentsJSON = encodeComponents(components)
        } else {
            componentsJSON = nil
        }

        return CloudFoodEntryDocument(
            id: entry.id.uuidString,
            userId: userId,
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
            createdAt: entry.createdAt,
            updatedAt: entry.updatedAt,
            deletedAt: nil,
            deviceId: context.deviceId,
            mutationId: context.mutationId
        )
    }

    static func domainModel(from document: CloudFoodEntryDocument) throws -> FoodEntry {
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

    // MARK: - Food entry (entity)

    static func cloudDocument(
        from entity: FoodEntryEntity,
        logDate: Date,
        context: CloudAccountDataMappingContext
    ) throws -> CloudFoodEntryDocument {
        try validateEntityOwnership(
            entity,
            entityName: "FoodEntryEntity",
            id: entity.id.uuidString,
            userId: context.userId
        )
        return try cloudDocument(from: entity.toModel(), logDate: logDate, context: context)
    }

    static func entity(
        from document: CloudFoodEntryDocument,
        context: CloudAccountDataMappingContext
    ) throws -> FoodEntryEntity {
        let ownerUID = try validateCloudUserId(document.userId, context: context)
        return FoodEntryEntity(
            id: UUID(uuidString: document.id) ?? UUID(),
            ownerUID: ownerUID,
            dailyLogId: UUID(uuidString: document.dailyLogId) ?? UUID(),
            mealTypeRawValue: document.mealType,
            name: document.name,
            quantity: document.quantity,
            unit: document.unit,
            calories: document.calories,
            protein: document.protein,
            carbs: document.carbs,
            fat: document.fat,
            fiber: document.fiber,
            sodium: document.sodium,
            sourceRawValue: document.source,
            confidenceRawValue: document.confidence,
            imageUrl: document.imageUrl,
            notes: document.notes,
            componentsJSON: document.componentsJSON,
            createdAt: document.createdAt,
            updatedAt: document.updatedAt
        )
    }

    // MARK: - Water entry (domain)

    static func cloudDocument(
        from entry: WaterEntry,
        logDate: Date,
        context: CloudAccountDataMappingContext
    ) throws -> CloudWaterEntryDocument {
        let userId = try normalizedUserId(context.userId)
        // Water entries only persist `createdAt` locally; mirror it for cloud `updatedAt`.
        let timestamp = entry.createdAt
        return CloudWaterEntryDocument(
            id: entry.id.uuidString,
            userId: userId,
            dailyLogId: entry.dailyLogId.uuidString,
            localDate: context.localDateString(for: logDate),
            amountMl: entry.amountMl,
            schemaVersion: AccountDataCloudSchema.currentSchemaVersion,
            createdAt: timestamp,
            updatedAt: timestamp,
            deletedAt: nil,
            deviceId: context.deviceId,
            source: AccountDataCloudSchema.clientSource,
            mutationId: context.mutationId
        )
    }

    static func domainModel(from document: CloudWaterEntryDocument) -> WaterEntry {
        WaterEntry(
            id: UUID(uuidString: document.id) ?? UUID(),
            dailyLogId: UUID(uuidString: document.dailyLogId) ?? UUID(),
            amountMl: document.amountMl,
            createdAt: document.createdAt
        )
    }

    // MARK: - Water entry (entity)

    static func cloudDocument(
        from entity: WaterEntryEntity,
        logDate: Date,
        context: CloudAccountDataMappingContext
    ) throws -> CloudWaterEntryDocument {
        try validateEntityOwnership(
            entity,
            entityName: "WaterEntryEntity",
            id: entity.id.uuidString,
            userId: context.userId
        )
        return try cloudDocument(from: entity.toModel(), logDate: logDate, context: context)
    }

    static func entity(
        from document: CloudWaterEntryDocument,
        context: CloudAccountDataMappingContext
    ) throws -> WaterEntryEntity {
        let ownerUID = try validateCloudUserId(document.userId, context: context)
        return WaterEntryEntity(
            id: UUID(uuidString: document.id) ?? UUID(),
            ownerUID: ownerUID,
            dailyLogId: UUID(uuidString: document.dailyLogId) ?? UUID(),
            amountMl: document.amountMl,
            createdAt: document.createdAt
        )
    }

    // MARK: - Weight entry (domain)

    static func cloudDocument(
        from entry: WeightEntry,
        context: CloudAccountDataMappingContext
    ) throws -> CloudWeightEntryDocument {
        let userId = try normalizedUserId(context.userId)
        // Weight entries only persist `createdAt` locally; mirror it for cloud `updatedAt`.
        let timestamp = entry.createdAt
        return CloudWeightEntryDocument(
            id: entry.id.uuidString,
            userId: userId,
            localDate: context.localDateString(for: entry.date),
            weightKg: entry.weightKg,
            note: entry.note,
            schemaVersion: AccountDataCloudSchema.currentSchemaVersion,
            createdAt: timestamp,
            updatedAt: timestamp,
            deletedAt: nil,
            deviceId: context.deviceId,
            source: AccountDataCloudSchema.clientSource,
            mutationId: context.mutationId
        )
    }

    static func domainModel(
        from document: CloudWeightEntryDocument,
        calendar: Calendar
    ) throws -> WeightEntry {
        guard let date = CloudAccountDataDateCodec.date(fromLocalDateString: document.localDate, calendar: calendar) else {
            throw CloudAccountDataMappingError.invalidDate(entity: "WeightEntry", id: document.id)
        }
        return WeightEntry(
            id: UUID(uuidString: document.id) ?? UUID(),
            date: date,
            weightKg: document.weightKg,
            note: document.note,
            createdAt: document.createdAt
        )
    }

    // MARK: - Weight entry (entity)

    static func cloudDocument(
        from entity: WeightEntryEntity,
        context: CloudAccountDataMappingContext
    ) throws -> CloudWeightEntryDocument {
        try validateEntityOwnership(
            entity,
            entityName: "WeightEntryEntity",
            id: entity.id.uuidString,
            userId: context.userId
        )
        return try cloudDocument(from: entity.toModel(), context: context)
    }

    static func entity(
        from document: CloudWeightEntryDocument,
        context: CloudAccountDataMappingContext
    ) throws -> WeightEntryEntity {
        let ownerUID = try validateCloudUserId(document.userId, context: context)
        guard let date = CloudAccountDataDateCodec.date(fromLocalDateString: document.localDate, calendar: context.calendar) else {
            throw CloudAccountDataMappingError.invalidDate(entity: "WeightEntryEntity", id: document.id)
        }
        return WeightEntryEntity(
            id: UUID(uuidString: document.id) ?? UUID(),
            ownerUID: ownerUID,
            date: date,
            weightKg: document.weightKg,
            note: document.note,
            createdAt: document.createdAt
        )
    }

    // MARK: - Daily review (domain)

    static func cloudDocument(
        from review: DailyReview,
        logDate: Date,
        context: CloudAccountDataMappingContext
    ) throws -> CloudDailyReviewDocument {
        let userId = try normalizedUserId(context.userId)
        // Daily reviews only persist `createdAt` locally; mirror it for cloud `updatedAt`.
        let timestamp = review.createdAt
        return CloudDailyReviewDocument(
            id: review.id.uuidString,
            userId: userId,
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
            createdAt: timestamp,
            updatedAt: timestamp,
            deletedAt: nil,
            deviceId: context.deviceId,
            source: AccountDataCloudSchema.clientSource,
            mutationId: context.mutationId
        )
    }

    static func domainModel(from document: CloudDailyReviewDocument) -> DailyReview {
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

    // MARK: - Daily review (entity)

    static func cloudDocument(
        from entity: DailyReviewEntity,
        logDate: Date,
        context: CloudAccountDataMappingContext
    ) throws -> CloudDailyReviewDocument {
        try validateEntityOwnership(
            entity,
            entityName: "DailyReviewEntity",
            id: entity.id.uuidString,
            userId: context.userId
        )
        return try cloudDocument(from: entity.toModel(), logDate: logDate, context: context)
    }

    static func entity(
        from document: CloudDailyReviewDocument,
        context: CloudAccountDataMappingContext
    ) throws -> DailyReviewEntity {
        let ownerUID = try validateCloudUserId(document.userId, context: context)
        return DailyReviewEntity(
            id: UUID(uuidString: document.id) ?? UUID(),
            ownerUID: ownerUID,
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
