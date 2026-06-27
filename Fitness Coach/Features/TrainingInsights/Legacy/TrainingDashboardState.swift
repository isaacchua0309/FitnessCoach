//
//  TrainingDashboardState.swift
//  Fitness Coach
//
//  FitPilot AI — Read-only intelligence state for the Training dashboard.
//

import Foundation

struct TrainingDashboardState: Equatable {
    var hero: TrainingHeroState
    var weekly: TrainingWeeklySummary
    var muscleDistribution: [MuscleDistributionItem]
    var recentWorkouts: [WorkoutDisplayItem]
}

struct TrainingHeroState: Equatable {
    var hasWorkoutToday: Bool
    var primaryWorkout: WorkoutDisplayItem?
    var lastWorkout: WorkoutDisplayItem?
}

struct TrainingWeeklySummary: Equatable {
    var workoutsCompleted: Int
    var totalCalories: Int
    var totalDurationMinutes: Int
    var trainingStreak: Int
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
