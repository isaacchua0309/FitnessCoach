//
//  PlanMacroCalculator.swift
//  Fitness Coach
//
//  Forma — Macro target allocation for plan generation (Docs/FormaCalculationSpec.md §6–7).
//
//  Daily-log macro arithmetic remains in `Core/Calculators/MacroCalculator.swift`.
//

import Foundation

enum PlanMacroCalculator {

    // MARK: Targets

    static func macroBreakdown(
        weightKg: Double,
        calorieTargetKcal: Int,
        goalDirection: PlanGoalDirection,
        trainingFrequencyPerWeek: Int,
        requestedWeeklyLossFraction: Double
    ) -> MacroBreakdown {
        let proteinGPerKg = proteinGPerKg(
            goalDirection: goalDirection,
            trainingFrequencyPerWeek: trainingFrequencyPerWeek,
            weeklyLossFraction: requestedWeeklyLossFraction
        )

        let fatGPerKg = FormaCalculationConstants.fatDefaultGPerKg

        var breakdown = computeMacros(
            weightKg: weightKg,
            calorieTargetKcal: calorieTargetKcal,
            proteinGPerKg: proteinGPerKg,
            fatGPerKg: fatGPerKg
        )

        if goalDirection == .cut {
            breakdown = adjustForCarbFeasibility(
                weightKg: weightKg,
                calorieTargetKcal: calorieTargetKcal,
                fatGPerKg: fatGPerKg,
                breakdown: breakdown
            )
        }

        return breakdown
    }

    // MARK: Protein g/kg selection

    static func proteinGPerKg(
        goalDirection: PlanGoalDirection,
        trainingFrequencyPerWeek: Int,
        weeklyLossFraction: Double
    ) -> Double {
        switch goalDirection {
        case .cut where trainingFrequencyPerWeek >= 2:
            if weeklyLossFraction >= FormaCalculationConstants.presetAggressiveWeeklyLossFraction {
                return FormaCalculationConstants.proteinAggressiveCutGPerKg
            }
            return FormaCalculationConstants.proteinCutWithTrainingGPerKg
        case .cut:
            return FormaCalculationConstants.proteinCutGPerKg
        case .maintain, .gain:
            return FormaCalculationConstants.proteinGeneralGPerKg
        }
    }

    // MARK: Helpers

    private static func computeMacros(
        weightKg: Double,
        calorieTargetKcal: Int,
        proteinGPerKg: Double,
        fatGPerKg: Double
    ) -> MacroBreakdown {
        let cappedProteinGPerKg = min(
            proteinGPerKg,
            min(
                FormaCalculationConstants.proteinMaximumGPerKg,
                FormaCalculationConstants.proteinAbsoluteMaximumG / weightKg
            )
        )

        let proteinG = (weightKg * cappedProteinGPerKg).rounded()
        let fatG = (weightKg * fatGPerKg).rounded()
        let carbG = carbGrams(
            calorieTargetKcal: calorieTargetKcal,
            proteinG: proteinG,
            fatG: fatG
        )

        return MacroBreakdown(
            proteinTargetG: proteinG,
            fatTargetG: fatG,
            carbTargetG: carbG,
            proteinGPerKg: cappedProteinGPerKg,
            fatGPerKg: fatGPerKg
        )
    }

    private static func carbGrams(
        calorieTargetKcal: Int,
        proteinG: Double,
        fatG: Double
    ) -> Double {
        let proteinKcal = proteinG * FormaCalculationConstants.kcalPerGramProtein
        let fatKcal = fatG * FormaCalculationConstants.kcalPerGramFat
        let remaining = Double(calorieTargetKcal) - proteinKcal - fatKcal
        return max((remaining / FormaCalculationConstants.kcalPerGramCarb).rounded(), 0)
    }

    private static func adjustForCarbFeasibility(
        weightKg: Double,
        calorieTargetKcal: Int,
        fatGPerKg: Double,
        breakdown: MacroBreakdown
    ) -> MacroBreakdown {
        var proteinGPerKg = breakdown.proteinGPerKg
        var current = breakdown

        while current.carbTargetG == 0,
              proteinGPerKg > FormaCalculationConstants.proteinMinimumGPerKg {
            proteinGPerKg = max(
                proteinGPerKg - FormaCalculationConstants.proteinStepDownGPerKg,
                FormaCalculationConstants.proteinMinimumGPerKg
            )
            current = computeMacros(
                weightKg: weightKg,
                calorieTargetKcal: calorieTargetKcal,
                proteinGPerKg: proteinGPerKg,
                fatGPerKg: fatGPerKg
            )
            if current.carbTargetG >= FormaCalculationConstants.minCarbWarnOnCutG {
                return current
            }
        }

        return current
    }
}
