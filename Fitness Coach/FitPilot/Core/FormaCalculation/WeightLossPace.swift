//
//  WeightLossPace.swift
//  Fitness Coach
//
//  Forma — Weight-loss pace model (presets and advanced targets).
//

import Foundation

// MARK: - Preset

enum WeightLossPreset: String, Codable, CaseIterable, Equatable, Sendable {
    case gentle
    case moderate
    case aggressive

    /// Fraction of body weight per week (e.g. 0.005 = 0.50%).
    var weeklyLossFraction: Double {
        switch self {
        case .gentle:
            return FormaCalculationConstants.presetGentleWeeklyLossFraction
        case .moderate:
            return FormaCalculationConstants.presetModerateWeeklyLossFraction
        case .aggressive:
            return FormaCalculationConstants.presetAggressiveWeeklyLossFraction
        }
    }

    init(legacy aggressiveness: CalorieAggressiveness) {
        switch aggressiveness {
        case .conservative:
            self = .gentle
        case .moderate:
            self = .moderate
        case .aggressive:
            self = .aggressive
        }
    }

    var legacyAggressiveness: CalorieAggressiveness {
        switch self {
        case .gentle:
            return .conservative
        case .moderate:
            return .moderate
        case .aggressive:
            return .aggressive
        }
    }
}

// MARK: - Pace

enum WeightLossPace: Equatable, Sendable {
    case preset(WeightLossPreset)
    case advancedKgPerWeek(Double)
    case advancedKgPerMonth(Double)
  /// Reserved for goal-date-driven pace (UI not yet wired).
    case goalDate(Date)
}

extension WeightLossPace {

    init(legacy aggressiveness: CalorieAggressiveness) {
        self = .preset(WeightLossPreset(legacy: aggressiveness))
    }

    var isLossPreset: Bool {
        if case .preset = self { return true }
        return false
    }

    /// Best-effort mapping for persisted `CalorieAggressiveness` (advanced modes default to moderate).
    var legacyAggressiveness: CalorieAggressiveness {
        switch self {
        case .preset(let preset):
            return preset.legacyAggressiveness
        case .advancedKgPerWeek, .advancedKgPerMonth, .goalDate:
            return .moderate
        }
    }

    func weeklyLossKg(
        weightKg: Double,
        goalWeightKg: Double,
        referenceDate: Date
    ) -> Double {
        switch self {
        case .preset(let preset):
            return weightKg * preset.weeklyLossFraction
        case .advancedKgPerWeek(let kg):
            return kg
        case .advancedKgPerMonth(let monthlyKg):
            let weeksPerMonth = FormaCalculationConstants.daysPerAverageMonth / 7.0
            return monthlyKg / weeksPerMonth
        case .goalDate(let goalDate):
            let remainingKg = weightKg - goalWeightKg
            let days = goalDate.timeIntervalSince(referenceDate) / 86_400.0
            let weeks = max(days / 7.0, 0.001)
            return max(remainingKg / weeks, 0)
        }
    }

    func weeklyLossFraction(weightKg: Double, goalWeightKg: Double, referenceDate: Date) -> Double {
        guard weightKg > 0 else { return 0 }
        return weeklyLossKg(
            weightKg: weightKg,
            goalWeightKg: goalWeightKg,
            referenceDate: referenceDate
        ) / weightKg
    }

    var displayName: String {
        switch self {
        case .preset(.gentle):
            return "Gentle"
        case .preset(.moderate):
            return "Moderate"
        case .preset(.aggressive):
            return "Aggressive"
        case .advancedKgPerWeek:
            return "Custom weekly"
        case .advancedKgPerMonth:
            return "Custom monthly"
        case .goalDate:
            return "Goal date"
        }
    }
}
