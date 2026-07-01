//
//  FormaCalculationConstants.swift
//  Fitness Coach
//
//  Forma — Named constants for the plan calculation engine (see Docs/FormaCalculationSpec.md).
//

import Foundation

enum FormaCalculationConstants {

    // MARK: Energy

    /// kcal per kg of body-weight change (fat tissue energy density).
nonisolated static let kcalPerKgFat: Double = 7700

nonisolated static let kcalPerGramProtein: Double = 4
nonisolated static let kcalPerGramCarb: Double = 4
nonisolated static let kcalPerGramFat: Double = 9

    // MARK: Mifflin–St Jeor sex offsets (kcal/day)

nonisolated static let bmrSexOffsetMale: Double = 5
nonisolated static let bmrSexOffsetFemale: Double = -161
nonisolated static let bmrSexOffsetNeutral: Double = -78

    // MARK: Activity (PAL multipliers)

nonisolated static let palSedentary: Double = 1.20
nonisolated static let palLightlyActive: Double = 1.375
nonisolated static let palModeratelyActive: Double = 1.55
nonisolated static let palVeryActive: Double = 1.725
nonisolated static let palAthlete: Double = 1.90

    // MARK: TDEE refinements

nonisolated static let stepBaselinePerDay: Int = 5000
nonisolated static let kcalPer1000StepsAboveBaseline: Double = 30
nonisolated static let kcalPerTrainingSessionPerWeek: Double = 20

    // MARK: Weight-loss pace presets (% of body weight per week)

nonisolated static let presetGentleWeeklyLossFraction: Double = 0.0025
nonisolated static let presetModerateWeeklyLossFraction: Double = 0.0050
nonisolated static let presetAggressiveWeeklyLossFraction: Double = 0.0075

    // MARK: Safety — pace

    /// Fraction of body weight per week (0.0075 = 0.75%).
nonisolated static let paceWarnWeeklyLossFraction: Double = 0.0075
nonisolated static let paceStrongWarnWeeklyLossFraction: Double = 0.01
nonisolated static let maxDeficitFractionOfTDEE: Double = 0.25

    // MARK: Safety — calorie floors (kcal/day)

nonisolated static let calorieFloorFemaleKcal: Int = 1200
nonisolated static let calorieFloorMaleKcal: Int = 1500
nonisolated static let calorieFloorNeutralKcal: Int = 1350
nonisolated static let calorieFloorBmrMultiplier: Double = 1.1

    // MARK: Macros (g/kg body weight)

nonisolated static let proteinGeneralGPerKg: Double = 1.8
nonisolated static let proteinCutGPerKg: Double = 1.8
nonisolated static let proteinCutWithTrainingGPerKg: Double = 2.0
nonisolated static let proteinAggressiveCutGPerKg: Double = 2.2
nonisolated static let proteinMinimumGPerKg: Double = 1.6
nonisolated static let proteinMaximumGPerKg: Double = 2.4
nonisolated static let proteinAbsoluteMaximumG: Double = 250
nonisolated static let proteinStepDownGPerKg: Double = 0.1

nonisolated static let fatDefaultGPerKg: Double = 0.8
nonisolated static let fatMinimumGPerKg: Double = 0.6
nonisolated static let fatStepDownGPerKg: Double = 0.1

nonisolated static let minCarbWarnOnCutG: Double = 50

    // MARK: Water (ml)

nonisolated static let mlPerKgBodyWeight: Double = 35
nonisolated static let workoutDayWaterBonusMl: Int = 500
nonisolated static let sedentaryLowStepsWaterReductionMl: Int = 200
nonisolated static let sedentaryLowStepsThreshold: Int = 4000
nonisolated static let waterMinimumMl: Int = 2000
nonisolated static let waterMaximumMl: Int = 5000

    // MARK: Goal direction

nonisolated static let goalDirectionEpsilonKg: Double = 0.5

    // MARK: Advanced pace

nonisolated static let daysPerAverageMonth: Double = 30.4375

    /// Maximum allowed weight-loss rate for custom and derived paces.
nonisolated static let maxWeeklyWeightLossKg: Double = 1.2

nonisolated static var maxMonthlyWeightLossKg: Double {
        maxWeeklyWeightLossKg * daysPerAverageMonth / 7.0
    }

    // MARK: Plausibility soft bounds (warnings only)

nonisolated static let plausibleAgeMin: Int = 16
nonisolated static let plausibleAgeMax: Int = 80
nonisolated static let plausibleHeightCmMin: Double = 120
nonisolated static let plausibleHeightCmMax: Double = 230
nonisolated static let plausibleWeightKgMin: Double = 35
nonisolated static let plausibleWeightKgMax: Double = 250
nonisolated static let plausibleBodyFatPercentMin: Double = 5
nonisolated static let plausibleBodyFatPercentMax: Double = 60
}
