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
    let suggestedFocus: String
}
