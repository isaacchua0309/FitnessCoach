//
//  TodayAISummary.swift
//  Fitness Coach
//
//  Compact same-day nutrition snapshot for daily review AI input mapping.
//  Coach gateway transport uses CoachContextPacketV2 — not this type.
//

import Foundation

struct TodayAISummary: Codable, Equatable, Sendable {
    var calorieTarget: Int
    var caloriesConsumed: Int
    var caloriesRemaining: Int
    var isOverCalorieTarget: Bool
    var proteinTarget: Double
    var proteinConsumed: Double
    var proteinRemaining: Double
    var hasMetProteinTarget: Bool
    var carbsTarget: Double
    var carbsConsumed: Double
    var carbsRemaining: Double
    var fatTarget: Double
    var fatConsumed: Double
    var fatRemaining: Double
    var waterTargetMl: Int
    var waterConsumedMl: Int
    var waterRemainingMl: Int
    var hasMetWaterTarget: Bool
    var weightKg: Double?
    var steps: Int?
    var workoutCaloriesBurned: Int
    var workoutsToday: Int
    var recentMeals: [String]

    init(
        calorieTarget: Int,
        caloriesConsumed: Int,
        caloriesRemaining: Int,
        isOverCalorieTarget: Bool = false,
        proteinTarget: Double,
        proteinConsumed: Double,
        proteinRemaining: Double = 0,
        hasMetProteinTarget: Bool = false,
        carbsTarget: Double,
        carbsConsumed: Double,
        carbsRemaining: Double = 0,
        fatTarget: Double,
        fatConsumed: Double,
        fatRemaining: Double = 0,
        waterTargetMl: Int,
        waterConsumedMl: Int,
        waterRemainingMl: Int = 0,
        hasMetWaterTarget: Bool = false,
        weightKg: Double?,
        steps: Int?,
        workoutCaloriesBurned: Int,
        workoutsToday: Int = 0,
        recentMeals: [String] = []
    ) {
        self.calorieTarget = calorieTarget
        self.caloriesConsumed = caloriesConsumed
        self.caloriesRemaining = caloriesRemaining
        self.isOverCalorieTarget = isOverCalorieTarget
        self.proteinTarget = proteinTarget
        self.proteinConsumed = proteinConsumed
        self.proteinRemaining = proteinRemaining
        self.hasMetProteinTarget = hasMetProteinTarget
        self.carbsTarget = carbsTarget
        self.carbsConsumed = carbsConsumed
        self.carbsRemaining = carbsRemaining
        self.fatTarget = fatTarget
        self.fatConsumed = fatConsumed
        self.fatRemaining = fatRemaining
        self.waterTargetMl = waterTargetMl
        self.waterConsumedMl = waterConsumedMl
        self.waterRemainingMl = waterRemainingMl
        self.hasMetWaterTarget = hasMetWaterTarget
        self.weightKg = weightKg
        self.steps = steps
        self.workoutCaloriesBurned = workoutCaloriesBurned
        self.workoutsToday = workoutsToday
        self.recentMeals = recentMeals
    }
}
