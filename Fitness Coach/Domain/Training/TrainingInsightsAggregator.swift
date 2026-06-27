//
//  TrainingInsightsAggregator.swift
//  Fitness Coach
//
//  Forma — Deterministic Apple Health workout aggregation for Training Insights.
//

import Foundation

enum TrainingInsightsAggregator {

    static let defaultLookbackDays = 28

    static func summary(
        workouts: [HealthWorkoutRecord],
        asOf date: Date = Date(),
        calendar: Calendar = .current
    ) -> TrainingInsightsSummary {
        let todayStart = calendar.startOfDay(for: date)
        let weekStart = calendar.date(byAdding: .day, value: -6, to: todayStart) ?? todayStart

        let weeklyWorkouts = workouts.filter { $0.startDate >= weekStart && $0.startDate <= date }
        let weekly = weeklySummary(from: weeklyWorkouts, calendar: calendar)
        let consistency = consistencySummary(
            workouts: workouts,
            asOf: date,
            calendar: calendar
        )

        return TrainingInsightsSummary(
            weekly: weekly,
            recentWorkout: workouts.max(by: { $0.startDate < $1.startDate }),
            consistency: consistency,
            consistencyNote: TrainingInsightsConsistencyNoteBuilder.note(for: consistency),
            coachNote: TrainingInsightsCoachNoteBuilder.note(weeklyWorkoutCount: weekly.workoutCount)
        )
    }

    // MARK: - Weekly

    static func weeklySummary(
        from workouts: [HealthWorkoutRecord],
        calendar: Calendar = .current
    ) -> TrainingInsightsWeeklySummary {
        let duration = workouts.reduce(0) { $0 + $1.durationMinutes }
        let calories = workouts.compactMap(\.activeCalories)
        let totalCalories = calories.isEmpty ? nil : calories.reduce(0, +)
        let uniqueDays = Set(workouts.map { calendar.startOfDay(for: $0.startDate) }).count

        return TrainingInsightsWeeklySummary(
            workoutDays: uniqueDays,
            workoutCount: workouts.count,
            totalDurationMinutes: duration,
            activeCalories: totalCalories,
            workoutTypes: workoutTypeCounts(from: workouts)
        )
    }

    static func workoutTypeCounts(from workouts: [HealthWorkoutRecord]) -> [TrainingInsightsWorkoutTypeCount] {
        var counts: [String: Int] = [:]
        for workout in workouts {
            counts[workout.activityName, default: 0] += 1
        }
        return counts
            .map { TrainingInsightsWorkoutTypeCount(name: $0.key, count: $0.value) }
            .sorted {
                if $0.count == $1.count { return $0.name < $1.name }
                return $0.count > $1.count
            }
    }

    // MARK: - Consistency

    static func consistencySummary(
        workouts: [HealthWorkoutRecord],
        asOf date: Date,
        calendar: Calendar = .current
    ) -> TrainingInsightsConsistencySummary {
        let todayStart = calendar.startOfDay(for: date)
        let monthStart = calendar.date(
            from: calendar.dateComponents([.year, .month], from: todayStart)
        ) ?? todayStart

        return TrainingInsightsConsistencySummary(
            workoutDays7: workoutDays(
                in: workouts,
                from: calendar.date(byAdding: .day, value: -6, to: todayStart) ?? todayStart,
                to: date,
                calendar: calendar
            ),
            workoutDays14: workoutDays(
                in: workouts,
                from: calendar.date(byAdding: .day, value: -13, to: todayStart) ?? todayStart,
                to: date,
                calendar: calendar
            ),
            workoutDays28: workoutDays(
                in: workouts,
                from: calendar.date(byAdding: .day, value: -27, to: todayStart) ?? todayStart,
                to: date,
                calendar: calendar
            ),
            workoutDaysThisMonth: workoutDays(
                in: workouts,
                from: monthStart,
                to: date,
                calendar: calendar
            )
        )
    }

    static func workoutDays(
        in workouts: [HealthWorkoutRecord],
        from startDate: Date,
        to endDate: Date,
        calendar: Calendar = .current
    ) -> Int {
        let days = workouts
            .filter { $0.startDate >= startDate && $0.startDate <= endDate }
            .map { calendar.startOfDay(for: $0.startDate) }
        return Set(days).count
    }

    static func lookbackStart(
        asOf date: Date = Date(),
        days: Int = defaultLookbackDays,
        calendar: Calendar = .current
    ) -> Date {
        let todayStart = calendar.startOfDay(for: date)
        let monthStart = calendar.date(
            from: calendar.dateComponents([.year, .month], from: todayStart)
        ) ?? todayStart
        let rollingStart = calendar.date(byAdding: .day, value: -(max(days, 1) - 1), to: todayStart) ?? todayStart
        return min(rollingStart, monthStart)
    }
}
