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
        asOf date: Date = Date(),
        calendar: Calendar = .current
    ) -> StreakSummary {
        let logByDay = Dictionary(uniqueKeysWithValues: logs.map {
            (calendar.startOfDay(for: $0.date), $0)
        })

        return StreakSummary(
            loggingStreak: consecutiveDays(
                startingFrom: date,
                calendar: calendar
            ) { day in
                guard let log = logByDay[day] else { return false }
                return isLoggingDay(log)
            },
            proteinStreak: consecutiveDays(startingFrom: date, calendar: calendar) { day in
                guard let log = logByDay[day] else { return false }
                return proteinGoalMet(log)
            },
            hydrationStreak: consecutiveDays(startingFrom: date, calendar: calendar) { day in
                guard let log = logByDay[day] else { return false }
                return waterGoalMet(log)
            },
            workoutStreak: consecutiveDays(startingFrom: date, calendar: calendar) { day in
                workoutDates.contains(day)
            }
        )
    }

    static func isLoggingDay(_ log: DailyLog) -> Bool {
        log.totals.calories > 0
            || log.waterConsumedMl > 0
            || log.weightKg != nil
    }

    static func isLogged(on day: Date, in logs: [DailyLog], calendar: Calendar) -> Bool {
        let dayStart = calendar.startOfDay(for: day)
        guard let log = logs.first(where: { calendar.isDate($0.date, inSameDayAs: dayStart) }) else {
            return false
        }
        return isLoggingDay(log)
    }

    static func longestLoggingStreak(
        in logs: [DailyLog],
        calendar: Calendar = .current
    ) -> Int {
        longestConsecutiveDays(in: logs, calendar: calendar, predicate: isLoggingDay)
    }

    static func longestProteinStreak(
        in logs: [DailyLog],
        calendar: Calendar = .current
    ) -> Int {
        longestConsecutiveDays(in: logs, calendar: calendar, predicate: proteinGoalMet)
    }

    static func longestHydrationStreak(
        in logs: [DailyLog],
        calendar: Calendar = .current
    ) -> Int {
        longestConsecutiveDays(in: logs, calendar: calendar, predicate: waterGoalMet)
    }

    static func loggingStreakEndingYesterday(
        logs: [DailyLog],
        asOf date: Date,
        calendar: Calendar = .current
    ) -> Int {
        guard let yesterday = calendar.date(byAdding: .day, value: -1, to: calendar.startOfDay(for: date)) else {
            return 0
        }
        let logByDay = Dictionary(uniqueKeysWithValues: logs.map {
            (calendar.startOfDay(for: $0.date), $0)
        })
        return consecutiveDays(startingFrom: yesterday, calendar: calendar) { day in
            guard let log = logByDay[day] else { return false }
            return isLoggingDay(log)
        }
    }

    /// Consecutive weeks (including the current week) with at least one workout day.
    static func trainingStreakWeeks(
        workoutDates: Set<Date>,
        asOf date: Date,
        calendar: Calendar = .current
    ) -> Int {
        guard !workoutDates.isEmpty else { return 0 }

        var streak = 0
        var cursor = calendar.startOfDay(for: date)

        while true {
            guard let weekInterval = calendar.dateInterval(of: .weekOfYear, for: cursor) else { break }
            let hasWorkout = workoutDates.contains { workoutDay in
                weekInterval.contains(workoutDay)
            }
            guard hasWorkout else { break }
            streak += 1
            guard let previousWeek = calendar.date(byAdding: .weekOfYear, value: -1, to: cursor) else {
                break
            }
            cursor = previousWeek
        }

        return streak
    }

    /// Logged days in the rolling window ending on `date` (inclusive).
    static func loggedDaysInRollingWindow(
        logs: [DailyLog],
        windowDays: Int = 7,
        asOf date: Date = Date(),
        calendar: Calendar = .current
    ) -> Int {
        guard windowDays > 0 else { return 0 }

        let endDay = calendar.startOfDay(for: date)
        guard let startDay = calendar.date(byAdding: .day, value: -(windowDays - 1), to: endDay) else {
            return 0
        }

        let logByDay = Dictionary(uniqueKeysWithValues: logs.map {
            (calendar.startOfDay(for: $0.date), $0)
        })

        var loggedDays = 0
        var cursor = startDay
        while cursor <= endDay {
            if let log = logByDay[cursor], isLoggingDay(log) {
                loggedDays += 1
            }
            guard let next = calendar.date(byAdding: .day, value: 1, to: cursor) else { break }
            cursor = next
        }

        return loggedDays
    }

    // MARK: - Private

    private static func proteinGoalMet(_ log: DailyLog) -> Bool {
        log.targets.proteinTarget > 0
            && log.totals.protein >= log.targets.proteinTarget * 0.9
    }

    private static func waterGoalMet(_ log: DailyLog) -> Bool {
        log.targets.waterTargetMl > 0
            && log.waterConsumedMl >= Int(Double(log.targets.waterTargetMl) * 0.8)
    }

    private static func longestConsecutiveDays(
        in logs: [DailyLog],
        calendar: Calendar,
        predicate: (DailyLog) -> Bool
    ) -> Int {
        let sortedDays = Set(
            logs.filter(predicate).map { calendar.startOfDay(for: $0.date) }
        ).sorted()
        guard !sortedDays.isEmpty else { return 0 }

        var best = 1
        var current = 1
        for index in 1..<sortedDays.count {
            let previous = sortedDays[index - 1]
            let day = sortedDays[index]
            if let nextDay = calendar.date(byAdding: .day, value: 1, to: previous),
               calendar.isDate(nextDay, inSameDayAs: day) {
                current += 1
                best = max(best, current)
            } else {
                current = 1
            }
        }
        return best
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
