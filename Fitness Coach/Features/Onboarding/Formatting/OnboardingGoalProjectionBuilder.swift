//
//  OnboardingGoalProjectionBuilder.swift
//  Fitness Coach
//
//  Forma — Display-only goal projection helpers for onboarding (no formula changes).
//

import Foundation

enum OnboardingGoalDirection: Equatable {
    case cut
    case maintain
    case gain
}

enum OnboardingGoalProjectionBuilder {

    /// WHO underweight threshold — warning only, does not block plan calculation.
    static let minimumHealthyGoalBMI = 18.5

    static func goalDirection(
        currentWeightKg: Double,
        goalWeightKg: Double
    ) -> OnboardingGoalDirection {
        let deltaKg = goalWeightKg - currentWeightKg
        if deltaKg < -FormaCalculationConstants.goalDirectionEpsilonKg {
            return .cut
        }
        if deltaKg > FormaCalculationConstants.goalDirectionEpsilonKg {
            return .gain
        }
        return .maintain
    }

    static func goalBMI(weightKg: Double, heightCm: Double) -> Double {
        let heightM = heightCm / 100
        guard heightM > 0 else { return 0 }
        return weightKg / (heightM * heightM)
    }

    static func isGoalBMITooLow(goalWeightKg: Double, heightCm: Double) -> Bool {
        guard heightCm > 0, goalWeightKg > 0 else { return false }
        return goalBMI(weightKg: goalWeightKg, heightCm: heightCm) < minimumHealthyGoalBMI
    }

    static func estimatedWeeks(
        currentWeightKg: Double,
        goalWeightKg: Double,
        weeklyLossKg: Double
    ) -> Int? {
        let remainingKg = currentWeightKg - goalWeightKg
        guard remainingKg > 0, weeklyLossKg > 0 else { return nil }
        return Int(ceil(remainingKg / weeklyLossKg))
    }

    static func expectedPaceLabel(weeklyKg: Double) -> String {
        OnboardingFormatter.weeklyLoss(weeklyKg) ?? formattedWeeklyLoss(weeklyKg)
    }

    static func estimatedTimelineLabel(weeks: Int) -> String {
        "About \(weeks) weeks"
    }

    static func dailyDeficitLabel(kcal: Int) -> String {
        "\(kcal) kcal/day"
    }

    static func projectionHeadline(for safetyDisplay: WeightLossPaceSafetyDisplay?) -> String {
        let copy = FormaProductCopy.Onboarding.V2.Goal.self
        switch safetyDisplay {
        case .sustainable, .none:
            return copy.sustainableHeadline
        case .demanding:
            return copy.demandingHeadline
        case .tooAggressive:
            return copy.cautionHeadline
        }
    }

    private static func formattedWeeklyLoss(_ weeklyKg: Double) -> String {
        weeklyKg.truncatingRemainder(dividingBy: 1) == 0
            ? "\(Int(weeklyKg)) kg/week"
            : String(format: "%.2f kg/week", weeklyKg)
    }
}
