//
//  PlanBodyBaselineMaintenanceEstimator.swift
//  Fitness Coach
//
//  Forma — Maintenance preview for Edit Plan body baseline step.
//

import Foundation

enum PlanBodyBaselineMaintenanceEstimator {

    static func maintenanceKcal(
        formState: PlanFormState,
        projection: PlanProjection
    ) -> Int? {
        if let maintenance = projection.maintenanceCalories {
            return maintenance
        }
        return preliminaryMaintenanceKcal(formState: formState)
    }

    private static func preliminaryMaintenanceKcal(formState: PlanFormState) -> Int? {
        guard let heightCm = parsedPositive(formState.heightCmText),
              let weightKg = parsedPositive(formState.currentWeightKgText),
              OnboardingPickerDefaults.metricHeightCmRange.contains(heightCm),
              OnboardingPickerDefaults.metricWeightKgRange.contains(weightKg)
        else {
            return nil
        }

        let ageYears = (try? formState.resolvedAge()) ?? OnboardingPickerDefaults.defaultAge
        let sex: Sex = formState.sex == .preferNotToSay ? .female : formState.sex

        let bmr = EnergyCalculator.bmrKcal(
            weightKg: weightKg,
            heightCm: heightCm,
            ageYears: ageYears,
            sex: sex
        )
        let steps = Int(formState.averageStepsText.trimmingCharacters(in: .whitespacesAndNewlines)) ?? 0
        let trainingDays = Int(formState.trainingFrequencyPerWeekText.trimmingCharacters(in: .whitespacesAndNewlines)) ?? 0

        return EnergyCalculator.tdeeKcal(
            bmrKcal: bmr,
            activityLevel: formState.activityLevel,
            averageStepsPerDay: steps,
            trainingFrequencyPerWeek: trainingDays
        )
    }

    private static func parsedPositive(_ text: String) -> Double? {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard let value = Double(trimmed), value > 0 else { return nil }
        return value
    }
}
