//
//  ProfilePreviewData.swift
//  Fitness Coach
//
//  FitPilot AI — Static preview data for Profile UI previews.
//

import Foundation

enum ProfilePreviewData {
    static let profile = UserProfile(
        id: UUID(),
        name: "Alex",
        age: 28,
        sex: .female,
        heightCm: 168,
        currentWeightKg: 72,
        goalWeightKg: 65,
        estimatedBodyFatPercentage: 24,
        activityLevel: .moderatelyActive,
        trainingFrequencyPerWeek: 4,
        averageSteps: 7500,
        dietPreference: "High protein, flexible carbs",
        unitSystem: .metric,
        targets: UserTargets(
            calorieTarget: 1850,
            proteinTarget: 144,
            carbTarget: 180,
            fatTarget: 58,
            waterTargetMl: 2520,
            expectedWeeklyWeightLossKg: 0.5,
            aggressiveness: .moderate
        ),
        createdAt: Date(),
        updatedAt: Date()
    )

    static let state = ProfileFormatter.dashboardState(from: profile)

    static let formState = ProfileFormState(profile: profile)

    static let generatedPreview = CalorieTargetResult(
        estimatedBMR: 1480,
        estimatedTDEE: 2290,
        targets: profile.targets,
        estimatedDailyDeficit: 440,
        isAggressive: false,
        warning: nil
    )
}
