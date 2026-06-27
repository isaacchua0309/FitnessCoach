//
//  FormaCalculationTestFixtures.swift
//  Fitness CoachTests
//
//  Forma — Shared fixtures and expectation helpers for calculation engine tests.
//

import Foundation
@testable import Fitness_Coach

enum FormaCalculationTestFixtures {

    static let referenceDate = Date(timeIntervalSince1970: 1_700_000_000)

    // MARK: - Fixture inputs

    /// Male, 24y, 177 cm, 90 kg, moderately active, moderate cut (0.50% body weight/week).
    static let maleModerateCut = PlanCalculationInput(
        ageYears: 24,
        sex: .male,
        heightCm: 177,
        weightKg: 90,
        goalWeightKg: 80,
        activityLevel: .moderatelyActive,
        trainingFrequencyPerWeek: 3,
        averageStepsPerDay: 5000,
        bodyFatPercent: nil,
        dietPreference: nil,
        weightLossPace: .preset(.moderate),
        referenceDate: referenceDate,
        isWorkoutDay: false
    )

    /// Female, 32y, 165 cm, 68 kg, lightly active, moderate cut.
    static let femaleModerateCut = PlanCalculationInput(
        ageYears: 32,
        sex: .female,
        heightCm: 165,
        weightKg: 68,
        goalWeightKg: 62,
        activityLevel: .lightlyActive,
        trainingFrequencyPerWeek: 2,
        averageStepsPerDay: 6000,
        bodyFatPercent: 28,
        dietPreference: nil,
        weightLossPace: .preset(.moderate),
        referenceDate: referenceDate,
        isWorkoutDay: false
    )

    /// Sedentary user with low step count.
    static let sedentaryCut = PlanCalculationInput(
        ageYears: 40,
        sex: .male,
        heightCm: 175,
        weightKg: 85,
        goalWeightKg: 78,
        activityLevel: .sedentary,
        trainingFrequencyPerWeek: 0,
        averageStepsPerDay: 3000,
        bodyFatPercent: nil,
        dietPreference: nil,
        weightLossPace: .preset(.moderate),
        referenceDate: referenceDate,
        isWorkoutDay: false
    )

    /// Highly active user (athlete PAL, high steps, frequent training).
    static let activeCut = PlanCalculationInput(
        ageYears: 26,
        sex: .male,
        heightCm: 182,
        weightKg: 78,
        goalWeightKg: 72,
        activityLevel: .athlete,
        trainingFrequencyPerWeek: 5,
        averageStepsPerDay: 12_000,
        bodyFatPercent: 14,
        dietPreference: nil,
        weightLossPace: .preset(.moderate),
        referenceDate: referenceDate,
        isWorkoutDay: false
    )

    /// Gentle preset (0.25% body weight/week).
    static let gentleCut = PlanCalculationInput(
        ageYears: 35,
        sex: .female,
        heightCm: 168,
        weightKg: 72,
        goalWeightKg: 68,
        activityLevel: .moderatelyActive,
        trainingFrequencyPerWeek: 3,
        averageStepsPerDay: 7000,
        bodyFatPercent: nil,
        dietPreference: nil,
        weightLossPace: .preset(.gentle),
        referenceDate: referenceDate,
        isWorkoutDay: false
    )

    /// Engine scenario with aggressive preset; protein may be 2.0 or 2.2 g/kg at the 0.75% boundary.
    static let aggressiveCut = PlanCalculationInput(
        ageYears: 29,
        sex: .male,
        heightCm: 178,
        weightKg: 88,
        goalWeightKg: 80,
        activityLevel: .moderatelyActive,
        trainingFrequencyPerWeek: 4,
        averageStepsPerDay: 8000,
        bodyFatPercent: nil,
        dietPreference: nil,
        weightLossPace: .preset(.aggressive),
        referenceDate: referenceDate,
        isWorkoutDay: false
    )

    /// Advanced pace: 0.55 kg/week.
    static let advancedWeeklyCut = PlanCalculationInput(
        ageYears: 33,
        sex: .male,
        heightCm: 180,
        weightKg: 84,
        goalWeightKg: 78,
        activityLevel: .moderatelyActive,
        trainingFrequencyPerWeek: 3,
        averageStepsPerDay: 6000,
        bodyFatPercent: nil,
        dietPreference: nil,
        weightLossPace: .advancedKgPerWeek(0.55),
        referenceDate: referenceDate,
        isWorkoutDay: false
    )

    /// Advanced pace: 2.0 kg/month.
    static let advancedMonthlyCut = PlanCalculationInput(
        ageYears: 38,
        sex: .female,
        heightCm: 162,
        weightKg: 70,
        goalWeightKg: 64,
        activityLevel: .lightlyActive,
        trainingFrequencyPerWeek: 2,
        averageStepsPerDay: 5500,
        bodyFatPercent: nil,
        dietPreference: nil,
        weightLossPace: .advancedKgPerMonth(2.0),
        referenceDate: referenceDate,
        isWorkoutDay: false
    )

