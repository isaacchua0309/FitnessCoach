//
//  FoodDraft.swift
//  Fitness Coach
//
//  FitPilot AI — App-facing input for creating a food entry.
//

import Foundation

struct FoodDraft: Codable, Equatable, Sendable {
    var mealType: MealType?
    var name: String
    var quantity: Double?
    var unit: String?
    var calories: Int
    var protein: Double
    var carbs: Double
    var fat: Double
    var fiber: Double?
    var sodium: Double?
    var source: FoodEntrySource
    var confidence: ConfidenceLevel
    var imageUrl: String?
    var notes: String?

    /// True when the draft includes at least one non-zero nutrition value worth showing.
    var hasUsableNutritionEstimate: Bool {
        calories > 0 || protein > 0 || carbs > 0 || fat > 0
    }

    /// True when calories and macros form a loggable profile (not calorie-only or macro-only partial input).
    var hasCompleteNutritionEstimate: Bool {
        guard hasUsableNutritionEstimate, calories > 0 else { return false }
        return protein > 0 || carbs > 0 || fat > 0
    }
}
