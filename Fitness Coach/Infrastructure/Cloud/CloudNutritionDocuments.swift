//
//  CloudNutritionDocuments.swift
//  Fitness Coach
//
//  Forma — Firestore DTOs for nutrition account persistence (Phase 2).
//
//  Privacy: text and numeric nutrition fields only. Meal image bytes are never included.
//

import Foundation

// MARK: - Document marker

protocol CloudNutritionRemoteSyncDocument: Codable, Equatable, Sendable {
    var userId: String { get }
    var schemaVersion: Int { get }
    var updatedAt: Date { get }
}

// MARK: - Sync metadata

struct CloudSyncMetadataDocument: CloudNutritionRemoteSyncDocument {
    var userId: String
    var schemaVersion: Int
    var clientSchemaVersion: Int
    var lastPushedAt: Date?
    var lastPulledAt: Date?
    var lastFullRestoreAt: Date?
    var deviceId: String
    var appVersion: String
    var updatedAt: Date
}

// MARK: - Daily log rollup

struct CloudDailyLogDocument: CloudNutritionRemoteSyncDocument {
    var id: String
    var userId: String
    var localDate: String
    var timezone: String
    var calorieTarget: Int
    var proteinTarget: Double
    var carbTarget: Double
    var fatTarget: Double
    var waterTargetMl: Int
    var expectedWeeklyWeightLossKg: Double?
    var aggressiveness: String
    var caloriesConsumed: Int
    var proteinConsumed: Double
    var carbsConsumed: Double
    var fatConsumed: Double
    var fiberConsumed: Double?
    var sodiumConsumed: Double?
    var waterConsumedMl: Int
    var steps: Int?
    var workoutCaloriesBurned: Int
    var weightKg: Double?
    var dailyReviewId: String?
    var schemaVersion: Int
    var updatedAt: Date
    var createdAt: Date
    var deletedAt: Date?
    var mutationId: String?
    var deviceId: String?
    var source: String
}

// MARK: - Food entry

struct CloudFoodEntryDocument: CloudNutritionRemoteSyncDocument {
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
    var source: String
    var confidence: String
    var imageUrl: String?
    var notes: String?
    var componentsJSON: String?
    var schemaVersion: Int
    var updatedAt: Date
    var createdAt: Date
    var deletedAt: Date?
    var mutationId: String?
}

// MARK: - Water entry

struct CloudWaterEntryDocument: CloudNutritionRemoteSyncDocument {
    var id: String
    var userId: String
    var dailyLogId: String
    var localDate: String
    var amountMl: Int
    var schemaVersion: Int
    var updatedAt: Date
    var createdAt: Date
    var deletedAt: Date?
    var mutationId: String?
}

// MARK: - Weight entry

struct CloudWeightEntryDocument: CloudNutritionRemoteSyncDocument {
    var id: String
    var userId: String
    var localDate: String
    var weightKg: Double
    var note: String?
    var schemaVersion: Int
    var updatedAt: Date
    var createdAt: Date
    var deletedAt: Date?
    var mutationId: String?
}

// MARK: - Daily review

struct CloudDailyReviewDocument: CloudNutritionRemoteSyncDocument {
    var id: String
    var userId: String
    var dailyLogId: String
    var localDate: String
    var summaryText: String
    var caloriesSummary: String
    var proteinSummary: String
    var hydrationSummary: String
    var workoutSummary: String?
    var weightSummary: String?
    var tomorrowRecommendation: String
    var schemaVersion: Int
    var updatedAt: Date
    var createdAt: Date
    var deletedAt: Date?
    var mutationId: String?
}
