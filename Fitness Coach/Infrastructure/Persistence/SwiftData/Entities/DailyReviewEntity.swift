//
//  DailyReviewEntity.swift
//  Fitness Coach
//
//  FitPilot AI — SwiftData persistence entity.
//

import Foundation
import SwiftData

@Model
final class DailyReviewEntity {

    @Attribute(.unique) var id: UUID
    /// Firebase UID that owns this daily review, when known.
    var ownerUID: String?

    // MARK: Account persistence (Phase 1)

    /// Local mutation timestamp for account persistence bookkeeping.
    var localUpdatedAt: Date?
    /// Per-entity schema version for future lightweight migrations.
    var entitySchemaVersion: Int = UserDataEntitySchema.currentEntitySchemaVersion

    var dailyLogId: UUID
    var summaryText: String
    var caloriesSummary: String
    var proteinSummary: String
    var hydrationSummary: String
    var workoutSummary: String?
    var weightSummary: String?
    var tomorrowRecommendation: String
    var createdAt: Date

    // MARK: Relationships

    var dailyLog: DailyLogEntity?

    init(
        id: UUID,
        ownerUID: String? = nil,
        dailyLogId: UUID,
        summaryText: String,
        caloriesSummary: String,
        proteinSummary: String,
        hydrationSummary: String,
        workoutSummary: String?,
        weightSummary: String?,
        tomorrowRecommendation: String,
        createdAt: Date,
        localUpdatedAt: Date? = nil,
        entitySchemaVersion: Int = UserDataEntitySchema.currentEntitySchemaVersion
    ) {
        self.id = id
        self.ownerUID = ownerUID
        self.dailyLogId = dailyLogId
        self.summaryText = summaryText
        self.caloriesSummary = caloriesSummary
        self.proteinSummary = proteinSummary
        self.hydrationSummary = hydrationSummary
        self.workoutSummary = workoutSummary
        self.weightSummary = weightSummary
        self.tomorrowRecommendation = tomorrowRecommendation
        self.createdAt = createdAt
        self.localUpdatedAt = localUpdatedAt ?? createdAt
        self.entitySchemaVersion = entitySchemaVersion
    }
}
