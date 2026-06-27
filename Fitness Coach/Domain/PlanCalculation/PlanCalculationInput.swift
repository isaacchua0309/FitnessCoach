//
//  PlanCalculationInput.swift
//  Fitness Coach
//
//  Forma — Pure inputs for the plan calculation engine.
//

import Foundation

// MARK: - Goal direction

enum PlanGoalDirection: String, Equatable, Sendable, Codable {
    case cut
    case maintain
    case gain
}

// MARK: - Input

struct PlanCalculationInput: Equatable, Sendable {

    // MARK: Anthropometrics

    let ageYears: Int
    let sex: Sex
    let heightCm: Double
    let weightKg: Double
    let goalWeightKg: Double

    // MARK: Activity

    let activityLevel: ActivityLevel
    let trainingFrequencyPerWeek: Int
    let averageStepsPerDay: Int

    // MARK: Optional context

    let bodyFatPercent: Double?
    /// Not used in v1.0 energy or macro math; reserved for explainability / coach copy.
    let dietPreference: String?

    // MARK: Strategy

    let weightLossPace: WeightLossPace
    /// Used for goal-date pace and plausibility checks.
    let referenceDate: Date
    /// When true, water target includes workout-day bonus (Section 8.2).
    let isWorkoutDay: Bool

    // MARK: Derived

    var goalDirection: PlanGoalDirection {
        let deltaKg = goalWeightKg - weightKg
        if deltaKg < -FormaCalculationConstants.goalDirectionEpsilonKg {
            return .cut
        }
        if deltaKg > FormaCalculationConstants.goalDirectionEpsilonKg {
            return .gain
        }
        return .maintain
    }

    // MARK: Structural validation

    func validate() throws {
        guard ageYears > 0 else {
            throw PlanCalculationError.invalidInput("Age must be greater than zero.")
        }
        guard heightCm > 0 else {
            throw PlanCalculationError.invalidInput("Height must be greater than zero.")
        }
        guard weightKg > 0 else {
            throw PlanCalculationError.invalidInput("Weight must be greater than zero.")
        }
        guard goalWeightKg > 0 else {
            throw PlanCalculationError.invalidInput("Goal weight must be greater than zero.")
        }
        guard trainingFrequencyPerWeek >= 0 else {
            throw PlanCalculationError.invalidInput("Training frequency must be zero or greater.")
        }
        guard averageStepsPerDay >= 0 else {
            throw PlanCalculationError.invalidInput("Average steps must be zero or greater.")
        }
        if let bodyFatPercent, !(0...80).contains(bodyFatPercent) {
            throw PlanCalculationError.invalidInput("Body fat must be between 0 and 80 percent.")
        }

        try WeightLossPaceValidator.validateForCalculation(
            pace: weightLossPace,
            weightKg: weightKg,
            goalWeightKg: goalWeightKg,
            goalDirection: goalDirection,
            referenceDate: referenceDate
        )
    }
}

enum PlanCalculationError: Error, Equatable, Sendable {
    case invalidInput(String)
}
