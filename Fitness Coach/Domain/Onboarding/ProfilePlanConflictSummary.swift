//
//  ProfilePlanConflictSummary.swift
//  Fitness Coach
//
//  Forma — Compact existing-vs-device plan labels for profile conflict UI.
//

import Foundation

struct ProfilePlanConflictSummary: Equatable, Sendable {
    let existingDailyTargetLabel: String
    let existingGoalWeightLabel: String
    let existingUpdatedAtLabel: String?
    let deviceDailyTargetLabel: String
    let deviceGoalWeightLabel: String
    let devicePaceLabel: String?

    var showsComparison: Bool {
        existingDailyTargetLabel != deviceDailyTargetLabel
            || existingGoalWeightLabel != deviceGoalWeightLabel
    }
}

enum ProfilePlanConflictSummaryBuilder {

    static func build(
        localProfile: UserProfile,
        cloudDocument: CloudUserProfileDocument
    ) -> ProfilePlanConflictSummary {
        ProfilePlanConflictSummary(
            existingDailyTargetLabel: dailyTargetLabel(cloudDocument.targets.calorieTarget),
            existingGoalWeightLabel: goalWeightLabel(cloudDocument.goalWeightKg),
            existingUpdatedAtLabel: updatedAtLabel(cloudDocument.updatedAt),
            deviceDailyTargetLabel: dailyTargetLabel(localProfile.targets.calorieTarget),
            deviceGoalWeightLabel: goalWeightLabel(localProfile.goalWeightKg),
            devicePaceLabel: paceLabel(for: localProfile.targets.aggressiveness)
        )
    }

    private static func dailyTargetLabel(_ calories: Int) -> String {
        guard calories > 0 else { return "—" }
        return OnboardingFormatter.kcal(calories)
    }

    private static func goalWeightLabel(_ kg: Double) -> String {
        guard kg > 0 else { return "—" }
        return kg.truncatingRemainder(dividingBy: 1) == 0
            ? "\(Int(kg)) kg"
            : String(format: "%.1f kg", kg)
    }

    private static func updatedAtLabel(_ date: Date) -> String? {
        guard date.timeIntervalSince1970 > 0 else { return nil }
        return DateFormatter.profilePlanConflictUpdatedAt.string(from: date)
    }

    private static func paceLabel(for aggressiveness: CalorieAggressiveness) -> String? {
        let label = OnboardingFormatter.aggressiveness(aggressiveness)
        return label.isEmpty ? nil : label
    }
}

private extension DateFormatter {
    static let profilePlanConflictUpdatedAt: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .none
        return formatter
    }()
}
