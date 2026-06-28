//
//  OnboardingProfileConflictSummaryBuilder.swift
//  Fitness Coach
//
//  Forma — Compact existing-vs-new plan labels for onboarding profile conflict UI.
//

import Foundation

struct OnboardingProfileConflictSummary: Equatable, Sendable {
    let existingDailyTargetLabel: String
    let existingGoalWeightLabel: String
    let newDailyTargetLabel: String
    let newGoalWeightLabel: String

    var showsComparison: Bool {
        existingDailyTargetLabel != newDailyTargetLabel
            || existingGoalWeightLabel != newGoalWeightLabel
    }
}

enum OnboardingProfileConflictSummaryBuilder {

    static func build(
        localProfile: UserProfile,
        cloudDocument: CloudUserProfileDocument
    ) -> OnboardingProfileConflictSummary {
        OnboardingProfileConflictSummary(
            existingDailyTargetLabel: OnboardingFormatter.kcal(cloudDocument.targets.calorieTarget),
            existingGoalWeightLabel: goalWeightLabel(cloudDocument.goalWeightKg),
            newDailyTargetLabel: OnboardingFormatter.kcal(localProfile.targets.calorieTarget),
            newGoalWeightLabel: goalWeightLabel(localProfile.goalWeightKg)
        )
    }

    private static func goalWeightLabel(_ kg: Double) -> String {
        kg.truncatingRemainder(dividingBy: 1) == 0
            ? "\(Int(kg)) kg"
            : String(format: "%.1f kg", kg)
    }
}
