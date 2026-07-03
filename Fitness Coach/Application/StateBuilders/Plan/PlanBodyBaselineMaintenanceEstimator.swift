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
        return preliminaryMaintenanceKcal(
            formState: formState,
            activityLevel: formState.activityLevel
        )
    }

    static func preliminaryMaintenanceKcal(
        formState: PlanFormState,
        activityLevel: ActivityLevel
    ) -> Int? {
        preliminaryMaintenanceKcal(
            formState: formState,
            activityLevel: activityLevel,
            useLevelTrainingDefaults: false
        )
    }

    static func previewMaintenanceKcal(
        for activityLevel: ActivityLevel,
        formState: PlanFormState
    ) -> Int? {
        preliminaryMaintenanceKcal(
            formState: formState,
            activityLevel: activityLevel,
            useLevelTrainingDefaults: true
        )
    }

    private static func preliminaryMaintenanceKcal(
        formState: PlanFormState,
        activityLevel: ActivityLevel,
        useLevelTrainingDefaults: Bool
    ) -> Int? {
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
        let rhythm = ActivityTrainingDefaultsResolver().defaults(for: activityLevel)
        let steps = useLevelTrainingDefaults
            ? rhythm.averageStepsPerDay
            : (parsedPositiveInt(formState.averageStepsText) ?? rhythm.averageStepsPerDay)
        let trainingDays = useLevelTrainingDefaults
            ? rhythm.trainingDaysPerWeek
            : (parsedPositiveInt(formState.trainingFrequencyPerWeekText) ?? rhythm.trainingDaysPerWeek)

        return EnergyCalculator.tdeeKcal(
            bmrKcal: bmr,
            activityLevel: activityLevel,
            averageStepsPerDay: steps,
            trainingFrequencyPerWeek: trainingDays
        )
    }

    private static func parsedPositiveInt(_ text: String) -> Int? {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard let value = Int(trimmed), value >= 0 else { return nil }
        return value
    }

    private static func parsedPositive(_ text: String) -> Double? {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard let value = Double(trimmed), value > 0 else { return nil }
        return value
    }
}
