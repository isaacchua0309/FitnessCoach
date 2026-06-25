//
//  WeeklyReviewEntity.swift
//  Fitness Coach
//
//  FitPilot AI — SwiftData persistence entity.
//

import Foundation
import SwiftData

@Model
final class WeeklyReviewEntity {

    @Attribute(.unique) var id: UUID
    var weekStartDate: Date
    var weekEndDate: Date
    var averageCalories: Int
    var averageProtein: Double
    var averageWaterMl: Int
    var averageSteps: Int?
    var workoutCount: Int
    var weightChangeKg: Double?
    var estimatedMaintenance: Int?
    var summaryText: String
    var recommendationText: String
    var createdAt: Date

    init(
        id: UUID,
        weekStartDate: Date,
        weekEndDate: Date,
        averageCalories: Int,
        averageProtein: Double,
        averageWaterMl: Int,
        averageSteps: Int?,
        workoutCount: Int,
        weightChangeKg: Double?,
        estimatedMaintenance: Int?,
        summaryText: String,
        recommendationText: String,
        createdAt: Date
    ) {
        self.id = id
        self.weekStartDate = weekStartDate
        self.weekEndDate = weekEndDate
        self.averageCalories = averageCalories
        self.averageProtein = averageProtein
        self.averageWaterMl = averageWaterMl
        self.averageSteps = averageSteps
        self.workoutCount = workoutCount
        self.weightChangeKg = weightChangeKg
        self.estimatedMaintenance = estimatedMaintenance
        self.summaryText = summaryText
        self.recommendationText = recommendationText
        self.createdAt = createdAt
    }
}
