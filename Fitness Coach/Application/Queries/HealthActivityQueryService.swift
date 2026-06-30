//
//  HealthActivityQueryService.swift
//  Fitness Coach
//
//  Application-layer queries for Apple Health workouts and steps.
//

import Foundation

struct HealthActivityQueryService: Sendable {

    let workoutReader: HealthKitWorkoutReading
    let stepReader: HealthKitStepReading

    func workoutCountToday(
        on date: Date = Date(),
        calendar: Calendar = .current
    ) async throws -> Int {
        let dayStart = calendar.startOfDay(for: date)
        let dayEnd = calendar.date(byAdding: .day, value: 1, to: dayStart) ?? date
        let workouts = try await workoutReader.fetchWorkouts(from: dayStart, to: dayEnd)
        return workouts.count
    }

    func workoutCountThisWeek(
        on date: Date = Date(),
        calendar: Calendar = .current
    ) async throws -> Int {
        let todayStart = calendar.startOfDay(for: date)
        let weekStart = calendar.date(byAdding: .day, value: -6, to: todayStart) ?? todayStart
        let dayEnd = calendar.date(byAdding: .day, value: 1, to: todayStart) ?? date
        let workouts = try await workoutReader.fetchWorkouts(from: weekStart, to: dayEnd)
        return workouts.count
    }

    func stepsToday(
        on date: Date = Date(),
        calendar: Calendar = .current
    ) async throws -> Int {
        let dayStart = calendar.startOfDay(for: date)
        let dayEnd = calendar.date(byAdding: .day, value: 1, to: dayStart) ?? date
        return try await stepReader.fetchStepCount(from: dayStart, to: dayEnd)
    }
}
