//
//  CommandIntent.swift
//  Fitness Coach
//
//  FitPilot AI — Structured intent produced by the deterministic local parser.
//
//  This is pure parsed intent. It does not execute actions, call services,
//  touch SwiftData, or invoke AI.
//

import Foundation

enum UndoTarget: String, Codable, Equatable, Sendable {
    case last
    case food
    case water
    case workout
    case weight
}

/// Which slice of today's authoritative state a local status query should answer.
enum CoachDailyStatusFocus: String, Codable, Equatable, Sendable {
    case summary
    case caloriesRemaining
    case proteinRemaining
    case waterRemaining
    case mealsToday
    case lastMeal
}

enum CommandIntent: Codable, Equatable, Sendable {
    case logWeight(WeightDraft)
    case logWater(WaterDraft)
    case logSteps(Int)
    case logFood(FoodDraft)
    case status(focus: CoachDailyStatusFocus)
    case dailyReview
    case undo(target: UndoTarget)
    case unsupported
    case needsAI
}
