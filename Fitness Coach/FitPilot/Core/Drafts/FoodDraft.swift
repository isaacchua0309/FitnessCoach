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
}
