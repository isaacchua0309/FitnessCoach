//
//  JourneyLogMetrics.swift
//  Fitness Coach
//
//  Forma — Shared deterministic metrics for Journey dashboard builders.
//

import Foundation

enum JourneyLogMetrics {

    static let proteinHitThreshold = 0.9
    static let waterHitThreshold = 0.8
    static let calorieAdherenceTolerance = 0.10
    static let weekDayCount = 7

    // MARK: - Day classification

    static func foodLoggedDays(in logs: [DailyLog]) -> Int {
        logs.filter { $0.totals.calories > 0 }.count
    }

    static func proteinGoalDays(in logs: [DailyLog]) -> Int {
        logs.filter { log in
            log.targets.proteinTarget > 0
                && log.totals.protein >= log.targets.proteinTarget * proteinHitThreshold
        }.count
    }

    static func waterGoalDays(in logs: [DailyLog]) -> Int {
        logs.filter { log in
            log.targets.waterTargetMl > 0
                && Double(log.waterConsumedMl) >= Double(log.targets.waterTargetMl) * waterHitThreshold
        }.count
    }

    static func calorieAdherenceDays(in logs: [DailyLog]) -> Int {
        logs.filter { log in
            let target = log.targets.calorieTarget
            guard target > 0 else { return false }
            let delta = abs(Double(log.totals.calories - target)) / Double(target)
            return delta <= calorieAdherenceTolerance
        }.count
    }

    static func adherencePercent(achieved: Int, eligible: Int) -> Double? {
        guard eligible > 0 else { return nil }
        return Double(achieved) / Double(eligible)
    }

    static func habitScore(achieved: Int, total: Int) -> Double {
        guard total > 0 else { return 0 }
        return Double(achieved) / Double(total)
    }

    // MARK: - Completed days

    static func completedDaySet(
        logs: [DailyLog],
        healthWorkoutDayStarts: Set<Date> = [],
        weights: [WeightEntry],
        calendar: Calendar
    ) -> Set<Date> {
        var days = Set<Date>()

        for log in logs where log.totals.calories > 0 || log.waterConsumedMl > 0 {
            days.insert(calendar.startOfDay(for: log.date))
        }
        for weight in weights {
            days.insert(calendar.startOfDay(for: weight.date))
        }
        days.formUnion(healthWorkoutDayStarts)

        return days
    }

    static func longestStreak(in sortedDays: [Date], calendar: Calendar) -> Int {
        guard !sortedDays.isEmpty else { return 0 }
        var best = 1
        var current = 1
        for index in 1..<sortedDays.count {
            let previous = sortedDays[index - 1]
            let day = sortedDays[index]
            if let next = calendar.date(byAdding: .day, value: 1, to: previous),
               calendar.isDate(next, inSameDayAs: day) {
                current += 1
                best = max(best, current)
            } else {
                current = 1
            }
        }
        return best
    }

    static func firstFoodLogDate(in logs: [DailyLog]) -> Date? {
        logs.filter { $0.totals.calories > 0 }
            .map(\.date)
            .min()
    }

    static func weightDelta(in weights: [WeightEntry]) -> Double? {
        let sorted = weights
            .filter { $0.weightKg > 0 }
            .sorted { $0.date < $1.date }
        guard let first = sorted.first, let last = sorted.last, sorted.count >= 2 else {
            return nil
        }
        return last.weightKg - first.weightKg
    }

    static func weekBuckets(
        logs: [DailyLog],
        calendar: Calendar,
        asOf: Date
    ) -> [[DailyLog]] {
        guard let weekStart = calendar.date(byAdding: .day, value: -6, to: calendar.startOfDay(for: asOf)) else {
            return []
        }

        var buckets: [Date: [DailyLog]] = [:]
        for log in logs where log.date >= weekStart && log.date <= asOf {
            let day = calendar.startOfDay(for: log.date)
            buckets[day, default: []].append(log)
        }

        return (0..<weekDayCount).compactMap { offset in
            guard let day = calendar.date(byAdding: .day, value: offset, to: weekStart) else { return nil }
            return buckets[calendar.startOfDay(for: day)] ?? []
        }
    }

    static func proteinDaysInWeek(_ weekBuckets: [[DailyLog]]) -> Int {
        weekBuckets.filter { bucket in
            guard let log = bucket.first else { return false }
            return log.targets.proteinTarget > 0
                && log.totals.protein >= log.targets.proteinTarget * proteinHitThreshold
        }.count
    }

    static func waterDaysInWeek(_ weekBuckets: [[DailyLog]]) -> Int {
        weekBuckets.filter { bucket in
            guard let log = bucket.first else { return false }
            return log.targets.waterTargetMl > 0
                && Double(log.waterConsumedMl) >= Double(log.targets.waterTargetMl) * waterHitThreshold
        }.count
    }

    /// Best protein-goal days across any rolling 7-day window in `logs`.
    static func bestProteinDaysInRollingWeek(
        logs: [DailyLog],
        calendar: Calendar
    ) -> Int {
        bestMetricInRollingWeek(logs: logs, calendar: calendar) { weekLogs in
            proteinGoalDays(in: weekLogs)
        }
    }

    /// Best water-goal days across any rolling 7-day window in `logs`.
    static func bestWaterDaysInRollingWeek(
        logs: [DailyLog],
        calendar: Calendar
    ) -> Int {
        bestMetricInRollingWeek(logs: logs, calendar: calendar) { weekLogs in
            waterGoalDays(in: weekLogs)
        }
    }

    private static func bestMetricInRollingWeek(
        logs: [DailyLog],
        calendar: Calendar,
        metric: ([DailyLog]) -> Int
    ) -> Int {
        let dayStarts = Set(logs.map { calendar.startOfDay(for: $0.date) }).sorted()
        guard !dayStarts.isEmpty else { return 0 }

        var best = 0
        for windowStart in dayStarts {
            guard let windowEnd = calendar.date(byAdding: .day, value: 6, to: windowStart) else {
                continue
            }
            let weekLogs = logs.filter {
                let day = calendar.startOfDay(for: $0.date)
                return day >= windowStart && day <= windowEnd
            }
            best = max(best, metric(weekLogs))
        }
        return best
    }
}
