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

    static func placeholder(for date: Date) -> HealthIntelligenceSnapshot {
        HealthIntelligenceSnapshot(
            date: date,
            recovery: .placeholder,
            workout: nil,
            activity: .empty,
            nutritionAdjustment: .none,
            weeklyReview: nil,
            planConfidence: .unknown,
            nextBestAction: .none
        )
    }
}
