//
//  CoachTodayContextState.swift
//  Fitness Coach
//
//  Forma — Compact read-only today snapshot for the Coach empty state.
//

import Foundation

struct CoachTodayContextState: Equatable, Sendable {
    let caloriesLine: String
    let proteinLine: String
    let waterLine: String
    /// Live activity signals (latest meal, steps, workout).
    let activityLines: [String]
    /// Soft note when Apple Health activity is unavailable — not an error state.
    let activityHintLine: String?
    let suggestedFocus: String
}
