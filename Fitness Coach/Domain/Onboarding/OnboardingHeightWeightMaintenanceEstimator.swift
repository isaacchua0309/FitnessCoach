//
//  OnboardingHeightWeightMaintenanceEstimator.swift
//  Fitness Coach
//
//  Forma — Preliminary maintenance estimate during height/weight onboarding.
//

import Foundation

struct OnboardingMaintenancePreviewState: Equatable, Sendable {
    let maintenanceKcal: Int?
    let isPlaceholder: Bool
    let accessibilityValue: String

    static let placeholder = OnboardingMaintenancePreviewState(
        maintenanceKcal: nil,
        isPlaceholder: true,
        accessibilityValue: FormaProductCopy.Onboarding.Flow.HeightWeight.previewPlaceholder
    )
}

enum OnboardingHeightWeightMaintenanceEstimator {

    static func previewState(for formState: OnboardingFormState) -> OnboardingMaintenancePreviewState {
        let heightCm = OnboardingHeightWeightValues.resolvedHeightCm(from: formState)
        let weightKg = OnboardingHeightWeightValues.resolvedWeightKg(from: formState)

        guard OnboardingPickerDefaults.metricHeightCmRange.contains(heightCm),
              OnboardingPickerDefaults.metricWeightKgRange.contains(weightKg) else {
            return .placeholder
        }

        let bmr = EnergyCalculator.bmrKcal(
            weightKg: weightKg,
            heightCm: heightCm,
            ageYears: OnboardingPickerDefaults.defaultAge,
            sex: .female
        )
        let maintenance = EnergyCalculator.tdeeKcal(
            bmrKcal: bmr,
            activityLevel: .moderatelyActive,
            averageStepsPerDay: 0,
            trainingFrequencyPerWeek: 0
        )

        let formatted = PlanDisplayFormatter.formatKcalPerDay(maintenance)
        return OnboardingMaintenancePreviewState(
            maintenanceKcal: maintenance,
            isPlaceholder: false,
            accessibilityValue: "\(FormaProductCopy.Onboarding.Flow.HeightWeight.previewTitle), \(formatted)"
        )
    }
}
