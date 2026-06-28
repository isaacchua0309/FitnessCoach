//
//  WeeklyReview.swift
//  Fitness Coach
//
//  Domain model for `WeeklyReviewEntity` (schema-only today).
//
//  TODO(migration): Implement weekly review generation or remove with entity.
//  See `Docs/PersistenceCleanupNotes.md`.
//

import Foundation

struct WeeklyReview: Codable, Identifiable, Equatable, Sendable {

    // MARK: Identity

    let id: UUID

    // MARK: Range

    var weekStartDate: Date
    var weekEndDate: Date

    // MARK: Averages

    var averageCalories: Int
    var averageProtein: Double
    var averageWaterMl: Int
    var averageSteps: Int?

    // MARK: Aggregates

    var workoutCount: Int
    var weightChangeKg: Double?
    var estimatedMaintenance: Int?

    // MARK: Coaching

    var summaryText: String
    var recommendationText: String

    // MARK: Metadata

    var createdAt: Date
}
