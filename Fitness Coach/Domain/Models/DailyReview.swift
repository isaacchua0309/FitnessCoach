//
//  DailyReview.swift
//  Fitness Coach
//
//  FitPilot AI — Core app-facing model.
//

import Foundation

struct DailyReview: Codable, Identifiable, Equatable, Sendable {

    // MARK: Identity

    let id: UUID
    var dailyLogId: UUID

    // MARK: Summary Sections

    var summaryText: String
    var caloriesSummary: String
    var proteinSummary: String
    var hydrationSummary: String
    var workoutSummary: String?
    var weightSummary: String?
    var tomorrowRecommendation: String

    // MARK: Metadata

    var createdAt: Date
}
