//
//  TrainingDashboardState.swift
//  Fitness Coach
//
//  FitPilot AI — Read-focused state for the Training screen.
//
//  This contains domain models for display only. It contains no SwiftData
//  entities and performs no persistence.
//

import Foundation

struct TrainingDashboardState: Equatable {
    var selectedDate: Date
    var todaysWorkouts: [WorkoutDisplayItem]
    var recentWorkouts: [WorkoutDisplayItem]
    var summary: TrainingSummary
}

struct WorkoutDisplayItem: Identifiable, Equatable {
    var id: UUID
    var name: String
    var dateText: String
    var durationText: String?
    var estimatedCaloriesText: String?
    var intensityText: String?
    var recoveryDemandText: String?
    var exerciseCount: Int
    var setCount: Int
    var totalVolumeKg: Double?
    var notes: String?
    var workout: WorkoutEntry
    var exerciseSets: [ExerciseSet]
}

struct TrainingSummary: Equatable {
    var workoutCountToday: Int
    var workoutCountInRecentRange: Int
    var estimatedCaloriesBurnedToday: Int
    var totalVolumeTodayKg: Double?
}
