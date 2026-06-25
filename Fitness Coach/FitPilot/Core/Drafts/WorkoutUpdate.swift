//
//  WorkoutUpdate.swift
//  Fitness Coach
//
//  FitPilot AI — Optional edits applied to an existing workout entry.
//
//  MVP semantics: a nil field means "do not change".
//

import Foundation

struct WorkoutUpdate: Codable, Equatable, Sendable {
    var name: String?
    var durationMinutes: Int?
    var estimatedCaloriesBurned: Int?
    var intensity: WorkoutIntensity?
    var recoveryDemand: RecoveryDemand?
    var notes: String?
}
