//
//  HealthIntelligenceSummaryModels.swift
//  Fitness Coach
//
//  Forma — Domain summaries produced by Health Intelligence engines.
//

import Foundation

struct RecoverySummary: Equatable, Sendable, Codable {
    var score: Double?
    var readinessLabel: String

    static let placeholder = RecoverySummary(
        score: nil,
        readinessLabel: "Unavailable"
    )
}

struct WorkoutSummary: Equatable, Sendable, Codable {
    var hasWorkout: Bool
    var primaryWorkoutType: FormaWorkoutCategory?
    var title: String
    var workoutCount: Int
    var totalDurationMinutes: Int
    var totalActiveCalories: Int?
    var intensity: WorkoutIntensity
    var demand: WorkoutDemand
    var latestWorkoutStart: Date?
    var latestWorkoutEnd: Date?
    var nutritionAdvice: String
    var hydrationAdviceMl: Int
    var explanation: String
    var confidence: WorkoutSummaryConfidence
    var sourceSummary: String

    static let noWorkout = WorkoutSummary(
        hasWorkout: false,
        primaryWorkoutType: nil,
        title: "Rest day so far",
        workoutCount: 0,
        totalDurationMinutes: 0,
        totalActiveCalories: nil,
        intensity: .unknown,
        demand: .low,
        latestWorkoutStart: nil,
        latestWorkoutEnd: nil,
        nutritionAdvice: "Stay on your usual plan today.",
        hydrationAdviceMl: 0,
        explanation: "No workouts are logged for today yet.",
        confidence: .low,
        sourceSummary: ""
    )
}

enum WorkoutIntensity: String, Equatable, Sendable, Codable {
    case low
    case moderate
    case high
    case unknown
}

enum WorkoutDemand: String, Equatable, Sendable, Codable {
    case low
    case moderate
    case high
    case unknown
}

enum WorkoutSummaryConfidence: String, Equatable, Sendable, Codable {
    case low
    case moderate
    case high
}

struct ActivitySummary: Equatable, Sendable, Codable {
    var steps: Int?
    var activeEnergyKcal: Int?
    var exerciseMinutes: Int?

    static let empty = ActivitySummary(
        steps: nil,
        activeEnergyKcal: nil,
        exerciseMinutes: nil
    )
}

struct AdaptiveNutritionSummary: Equatable, Sendable, Codable {
    var calorieAdjustment: Int
    var rationale: String

    static let none = AdaptiveNutritionSummary(
        calorieAdjustment: 0,
        rationale: ""
    )
}

struct WeeklyHealthReview: Equatable, Sendable, Codable {
    var headline: String
    var workoutDays: Int
    var narrative: String?

    static let empty = WeeklyHealthReview(
        headline: "",
        workoutDays: 0,
        narrative: nil
    )
}

struct PlanHealthConfidence: Equatable, Sendable, Codable {
    var score: Double
    var label: String

    static let unknown = PlanHealthConfidence(
        score: 0,
        label: "Unknown"
    )
}

/// Health Intelligence recommendation — distinct from Today `NextBestActionState`.
typealias NextBestAction = HealthIntelligenceNextBestAction

struct HealthIntelligenceNextBestAction: Equatable, Sendable, Codable {
    var title: String
    var detail: String?
    var priority: Int

    static let none = HealthIntelligenceNextBestAction(
        title: "",
        detail: nil,
        priority: 0
    )
}