    /// Unsafe pace: >1% body weight/week (1.0 kg/week on 70 kg ≈ 1.43%/week).
    static let unsafePaceCut = PlanCalculationInput(
        ageYears: 27,
        sex: .male,
        heightCm: 176,
        weightKg: 70,
        goalWeightKg: 62,
        activityLevel: .moderatelyActive,
        trainingFrequencyPerWeek: 3,
        averageStepsPerDay: 6000,
        bodyFatPercent: nil,
        dietPreference: nil,
        weightLossPace: .advancedKgPerWeek(1.0),
        referenceDate: referenceDate,
        isWorkoutDay: false
    )

    /// Small female, sedentary, aggressive preset — calorie floor should bind.
    static let calorieFloorCut = PlanCalculationInput(
        ageYears: 45,
        sex: .female,
        heightCm: 155,
        weightKg: 52,
        goalWeightKg: 48,
        activityLevel: .sedentary,
        trainingFrequencyPerWeek: 0,
        averageStepsPerDay: 3000,
        bodyFatPercent: nil,
        dietPreference: nil,
        weightLossPace: .preset(.aggressive),
        referenceDate: referenceDate,
        isWorkoutDay: false
    )

    /// Maintenance: goal within ±0.5 kg of current weight.
    static let maintenance = PlanCalculationInput(
        ageYears: 31,
        sex: .female,
        heightCm: 170,
        weightKg: 65,
        goalWeightKg: 65,
        activityLevel: .moderatelyActive,
        trainingFrequencyPerWeek: 3,
        averageStepsPerDay: 7000,
        bodyFatPercent: nil,
        dietPreference: nil,
        weightLossPace: .preset(.moderate),
        referenceDate: referenceDate,
        isWorkoutDay: false
    )

    /// Goal weight equal to current weight (exact match).
    static let goalEqualsCurrent = PlanCalculationInput(
        ageYears: 28,
        sex: .male,
        heightCm: 175,
        weightKg: 72,
        goalWeightKg: 72,
        activityLevel: .lightlyActive,
        trainingFrequencyPerWeek: 2,
        averageStepsPerDay: 5000,
        bodyFatPercent: nil,
        dietPreference: nil,
        weightLossPace: .preset(.gentle),
        referenceDate: referenceDate,
        isWorkoutDay: false
    )
}

// MARK: - Expectation helpers

enum FormaCalculationExpectations {

    static let bmrToleranceKcal: Double = 0.5
    static let macroToleranceG: Double = 0.5
    static let weeklyLossToleranceKg: Double = 0.02
    static let paceFractionTolerance: Double = 0.0001

    /// Mifflin–St Jeor BMR (kcal/day).
    static func expectedBmrKcal(for input: PlanCalculationInput) -> Int {
        EnergyCalculator.bmrKcal(
            weightKg: input.weightKg,
            heightCm: input.heightCm,
            ageYears: input.ageYears,
            sex: input.sex
        )
    }

    /// Base TDEE = BMR × PAL multiplier (before step/training bonuses).
    static func expectedBaseTdeeKcal(bmrKcal: Int, activityLevel: ActivityLevel) -> Int {
        let multiplier = EnergyCalculator.activityMultiplier(for: activityLevel)
        return Int((Double(bmrKcal) * multiplier).rounded())
    }

    /// Full engine TDEE including step and training bonuses.
    static func expectedTdeeKcal(for input: PlanCalculationInput) -> Int {
        let bmr = expectedBmrKcal(for: input)
        return EnergyCalculator.tdeeKcal(
            bmrKcal: bmr,
            activityLevel: input.activityLevel,
            averageStepsPerDay: input.averageStepsPerDay,
            trainingFrequencyPerWeek: input.trainingFrequencyPerWeek
        )
    }

    static func expectedWeeklyLossKg(for input: PlanCalculationInput) -> Double? {
        WeightLossRateCalculator.requestedWeeklyLossKg(input: input)
    }

    static func expectedDailyDeficitKcal(weeklyLossKg: Double) -> Int {
        WeightLossRateCalculator.dailyDeficitKcal(fromWeeklyLossKg: weeklyLossKg)
    }

    static func expectedWaterMl(weightKg: Double, isWorkoutDay: Bool = false) -> Int {
        Int((weightKg * FormaCalculationConstants.mlPerKgBodyWeight).rounded())
            + (isWorkoutDay ? FormaCalculationConstants.workoutDayWaterBonusMl : 0)
    }

    static func expectedProteinG(
        weightKg: Double,
        goalDirection: PlanGoalDirection,
        trainingFrequencyPerWeek: Int,
        weeklyLossFraction: Double
    ) -> Double {
        let gPerKg = PlanMacroCalculator.proteinGPerKg(
            goalDirection: goalDirection,
            trainingFrequencyPerWeek: trainingFrequencyPerWeek,
            weeklyLossFraction: weeklyLossFraction
        )
        return (weightKg * gPerKg).rounded()
    }
}
