//
//  HealthWorkoutRecord.swift
//  Fitness Coach
//
//  Forma — App-facing workout sample from Apple Health (read-only).
//

import Foundation

struct HealthWorkoutRecord: Equatable, Sendable, Identifiable {
    let id: UUID
    let activityName: String
    let startDate: Date
    let endDate: Date
    let durationMinutes: Int
    let activeCalories: Int?
}

struct TrainingInsightsWorkoutTypeCount: Equatable, Sendable {
    let name: String
    let count: Int
}

struct TrainingInsightsWeeklySummary: Equatable, Sendable {
    let workoutDays: Int
    let workoutCount: Int
    let totalDurationMinutes: Int
    let activeCalories: Int?
    let workoutTypes: [TrainingInsightsWorkoutTypeCount]

    var hasActivity: Bool { workoutDays > 0 }

    var mostCommonWorkoutType: String? {
        workoutTypes.first?.name
    }
}

struct TrainingInsightsConsistencySummary: Equatable, Sendable {
    let workoutDays7: Int
    let workoutDays14: Int
    let workoutDays28: Int
    let workoutDaysThisMonth: Int
}

struct TrainingInsightsSummary: Equatable, Sendable {
    let weekly: TrainingInsightsWeeklySummary
    let recentWorkout: HealthWorkoutRecord?
    let consistency: TrainingInsightsConsistencySummary
    let consistencyNote: String
    let coachNote: String

    var hasWorkouts: Bool {
        consistency.workoutDays28 > 0 || recentWorkout != nil
    }
}
