//
//  FoodEntry.swift
//  Fitness Coach
//
//  FitPilot AI — Core app-facing model.
//

import Foundation

struct FoodEntry: Codable, Identifiable, Equatable, Sendable {

    // MARK: Identity

    let id: UUID
    var dailyLogId: UUID

    // MARK: Description

    var mealType: MealType?
    var name: String
    var quantity: Double?
    var unit: String?

    // MARK: Nutrition

    var calories: Int
    var protein: Double
    var carbs: Double
    var fat: Double
    var fiber: Double?
    var sodium: Double?

    // MARK: Provenance

    var source: FoodEntrySource
    var confidence: ConfidenceLevel
    var imageUrl: String?
    var notes: String?

    // MARK: Metadata

    var createdAt: Date
    var updatedAt: Date
}
