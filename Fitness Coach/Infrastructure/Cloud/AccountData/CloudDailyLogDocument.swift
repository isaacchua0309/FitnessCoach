//
//  CloudDailyLogDocument.swift
//  Fitness Coach
//
//  Forma — Firestore DTO for daily nutrition rollups (`dailyLogs/{yyyy-MM-dd}`).
//
//  Restorable before food/water subcollections are fetched.
//

import Foundation

struct CloudDailyLogDocument: Codable, Equatable, Sendable, CloudAccountDataDocument {
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
    var createdAt: Date
    var updatedAt: Date
    var deletedAt: Date?
    var deviceId: String?
    var source: String?
    var mutationId: String?
}
