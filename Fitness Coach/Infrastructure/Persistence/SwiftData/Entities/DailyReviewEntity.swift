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
    var dailyLogId: UUID
    var summaryText: String
    var caloriesSummary: String
    var proteinSummary: String
    var hydrationSummary: String
    var workoutSummary: String?
    var weightSummary: String?
    var tomorrowRecommendation: String
    var createdAt: Date

    // MARK: Account persistence sync metadata (Phase 3)

    var cloudId: String?
    var cloudUpdatedAt: Date?
    var lastSyncedAt: Date?
    var syncStatusRawValue: String = AccountDataSyncStatus.localOnly.rawValue
    var lastSyncError: String?
    var deletedAt: Date?
    var lastMutationId: String?
    var syncAttemptCount: Int = 0
    var nextRetryAt: Date?

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
        createdAt: Date
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
    }
}
