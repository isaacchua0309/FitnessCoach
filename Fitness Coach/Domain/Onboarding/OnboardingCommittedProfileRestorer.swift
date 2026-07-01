//
//  OnboardingCommittedProfileRestorer.swift
//  Fitness Coach
//
//  Forma — Resume save-plan handoff from a committed local profile (no draft).
//

import Foundation

enum OnboardingCommittedProfileRestorer {

    /// Local profile exists but save-plan sign-in is still pending.
    static func shouldResumeSavePlan(profile: UserProfile) -> Bool {
        profile.ownerUID == nil
    }

    static func hydrateFormState(
        _ formState: inout OnboardingFormState,
        from profile: UserProfile,
        referenceDate: Date = Date()
    ) {
        formState.unitSystem = profile.unitSystem
        formState.sex = profile.sex
        formState.activityLevel = profile.activityLevel
        formState.heightCmText = formatted(profile.heightCm)
        formState.currentWeightKgText = formatted(profile.currentWeightKg)
        formState.goalWeightKgText = formatted(profile.goalWeightKg)
        formState.trainingFrequencyPerWeekText = String(profile.trainingFrequencyPerWeek)
        formState.averageStepsText = String(profile.averageSteps)

        if let bodyFat = profile.estimatedBodyFatPercentage {
            formState.estimatedBodyFatPercentageText = formatted(bodyFat)
        }

        if let name = profile.name?.trimmingCharacters(in: .whitespacesAndNewlines), !name.isEmpty {
            formState.name = name
        }

        if let diet = profile.dietPreference?.trimmingCharacters(in: .whitespacesAndNewlines), !diet.isEmpty {
            formState.dietPreference = diet
        }

        formState.birthDate = profile.birthDate
        if profile.birthDate != nil {
            formState.syncAgeTextFromBirthDate(referenceDate: referenceDate)
        } else {
            formState.ageText = String(profile.age)
        }
    }

    static func reconstructGeneratedPlan(from profile: UserProfile) -> CalorieTargetResult {
        CalorieTargetResult(
            estimatedBMR: 0,
            estimatedTDEE: 0,
            targets: profile.targets,
            estimatedDailyDeficit: 0,
            isAggressive: profile.targets.aggressiveness == .aggressive,
            warning: nil
        )
    }

    private static func formatted(_ value: Double) -> String {
        if value.truncatingRemainder(dividingBy: 1) == 0 {
            return String(Int(value))
        }
        return String(value)
    }
}
