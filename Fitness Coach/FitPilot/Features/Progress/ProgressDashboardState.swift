//
//  ProgressDashboardState.swift
//  Fitness Coach
//
//  FitPilot AI — Read-only view state for Progress trends.
//
//  This state contains no SwiftData entities and performs no calculations.
//  ProgressModel builds it from services and deterministic calculators.
//

import Foundation

struct ProgressDashboardState: Equatable {
    var selectedRangeDays: Int

    var weightSummary: ProgressWeightSummary
    var weightChartPoints: [WeightChartPoint]

    var nutritionSummary: ProgressNutritionSummary
    var waterSummary: ProgressWaterSummary
    var maintenanceEstimate: MaintenanceEstimate?
    var goalProjection: ProgressProjection?
    var workoutSummary: ProgressWorkoutSummary?

    var hasEnoughData: Bool
}

struct ProgressWeightSummary: Equatable {
    var latestWeightKg: Double?
    var sevenDayAverageKg: Double?
    var previousSevenDayAverageKg: Double?
    var changeKg: Double?
    var direction: WeightTrendDirection
    var hasSuddenSpike: Bool
}

struct WeightChartPoint: Identifiable, Equatable {
    var id: UUID
    var date: Date
    var weightKg: Double
    var sevenDayAverageKg: Double?

    init(id: UUID = UUID(), date: Date, weightKg: Double, sevenDayAverageKg: Double?) {
        self.id = id
        self.date = date
        self.weightKg = weightKg
        self.sevenDayAverageKg = sevenDayAverageKg
    }
}

struct ProgressNutritionSummary: Equatable {
    var loggedDays: Int
    var averageCalories: Int?
    var averageProtein: Double?
    var averageCarbs: Double?
    var averageFat: Double?
    var averageFiber: Double?
}

struct ProgressWaterSummary: Equatable {
    var loggedDays: Int
    var averageWaterMl: Int?
    var averageWaterTargetMl: Int?
    var consistencyPercent: Double?
}

struct ProgressWorkoutSummary: Equatable {
    var workoutCount: Int
    var totalEstimatedCaloriesBurned: Int
    var averageWorkoutsPerWeek: Double
}
