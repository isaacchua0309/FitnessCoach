//
//  WorkoutEntry.swift
//  Fitness Coach
//
//  FitPilot AI — Core app-facing model.
//

import Foundation

struct WorkoutEntry: Codable, Identifiable, Equatable, Sendable {

    // MARK: Identity

    let id: UUID
    var dailyLogId: UUID

    // MARK: Description

    var name: String?
    var durationMinutes: Int?
    var estimatedCaloriesBurned: Int?
    var intensity: WorkoutIntensity?
    var recoveryDemand: RecoveryDemand?
    var notes: String?

    // MARK: Metadata

    var createdAt: Date
    var updatedAt: Date
}
