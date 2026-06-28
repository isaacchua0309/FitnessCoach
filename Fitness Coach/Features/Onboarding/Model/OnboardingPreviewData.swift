//
//  OnboardingPreviewData.swift
//  Fitness Coach
//
//  FitPilot AI — Static preview data for Onboarding UI previews.
//

import Foundation

enum OnboardingPreviewData {
    static let formState: OnboardingFormState = {
        var state = OnboardingFormState()
        state.ageText = "28"
        state.sex = .female
        state.heightCmText = "168"
        state.currentWeightKgText = "72"
        state.goalWeightKgText = "65"
        state.estimatedBodyFatPercentageText = "24"
        state.name = "Alex"
        state.dietPreference = "High protein"
        return state
    }()

    static let generatedPlan = CalorieTargetResult(
        estimatedBMR: 1480,
        estimatedTDEE: 2290,
        targets: UserTargets(
            calorieTarget: 1850,
            proteinTarget: 144,
            carbTarget: 180,
            fatTarget: 58,
            waterTargetMl: 2520,
            expectedWeeklyWeightLossKg: 0.5,
            aggressiveness: .moderate
        ),
        estimatedDailyDeficit: 440,
        isAggressive: false,
        warning: nil
    )

    static var planRevealState: OnboardingPlanRevealState? {
        OnboardingPlanRevealBuilder.build(formState: formState, plan: generatedPlan)
    }

    // MARK: - Target weight (SwiftHorizontalRuler adapter previews)

    static func targetWeightFormState(
        currentKg: Double = 90,
        goalKg: Double? = nil,
        heightCm: Double = 170,
        unitSystem: UnitSystem = .metric
    ) -> OnboardingFormState {
        var state = OnboardingFormState()
        OnboardingHeightWeightValues.setHeightCm(heightCm, in: &state)
        OnboardingHeightWeightValues.setWeightKg(currentKg, in: &state)
        state.unitSystem = unitSystem
        if let goalKg {
            OnboardingTargetWeightValues.setGoalWeightKg(goalKg, in: &state)
        } else {
            OnboardingTargetWeightValues.applyDefaultsIfNeeded(to: &state)
        }
        return state
    }

    /// Current 90.0 kg → target 90.0 kg (maintain).
    static var targetWeightMaintainFormState: OnboardingFormState {
        targetWeightFormState(currentKg: 90, goalKg: 90)
    }

    /// Current 90.0 kg → target 85.3 kg (loss).
    static var targetWeightLossFormState: OnboardingFormState {
        targetWeightFormState(currentKg: 90, goalKg: 85.3)
    }

    /// Current 90.0 kg → target 93.0 kg (gain).
    static var targetWeightGainFormState: OnboardingFormState {
        targetWeightFormState(currentKg: 90, goalKg: 93)
    }

    /// Imperial loss: current 90.0 kg → target 85.3 kg (displayed in lb).
    static var targetWeightImperialLossFormState: OnboardingFormState {
        targetWeightFormState(currentKg: 90, goalKg: 85.3, unitSystem: .imperial)
    }
}
