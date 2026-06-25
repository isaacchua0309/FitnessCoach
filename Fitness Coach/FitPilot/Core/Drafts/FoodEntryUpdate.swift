//
//  FoodEntryUpdate.swift
//  Fitness Coach
//
//  FitPilot AI — Optional edits applied to an existing food entry.
//
//  MVP semantics: a nil field means "do not change". Clearing optional values
//  can be modeled more explicitly later if needed.
//

import Foundation

struct FoodEntryUpdate: Codable, Equatable, Sendable {
    var mealType: MealType?
    var name: String?
    var quantity: Double?
    var unit: String?
    var calories: Int?
    var protein: Double?
    var carbs: Double?
    var fat: Double?
    var fiber: Double?
    var sodium: Double?
    var source: FoodEntrySource?
    var confidence: ConfidenceLevel?
    var imageUrl: String?
    var notes: String?
}
