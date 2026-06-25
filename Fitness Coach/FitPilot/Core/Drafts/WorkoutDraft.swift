//
//  WorkoutDraft.swift
//  Fitness Coach
//
//  FitPilot AI — App-facing input for logging a workout.
//

import Foundation

struct WorkoutDraft: Codable, Equatable, Sendable {
    var name: String?
    var durationMinutes: Int?
    var estimatedCaloriesBurned: Int?
    var intensity: WorkoutIntensity?
    var recoveryDemand: RecoveryDemand?
    var notes: String?
    var exerciseSets: [ExerciseSetDraft]
}
