//
//  TodayHealthWorkoutResolver.swift
//  Fitness Coach
//
//  Forma — Today's Apple Health workout count for the Today checklist (Stage 8).
//

import Foundation

enum TodayHealthWorkoutResolver {

    static func workoutCountToday(
        reader: HealthKitWorkoutReading,
        on date: Date = Date(),
        calendar: Calendar = .current
    ) async throws -> Int {
        let dayStart = calendar.startOfDay(for: date)
        let dayEnd = calendar.date(byAdding: .day, value: 1, to: dayStart) ?? date
        let workouts = try await reader.fetchWorkouts(from: dayStart, to: dayEnd)
        return workouts.count
    }

    static func workoutCountThisWeek(
        reader: HealthKitWorkoutReading,
        on date: Date = Date(),
        calendar: Calendar = .current
    ) async throws -> Int {
        let todayStart = calendar.startOfDay(for: date)
        let weekStart = calendar.date(byAdding: .day, value: -6, to: todayStart) ?? todayStart
        let dayEnd = calendar.date(byAdding: .day, value: 1, to: todayStart) ?? date
        let workouts = try await reader.fetchWorkouts(from: weekStart, to: dayEnd)
        return workouts.count
    }
}
