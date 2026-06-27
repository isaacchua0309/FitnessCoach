//
//  CalorieTargetCalculator.swift
//  Fitness Coach
//
//  FitPilot AI — Legacy entry point; delegates to FormaCalculationEngine.
//

import Foundation

struct CalorieTargetCalculator {

    @available(*, deprecated, message: "Use TargetService.generateInitialTargets or PlanCalculationBridge.")
    static func estimateBMR(input: CalorieTargetInput) -> Int {
        EnergyCalculator.bmrKcal(
            weightKg: input.weightKg,
            heightCm: input.heightCm,
            ageYears: input.age,
            sex: input.sex
        )
    }

    @available(*, deprecated, message: "Use TargetService.generateInitialTargets or PlanCalculationBridge.")
    static func estimateTDEE(
        bmr: Int,
        activityLevel: ActivityLevel,
        averageSteps: Int,
        trainingFrequencyPerWeek: Int
    ) -> Int {
        EnergyCalculator.tdeeKcal(
            bmrKcal: bmr,
            activityLevel: activityLevel,
            averageStepsPerDay: averageSteps,
            trainingFrequencyPerWeek: trainingFrequencyPerWeek
        )
    }

    @available(*, deprecated, message: "Use TargetService.generateInitialTargets or PlanCalculationBridge.")
    static func generateTargets(input: CalorieTargetInput) throws -> CalorieTargetResult {
        try PlanCalculationBridge.calorieTargetResult(from: input)
    }
}
