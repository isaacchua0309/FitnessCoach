//
//  CloudNutritionDocumentMapping.swift
//  Fitness Coach
//
//  Forma — Backward-compatible aliases over account data cloud mappers (Phase 2).
//

import Foundation

typealias CloudNutritionSyncMappingContext = CloudAccountDataMappingContext
typealias CloudNutritionDateCodec = CloudAccountDataDateCodec

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
    ) throws -> CloudDailyLogDocument {
        try CloudAccountDataMappers.cloudDocument(from: log, context: context)
    }

    static func makeDailyLog(
        from document: CloudDailyLogDocument,
        calendar: Calendar
    ) throws -> DailyLog {
        try CloudAccountDataMappers.domainModel(from: document, calendar: calendar)
    }

    // MARK: - Food

    static func makeCloudFoodEntryDocument(
        from entry: FoodEntry,
        logDate: Date,
        context: CloudNutritionSyncMappingContext
    ) throws -> CloudFoodEntryDocument {
        try CloudAccountDataMappers.cloudDocument(from: entry, logDate: logDate, context: context)
    }

    static func makeFoodEntry(from document: CloudFoodEntryDocument) throws -> FoodEntry {
        try CloudAccountDataMappers.domainModel(from: document)
    }

    // MARK: - Water

    static func makeCloudWaterEntryDocument(
        from entry: WaterEntry,
        logDate: Date,
        context: CloudNutritionSyncMappingContext
    ) throws -> CloudWaterEntryDocument {
        try CloudAccountDataMappers.cloudDocument(from: entry, logDate: logDate, context: context)
    }

    static func makeWaterEntry(from document: CloudWaterEntryDocument) -> WaterEntry {
        CloudAccountDataMappers.domainModel(from: document)
    }

    // MARK: - Weight

    static func makeCloudWeightEntryDocument(
        from entry: WeightEntry,
        context: CloudNutritionSyncMappingContext
    ) throws -> CloudWeightEntryDocument {
        try CloudAccountDataMappers.cloudDocument(from: entry, context: context)
    }

    static func makeWeightEntry(
        from document: CloudWeightEntryDocument,
        calendar: Calendar
    ) throws -> WeightEntry {
        try CloudAccountDataMappers.domainModel(from: document, calendar: calendar)
    }

    // MARK: - Daily review

    static func makeCloudDailyReviewDocument(
        from review: DailyReview,
        logDate: Date,
        context: CloudNutritionSyncMappingContext
    ) throws -> CloudDailyReviewDocument {
        try CloudAccountDataMappers.cloudDocument(from: review, logDate: logDate, context: context)
    }

    static func makeDailyReview(from document: CloudDailyReviewDocument) -> DailyReview {
        CloudAccountDataMappers.domainModel(from: document)
    }

    // MARK: - JSON helpers

    static func encodeComponents(_ components: [FoodComponent]) -> String? {
        CloudAccountDataMappers.encodeComponents(components)
    }

    static func decodeComponents(_ json: String?) -> [FoodComponent]? {
        CloudAccountDataMappers.decodeComponents(json)
    }
}
