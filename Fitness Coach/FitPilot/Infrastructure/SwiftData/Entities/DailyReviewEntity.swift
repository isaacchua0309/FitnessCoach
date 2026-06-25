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
