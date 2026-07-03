//
//  PlanGoalWeightValidationBuilder.swift
//  Fitness Coach
//
//  Forma — Goal weight validation for the Edit Plan wizard.
//

import Foundation

enum PlanGoalWeightValidationBuilder {

    static func validate(
        goalWeightText: String,
        currentWeightKg: Double?,
        heightCm: Double?,
        goalType: PlanGoalType,
        unitSystem: UnitSystem = .metric
    ) -> String? {
        let trimmed = goalWeightText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty, let goalKg = Double(trimmed), goalKg > 0 else {
            return FormaProductCopy.PlanEditTarget.validationEnterGoalWeight()
        }

        guard let currentKg = currentWeightKg, currentKg > 0 else {
            return nil
        }

        let allowed = OnboardingGoalWeightBounds.rangeKg(
            currentWeightKg: currentKg,
            heightCm: heightCm
        )
        guard allowed.contains(goalKg) else {
            let lower = OnboardingGoalWeightBounds.weightSummary(
                valueKg: allowed.lowerBound,
                unitSystem: unitSystem
            )
            let upper = OnboardingGoalWeightBounds.weightSummary(
                valueKg: allowed.upperBound,
                unitSystem: unitSystem
            )
            return FormaProductCopy.PlanEditTarget.validationGoalOutOfRange(
                range: "\(lower) and \(upper)"
            )
        }

        let currentSummary = OnboardingGoalWeightBounds.weightSummary(
            valueKg: currentKg,
            unitSystem: unitSystem
        )
        let epsilon = FormaCalculationConstants.goalDirectionEpsilonKg

        switch goalType {
        case .loseFat:
            guard goalKg < currentKg - epsilon else {
                return FormaProductCopy.PlanEditTarget.validationGoalMustBeLower(
                    current: currentSummary
                )
            }
        case .gainMuscle:
            guard goalKg > currentKg + epsilon else {
                return FormaProductCopy.PlanEditTarget.validationGoalMustBeHigher(
                    current: currentSummary
                )
            }
        case .maintain:
            guard abs(goalKg - currentKg) <= epsilon else {
                return FormaProductCopy.PlanEditTarget.validationGoalShouldMatchCurrent(
                    current: currentSummary
                )
            }
        }

        return nil
    }
}
