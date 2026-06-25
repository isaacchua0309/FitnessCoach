//
//  CalorieTargetCalculator.swift
//  Fitness Coach
//
//  FitPilot AI — Deterministic calorie and macro target generation.
//

import Foundation

struct CalorieTargetCalculator {

    // MARK: Tunables

    /// Lower bound to keep generated calorie targets within a safe MVP range.
    private static let minimumCalorieTarget = 1200

    /// Protein grams per kg of body weight for a high-protein cut.
    private static let proteinGramsPerKg = 2.0

    /// Fat grams per kg of body weight as a hormonal minimum floor.
    private static let fatGramsPerKg = 0.8

    // MARK: BMR

    static func estimateBMR(input: CalorieTargetInput) -> Int {
        // Mifflin-St Jeor (metric).
        let base = (10.0 * input.weightKg)
            + (6.25 * input.heightCm)
            - (5.0 * Double(input.age))

        let offset: Double
        switch input.sex {
        case .male:
            offset = 5
        case .female:
            offset = -161
        case .other, .preferNotToSay:
            // Neutral average of the male/female offsets.
            offset = -78
        }

        return Int((base + offset).rounded())
    }

    // MARK: TDEE

    static func estimateTDEE(
        bmr: Int,
        activityLevel: ActivityLevel,
        averageSteps: Int,
        trainingFrequencyPerWeek: Int
    ) -> Int {
        let multiplier = activityMultiplier(for: activityLevel)
        var tdee = Double(bmr) * multiplier

        // Small MVP nudges for steps and training that are not already fully
        // captured by the coarse activity multiplier.
        let stepBonus = Double(max(averageSteps - 5000, 0)) / 1000.0 * 30.0
        let trainingBonus = Double(max(trainingFrequencyPerWeek, 0)) * 20.0
        tdee += stepBonus + trainingBonus

        return Int(tdee.rounded())
    }

    // MARK: Targets

    static func generateTargets(input: CalorieTargetInput) -> CalorieTargetResult {
        let bmr = estimateBMR(input: input)
        let tdee = estimateTDEE(
            bmr: bmr,
            activityLevel: input.activityLevel,
            averageSteps: input.averageSteps,
            trainingFrequencyPerWeek: input.trainingFrequencyPerWeek
        )

        let requestedDeficit = dailyDeficit(for: input.aggressiveness)
        let rawTarget = tdee - requestedDeficit
        let calorieTarget = max(rawTarget, minimumCalorieTarget)

        // The applied deficit may be smaller than requested once the floor is hit.
        let appliedDeficit = tdee - calorieTarget

        // Protein and fat from body weight, carbs from remaining calories.
        let proteinGrams = (input.weightKg * proteinGramsPerKg).rounded()
        let fatGrams = (input.weightKg * fatGramsPerKg).rounded()

        let proteinCalories = proteinGrams * CalculatorConstants.proteinKcalPerGram
        let fatCalories = fatGrams * CalculatorConstants.fatKcalPerGram
        let remainingCalories = Double(calorieTarget) - proteinCalories - fatCalories
        let carbGrams = max(remainingCalories / CalculatorConstants.carbKcalPerGram, 0).rounded()

        let weeklyLoss = expectedWeeklyWeightLossKg(dailyDeficit: appliedDeficit)
        let aggressive = isAggressive(
            dailyDeficit: appliedDeficit,
            calorieTarget: calorieTarget,
            tdee: tdee
        )

        let targets = UserTargets(
            calorieTarget: calorieTarget,
            proteinTarget: proteinGrams,
            carbTarget: carbGrams,
            fatTarget: fatGrams,
            waterTargetMl: WaterTargetCalculator.targetMl(
                bodyWeightKg: input.weightKg,
                isWorkoutDay: false
            ),
            expectedWeeklyWeightLossKg: weeklyLoss,
            aggressiveness: input.aggressiveness
        )

        return CalorieTargetResult(
            estimatedBMR: bmr,
            estimatedTDEE: tdee,
            targets: targets,
            estimatedDailyDeficit: appliedDeficit,
            isAggressive: aggressive,
            warning: aggressive ? "aggressiveDeficit" : nil
        )
    }

    // MARK: Helpers

    private static func activityMultiplier(for level: ActivityLevel) -> Double {
        switch level {
        case .sedentary:
            return 1.2
        case .lightlyActive:
            return 1.375
        case .moderatelyActive:
            return 1.55
        case .veryActive:
            return 1.725
        case .athlete:
            return 1.9
        }
    }

    private static func dailyDeficit(for aggressiveness: CalorieAggressiveness) -> Int {
        switch aggressiveness {
        case .conservative:
            return 300
        case .moderate:
            return 500
        case .aggressive:
            return 750
        }
    }

    private static func expectedWeeklyWeightLossKg(dailyDeficit: Int) -> Double {
        let weeklyDeficit = Double(dailyDeficit) * 7.0
        return weeklyDeficit / CalculatorConstants.kcalPerKgFat
    }

    private static func isAggressive(dailyDeficit: Int, calorieTarget: Int, tdee: Int) -> Bool {
        if calorieTarget <= minimumCalorieTarget { return true }
        guard tdee > 0 else { return false }
        let deficitRatio = Double(dailyDeficit) / Double(tdee)
        return deficitRatio > 0.25
    }
}
