//
//  TrainingInsightsPreviewData.swift
//  Fitness Coach
//
//  Forma — Sample Apple Health training insights for previews.
//

import Foundation

enum TrainingInsightsPreviewData {

    private static var calendar: Calendar {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(secondsFromGMT: 0)!
        return calendar
    }

    static var referenceNow: Date {
        var components = DateComponents()
        components.year = 2026
        components.month = 6
        components.day = 27
        components.hour = 12
        return calendar.date(from: components)!
    }

    static let sampleWorkouts: [HealthWorkoutRecord] = {
        let now = referenceNow
        return [
            HealthWorkoutRecord(
                id: UUID(uuidString: "00000000-0000-0000-0000-000000000101")!,
                activityName: "Strength training",
                startDate: calendar.date(byAdding: .day, value: -1, to: now)!,
                endDate: calendar.date(byAdding: .minute, value: 45, to: calendar.date(byAdding: .day, value: -1, to: now)!)!,
                durationMinutes: 45,
                activeCalories: 320
            ),
            HealthWorkoutRecord(
                id: UUID(uuidString: "00000000-0000-0000-0000-000000000102")!,
                activityName: "Running",
                startDate: calendar.date(byAdding: .day, value: -4, to: now)!,
                endDate: calendar.date(byAdding: .minute, value: 50, to: calendar.date(byAdding: .day, value: -4, to: now)!)!,
                durationMinutes: 50,
                activeCalories: 300
            ),
            HealthWorkoutRecord(
                id: UUID(uuidString: "00000000-0000-0000-0000-000000000103")!,
                activityName: "Strength training",
                startDate: calendar.date(byAdding: .day, value: -10, to: now)!,
                endDate: calendar.date(byAdding: .minute, value: 40, to: calendar.date(byAdding: .day, value: -10, to: now)!)!,
                durationMinutes: 40,
                activeCalories: 280
            )
        ]
    }()

    static var sampleSummary: TrainingInsightsSummary {
        TrainingInsightsAggregator.summary(
            workouts: sampleWorkouts,
            asOf: referenceNow,
            calendar: calendar
        )
    }
}
