//
//  CalculationResultModels.swift
//  Fitness Coach
//
//  FitPilot AI — Structured result types returned by deterministic calculators.
//

import Foundation

// MARK: - Calorie Target

struct CalorieTargetInput: Equatable, Sendable {
    let age: Int
    let sex: Sex
    let heightCm: Double
    let weightKg: Double
    let goalWeightKg: Double
    let estimatedBodyFatPercentage: Double?
    let activityLevel: ActivityLevel
    let trainingFrequencyPerWeek: Int
    let averageSteps: Int
    let aggressiveness: CalorieAggressiveness
}

struct CalorieTargetResult: Equatable, Sendable {
    let estimatedBMR: Int
    let estimatedTDEE: Int
    let targets: UserTargets
    let estimatedDailyDeficit: Int
    let isAggressive: Bool
    let warning: String?
}

// MARK: - Maintenance

struct MaintenanceEstimate: Equatable, Sendable {
    let days: Int
    let averageCalories: Int
    let weightChangeKg: Double?
    let estimatedDailyDeficit: Int?
    let estimatedMaintenanceCalories: Int?
    let confidence: ConfidenceLevel
    let hasEnoughData: Bool
}

// MARK: - Weight Trend

enum WeightTrendDirection: String, Codable, Equatable, Sendable {
    case decreasing
    case increasing
    case stable
    case insufficientData
}

struct WeightTrend: Equatable, Sendable {
    let latestWeightKg: Double?
    let previousWeightKg: Double?
    let sevenDayAverageKg: Double?
    let previousSevenDayAverageKg: Double?
    let changeKg: Double?
    let direction: WeightTrendDirection
    let hasSuddenSpike: Bool
}

// MARK: - Workout

struct WorkoutCalculationResult: Equatable, Sendable {
    let estimatedVolumeKg: Double?
    let estimatedCaloriesBurned: Int?
    let intensity: WorkoutIntensity
    let recoveryDemand: RecoveryDemand
}

// MARK: - Progress Projection

struct ProgressProjection: Equatable, Sendable {
    let currentWeightKg: Double?
    let goalWeightKg: Double
    let remainingKg: Double?
    let weeklyRateKg: Double?
    let estimatedWeeksToGoal: Double?
    let projectedGoalDate: Date?
    let confidence: ConfidenceLevel
}
