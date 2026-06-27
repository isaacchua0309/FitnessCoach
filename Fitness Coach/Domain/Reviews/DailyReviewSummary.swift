//
//  DailyReviewSummary.swift
//  Fitness Coach
//
//  FitPilot AI — Deterministic daily review source data.
//
//  This is not AI output and not a SwiftData entity. It contains only values
//  derived from domain models, services, and deterministic calculators.
//

import Foundation

struct DailyReviewSummary: Codable, Equatable, Sendable {
    var date: Date

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
    var latestWeightKg: Double?
    var steps: Int?

    var workoutCount: Int
    var workoutCaloriesBurned: Int
    var hasWorkout: Bool

    var foodEntryCount: Int
    var topProteinFoodNames: [String]
    var lowConfidenceFoodCount: Int

    var deterministicNotes: [String]
}
