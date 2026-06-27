//
//  StreakCalculator.swift
//  Fitness Coach
//
//  FitPilot AI — Deterministic logging streak calculations.
//

import Foundation

struct StreakSummary: Equatable, Sendable {
    var loggingStreak: Int
    var proteinStreak: Int
    var hydrationStreak: Int
    var workoutStreak: Int
}

enum StreakCalculator {

    static func calculate(
        logs: [DailyLog],
        workoutDates: Set<Date>,
        asOf date: Date = Date()
    ) -> StreakSummary {
        let calendar = Calendar.current
        let logByDay = Dictionary(uniqueKeysWithValues: logs.map {
            (calendar.startOfDay(for: $0.date), $0)
        })

        return StreakSummary(
            loggingStreak: consecutiveDays(
                startingFrom: date,
                calendar: calendar
            ) { day in
                guard let log = logByDay[day] else { return false }
                return log.totals.calories > 0
                    || log.waterConsumedMl > 0
                    || log.weightKg != nil
            },
            proteinStreak: consecutiveDays(startingFrom: date, calendar: calendar) { day in
                guard let log = logByDay[day] else { return false }
                return log.targets.proteinTarget > 0
                    && log.totals.protein >= log.targets.proteinTarget * 0.9
            },
            hydrationStreak: consecutiveDays(startingFrom: date, calendar: calendar) { day in
                guard let log = logByDay[day] else { return false }
                return log.targets.waterTargetMl > 0
                    && log.waterConsumedMl >= Int(Double(log.targets.waterTargetMl) * 0.8)
            },
            workoutStreak: consecutiveDays(startingFrom: date, calendar: calendar) { day in
                workoutDates.contains(day)
            }
        )
    }

    private static func consecutiveDays(
        startingFrom date: Date,
        calendar: Calendar,
        predicate: (Date) -> Bool
    ) -> Int {
        var streak = 0
        var cursor = calendar.startOfDay(for: date)

        while predicate(cursor) {
            streak += 1
            guard let previous = calendar.date(byAdding: .day, value: -1, to: cursor) else { break }
            cursor = previous
        }

        return streak
    }
}
