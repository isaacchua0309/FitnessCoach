//
//  ExerciseSetDraft.swift
//  Fitness Coach
//
//  FitPilot AI — App-facing input for a single exercise set.
//

import Foundation

struct ExerciseSetDraft: Codable, Equatable, Sendable {
    var exerciseName: String
    var setNumber: Int
    var reps: Int
    var weightKg: Double?
    var rpe: Double?
}
