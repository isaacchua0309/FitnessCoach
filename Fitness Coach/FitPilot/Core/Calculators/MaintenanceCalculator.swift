//
//  MaintenanceCalculator.swift
//  Fitness Coach
//
//  FitPilot AI — Deterministic maintenance calorie estimation from real data.
//

import Foundation

struct MaintenanceCalculator {

    // MARK: Averages

    static func averageCalories(from logs: [DailyLog]) -> Int? {
        guard !logs.isEmpty else { return nil }
        let total = logs.reduce(0) { $0 + $1.totals.calories }
        return Int((Double(total) / Double(logs.count)).rounded())
    }

    static func weightChangeKg(from weights: [WeightEntry]) -> Double? {
        guard weights.count >= 2 else { return nil }
        let sorted = weights.sorted { $0.date < $1.date }
        guard let first = sorted.first, let last = sorted.last else { return nil }
        return last.weightKg - first.weightKg
    }

    // MARK: Estimate

    static func estimateMaintenance(logs: [DailyLog], weights: [WeightEntry]) -> MaintenanceEstimate {
        let days = logs.count
        let average = averageCalories(from: logs)
        let change = weightChangeKg(from: weights)
        let hasEnoughData = days >= CalculatorConstants.minimumMaintenanceDays

        guard hasEnoughData, let averageCalories = average, let weightChangeKg = change else {
            return MaintenanceEstimate(
                days: days,
                averageCalories: average ?? 0,
                weightChangeKg: change,
                estimatedDailyDeficit: nil,
                estimatedMaintenanceCalories: nil,
                confidence: .low,
                hasEnoughData: hasEnoughData
            )
        }

        // Weight lost (positive change loss) implies an energy deficit. A weight
        // gain produces a negative deficit, lowering maintenance below intake.
        let weightLostKg = -weightChangeKg
        let dailyDeficit = (weightLostKg * CalculatorConstants.kcalPerKgFat) / Double(days)
        let maintenance = Double(averageCalories) + dailyDeficit

        return MaintenanceEstimate(
            days: days,
            averageCalories: averageCalories,
            weightChangeKg: weightChangeKg,
            estimatedDailyDeficit: Int(dailyDeficit.rounded()),
            estimatedMaintenanceCalories: Int(maintenance.rounded()),
            confidence: confidence(forDays: days),
            hasEnoughData: true
        )
    }

    // MARK: Helpers

    private static func confidence(forDays days: Int) -> ConfidenceLevel {
        switch days {
        case ..<CalculatorConstants.minimumMaintenanceDays:
            return .low
        case CalculatorConstants.minimumMaintenanceDays..<14:
            return .medium
        default:
            return .high
        }
    }
}
