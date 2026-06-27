//
//  PlanExplanationBuilder.swift
//  Fitness Coach
//
//  Forma — Human-readable explanation strings (Docs/FormaCalculationSpec.md §9).
//

import Foundation

enum PlanExplanationBuilder {

    static func build(
        input: PlanCalculationInput,
        energy: EnergyBreakdown,
        pace: PaceBreakdown?,
        calories: CalorieTargetBreakdown,
        macros: MacroBreakdown,
        waterTargetMl: Int,
        weightLossRateKgPerWeek: Double
    ) -> PlanCalculationExplanation {
        let bmrLine = """
        Your estimated resting burn (BMR) is \(energy.bmrKcal) kcal/day, based on age \(input.ageYears), height \(formatNumber(input.heightCm)) cm, weight \(formatNumber(input.weightKg)) kg, and \(sexLabel(input.sex)).
        """

        let activityLabel = activityLevelLabel(input.activityLevel)
        let tdeeLine = """
        With \(activityLabel) activity, about \(input.averageStepsPerDay) daily steps, and \(input.trainingFrequencyPerWeek) training sessions per week, your estimated maintenance (TDEE) is \(energy.tdeeKcal) kcal/day.
        """

        let lossRateLine: String?
        let dailyDeficitLine: String?

        if let pace, input.goalDirection == .cut {
            let presetName = WeightLossRateCalculator.presetDisplayName(for: input.weightLossPace)
            let percent = pace.weeklyLossFractionOfBodyWeight * 100
            lossRateLine = """
            You chose a \(presetName) pace targeting about \(formatKg(pace.requestedWeeklyLossKg)) kg/week (\(formatPercent(percent))% of body weight).
            """
            dailyDeficitLine = """
            That implies a \(calories.requestedDailyDeficitKcal) kcal/day deficit. After safety limits, your plan uses \(calories.appliedDailyDeficitKcal) kcal/day (about \(formatKg(weightLossRateKgPerWeek)) kg/week).
            """
        } else {
            lossRateLine = nil
            dailyDeficitLine = nil
        }

        let calorieTargetLine: String
        switch input.goalDirection {
        case .cut:
            calorieTargetLine = "Daily calorie target: \(calories.calorieTargetKcal) kcal (= TDEE − applied deficit)."
        case .maintain:
            calorieTargetLine = "Daily calorie target: \(calories.calorieTargetKcal) kcal (= estimated TDEE for maintenance)."
        case .gain:
            calorieTargetLine = "Daily calorie target: \(calories.calorieTargetKcal) kcal (= estimated TDEE; gain surplus presets are not yet applied)."
        }

        let proteinLine = """
        Protein target: \(formatGrams(macros.proteinTargetG)) g (\(formatNumber(macros.proteinGPerKg)) g/kg) to support recovery during \(goalDirectionLabel(input.goalDirection)).
        """

        let fatLine = "Fat target: \(formatGrams(macros.fatTargetG)) g (\(formatNumber(macros.fatGPerKg)) g/kg minimum)."

        let carbLine = "Carbohydrate target: \(formatGrams(macros.carbTargetG)) g (remaining calories after protein and fat)."

        let workoutSuffix = input.isWorkoutDay ? ", including a workout-day bonus" : ""
        let waterLine = "Water target: \(waterTargetMl) ml (~\(Int(FormaCalculationConstants.mlPerKgBodyWeight)) ml per kg body weight\(workoutSuffix))."

        return PlanCalculationExplanation(
            bmrLine: bmrLine,
            tdeeLine: tdeeLine,
            lossRateLine: lossRateLine,
            dailyDeficitLine: dailyDeficitLine,
            calorieTargetLine: calorieTargetLine,
            proteinLine: proteinLine,
            fatLine: fatLine,
            carbLine: carbLine,
            waterLine: waterLine
        )
    }

    // MARK: Formatting

    private static func sexLabel(_ sex: Sex) -> String {
        switch sex {
        case .male: return "male"
        case .female: return "female"
        case .other: return "other"
        case .preferNotToSay: return "unspecified sex"
        }
    }

    private static func activityLevelLabel(_ level: ActivityLevel) -> String {
        switch level {
        case .sedentary: return "sedentary"
        case .lightlyActive: return "lightly active"
        case .moderatelyActive: return "moderately active"
        case .veryActive: return "very active"
        case .athlete: return "athlete"
        }
    }

    private static func goalDirectionLabel(_ direction: PlanGoalDirection) -> String {
        switch direction {
        case .cut: return "fat loss"
        case .maintain: return "maintenance"
        case .gain: return "muscle gain"
        }
    }

    private static func formatNumber(_ value: Double) -> String {
        value.truncatingRemainder(dividingBy: 1) == 0
            ? "\(Int(value))"
            : String(format: "%.1f", value)
    }

    private static func formatKg(_ value: Double) -> String {
        value.truncatingRemainder(dividingBy: 1) == 0
            ? "\(Int(value))"
            : String(format: "%.2f", value)
    }

    private static func formatGrams(_ value: Double) -> String {
        value.truncatingRemainder(dividingBy: 1) == 0
            ? "\(Int(value))"
            : String(format: "%.1f", value)
    }

    private static func formatPercent(_ value: Double) -> String {
        String(format: "%.2f", value)
    }
}
