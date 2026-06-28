//
//  TodayHealthStepResolver.swift
//  Fitness Coach
//
//  Forma — Today's Apple Health step count for the Today activity section.
//

import Foundation

enum TodayHealthStepResolver {

    static func stepsToday(
        reader: HealthKitStepReading,
        on date: Date = Date(),
        calendar: Calendar = .current
    ) async throws -> Int {
        let dayStart = calendar.startOfDay(for: date)
        let dayEnd = calendar.date(byAdding: .day, value: 1, to: dayStart) ?? date
        return try await reader.fetchStepCount(from: dayStart, to: dayEnd)
    }
}
