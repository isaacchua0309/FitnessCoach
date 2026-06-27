//
//  TodayCoachPrompt.swift
//  Fitness Coach
//
//  FitPilot AI — Prefill prompts when routing from read-only Today to Coach.
//

import Foundation

enum TodayCoachPrompt {
    static let logMeal = "Log my meal"
    static let logWater = "Log 500ml water"
    static let logWeight = "Log my weight"
    static let logWorkout = "Log training"
    static let logProtein = "Log a high-protein meal"

    static func forGoal(_ kind: TodayGoalItem.Kind) -> String {
        switch kind {
        case .weight: logWeight
        case .protein: logProtein
        case .water: logWater
        case .workout: logWorkout
        }
    }
}
