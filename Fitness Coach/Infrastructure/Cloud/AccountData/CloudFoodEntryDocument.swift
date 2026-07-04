//
//  CloudFoodEntryDocument.swift
//  Fitness Coach
//
//  Forma — Firestore DTO for food log entries.
//
//  Privacy: text/URL references only. Raw meal image bytes are never included.
//

import Foundation

struct CloudFoodEntryDocument: Codable, Equatable, Sendable, CloudAccountDataDocument {
    var id: String
    var userId: String
    var dailyLogId: String
    var localDate: String
    var mealType: String?
    var name: String
    var quantity: Double?
    var unit: String?
    var calories: Int
    var protein: Double
    var carbs: Double
    var fat: Double
    var fiber: Double?
    var sodium: Double?
    /// Meal provenance (`FoodEntrySource` raw value).
    var source: String
    var confidence: String
    var imageUrl: String?
    var notes: String?
    /// JSON-encoded `[FoodComponent]` for multi-component meals.
    var componentsJSON: String?
    var schemaVersion: Int
    var createdAt: Date
    var updatedAt: Date
    var deletedAt: Date?
    var deviceId: String?
    var mutationId: String?
}
