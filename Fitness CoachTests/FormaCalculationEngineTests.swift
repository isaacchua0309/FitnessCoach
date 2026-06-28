//
//  FormaCalculationEngineTests.swift
//  Fitness CoachTests
//
//  Forma — Unit tests for the pure plan calculation engine.
//

import XCTest
@testable import Fitness_Coach

final class FormaCalculationEngineTests: XCTestCase {

    // MARK: - Spec worked example (Docs/FormaCalculationSpec.md §11)

    func testWorkedExampleModerateCut() throws {
        let input = PlanCalculationInput(
            ageYears: 30,
            sex: .male,
            heightCm: 180,
            weightKg: 82,
            goalWeightKg: 75,
            activityLevel: .moderatelyActive,
            trainingFrequencyPerWeek: 3,
            averageStepsPerDay: 6000,
            bodyFatPercent: nil,
            dietPreference: nil,
            weightLossPace: .preset(.moderate),
            referenceDate: Date(timeIntervalSince1970: 0),
            isWorkoutDay: false
        )

        let result = try FormaCalculationEngine.calculate(input)

        XCTAssertEqual(result.bmrKcal, 1800)
        XCTAssertEqual(result.tdeeKcal, 2880)
        XCTAssertEqual(result.requestedDailyDeficitKcal, 451)
        XCTAssertEqual(result.dailyDeficitKcal, 451)
        XCTAssertEqual(result.calorieTargetKcal, 2429)
        XCTAssertEqual(result.proteinTargetG, 164)
        XCTAssertEqual(result.fatTargetG, 66)
        // Spec §11 carb arithmetic has a typo (605 kcal remainder); correct value is 295 g.
        XCTAssertEqual(result.carbTargetG, 295)
        XCTAssertEqual(result.waterTargetMl, 2870)
        XCTAssertEqual(result.goalDirection, .cut)
        XCTAssertFalse(result.explanation.allLines.isEmpty)
    }

    // MARK: - BMR

    func testBmrFemaleOffset() {
        let bmr = EnergyCalculator.bmrKcal(
            weightKg: 60,
            heightCm: 165,
            ageYears: 30,
            sex: .female
        )
        // 10*60 + 6.25*165 - 5*30 - 161 = 600 + 1031.25 - 150 - 161 = 1320.25 → 1320
        XCTAssertEqual(bmr, 1320)
    }

    // MARK: - Pace presets scale with body weight

    func testPresetGentleScalesWithWeight() throws {
        let light = try FormaCalculationEngine.calculate(baseInput(weightKg: 60, weightLossPace: .preset(.gentle)))
        let heavy = try FormaCalculationEngine.calculate(baseInput(weightKg: 100, weightLossPace: .preset(.gentle)))

        XCTAssertLessThan(light.requestedDailyDeficitKcal, heavy.requestedDailyDeficitKcal)
        XCTAssertLessThan(light.weightLossRateKgPerWeek, heavy.weightLossRateKgPerWeek)
    }

    // MARK: - Maintenance

    func testMaintenanceGoalHasNoDeficit() throws {
        let input = baseInput(weightKg: 70, goalWeightKg: 70, weightLossPace: .preset(.moderate))
        let result = try FormaCalculationEngine.calculate(input)

        XCTAssertEqual(result.goalDirection, .maintain)
        XCTAssertEqual(result.requestedDailyDeficitKcal, 0)
        XCTAssertEqual(result.dailyDeficitKcal, 0)
        XCTAssertEqual(result.calorieTargetKcal, result.tdeeKcal)
        XCTAssertEqual(result.weightLossRateKgPerWeek, 0, accuracy: 0.001)
    }

    // MARK: - Calorie floor

    func testCalorieFloorCapsAggressiveDeficit() throws {
        let input = PlanCalculationInput(
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
            referenceDate: Date(timeIntervalSince1970: 0),
            isWorkoutDay: false
        )

        let result = try FormaCalculationEngine.calculate(input)

        XCTAssertGreaterThanOrEqual(result.calorieTargetKcal, 1200)
        XCTAssertLessThan(result.dailyDeficitKcal, result.requestedDailyDeficitKcal)
        XCTAssertTrue(result.warnings.contains { $0.code == "calorieFloorApplied" })
    }

    // MARK: - Advanced weekly pace

    func testAdvancedWeeklyPace() throws {
        let input = baseInput(weightKg: 80, weightLossPace: .advancedKgPerWeek(0.5))
        let result = try FormaCalculationEngine.calculate(input)

        XCTAssertEqual(result.requestedDailyDeficitKcal, 550)
        XCTAssertEqual(result.weightLossRateKgPerWeek, 0.5, accuracy: 0.02)
    }

    // MARK: - Safety

    func testVeryAggressivePaceTriggersStrongWarning() throws {
        let input = baseInput(
            weightKg: 70,
            goalWeightKg: 62,
            weightLossPace: .advancedKgPerWeek(0.8)
        )
        let result = try FormaCalculationEngine.calculate(input)

        XCTAssertEqual(result.safetyLevel, .strongWarning)
        XCTAssertTrue(result.warnings.contains { $0.code == "paceVeryAggressive" })
    }

    // MARK: - Structural validation

    func testInvalidWeightThrows() {
        let input = baseInput(weightKg: 0)
        XCTAssertThrowsError(try FormaCalculationEngine.calculate(input)) { error in
            XCTAssertEqual(error as? PlanCalculationError, .invalidInput("Weight must be greater than zero."))
        }
    }

    // MARK: - Helpers

    private func baseInput(
        weightKg: Double = 82,
        goalWeightKg: Double = 75,
        weightLossPace: WeightLossPace = .preset(.moderate)
    ) -> PlanCalculationInput {
        PlanCalculationInput(
            ageYears: 30,
            sex: .male,
            heightCm: 180,
            weightKg: weightKg,
            goalWeightKg: goalWeightKg,
            activityLevel: .moderatelyActive,
            trainingFrequencyPerWeek: 3,
            averageStepsPerDay: 6000,
            bodyFatPercent: nil,
            dietPreference: nil,
            weightLossPace: weightLossPace,
            referenceDate: Date(timeIntervalSince1970: 0),
            isWorkoutDay: false
        )
    }
}
