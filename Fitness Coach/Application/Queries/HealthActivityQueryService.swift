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

    func workouts(
        from startDate: Date,
        to endDate: Date
    ) async throws -> [HealthWorkoutRecord] {
        try await workoutReader.fetchWorkouts(from: startDate, to: endDate)
    }

    func workoutCountToday(
        on date: Date = Date(),
        calendar: Calendar = .current
    ) async throws -> Int {
        try await dailyTrainingActivity(on: date, calendar: calendar).workoutCount
    }

    func workoutCountThisWeek(
        on date: Date = Date(),
        calendar: Calendar = .current
    ) async throws -> Int {
        let todayStart = calendar.startOfDay(for: date)
        let weekStart = calendar.date(byAdding: .day, value: -6, to: todayStart) ?? todayStart
        let dayEnd = calendar.date(byAdding: .day, value: 1, to: todayStart) ?? date
        let workouts = try await workouts(from: weekStart, to: dayEnd)
        return workouts.count
    }

    func dailyTrainingActivity(
        on date: Date = Date(),
        calendar: Calendar = .current
    ) async throws -> DailyTrainingActivity {
        let dayStart = calendar.startOfDay(for: date)
        let dayEnd = calendar.date(byAdding: .day, value: 1, to: dayStart) ?? date
        let dayWorkouts = try await workouts(from: dayStart, to: dayEnd)
        return DailyTrainingActivity(workouts: dayWorkouts)
    }

    func workoutDayStarts(
        from startDate: Date,
        to endDate: Date,
        calendar: Calendar = .current
    ) async throws -> Set<Date> {
        let records = try await workouts(from: startDate, to: endDate)
        return Set(records.map { calendar.startOfDay(for: $0.startDate) })
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
