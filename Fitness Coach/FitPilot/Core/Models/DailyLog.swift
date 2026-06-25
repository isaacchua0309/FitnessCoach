//
//  DailyLog.swift
//  Fitness Coach
//
//  FitPilot AI — Core app-facing model.
//
//  Stores daily summary values only. FoodEntry, WaterEntry, WorkoutEntry,
//  and WeightEntry remain separate models.
//

import Foundation

struct DailyLog: Codable, Identifiable, Equatable, Sendable {

    // MARK: Identity

    let id: UUID
    var date: Date

    // MARK: Daily Summary

    var weightKg: Double?
    var targets: UserTargets
    var totals: MacroTotals
    var waterConsumedMl: Int
    var steps: Int?
    var workoutCaloriesBurned: Int

    // MARK: Relations

    var dailyReviewId: UUID?

    // MARK: Metadata

    var createdAt: Date
    var updatedAt: Date
}
