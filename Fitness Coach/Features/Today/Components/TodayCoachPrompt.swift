//
//  TodayCoachPrompt.swift
//  Fitness Coach
//
//  FitPilot AI — Prefill prompts when routing from read-only Today to Coach.
//

import Foundation

enum TodayCoachPrompt {
    static func logMeal(_ mealType: MealType? = nil) -> String {
        switch mealType {
        case .breakfast: return "Log my breakfast"
        case .lunch: return "Log my lunch"
        case .dinner: return "Log my dinner"
        case .snack: return "Log a snack"
        case .unknown, nil: return "Log my meal"
        }
    }

    static let scanFood = "Scan my meal"
    static let logWater = "Log 500ml water"
    static let logWeight = "Log my weight"
    static let logProtein = "Log a high-protein meal"
    static let reviewToday = "Review my day"
}
