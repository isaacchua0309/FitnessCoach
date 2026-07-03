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
    var hasWorkoutToday: Bool
    var workoutCount: Int
    var primaryActivityName: String?

    static let empty = WorkoutSummary(
        hasWorkoutToday: false,
        workoutCount: 0,
        primaryActivityName: nil
    )
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
