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
        switch PlanNumericInputParser.parsePositiveDecimal(goalWeightText) {
        case .failure(.empty):
            return FormaProductCopy.PlanEditTarget.validationEnterGoalWeight()
        case .failure(.invalidFormat):
            return FormaProductCopy.PlanEditTarget.validationInvalidNumber()
        case .failure(.nonPositive):
            return FormaProductCopy.PlanEditTarget.validationEnterGoalWeight()
        case .success(let goalKg):
            return validateParsedGoal(
                goalKg: goalKg,
                currentWeightKg: currentWeightKg,
                heightCm: heightCm,
                goalType: goalType,
                unitSystem: unitSystem
            )
        }
    }

    private static func validateParsedGoal(
        goalKg: Double,
        currentWeightKg: Double?,
        heightCm: Double?,
        goalType: PlanGoalType,
        unitSystem: UnitSystem
    ) -> String? {
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
            if goalKg < allowed.lowerBound {
                return FormaProductCopy.PlanEditTarget.validationGoalBelowMinimum(minimum: lower)
            }
            if goalKg > allowed.upperBound {
                return FormaProductCopy.PlanEditTarget.validationGoalAboveMaximum(maximum: upper)
            }
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
