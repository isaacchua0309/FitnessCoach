//
//  WeightLossRateCalculator.swift
//  Fitness Coach
//
//  Forma — Weight-loss pace and daily deficit derivation (Docs/FormaCalculationSpec.md §4).
//

import Foundation

enum WeightLossRateCalculator {

    // MARK: Pace → weekly loss

    static func paceBreakdown(
        input: PlanCalculationInput
    ) -> PaceBreakdown? {
        guard let weeklyLossKg = requestedWeeklyLossKg(input: input) else {
            return nil
        }

        let fraction = input.weightKg > 0 ? weeklyLossKg / input.weightKg : 0
        let dailyDeficit = dailyDeficitKcal(fromWeeklyLossKg: weeklyLossKg)

        return PaceBreakdown(
            paceDescription: paceDescription(
                for: input.weightLossPace,
                weeklyLossKg: weeklyLossKg,
                fraction: fraction
            ),
            requestedWeeklyLossKg: weeklyLossKg,
            weeklyLossFractionOfBodyWeight: fraction,
            requestedDailyDeficitKcal: dailyDeficit
        )
    }

    static func requestedWeeklyLossKg(input: PlanCalculationInput) -> Double? {
        switch input.goalDirection {
        case .maintain, .gain:
            return nil
        case .cut:
            return weeklyLossKg(for: input.weightLossPace, input: input)
        }
    }

    static func weeklyLossKg(
        for pace: WeightLossPace,
        input: PlanCalculationInput
    ) -> Double {
        pace.weeklyLossKg(
            weightKg: input.weightKg,
            goalWeightKg: input.goalWeightKg,
            referenceDate: input.referenceDate
        )
    }

    // MARK: Deficit ↔ weekly loss

    static func dailyDeficitKcal(fromWeeklyLossKg weeklyLossKg: Double) -> Int {
        let deficit = (weeklyLossKg * FormaCalculationConstants.kcalPerKgFat) / 7.0
        return Int(deficit.rounded())
    }

    static func weeklyLossKg(fromDailyDeficitKcal dailyDeficitKcal: Int) -> Double {
        let weeklyDeficit = Double(dailyDeficitKcal) * 7.0
        return weeklyDeficit / FormaCalculationConstants.kcalPerKgFat
    }

    // MARK: Labels

    static func paceDescription(
        for pace: WeightLossPace,
        weeklyLossKg: Double,
        fraction: Double
    ) -> String {
        let percentText = String(format: "%.2f", fraction * 100)
        let weeklyText = formatKg(weeklyLossKg)

        switch pace {
        case .preset(.gentle):
            return "Gentle pace targeting about \(weeklyText) kg/week (\(percentText)% of body weight)"
        case .preset(.moderate):
            return "Moderate pace targeting about \(weeklyText) kg/week (\(percentText)% of body weight)"
        case .preset(.aggressive):
            return "Aggressive pace targeting about \(weeklyText) kg/week (\(percentText)% of body weight)"
        case .advancedKgPerWeek:
            return "Custom pace targeting \(weeklyText) kg/week (\(percentText)% of body weight)"
        case .advancedKgPerMonth:
            return "Custom monthly pace equivalent to about \(weeklyText) kg/week"
        case .goalDate:
            return "Goal-date pace requiring about \(weeklyText) kg/week (\(percentText)% of body weight)"
        }
    }

    static func presetDisplayName(for pace: WeightLossPace) -> String {
        pace.displayName
    }

    private static func formatKg(_ value: Double) -> String {
        value.truncatingRemainder(dividingBy: 1) == 0
            ? "\(Int(value))"
            : String(format: "%.2f", value)
    }
}
