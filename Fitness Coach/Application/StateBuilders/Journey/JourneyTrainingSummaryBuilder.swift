//
//  JourneyTrainingSummaryBuilder.swift
//  Fitness Coach
//
//  Forma — Apple Health training summaries for Journey (Stage 9).
//

import Foundation

enum JourneyTrainingSummaryBuilder {

    static func weeklyTrainingStatus(
        integrationState: TrainingIntegrationState,
        dataSource: TrainingDataSource,
        weekWorkouts: [HealthWorkoutRecord],
        asOf date: Date = Date(),
        calendar: Calendar = .current
    ) -> JourneyWeeklyTrainingStatus {
        guard dataSource == .appleHealth else {
            return .hidden
        }
        if integrationState.showsConnectionGate {
            return .locked
        }
        guard integrationState.isConnected else {
            return .locked
        }

        let todayStart = calendar.startOfDay(for: date)
        let weekStart = calendar.date(byAdding: .day, value: -6, to: todayStart) ?? todayStart
        let filtered = weekWorkouts.filter { $0.startDate >= weekStart && $0.startDate <= date }

        let weekly = TrainingInsightsAggregator.weeklySummary(
            from: filtered,
            calendar: calendar
        )

        guard weekly.hasActivity else {
            return .connectedEmpty
        }

        let burnValues = filtered.compactMap(\.activeCalories)
        let avgBurn = burnValues.isEmpty
            ? nil
            : Int((Double(burnValues.reduce(0, +)) / Double(burnValues.count)).rounded())

        let durations = filtered.compactMap(\.durationMinutes)
        let avgDuration = durations.isEmpty
            ? nil
            : Int((Double(durations.reduce(0, +)) / Double(durations.count)).rounded())

        return .connected(
            workoutDays: weekly.workoutDays,
            averageCaloriesBurned: avgBurn,
            averageTrainingDurationMinutes: avgDuration
        )
    }

    static func workoutAnalytics(
        integrationState: TrainingIntegrationState,
        dataSource: TrainingDataSource,
        workouts: [HealthWorkoutRecord],
        rangeDays: Int,
        calendar: Calendar = .current
    ) -> ProgressWorkoutSummary? {
        guard dataSource == .appleHealth, integrationState.isConnected else {
            return nil
        }
        guard !workouts.isEmpty else {
            return nil
        }

        let totalCalories = workouts.compactMap(\.activeCalories).reduce(0, +)
        let weeks = max(Double(rangeDays) / 7.0, 1.0)
        let durations = workouts.compactMap(\.durationMinutes)
        let avgDuration = durations.isEmpty
            ? nil
            : Int((Double(durations.reduce(0, +)) / Double(durations.count)).rounded())
        let workoutDays = Set(
            workouts.map { calendar.startOfDay(for: $0.startDate) }
        ).count

        return ProgressWorkoutSummary(
            workoutCount: workouts.count,
            workoutDays: workoutDays,
            totalEstimatedCaloriesBurned: totalCalories,
            averageWorkoutsPerWeek: Double(workouts.count) / weeks,
            averageDurationMinutes: avgDuration,
            isFromAppleHealth: true
        )
    }

    static func healthWorkoutDayStarts(
        from workouts: [HealthWorkoutRecord],
        calendar: Calendar = .current
    ) -> Set<Date> {
        Set(workouts.map { calendar.startOfDay(for: $0.startDate) })
    }
}
