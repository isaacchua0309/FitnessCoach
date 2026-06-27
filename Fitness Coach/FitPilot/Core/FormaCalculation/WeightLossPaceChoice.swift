//
//  WeightLossPaceChoice.swift
//  Fitness Coach
//
//  Forma — Plan-edit pace selection (presets + advanced).
//

import Foundation

enum WeightLossPaceChoice: String, Equatable, CaseIterable, Identifiable, Sendable {
    case gentle
    case moderate
    case aggressive
    case advanced

    var id: String { rawValue }

    var isAdvanced: Bool { self == .advanced }

    var displayName: String {
        switch self {
        case .gentle:
            return "Gentle"
        case .moderate:
            return "Moderate"
        case .aggressive:
            return "Aggressive"
        case .advanced:
            return "Advanced"
        }
    }

    var subtitle: String {
        switch self {
        case .gentle:
            return "About 0.25% of body weight per week"
        case .moderate:
            return "About 0.50% of body weight per week"
        case .aggressive:
            return "About 0.75% of body weight per week"
        case .advanced:
            return "Set a custom weekly or monthly target"
        }
    }

    var weightLossPace: WeightLossPace? {
        switch self {
        case .gentle:
            return .preset(.gentle)
        case .moderate:
            return .preset(.moderate)
        case .aggressive:
            return .preset(.aggressive)
        case .advanced:
            return nil
        }
    }

    var legacyAggressiveness: CalorieAggressiveness {
        switch self {
        case .gentle:
            return .conservative
        case .moderate, .advanced:
            return .moderate
        case .aggressive:
            return .aggressive
        }
    }

    init(preset: WeightLossPreset) {
        switch preset {
        case .gentle:
            self = .gentle
        case .moderate:
            self = .moderate
        case .aggressive:
            self = .aggressive
        }
    }
}

struct WeightLossAdvancedPaceDraft: Equatable, Sendable {
    enum Period: String, CaseIterable, Identifiable, Sendable {
        case weekly
        case monthly

        var id: String { rawValue }

        var label: String {
            switch self {
            case .weekly:
                return "Per week"
            case .monthly:
                return "Per month"
            }
        }

        var fieldTitle: String {
            switch self {
            case .weekly:
                return "Lose per week"
            case .monthly:
                return "Lose per month"
            }
        }
    }

    var period: Period = .weekly
    var amountText: String = ""

    static let `default` = WeightLossAdvancedPaceDraft()
}

enum WeightLossPaceChoiceResolver {

    static func resolvedPace(
        choice: WeightLossPaceChoice,
        advancedDraft: WeightLossAdvancedPaceDraft
    ) throws -> WeightLossPace {
        if let presetPace = choice.weightLossPace {
            return presetPace
        }

        let trimmed = advancedDraft.amountText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard let value = Double(trimmed), value > 0 else {
            throw PlanCalculationError.invalidInput("Enter a weight-loss amount greater than zero.")
        }

        switch advancedDraft.period {
        case .weekly:
            return .advancedKgPerWeek(value)
        case .monthly:
            return .advancedKgPerMonth(value)
        }
    }

    static func infer(
        aggressiveness: CalorieAggressiveness,
        expectedWeeklyLossKg: Double?,
        weightKg: Double,
        goalWeightKg: Double
    ) -> (choice: WeightLossPaceChoice, advancedDraft: WeightLossAdvancedPaceDraft) {
        let preset = WeightLossPreset(legacy: aggressiveness)
        let isCut = goalWeightKg < weightKg - FormaCalculationConstants.goalDirectionEpsilonKg

        if isCut, let expectedWeekly = expectedWeeklyLossKg {
            let presetWeekly = weightKg * preset.weeklyLossFraction
            if abs(expectedWeekly - presetWeekly) > 0.02 {
                return (
                    .advanced,
                    WeightLossAdvancedPaceDraft(
                        period: .weekly,
                        amountText: formatAmount(expectedWeekly)
                    )
                )
            }
        }

        return (WeightLossPaceChoice(preset: preset), .default)
    }

    private static func formatAmount(_ value: Double) -> String {
        value.truncatingRemainder(dividingBy: 1) == 0
            ? "\(Int(value))"
            : String(format: "%.2f", value)
    }
}
