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
