//
//  PlanPreviewData.swift
//  Fitness Coach
//
//  FitPilot AI — Static preview data for Plan UI previews.
//

import Foundation

enum PlanPreviewData {
    static let profile = UserProfile(
        id: UUID(),
        name: "Alex",
        age: 28,
        sex: .female,
        heightCm: 168,
        currentWeightKg: 90,
        goalWeightKg: 75,
        estimatedBodyFatPercentage: 24,
        activityLevel: .moderatelyActive,
        trainingFrequencyPerWeek: 3,
        averageSteps: 5000,
        dietPreference: "High Protein",
        unitSystem: .metric,
        targets: UserTargets(
            calorieTarget: 2233,
            proteinTarget: 180,
            carbTarget: 180,
            fatTarget: 58,
            waterTargetMl: 3150,
            expectedWeeklyWeightLossKg: 0.8,
            aggressiveness: .aggressive
        ),
        createdAt: Calendar.current.date(from: DateComponents(year: 2025, month: 6, day: 25)) ?? Date(),
        updatedAt: Date()
    )

    static let state = PlanStateBuilder.dashboardState(profile: profile)

    static let formState = PlanFormState(profile: profile)

    static let generatedPreview = CalorieTargetResult(
        estimatedBMR: 1480,
        estimatedTDEE: 2290,
        targets: profile.targets,
        estimatedDailyDeficit: 440,
        isAggressive: false,
        warning: nil
    )
}
