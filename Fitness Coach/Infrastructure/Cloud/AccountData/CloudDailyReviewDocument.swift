//
//  CloudDailyReviewDocument.swift
//  Fitness Coach
//
//  Forma — Firestore DTO for persisted daily review summaries.
//

import Foundation

struct CloudDailyReviewDocument: Codable, Equatable, Sendable, CloudAccountDataDocument {
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
    var createdAt: Date
    var updatedAt: Date
    var deletedAt: Date?
    var deviceId: String?
    var source: String?
    var mutationId: String?
}
