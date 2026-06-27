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
}
