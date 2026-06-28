//
//  PlanCalculationBridge.swift
//  Fitness Coach
//
//  Forma — Maps legacy app plan types to FormaCalculationEngine (single source of truth).
//

import Foundation

enum PlanCalculationBridge {

    // MARK: - Public API

    static func calorieTargetResult(from input: CalorieTargetInput) throws -> CalorieTargetResult {
        let planInput = planInput(from: input)
        let result = try FormaCalculationEngine.calculate(planInput)
        #if DEBUG
        FormaCalculationDebug.logGeneration(result: result)
        #endif
        return mapToCalorieTargetResult(result, aggressiveness: input.aggressiveness)
    }

    static func planInput(
        from input: CalorieTargetInput,
        referenceDate: Date = Date(),
        isWorkoutDay: Bool = false
    ) -> PlanCalculationInput {
        PlanCalculationInput(
            ageYears: input.age,
            sex: input.sex,
            heightCm: input.heightCm,
            weightKg: input.weightKg,
            goalWeightKg: input.goalWeightKg,
            activityLevel: input.activityLevel,
            trainingFrequencyPerWeek: input.trainingFrequencyPerWeek,
            averageStepsPerDay: input.averageSteps,
            bodyFatPercent: input.estimatedBodyFatPercentage,
            dietPreference: nil,
            weightLossPace: input.weightLossPace ?? WeightLossPace(legacy: input.aggressiveness),
            referenceDate: referenceDate,
            isWorkoutDay: isWorkoutDay
        )
    }

    static func planInput(
        from profile: UserProfile,
        referenceDate: Date = Date(),
        isWorkoutDay: Bool = false
    ) -> PlanCalculationInput {
        PlanCalculationInput(
            ageYears: profile.age,
            sex: profile.sex,
            heightCm: profile.heightCm,
            weightKg: profile.currentWeightKg,
            goalWeightKg: profile.goalWeightKg,
            activityLevel: profile.activityLevel,
            trainingFrequencyPerWeek: profile.trainingFrequencyPerWeek,
            averageStepsPerDay: profile.averageSteps,
            bodyFatPercent: profile.estimatedBodyFatPercentage,
            dietPreference: profile.dietPreference,
            weightLossPace: resolvedWeightLossPace(for: profile),
            referenceDate: referenceDate,
            isWorkoutDay: isWorkoutDay
        )
    }

    static func planResult(
        from profile: UserProfile,
        referenceDate: Date = Date(),
        isWorkoutDay: Bool = false
    ) throws -> PlanCalculationResult {
        try FormaCalculationEngine.calculate(
            planInput(from: profile, referenceDate: referenceDate, isWorkoutDay: isWorkoutDay)
        )
    }

    static func resolvedWeightLossPace(for profile: UserProfile) -> WeightLossPace {
        let inferred = WeightLossPaceChoiceResolver.infer(
            aggressiveness: profile.targets.aggressiveness,
            expectedWeeklyLossKg: profile.targets.expectedWeeklyWeightLossKg,
            weightKg: profile.currentWeightKg,
            goalWeightKg: profile.goalWeightKg
        )

        if let presetPace = inferred.choice.weightLossPace {
            return presetPace
        }

        if let resolved = try? WeightLossPaceChoiceResolver.resolvedPace(
            choice: inferred.choice,
            advancedDraft: inferred.advancedDraft
        ) {
            return resolved
        }

        return WeightLossPace(legacy: profile.targets.aggressiveness)
    }

    static func waterTargetMl(
        bodyWeightKg: Double,
        activityLevel: ActivityLevel,
        averageStepsPerDay: Int,
        isWorkoutDay: Bool
    ) -> Int {
        WaterCalculator.targetMl(
            weightKg: bodyWeightKg,
            activityLevel: activityLevel,
            averageStepsPerDay: averageStepsPerDay,
            isWorkoutDay: isWorkoutDay
        )
    }

    // MARK: - Mapping

    private static func mapToCalorieTargetResult(
        _ result: PlanCalculationResult,
        aggressiveness: CalorieAggressiveness
    ) -> CalorieTargetResult {
        let aggressive = isAggressive(safetyLevel: result.safetyLevel, warnings: result.warnings)
        let weeklyLoss: Double?
        if result.goalDirection == .cut, result.weightLossRateKgPerWeek > 0 {
            weeklyLoss = result.weightLossRateKgPerWeek
        } else {
            weeklyLoss = result.goalDirection == .cut ? 0 : nil
        }

        let targets = UserTargets(
            calorieTarget: result.calorieTargetKcal,
            proteinTarget: result.proteinTargetG,
            carbTarget: result.carbTargetG,
            fatTarget: result.fatTargetG,
            waterTargetMl: result.waterTargetMl,
            expectedWeeklyWeightLossKg: weeklyLoss,
            aggressiveness: aggressiveness
        )

        return CalorieTargetResult(
            estimatedBMR: result.bmrKcal,
            estimatedTDEE: result.tdeeKcal,
            targets: targets,
            estimatedDailyDeficit: result.dailyDeficitKcal,
            isAggressive: aggressive,
            warning: aggressive ? "aggressiveDeficit" : nil
        )
    }

    private static func isAggressive(
        safetyLevel: PlanSafetyLevel,
        warnings: [PlanWarning]
    ) -> Bool {
        switch safetyLevel {
        case .strongWarning, .error:
            return true
        case .caution:
            return warnings.contains {
                $0.code == "paceAggressive"
                    || $0.code == "paceVeryAggressive"
                    || $0.code == "calorieFloorApplied"
                    || $0.code == "deficitExceedsQuarterTDEE"
            }
        case .ok:
            return false
        }
    }
}

extension PlanCalculationError {

    var userMessage: String {
        switch self {
        case .invalidInput(let message):
            return message
        }
    }
}

#if DEBUG
import OSLog

enum FormaCalculationDebug {

    private static let logger = Logger(subsystem: "Forma", category: "Calculation")

    static func logGeneration(result: PlanCalculationResult) {
        logger.info(
            "goal=\(result.goalDirection.rawValue, privacy: .public) safety=\(result.safetyLevel.rawValue, privacy: .public) warnings=\(result.warnings.count, privacy: .public)"
        )
    }
}
#endif
