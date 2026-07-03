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

    // MARK: - Week window

    static func rollingWeekDayStarts(
        asOf date: Date,
        calendar: Calendar
    ) -> [Date] {
        let endDay = calendar.startOfDay(for: date)
        return (0..<weekDayCount).compactMap { offset in
            calendar.date(byAdding: .day, value: -(weekDayCount - 1) + offset, to: endDay)
        }
    }

    static func logByDay(in logs: [DailyLog], calendar: Calendar) -> [Date: DailyLog] {
        Dictionary(
            uniqueKeysWithValues: logs.map { (calendar.startOfDay(for: $0.date), $0) }
        )
    }

    static func weightByDay(in weights: [WeightEntry], calendar: Calendar) -> Set<Date> {
        Set(weights.filter { $0.weightKg > 0 }.map { calendar.startOfDay(for: $0.date) })
    }

    // MARK: - Day classification

    static func foodLoggedDays(in logs: [DailyLog]) -> Int {
        uniqueFoodLoggedDays(in: logs, calendar: .current)
    }

    static func uniqueFoodLoggedDays(in logs: [DailyLog], calendar: Calendar) -> Int {
        Set(
            logs.filter { $0.totals.calories > 0 }
                .map { calendar.startOfDay(for: $0.date) }
        ).count
    }

    static func proteinGoalDays(in logs: [DailyLog]) -> Int {
        uniqueProteinGoalDays(in: logs, calendar: .current)
    }

    static func uniqueProteinGoalDays(in logs: [DailyLog], calendar: Calendar) -> Int {
        Set(
            logs.filter { log in
                log.targets.proteinTarget > 0
                    && log.totals.protein >= log.targets.proteinTarget * proteinHitThreshold
            }.map { calendar.startOfDay(for: $0.date) }
        ).count
    }

    static func waterGoalDays(in logs: [DailyLog]) -> Int {
        uniqueWaterGoalDays(in: logs, calendar: .current)
    }

    static func uniqueWaterGoalDays(in logs: [DailyLog], calendar: Calendar) -> Int {
        Set(
            logs.filter { log in
                log.targets.waterTargetMl > 0
                    && Double(log.waterConsumedMl) >= Double(log.targets.waterTargetMl) * waterHitThreshold
            }.map { calendar.startOfDay(for: $0.date) }
        ).count
    }

    static func calorieAdherenceDays(in logs: [DailyLog]) -> Int {
        uniqueCalorieAdherenceDays(in: logs, calendar: .current)
    }

    static func uniqueCalorieAdherenceDays(in logs: [DailyLog], calendar: Calendar) -> Int {
        Set(
            logs.filter { log in
                let target = log.targets.calorieTarget
                guard target > 0 else { return false }
                let delta = abs(Double(log.totals.calories - target)) / Double(target)
                return delta <= calorieAdherenceTolerance
            }.map { calendar.startOfDay(for: $0.date) }
        ).count
    }

    static func weightLoggedDays(
        in logs: [DailyLog],
        weights: [WeightEntry],
        calendar: Calendar
    ) -> Int {
        weightDays(in: logs, weights: weights, calendar: calendar).count
    }

    static func weightDays(
        in logs: [DailyLog],
        weights: [WeightEntry],
        calendar: Calendar
    ) -> Set<Date> {
        let entryDays = weightByDay(in: weights, calendar: calendar)
        let logDays = Set(
            logs.compactMap { log -> Date? in
                guard log.weightKg != nil else { return nil }
                return calendar.startOfDay(for: log.date)
            }
        )
        return entryDays.union(logDays)
    }

    static func workoutDays(
        in logs: [DailyLog],
        healthWorkoutDayStarts: Set<Date>,
        calendar: Calendar
    ) -> Int {
        workoutDaySet(in: logs, healthWorkoutDayStarts: healthWorkoutDayStarts, calendar: calendar).count
    }

    static func workoutDaySet(
        in logs: [DailyLog],
        healthWorkoutDayStarts: Set<Date>,
        calendar: Calendar
    ) -> Set<Date> {
        let logged = Set(
            logs.filter { $0.workoutCaloriesBurned > 0 }
                .map { calendar.startOfDay(for: $0.date) }
        )
        return logged.union(healthWorkoutDayStarts)
    }

    static func isFoodLogged(on day: Date, logsByDay: [Date: DailyLog]) -> Bool {
        guard let log = logsByDay[day] else { return false }
        return log.totals.calories > 0
    }

    static func isProteinGoalMet(on day: Date, logsByDay: [Date: DailyLog]) -> Bool {
        guard let log = logsByDay[day] else { return false }
        return log.targets.proteinTarget > 0
            && log.totals.protein >= log.targets.proteinTarget * proteinHitThreshold
    }

    static func isWaterGoalMet(on day: Date, logsByDay: [Date: DailyLog]) -> Bool {
        guard let log = logsByDay[day] else { return false }
        return log.targets.waterTargetMl > 0
            && Double(log.waterConsumedMl) >= Double(log.targets.waterTargetMl) * waterHitThreshold
    }

    static func isCalorieGoalMet(on day: Date, logsByDay: [Date: DailyLog]) -> Bool {
        guard let log = logsByDay[day] else { return false }
        let target = log.targets.calorieTarget
        guard target > 0 else { return false }
        let delta = abs(Double(log.totals.calories - target)) / Double(target)
        return delta <= calorieAdherenceTolerance
    }

    static func isWorkoutLogged(
        on day: Date,
        logsByDay: [Date: DailyLog],
        healthWorkoutDayStarts: Set<Date>
    ) -> Bool {
        if healthWorkoutDayStarts.contains(day) { return true }
        guard let log = logsByDay[day] else { return false }
        return log.workoutCaloriesBurned > 0
    }

    static func isWeightLogged(
        on day: Date,
        logsByDay: [Date: DailyLog],
        weightDays: Set<Date>
    ) -> Bool {
        weightDays.contains(day) || logsByDay[day]?.weightKg != nil
    }

    static func adherencePercent(achieved: Int, eligible: Int) -> Double? {
        guard eligible > 0 else { return nil }
        return Double(achieved) / Double(eligible)
    }

    static func habitScore(achieved: Int, total: Int) -> Double {
        guard total > 0 else { return 0 }
        return Double(achieved) / Double(total)
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
}
