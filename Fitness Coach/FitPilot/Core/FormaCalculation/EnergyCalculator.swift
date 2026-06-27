//
//  EnergyCalculator.swift
//  Fitness Coach
//
//  Forma — BMR and TDEE estimation (Docs/FormaCalculationSpec.md §3).
//

import Foundation

enum EnergyCalculator {

    // MARK: BMR

    /// Mifflin–St Jeor BMR in kcal/day.
    static func bmrKcal(
        weightKg: Double,
        heightCm: Double,
        ageYears: Int,
        sex: Sex
    ) -> Int {
        let base = (10.0 * weightKg)
            + (6.25 * heightCm)
            - (5.0 * Double(ageYears))
            + bmrSexOffset(for: sex)
        return Int(base.rounded())
    }

    // MARK: TDEE

    static func energyBreakdown(
        bmrKcal: Int,
        activityLevel: ActivityLevel,
        averageStepsPerDay: Int,
        trainingFrequencyPerWeek: Int
    ) -> EnergyBreakdown {
        let multiplier = activityMultiplier(for: activityLevel)
        let baseTdee = Double(bmrKcal) * multiplier

        let stepBonus = stepBonusKcal(averageStepsPerDay: averageStepsPerDay)
        let trainingBonus = trainingBonusKcal(trainingFrequencyPerWeek: trainingFrequencyPerWeek)

        let tdee = Int((baseTdee + Double(stepBonus) + Double(trainingBonus)).rounded())

        return EnergyBreakdown(
            bmrKcal: bmrKcal,
            activityMultiplier: multiplier,
            stepBonusKcal: stepBonus,
            trainingBonusKcal: trainingBonus,
            tdeeKcal: tdee
        )
    }

    static func tdeeKcal(
        bmrKcal: Int,
        activityLevel: ActivityLevel,
        averageStepsPerDay: Int,
        trainingFrequencyPerWeek: Int
    ) -> Int {
        energyBreakdown(
            bmrKcal: bmrKcal,
            activityLevel: activityLevel,
            averageStepsPerDay: averageStepsPerDay,
            trainingFrequencyPerWeek: trainingFrequencyPerWeek
        ).tdeeKcal
    }

    // MARK: Calorie floor

    static func calorieFloorKcal(bmrKcal: Int, sex: Sex) -> Int {
        let sexFloor: Int
        switch sex {
        case .female:
            sexFloor = FormaCalculationConstants.calorieFloorFemaleKcal
        case .male:
            sexFloor = FormaCalculationConstants.calorieFloorMaleKcal
        case .other, .preferNotToSay:
            sexFloor = FormaCalculationConstants.calorieFloorNeutralKcal
        }
        let bmrFloor = Int(
            (Double(bmrKcal) * FormaCalculationConstants.calorieFloorBmrMultiplier).rounded()
        )
        return max(sexFloor, bmrFloor)
    }

    // MARK: Calorie target

    static func calorieTargetBreakdown(
        tdeeKcal: Int,
        bmrKcal: Int,
        sex: Sex,
        goalDirection: PlanGoalDirection,
        requestedDailyDeficitKcal: Int
    ) -> CalorieTargetBreakdown {
        switch goalDirection {
        case .maintain:
            return CalorieTargetBreakdown(
                calorieFloorKcal: calorieFloorKcal(bmrKcal: bmrKcal, sex: sex),
                rawCalorieTargetKcal: tdeeKcal,
                calorieTargetKcal: tdeeKcal,
                requestedDailyDeficitKcal: 0,
                appliedDailyDeficitKcal: 0,
                calorieFloorApplied: false
            )

        case .gain:
            // v1.0: gain surplus presets are out of scope; maintenance calories until surplus is defined.
            return CalorieTargetBreakdown(
                calorieFloorKcal: calorieFloorKcal(bmrKcal: bmrKcal, sex: sex),
                rawCalorieTargetKcal: tdeeKcal,
                calorieTargetKcal: tdeeKcal,
                requestedDailyDeficitKcal: 0,
                appliedDailyDeficitKcal: 0,
                calorieFloorApplied: false
            )

        case .cut:
            let floor = calorieFloorKcal(bmrKcal: bmrKcal, sex: sex)
            let rawTarget = tdeeKcal - requestedDailyDeficitKcal
            let target = max(rawTarget, floor)
            let appliedDeficit = tdeeKcal - target
            return CalorieTargetBreakdown(
                calorieFloorKcal: floor,
                rawCalorieTargetKcal: rawTarget,
                calorieTargetKcal: target,
                requestedDailyDeficitKcal: requestedDailyDeficitKcal,
                appliedDailyDeficitKcal: appliedDeficit,
                calorieFloorApplied: rawTarget < floor
            )
        }
    }

    // MARK: Helpers

    static func bmrSexOffset(for sex: Sex) -> Double {
        switch sex {
        case .male:
            return FormaCalculationConstants.bmrSexOffsetMale
        case .female:
            return FormaCalculationConstants.bmrSexOffsetFemale
        case .other, .preferNotToSay:
            return FormaCalculationConstants.bmrSexOffsetNeutral
        }
    }

    static func activityMultiplier(for level: ActivityLevel) -> Double {
        switch level {
        case .sedentary:
            return FormaCalculationConstants.palSedentary
        case .lightlyActive:
            return FormaCalculationConstants.palLightlyActive
        case .moderatelyActive:
            return FormaCalculationConstants.palModeratelyActive
        case .veryActive:
            return FormaCalculationConstants.palVeryActive
        case .athlete:
            return FormaCalculationConstants.palAthlete
        }
    }

    static func stepBonusKcal(averageStepsPerDay: Int) -> Int {
        let aboveBaseline = max(
            averageStepsPerDay - FormaCalculationConstants.stepBaselinePerDay,
            0
        )
        let bonus = Double(aboveBaseline) / 1000.0 * FormaCalculationConstants.kcalPer1000StepsAboveBaseline
        return Int(bonus.rounded())
    }

    static func trainingBonusKcal(trainingFrequencyPerWeek: Int) -> Int {
        let bonus = Double(max(trainingFrequencyPerWeek, 0))
            * FormaCalculationConstants.kcalPerTrainingSessionPerWeek
        return Int(bonus.rounded())
    }
}
