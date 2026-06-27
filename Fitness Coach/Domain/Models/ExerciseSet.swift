//
//  ExerciseSet.swift
//  Fitness Coach
//
//  FitPilot AI — Core app-facing model.
//

import Foundation

struct ExerciseSet: Codable, Identifiable, Equatable, Sendable {
    let id: UUID
    var workoutEntryId: UUID
    var exerciseName: String
    var setNumber: Int
    var reps: Int
    var weightKg: Double?
    var rpe: Double?
    var createdAt: Date
}
