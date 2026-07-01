//
//  DailyTrainingActivity.swift
//  Fitness Coach
//
//  Read-model for Apple Health training on a single day.
//

import Foundation

struct DailyTrainingActivity: Equatable, Sendable {
    let workoutCount: Int
    let workoutCaloriesBurned: Int
    let hasWorkout: Bool

    static let empty = DailyTrainingActivity(
        workoutCount: 0,
        workoutCaloriesBurned: 0,
        hasWorkout: false
    )

    init(
        workouts: [HealthWorkoutRecord]
    ) {
        workoutCount = workouts.count
        workoutCaloriesBurned = workouts.compactMap(\.activeCalories).reduce(0, +)
        hasWorkout = !workouts.isEmpty
    }
}
