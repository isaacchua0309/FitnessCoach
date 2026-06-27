//
//  PlanSafetyValidator.swift
//  Fitness Coach
//
//  Forma — Safety validation for plan calculations (Docs/FormaCalculationSpec.md §5).
//

import Foundation

enum PlanSafetyValidator {

    struct Context: Equatable, Sendable {
        let input: PlanCalculationInput
        let pace: PaceBreakdown?
        let calories: CalorieTargetBreakdown
        let macros: MacroBreakdown
        let tdeeKcal: Int
    }

    static func validate(_ context: Context) -> (warnings: [PlanWarning], safetyLevel: PlanSafetyLevel) {
        var warnings: [PlanWarning] = []

        warnings.append(contentsOf: plausibilityWarnings(for: context.input))
        warnings.append(contentsOf: goalConsistencyWarnings(for: context))
        warnings.append(contentsOf: paceWarnings(for: context))
        warnings.append(contentsOf: calorieWarnings(for: context))
        warnings.append(contentsOf: macroWarnings(for: context))

        let level = aggregateSafetyLevel(from: warnings)
        return (warnings, level)
    }

    // MARK: Plausibility (soft)

    private static func plausibilityWarnings(for input: PlanCalculationInput) -> [PlanWarning] {
        var warnings: [PlanWarning] = []
        let c = FormaCalculationConstants.self

        if !(c.plausibleAgeMin...c.plausibleAgeMax).contains(input.ageYears) {
            warnings.append(PlanWarning(
                code: "plausibleAge",
                severity: .warn,
                message: "Age is outside the typical range used for plan estimates (16–80)."
            ))
        }
        if !(c.plausibleHeightCmMin...c.plausibleHeightCmMax).contains(input.heightCm) {
            warnings.append(PlanWarning(
                code: "plausibleHeight",
                severity: .warn,
                message: "Height is outside the typical range used for plan estimates (120–230 cm)."
            ))
        }
        if !(c.plausibleWeightKgMin...c.plausibleWeightKgMax).contains(input.weightKg) {
            warnings.append(PlanWarning(
                code: "plausibleWeight",
                severity: .warn,
                message: "Weight is outside the typical range used for plan estimates (35–250 kg)."
            ))
        }
        if let bodyFat = input.bodyFatPercent,
           !(c.plausibleBodyFatPercentMin...c.plausibleBodyFatPercentMax).contains(bodyFat) {
            warnings.append(PlanWarning(
                code: "plausibleBodyFat",
                severity: .warn,
                message: "Body fat is outside the typical range used for plan estimates (5–60%)."
            ))
        }
        return warnings
    }

    // MARK: Goal consistency

    private static func goalConsistencyWarnings(for context: Context) -> [PlanWarning] {
        var warnings: [PlanWarning] = []
        let input = context.input

        if input.goalDirection == .gain, input.weightLossPace.isLossPreset {
            warnings.append(PlanWarning(
                code: "gainWithLossPreset",
                severity: .warn,
                message: "Weight-gain goal selected with a fat-loss pace; pace is not applied."
            ))
        }

        if input.goalDirection == .maintain, input.weightLossPace.isLossPreset {
            warnings.append(PlanWarning(
                code: "maintainWithLossPreset",
                severity: .warn,
                message: "Maintenance goal with a fat-loss pace; consider switching to maintenance mode."
            ))
        }

        if input.goalWeightKg >= input.weightKg {
            switch input.weightLossPace {
            case .advancedKgPerWeek(let kg) where kg > 0,
                 .advancedKgPerMonth(let kg) where kg > 0:
                warnings.append(PlanWarning(
                    code: "lossPaceWithNonCutGoal",
                    severity: .error,
                    message: "A fat-loss pace cannot be used when goal weight is not below current weight."
                ))
            default:
                break
            }
        }

        return warnings
    }

    // MARK: Pace

    private static func paceWarnings(for context: Context) -> [PlanWarning] {
        guard context.input.goalDirection == .cut else { return [] }

        var warnings = WeightLossPaceValidator.safetyWarnings(
            pace: context.input.weightLossPace,
            weightKg: context.input.weightKg,
            goalWeightKg: context.input.goalWeightKg,
            goalDirection: context.input.goalDirection,
            referenceDate: context.input.referenceDate
        )

        if context.tdeeKcal > 0, let pace = context.pace {
            let deficitRatio = Double(pace.requestedDailyDeficitKcal) / Double(context.tdeeKcal)
            if deficitRatio > FormaCalculationConstants.maxDeficitFractionOfTDEE {
                warnings.append(PlanWarning(
                    code: "deficitExceedsQuarterTDEE",
                    severity: .warn,
                    message: "Requested deficit exceeds 25% of estimated TDEE."
                ))
            }
        }

        return warnings
    }

    // MARK: Calories

    private static func calorieWarnings(for context: Context) -> [PlanWarning] {
        guard context.calories.calorieFloorApplied else { return [] }
        return [
            PlanWarning(
                code: "calorieFloorApplied",
                severity: .warn,
                message: "Calorie floor applied; actual fat-loss pace is slower than requested."
            )
        ]
    }

    // MARK: Macros

    private static func macroWarnings(for context: Context) -> [PlanWarning] {
        guard context.input.goalDirection == .cut else { return [] }

        var warnings: [PlanWarning] = []
        let calorieTarget = context.calories.calorieTargetKcal
        let proteinKcal = context.macros.proteinTargetG * FormaCalculationConstants.kcalPerGramProtein
        let fatKcal = context.macros.fatTargetG * FormaCalculationConstants.kcalPerGramFat
        let remainingKcal = Double(calorieTarget) - proteinKcal - fatKcal

        if remainingKcal < 0 {
            warnings.append(PlanWarning(
                code: "macroInfeasible",
                severity: .error,
                message: "Protein and fat minimums exceed the calorie target."
            ))
        } else if context.macros.carbTargetG == 0 {
            warnings.append(PlanWarning(
                code: "carbsZero",
                severity: .strongWarning,
                message: "No carbohydrate budget remains after protein and fat minimums."
            ))
        } else if context.macros.carbTargetG < FormaCalculationConstants.minCarbWarnOnCutG {
            warnings.append(PlanWarning(
                code: "carbsVeryLow",
                severity: .warn,
                message: "Carbohydrate allowance is very low and may be hard to sustain."
            ))
        }

        return warnings
    }

    // MARK: Aggregation

    private static func aggregateSafetyLevel(from warnings: [PlanWarning]) -> PlanSafetyLevel {
        if warnings.contains(where: { $0.severity == .error }) {
            return .error
        }
        if warnings.contains(where: { $0.severity == .strongWarning }) {
            return .strongWarning
        }
        if warnings.contains(where: { $0.severity == .warn }) {
            return .caution
        }
        return .ok
    }
}
