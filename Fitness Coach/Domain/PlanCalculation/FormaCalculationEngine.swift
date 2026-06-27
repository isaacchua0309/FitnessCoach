//
//  FormaCalculationEngine.swift
//  Fitness Coach
//
//  Forma — Pure orchestrator for plan target calculation (Docs/FormaCalculationSpec.md).
//

import Foundation

enum FormaCalculationEngine {

    /// Runs the full deterministic plan calculation pipeline.
    static func calculate(_ input: PlanCalculationInput) throws -> PlanCalculationResult {
        try input.validate()

        let bmr = EnergyCalculator.bmrKcal(
            weightKg: input.weightKg,
            heightCm: input.heightCm,
            ageYears: input.ageYears,
            sex: input.sex
        )

        let energy = EnergyCalculator.energyBreakdown(
            bmrKcal: bmr,
            activityLevel: input.activityLevel,
            averageStepsPerDay: input.averageStepsPerDay,
            trainingFrequencyPerWeek: input.trainingFrequencyPerWeek
        )

        let pace = WeightLossRateCalculator.paceBreakdown(input: input)
        let requestedDeficit = pace?.requestedDailyDeficitKcal ?? 0
        let weeklyLossFraction = pace?.weeklyLossFractionOfBodyWeight ?? 0

        let calories = EnergyCalculator.calorieTargetBreakdown(
            tdeeKcal: energy.tdeeKcal,
            bmrKcal: energy.bmrKcal,
            sex: input.sex,
            goalDirection: input.goalDirection,
            requestedDailyDeficitKcal: requestedDeficit
        )

        let macros = PlanMacroCalculator.macroBreakdown(
            weightKg: input.weightKg,
            calorieTargetKcal: calories.calorieTargetKcal,
            goalDirection: input.goalDirection,
            trainingFrequencyPerWeek: input.trainingFrequencyPerWeek,
            requestedWeeklyLossFraction: weeklyLossFraction
        )

        let waterTargetMl = WaterCalculator.targetMl(
            weightKg: input.weightKg,
            activityLevel: input.activityLevel,
            averageStepsPerDay: input.averageStepsPerDay,
            isWorkoutDay: input.isWorkoutDay
        )

        let weightLossRateKgPerWeek = WeightLossRateCalculator.weeklyLossKg(
            fromDailyDeficitKcal: calories.appliedDailyDeficitKcal
        )

        let safetyContext = PlanSafetyValidator.Context(
            input: input,
            pace: pace,
            calories: calories,
            macros: macros,
            tdeeKcal: energy.tdeeKcal
        )
        let (warnings, safetyLevel) = PlanSafetyValidator.validate(safetyContext)

        let explanation = PlanExplanationBuilder.build(
            input: input,
            energy: energy,
            pace: pace,
            calories: calories,
            macros: macros,
            waterTargetMl: waterTargetMl,
            weightLossRateKgPerWeek: weightLossRateKgPerWeek
        )

        return PlanCalculationResult(
            goalDirection: input.goalDirection,
            bmrKcal: energy.bmrKcal,
            tdeeKcal: energy.tdeeKcal,
            requestedDailyDeficitKcal: calories.requestedDailyDeficitKcal,
            dailyDeficitKcal: calories.appliedDailyDeficitKcal,
            calorieTargetKcal: calories.calorieTargetKcal,
            proteinTargetG: macros.proteinTargetG,
            fatTargetG: macros.fatTargetG,
            carbTargetG: macros.carbTargetG,
            waterTargetMl: waterTargetMl,
            weightLossRateKgPerWeek: weightLossRateKgPerWeek,
            safetyLevel: safetyLevel,
            warnings: warnings,
            explanation: explanation,
            energy: energy,
            pace: pace,
            calories: calories,
            macros: macros
        )
    }
}
