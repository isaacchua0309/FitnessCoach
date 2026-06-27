//
//  DailyLogEntity.swift
//  Fitness Coach
//
//  FitPilot AI — SwiftData persistence entity.
//

import Foundation
import SwiftData

@Model
final class DailyLogEntity {

    // MARK: Identity

    @Attribute(.unique) var id: UUID
    var date: Date

    // MARK: Summary

    var weightKg: Double?

    // MARK: Targets (flattened from UserTargets)

    var calorieTarget: Int
    var proteinTarget: Double
    var carbTarget: Double
    var fatTarget: Double
    var waterTargetMl: Int
    var expectedWeeklyWeightLossKg: Double?
    var aggressivenessRawValue: String

    // MARK: Totals (flattened from MacroTotals)

    var caloriesConsumed: Int
    var proteinConsumed: Double
    var carbsConsumed: Double
    var fatConsumed: Double
    var fiberConsumed: Double?
    var sodiumConsumed: Double?

    // MARK: Other Summary

    var waterConsumedMl: Int
    var steps: Int?
    var workoutCaloriesBurned: Int
    var dailyReviewId: UUID?

    // MARK: Metadata

    var createdAt: Date
    var updatedAt: Date

    // MARK: Relationships

    @Relationship(deleteRule: .cascade, inverse: \FoodEntryEntity.dailyLog)
    var foodEntries: [FoodEntryEntity]

    @Relationship(deleteRule: .cascade, inverse: \WaterEntryEntity.dailyLog)
    var waterEntries: [WaterEntryEntity]

    @Relationship(deleteRule: .cascade, inverse: \WorkoutEntryEntity.dailyLog)
    var workoutEntries: [WorkoutEntryEntity]

    @Relationship(deleteRule: .cascade, inverse: \DailyReviewEntity.dailyLog)
    var dailyReview: DailyReviewEntity?

    init(
        id: UUID,
        date: Date,
        weightKg: Double?,
        calorieTarget: Int,
        proteinTarget: Double,
        carbTarget: Double,
        fatTarget: Double,
        waterTargetMl: Int,
        expectedWeeklyWeightLossKg: Double?,
        aggressivenessRawValue: String,
        caloriesConsumed: Int,
        proteinConsumed: Double,
        carbsConsumed: Double,
        fatConsumed: Double,
        fiberConsumed: Double?,
        sodiumConsumed: Double?,
        waterConsumedMl: Int,
        steps: Int?,
        workoutCaloriesBurned: Int,
        dailyReviewId: UUID?,
        createdAt: Date,
        updatedAt: Date
    ) {
        self.id = id
        self.date = date
        self.weightKg = weightKg
        self.calorieTarget = calorieTarget
        self.proteinTarget = proteinTarget
        self.carbTarget = carbTarget
        self.fatTarget = fatTarget
        self.waterTargetMl = waterTargetMl
        self.expectedWeeklyWeightLossKg = expectedWeeklyWeightLossKg
        self.aggressivenessRawValue = aggressivenessRawValue
        self.caloriesConsumed = caloriesConsumed
        self.proteinConsumed = proteinConsumed
        self.carbsConsumed = carbsConsumed
        self.fatConsumed = fatConsumed
        self.fiberConsumed = fiberConsumed
        self.sodiumConsumed = sodiumConsumed
        self.waterConsumedMl = waterConsumedMl
        self.steps = steps
        self.workoutCaloriesBurned = workoutCaloriesBurned
        self.dailyReviewId = dailyReviewId
        self.createdAt = createdAt
        self.updatedAt = updatedAt
        self.foodEntries = []
        self.waterEntries = []
        self.workoutEntries = []
        self.dailyReview = nil
    }
}
