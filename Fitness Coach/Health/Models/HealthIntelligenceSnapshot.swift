//
//  HealthIntelligenceSnapshot.swift
//  Fitness Coach
//
//  Forma — Aggregated Health Intelligence output for a single day.
//
//  UI should consume `HealthIntelligenceSnapshot` (via `HealthIntelligenceEngine`) rather than
//  querying HealthKit or repository aggregates directly. Snapshots compose normalized cache data
//  into a stable, testable contract for Today, Journey, Plan, and Coach.
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
