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
    /// When set, overrides legacy `aggressiveness` mapping in the calculation engine.
    let weightLossPace: WeightLossPace?

    init(
        age: Int,
        sex: Sex,
        heightCm: Double,
        weightKg: Double,
        goalWeightKg: Double,
        estimatedBodyFatPercentage: Double?,
        activityLevel: ActivityLevel,
        trainingFrequencyPerWeek: Int,
        averageSteps: Int,
        aggressiveness: CalorieAggressiveness,
        weightLossPace: WeightLossPace? = nil
    ) {
        self.age = age
        self.sex = sex
        self.heightCm = heightCm
        self.weightKg = weightKg
        self.goalWeightKg = goalWeightKg
        self.estimatedBodyFatPercentage = estimatedBodyFatPercentage
        self.activityLevel = activityLevel
        self.trainingFrequencyPerWeek = trainingFrequencyPerWeek
        self.averageSteps = averageSteps
        self.aggressiveness = aggressiveness
        self.weightLossPace = weightLossPace
    }
}

struct CalorieTargetResult: Equatable, Sendable {
    let estimatedBMR: Int
    let estimatedTDEE: Int
    let targets: UserTargets
    let estimatedDailyDeficit: Int
    let isAggressive: Bool
    let warning: String?
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
