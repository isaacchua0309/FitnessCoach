//
//  HealthIntelligenceSnapshot.swift
//  Fitness Coach
//
//  Forma — Aggregated Health Intelligence output for a single day.
//

import Foundation

struct HealthIntelligenceSnapshot: Equatable, Sendable, Codable {
    let date: Date
    let recovery: RecoverySummary
    let workout: WorkoutSummary?
    let activity: ActivitySummary
    let nutritionAdjustment: AdaptiveNutritionSummary
    let weeklyReview: WeeklyHealthReview?
    let planConfidence: PlanHealthConfidence
    let nextBestAction: NextBestAction
}
