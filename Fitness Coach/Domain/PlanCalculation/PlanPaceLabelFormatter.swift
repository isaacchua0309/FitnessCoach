//
//  PlanPaceLabelFormatter.swift
//  Fitness Coach
//
//  Shared weight-loss pace labels for plan summary and details sheet.
//

import Foundation

enum PlanPaceLabelFormatter {

    enum Style {
        /// Lowercase pace name for narrative summary sentences.
        case summary
        /// Display name with weekly rate for structured details rows.
        case details
    }

    static func label(
        profile: UserProfile,
        result: PlanCalculationResult,
        style: Style
    ) -> String {
        let inferred = WeightLossPaceChoiceResolver.infer(
            aggressiveness: profile.targets.aggressiveness,
            expectedWeeklyLossKg: profile.targets.expectedWeeklyWeightLossKg,
            weightKg: profile.currentWeightKg,
            goalWeightKg: profile.goalWeightKg
        )

        switch style {
        case .summary:
            return summaryLabel(choice: inferred.choice, result: result)
        case .details:
            return detailsLabel(choice: inferred.choice, result: result)
        }
    }

    // MARK: - Private

    private static func summaryLabel(
        choice: WeightLossPaceChoice,
        result: PlanCalculationResult
    ) -> String {
        switch choice {
        case .gentle:
            return "gentle"
        case .moderate:
            return "moderate"
        case .aggressive:
            return "aggressive"
        case .advanced:
            let weekly = PlanDisplayFormatter.formatKg(result.weightLossRateKgPerWeek)
            return "custom pace of about \(weekly) kg/week"
        }
    }

    private static func detailsLabel(
        choice: WeightLossPaceChoice,
        result: PlanCalculationResult
    ) -> String {
        let weekly = PlanDisplayFormatter.formatKg(result.weightLossRateKgPerWeek)
        switch choice {
        case .gentle, .moderate, .aggressive:
            return "\(choice.displayName) (about \(weekly)/week)"
        case .advanced:
            return "Custom (about \(weekly)/week)"
        }
    }
}
