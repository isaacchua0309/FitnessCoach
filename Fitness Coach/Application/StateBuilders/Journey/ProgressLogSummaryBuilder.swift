//
//  ProgressLogSummaryBuilder.swift
//  Fitness Coach
//
//  Forma — Pure aggregations for Journey detailed analytics.
//

import Foundation

enum ProgressLogSummaryBuilder {

    static func nutritionSummary(from logs: [DailyLog]) -> ProgressNutritionSummary {
        guard !logs.isEmpty else {
            return ProgressNutritionSummary(
                loggedDays: 0,
                averageCalories: nil,
                averageProtein: nil,
                averageCarbs: nil,
                averageFat: nil,
                averageFiber: nil
            )
        }

        let count = Double(logs.count)
        let totalCalories = logs.reduce(0) { $0 + $1.totals.calories }
        let totalProtein = logs.reduce(0.0) { $0 + $1.totals.protein }
        let totalCarbs = logs.reduce(0.0) { $0 + $1.totals.carbs }
        let totalFat = logs.reduce(0.0) { $0 + $1.totals.fat }
        let fiberValues = logs.compactMap(\.totals.fiber)

        return ProgressNutritionSummary(
            loggedDays: logs.count,
            averageCalories: Int((Double(totalCalories) / count).rounded()),
            averageProtein: totalProtein / count,
            averageCarbs: totalCarbs / count,
            averageFat: totalFat / count,
            averageFiber: average(fiberValues)
        )
    }

    static func waterSummary(from logs: [DailyLog]) -> ProgressWaterSummary {
        guard !logs.isEmpty else {
            return ProgressWaterSummary(
                loggedDays: 0,
                averageWaterMl: nil,
                averageWaterTargetMl: nil,
                consistencyPercent: nil
            )
        }

        let totalWater = logs.reduce(0) { $0 + $1.waterConsumedMl }
        let totalTargets = logs.reduce(0) { $0 + $1.targets.waterTargetMl }
        let eligible = logs.filter { $0.targets.waterTargetMl > 0 }
        let consistentDays = eligible.filter {
            Double($0.waterConsumedMl) >= Double($0.targets.waterTargetMl) * 0.8
        }.count

        let consistency: Double? = eligible.isEmpty
            ? nil
            : Double(consistentDays) / Double(eligible.count)

        return ProgressWaterSummary(
            loggedDays: logs.count,
            averageWaterMl: Int((Double(totalWater) / Double(logs.count)).rounded()),
            averageWaterTargetMl: Int((Double(totalTargets) / Double(logs.count)).rounded()),
            consistencyPercent: consistency
        )
    }

    private static func average(_ values: [Double]) -> Double? {
        guard !values.isEmpty else { return nil }
        return values.reduce(0, +) / Double(values.count)
    }
}
