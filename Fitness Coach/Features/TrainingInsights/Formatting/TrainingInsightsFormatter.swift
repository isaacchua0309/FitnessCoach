//
//  TrainingInsightsFormatter.swift
//  Fitness Coach
//
//  Forma — Display formatting for Apple Health Training Insights.
//

import Foundation

enum TrainingInsightsFormatter {

    static func workoutCount(_ count: Int) -> String {
        count == 1 ? "1 workout" : "\(count) workouts"
    }

    static func workoutDays(_ count: Int) -> String {
        count == 1 ? "1 day" : "\(count) days"
    }

    static func workoutDaysThisWeek(_ count: Int) -> String {
        count == 1 ? "1 workout day" : "\(count) workout days"
    }

    static func durationMinutes(_ minutes: Int) -> String {
        TrainingFormatter.totalDuration(minutes)
    }

    static func activeCalories(_ calories: Int?) -> String? {
        guard let calories, calories > 0 else { return nil }
        return "\(calories) kcal"
    }

    static func recentWorkoutLine(_ workout: HealthWorkoutRecord) -> String {
        let duration = durationMinutes(workout.durationMinutes)
        return "\(workout.activityName) · \(duration)"
    }

    static func workoutDate(_ date: Date) -> String {
        date.formatted(date: .abbreviated, time: .omitted)
    }

    static func mostCommonWorkoutType(_ types: [TrainingInsightsWorkoutTypeCount]) -> String? {
        types.first?.name
    }

    static func workoutDays(inLast days: Int, count: Int) -> String {
        let dayLabel = count == 1 ? "workout day" : "workout days"
        return "\(count) \(dayLabel) in the last \(days) days"
    }

    static func workoutDaysThisMonth(_ count: Int) -> String {
        let dayLabel = count == 1 ? "workout day" : "workout days"
        return "\(count) \(dayLabel) this month"
    }

    static func workoutTypes(_ types: [TrainingInsightsWorkoutTypeCount]) -> String? {
        guard !types.isEmpty else { return nil }
        return types
            .map { type in
                type.count == 1 ? type.name : "\(type.name) (\(type.count))"
            }
            .joined(separator: " · ")
    }

    static func noWorkoutsThisWeek() -> String {
        FormaProductCopy.Journey.noAppleHealthWorkoutsThisWeek
    }
}
