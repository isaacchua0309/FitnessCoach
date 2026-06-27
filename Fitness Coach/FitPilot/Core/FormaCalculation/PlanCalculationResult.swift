//
//  PlanCalculationResult.swift
//  Fitness Coach
//
//  Forma — Pure outputs from the plan calculation engine.
//

import Foundation

// MARK: - Safety

enum PlanWarningSeverity: String, Equatable, Sendable, Codable {
    case warn
    case strongWarning
    case error
}

enum PlanSafetyLevel: String, Equatable, Sendable, Codable {
    case ok
    case caution
    case strongWarning
    case error
}

struct PlanWarning: Equatable, Sendable, Identifiable {
    let code: String
    let severity: PlanWarningSeverity
    let message: String

    var id: String { code }
}

// MARK: - Explanation

struct PlanCalculationExplanation: Equatable, Sendable {

    let bmrLine: String
    let tdeeLine: String
    let lossRateLine: String?
    let dailyDeficitLine: String?
    let calorieTargetLine: String
    let proteinLine: String
    let fatLine: String
    let carbLine: String
    let waterLine: String

    /// Ordered human-readable lines for display.
    var allLines: [String] {
        var lines = [bmrLine, tdeeLine]
        if let lossRateLine { lines.append(lossRateLine) }
        if let dailyDeficitLine { lines.append(dailyDeficitLine) }
        lines.append(contentsOf: [
            calorieTargetLine,
            proteinLine,
            fatLine,
            carbLine,
            waterLine
        ])
        return lines
    }
}

// MARK: - Intermediate breakdown (machine-readable explainability)

struct EnergyBreakdown: Equatable, Sendable {
    let bmrKcal: Int
    let activityMultiplier: Double
    let stepBonusKcal: Int
    let trainingBonusKcal: Int
    let tdeeKcal: Int
}

struct PaceBreakdown: Equatable, Sendable {
    let paceDescription: String
    let requestedWeeklyLossKg: Double
    let weeklyLossFractionOfBodyWeight: Double
    let requestedDailyDeficitKcal: Int
}

struct MacroBreakdown: Equatable, Sendable {
    let proteinTargetG: Double
    let fatTargetG: Double
    let carbTargetG: Double
    let proteinGPerKg: Double
    let fatGPerKg: Double
}

struct CalorieTargetBreakdown: Equatable, Sendable {
    let calorieFloorKcal: Int
    let rawCalorieTargetKcal: Int
    let calorieTargetKcal: Int
    let requestedDailyDeficitKcal: Int
    let appliedDailyDeficitKcal: Int
    let calorieFloorApplied: Bool
}

// MARK: - Result

struct PlanCalculationResult: Equatable, Sendable {

    let goalDirection: PlanGoalDirection

    // MARK: Energy (kcal)

    let bmrKcal: Int
    let tdeeKcal: Int
    let requestedDailyDeficitKcal: Int
    let dailyDeficitKcal: Int
    let calorieTargetKcal: Int

    // MARK: Macros (g)

    let proteinTargetG: Double
    let fatTargetG: Double
    let carbTargetG: Double

    // MARK: Water (ml)

    let waterTargetMl: Int

    // MARK: Pace (kg/week)

    let weightLossRateKgPerWeek: Double

    // MARK: Safety & explainability

    let safetyLevel: PlanSafetyLevel
    let warnings: [PlanWarning]
    let explanation: PlanCalculationExplanation

    // MARK: Detailed breakdown

    let energy: EnergyBreakdown
    let pace: PaceBreakdown?
    let calories: CalorieTargetBreakdown
    let macros: MacroBreakdown
}
