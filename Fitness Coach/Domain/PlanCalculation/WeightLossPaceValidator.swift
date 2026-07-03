//
//  WeightLossPaceValidator.swift
//  Fitness Coach
//
//  Forma — Structural and safety validation for WeightLossPace.
//

import Foundation

enum WeightLossPaceValidationError: Equatable, Sendable {
    case negativeValue
    case zeroForFatLossGoal
    case goalDateNotInFuture
    case exceedsMaximumWeeklyLoss(weeklyKg: Double, period: WeightLossAdvancedPaceDraft.Period?)

    var message: String {
        let copy = FormaProductCopy.PlanEditPace.self
        switch self {
        case .negativeValue:
            return copy.cannotBeNegative
        case .zeroForFatLossGoal:
            return copy.mustBePositive
        case .goalDateNotInFuture:
            return copy.goalDateMustBeFuture
        case .exceedsMaximumWeeklyLoss(_, let period):
            let c = FormaCalculationConstants.self
            switch period {
            case .monthly:
                return copy.exceedsMonthlyMaximum(Self.formatKg(c.maxMonthlyWeightLossKg))
            case .weekly, .none:
                return copy.exceedsWeeklyMaximum(Self.formatKg(c.maxWeeklyWeightLossKg))
            }
        }
    }

    private static func formatKg(_ value: Double) -> String {
        value.truncatingRemainder(dividingBy: 1) == 0
            ? "\(Int(value)) kg"
            : String(format: "%.1f kg", value)
    }
}

struct WeightLossPaceValidationResult: Equatable, Sendable {
    let error: WeightLossPaceValidationError?
    let warnings: [PlanWarning]

    var isValid: Bool { error == nil }

    var safetyLevel: PlanSafetyLevel {
        if error != nil { return .error }
        if warnings.contains(where: { $0.severity == .strongWarning }) { return .strongWarning }
        if warnings.contains(where: { $0.severity == .warn }) { return .caution }
        return .ok
    }
}

enum WeightLossPaceValidator {

    // MARK: - Combined

    static func validate(
        pace: WeightLossPace,
        weightKg: Double,
        goalWeightKg: Double,
        goalDirection: PlanGoalDirection,
        referenceDate: Date
    ) -> WeightLossPaceValidationResult {
        let error = structuralError(
            pace: pace,
            weightKg: weightKg,
            goalWeightKg: goalWeightKg,
            goalDirection: goalDirection,
            referenceDate: referenceDate
        )
        let warnings = error == nil
            ? safetyWarnings(
                pace: pace,
                weightKg: weightKg,
                goalWeightKg: goalWeightKg,
                goalDirection: goalDirection,
                referenceDate: referenceDate
            )
            : []
        return WeightLossPaceValidationResult(error: error, warnings: warnings)
    }

  /// Throws `PlanCalculationError` when pace is structurally invalid for calculation.
    static func validateForCalculation(
        pace: WeightLossPace,
        weightKg: Double,
        goalWeightKg: Double,
        goalDirection: PlanGoalDirection,
        referenceDate: Date
    ) throws {
        if let error = structuralError(
            pace: pace,
            weightKg: weightKg,
            goalWeightKg: goalWeightKg,
            goalDirection: goalDirection,
            referenceDate: referenceDate
        ) {
            throw PlanCalculationError.invalidInput(error.message)
        }
    }

    // MARK: - Structural

    static func structuralError(
        pace: WeightLossPace,
        weightKg: Double,
        goalWeightKg: Double,
        goalDirection: PlanGoalDirection,
        referenceDate: Date
    ) -> WeightLossPaceValidationError? {
        switch pace {
        case .preset:
            break
        case .advancedKgPerWeek(let kg):
            if kg < 0 { return .negativeValue }
            if kg == 0, goalDirection == .cut { return .zeroForFatLossGoal }
        case .advancedKgPerMonth(let kg):
            if kg < 0 { return .negativeValue }
            if kg == 0, goalDirection == .cut { return .zeroForFatLossGoal }
        case .goalDate(let goalDate):
            guard goalDate > referenceDate else { return .goalDateNotInFuture }
        }

        if goalDirection == .cut {
            let weekly = pace.weeklyLossKg(
                weightKg: weightKg,
                goalWeightKg: goalWeightKg,
                referenceDate: referenceDate
            )
            if weekly < 0 { return .negativeValue }
            if weekly == 0 { return .zeroForFatLossGoal }
            if weekly > FormaCalculationConstants.maxWeeklyWeightLossKg {
                return .exceedsMaximumWeeklyLoss(
                    weeklyKg: weekly,
                    period: advancedPeriod(for: pace)
                )
            }
        }

        return nil
    }

    private static func advancedPeriod(for pace: WeightLossPace) -> WeightLossAdvancedPaceDraft.Period? {
        switch pace {
        case .advancedKgPerWeek:
            return .weekly
        case .advancedKgPerMonth:
            return .monthly
        default:
            return nil
        }
    }

    // MARK: - Safety warnings (pace vs body weight)

    static func safetyWarnings(
        pace: WeightLossPace,
        weightKg: Double,
        goalWeightKg: Double,
        goalDirection: PlanGoalDirection,
        referenceDate: Date
    ) -> [PlanWarning] {
        guard goalDirection == .cut, weightKg > 0 else { return [] }

        let weekly = pace.weeklyLossKg(
            weightKg: weightKg,
            goalWeightKg: goalWeightKg,
            referenceDate: referenceDate
        )

        let fraction = weeklyLossFractionForSafety(
            pace: pace,
            weightKg: weightKg,
            goalWeightKg: goalWeightKg,
            referenceDate: referenceDate
        )
        let c = FormaCalculationConstants.self
        var warnings: [PlanWarning] = []

        if weekly > 0, weekly < c.minMeaningfulWeeklyLossKg {
            warnings.append(PlanWarning(
                code: "paceVerySlow",
                severity: .warn,
                message: FormaProductCopy.PlanEditPace.verySlowPaceWarning
            ))
        }

        if fraction > c.paceStrongWarnWeeklyLossFraction {
            warnings.append(PlanWarning(
                code: "paceVeryAggressive",
                severity: .strongWarning,
                message: FormaProductCopy.PlanEditPace.aggressivePaceWarning
            ))
        } else if fraction >= c.paceWarnWeeklyLossFraction {
            warnings.append(PlanWarning(
                code: "paceAggressive",
                severity: .warn,
                message: FormaProductCopy.PlanEditPace.aggressivePaceWarning
            ))
        }

        return warnings
    }

    /// Presets use named fractions; advanced modes derive from absolute kg targets.
    private static func weeklyLossFractionForSafety(
        pace: WeightLossPace,
        weightKg: Double,
        goalWeightKg: Double,
        referenceDate: Date
    ) -> Double {
        switch pace {
        case .preset(let preset):
            return preset.weeklyLossFraction
        default:
            return pace.weeklyLossFraction(
                weightKg: weightKg,
                goalWeightKg: goalWeightKg,
                referenceDate: referenceDate
            )
        }
    }
}
