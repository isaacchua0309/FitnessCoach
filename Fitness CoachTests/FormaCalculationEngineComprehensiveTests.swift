//
//  FormaCalculationEngineComprehensiveTests.swift
//  Fitness CoachTests
//
//  Forma — Comprehensive fixture-based tests for the pure calculation engine.
//

import XCTest
@testable import Fitness_Coach

final class FormaCalculationEngineComprehensiveTests: XCTestCase {

    private let bmrTolerance = FormaCalculationExpectations.bmrToleranceKcal
    private let macroTolerance = FormaCalculationExpectations.macroToleranceG
    private let weeklyLossTolerance = FormaCalculationExpectations.weeklyLossToleranceKg

    // MARK: - 1. Male moderate cut (primary fixture)

    func testFixture1_MaleModerateCut() throws {
        let input = FormaCalculationTestFixtures.maleModerateCut
        let result = try FormaCalculationEngine.calculate(input)
        let expectedBmr = FormaCalculationExpectations.expectedBmrKcal(for: input)
        let expectedBaseTdee = FormaCalculationExpectations.expectedBaseTdeeKcal(
            bmrKcal: expectedBmr,
            activityLevel: input.activityLevel
        )
        let expectedTdee = FormaCalculationExpectations.expectedTdeeKcal(for: input)
        let expectedWeeklyLoss = input.weightKg * FormaCalculationConstants.presetModerateWeeklyLossFraction
        let expectedDeficit = FormaCalculationExpectations.expectedDailyDeficitKcal(weeklyLossKg: expectedWeeklyLoss)

        // BMR ≈ Mifflin–St Jeor: 10×90 + 6.25×177 − 5×24 + 5 = 1891 kcal
        XCTAssertEqual(Double(result.bmrKcal), Double(expectedBmr), accuracy: bmrTolerance)
        XCTAssertEqual(result.bmrKcal, 1891)

        // Base TDEE = BMR × 1.55 = 2931 kcal (before activity bonuses)
        XCTAssertEqual(expectedBaseTdee, 2931)

        // Full TDEE includes training bonus (+60 kcal for 3 sessions)
        XCTAssertEqual(result.tdeeKcal, expectedTdee)
        XCTAssertEqual(result.tdeeKcal, 2991)

        // Deficit from 0.50% body weight/week: 0.45 kg/week → 495 kcal/day
        XCTAssertEqual(result.requestedDailyDeficitKcal, expectedDeficit)
        XCTAssertEqual(result.requestedDailyDeficitKcal, 495)
        XCTAssertEqual(
            result.pace?.weeklyLossFractionOfBodyWeight ?? 0,
            FormaCalculationConstants.presetModerateWeeklyLossFraction,
            accuracy: FormaCalculationExpectations.paceFractionTolerance
        )

        XCTAssertEqual(result.calorieTargetKcal, expectedTdee - expectedDeficit)
        XCTAssertEqual(result.proteinTargetG, 180, accuracy: macroTolerance)
        XCTAssertEqual(result.waterTargetMl, 3150)
        XCTAssertEqual(result.goalDirection, .cut)
        XCTAssertFalse(result.explanation.allLines.isEmpty)
    }

    // MARK: - 2. Female example

    func testFixture2_FemaleModerateCut() throws {
        let input = FormaCalculationTestFixtures.femaleModerateCut
        let result = try FormaCalculationEngine.calculate(input)
        let expectedBmr = FormaCalculationExpectations.expectedBmrKcal(for: input)
        let expectedTdee = FormaCalculationExpectations.expectedTdeeKcal(for: input)

        XCTAssertEqual(Double(result.bmrKcal), Double(expectedBmr), accuracy: bmrTolerance)
        XCTAssertEqual(result.tdeeKcal, expectedTdee)
        XCTAssertEqual(result.goalDirection, .cut)
        XCTAssertGreaterThan(result.requestedDailyDeficitKcal, 0)
        XCTAssertEqual(result.proteinTargetG, 136, accuracy: macroTolerance) // 68 kg × 2.0 g/kg
        XCTAssertEqual(result.waterTargetMl, 2380)
    }

    // MARK: - 3. Sedentary user

    func testFixture3_SedentaryUser() throws {
        let input = FormaCalculationTestFixtures.sedentaryCut
        let result = try FormaCalculationEngine.calculate(input)

        XCTAssertEqual(
            result.energy.activityMultiplier,
            FormaCalculationConstants.palSedentary,
            accuracy: 0.001
        )
        XCTAssertEqual(result.energy.stepBonusKcal, 0)
        XCTAssertEqual(result.energy.trainingBonusKcal, 0)
        XCTAssertLessThan(result.tdeeKcal, try resultForActiveUser().tdeeKcal)
        XCTAssertEqual(result.goalDirection, .cut)
    }

    // MARK: - 4. Active user

    func testFixture4_ActiveUser() throws {
        let input = FormaCalculationTestFixtures.activeCut
        let result = try FormaCalculationEngine.calculate(input)

        XCTAssertEqual(
            result.energy.activityMultiplier,
            FormaCalculationConstants.palAthlete,
            accuracy: 0.001
        )
        XCTAssertGreaterThan(result.energy.stepBonusKcal, 0)
        XCTAssertEqual(result.energy.trainingBonusKcal, 100)
        XCTAssertGreaterThan(result.tdeeKcal, 3000)
        XCTAssertEqual(result.proteinTargetG, 156, accuracy: macroTolerance) // 78 × 2.0
    }

    // MARK: - 5. Gentle cut

    func testFixture5_GentleCut() throws {
        let input = FormaCalculationTestFixtures.gentleCut
        let result = try FormaCalculationEngine.calculate(input)
        let expectedWeekly = input.weightKg * FormaCalculationConstants.presetGentleWeeklyLossFraction

        XCTAssertEqual(
            result.pace?.weeklyLossFractionOfBodyWeight ?? 0,
            FormaCalculationConstants.presetGentleWeeklyLossFraction,
            accuracy: FormaCalculationExpectations.paceFractionTolerance
        )
        XCTAssertEqual(result.pace?.requestedWeeklyLossKg ?? 0, expectedWeekly, accuracy: weeklyLossTolerance)
        XCTAssertLessThan(result.requestedDailyDeficitKcal, moderateDeficitForWeight(input.weightKg))
        XCTAssertEqual(result.safetyLevel, .ok)
    }

    // MARK: - 6. Aggressive cut

    func testFixture6_AggressiveCut() throws {
        let input = FormaCalculationTestFixtures.aggressiveCut
        let result = try FormaCalculationEngine.calculate(input)
        let expectedWeekly = input.weightKg * FormaCalculationConstants.presetAggressiveWeeklyLossFraction

        XCTAssertEqual(
            result.pace?.weeklyLossFractionOfBodyWeight ?? 0,
            FormaCalculationConstants.presetAggressiveWeeklyLossFraction,
            accuracy: FormaCalculationExpectations.paceFractionTolerance
        )
        XCTAssertEqual(result.pace?.requestedWeeklyLossKg ?? 0, expectedWeekly, accuracy: weeklyLossTolerance)
        XCTAssertGreaterThanOrEqual(result.proteinTargetG, 176 - macroTolerance)
        XCTAssertLessThanOrEqual(result.proteinTargetG, 194 + macroTolerance)
        XCTAssertTrue(
            result.macros.proteinGPerKg == FormaCalculationConstants.proteinCutWithTrainingGPerKg
                || result.macros.proteinGPerKg == FormaCalculationConstants.proteinAggressiveCutGPerKg
        )
        XCTAssertGreaterThan(result.requestedDailyDeficitKcal, moderateDeficitForWeight(input.weightKg))
    }

    // MARK: - 7. Advanced kg/week

    func testFixture7_AdvancedWeeklyPace() throws {
        let input = FormaCalculationTestFixtures.advancedWeeklyCut
        let result = try FormaCalculationEngine.calculate(input)

        XCTAssertEqual(result.requestedDailyDeficitKcal, 605) // round(0.55 × 7700 / 7)
        XCTAssertEqual(result.weightLossRateKgPerWeek, 0.55, accuracy: weeklyLossTolerance)
        XCTAssertEqual(result.pace?.requestedWeeklyLossKg ?? 0, 0.55, accuracy: weeklyLossTolerance)
    }

    // MARK: - 8. Advanced kg/month

    func testFixture8_AdvancedMonthlyPace() throws {
        let input = FormaCalculationTestFixtures.advancedMonthlyCut
        let result = try FormaCalculationEngine.calculate(input)

        let weeksPerMonth = FormaCalculationConstants.daysPerAverageMonth / 7.0
        let expectedWeekly = 2.0 / weeksPerMonth
        let expectedDeficit = FormaCalculationExpectations.expectedDailyDeficitKcal(weeklyLossKg: expectedWeekly)

        XCTAssertEqual(result.requestedDailyDeficitKcal, expectedDeficit)
        XCTAssertEqual(result.pace?.requestedWeeklyLossKg ?? 0, expectedWeekly, accuracy: weeklyLossTolerance)
    }

    // MARK: - 9. Unsafe target >1% body weight/week

    func testFixture9_UnsafePaceStrongWarning() throws {
        let input = FormaCalculationTestFixtures.unsafePaceCut
        let result = try FormaCalculationEngine.calculate(input)
        let paceFraction = (result.pace?.requestedWeeklyLossKg ?? 0) / input.weightKg

        XCTAssertGreaterThan(paceFraction, FormaCalculationConstants.paceStrongWarnWeeklyLossFraction)
        XCTAssertEqual(result.safetyLevel, .strongWarning)
        XCTAssertTrue(result.warnings.contains { $0.code == "paceVeryAggressive" })
        XCTAssertEqual(result.warnings.first { $0.code == "paceVeryAggressive" }?.severity, .strongWarning)
    }

    // MARK: - 10. Calorie floor triggers warning

    func testFixture10_CalorieFloorWarning() throws {
        let input = FormaCalculationTestFixtures.calorieFloorCut
        let result = try FormaCalculationEngine.calculate(input)

        XCTAssertTrue(result.calories.calorieFloorApplied)
        XCTAssertLessThan(result.dailyDeficitKcal, result.requestedDailyDeficitKcal)
        XCTAssertGreaterThanOrEqual(result.calorieTargetKcal, FormaCalculationConstants.calorieFloorFemaleKcal)
        XCTAssertTrue(result.warnings.contains { $0.code == "calorieFloorApplied" })
        XCTAssertEqual(result.warnings.first { $0.code == "calorieFloorApplied" }?.severity, .warn)
        XCTAssertNotEqual(result.safetyLevel, .ok)
    }

    // MARK: - 11. Carb / fat feasibility warning

    func testFixture11_CarbsVeryLowWarningViaValidator() {
        let input = FormaCalculationTestFixtures.maleModerateCut
        let context = PlanSafetyValidator.Context(
            input: input,
            pace: PaceBreakdown(
                paceDescription: "test",
                requestedWeeklyLossKg: 0.45,
                weeklyLossFractionOfBodyWeight: 0.005,
                requestedDailyDeficitKcal: 495
            ),
            calories: CalorieTargetBreakdown(
                calorieFloorKcal: 1500,
                rawCalorieTargetKcal: 2000,
                calorieTargetKcal: 2000,
                requestedDailyDeficitKcal: 495,
                appliedDailyDeficitKcal: 495,
                calorieFloorApplied: false
            ),
            macros: MacroBreakdown(
                proteinTargetG: 180,
                fatTargetG: 72,
                carbTargetG: 40,
                proteinGPerKg: 2.0,
                fatGPerKg: 0.8
            ),
            tdeeKcal: 2991
        )

        let (warnings, level) = PlanSafetyValidator.validate(context)

        XCTAssertTrue(warnings.contains { $0.code == "carbsVeryLow" })
        XCTAssertEqual(warnings.first { $0.code == "carbsVeryLow" }?.severity, .warn)
        XCTAssertNotEqual(level, .ok)
    }

    func testFixture11_MacroInfeasibilityWarningViaValidator() {
        let input = FormaCalculationTestFixtures.maleModerateCut
        let context = PlanSafetyValidator.Context(
            input: input,
            pace: PaceBreakdown(
                paceDescription: "test",
                requestedWeeklyLossKg: 0.45,
                weeklyLossFractionOfBodyWeight: 0.005,
                requestedDailyDeficitKcal: 495
            ),
            calories: CalorieTargetBreakdown(
                calorieFloorKcal: 1500,
                rawCalorieTargetKcal: 1200,
                calorieTargetKcal: 1200,
                requestedDailyDeficitKcal: 495,
                appliedDailyDeficitKcal: 495,
                calorieFloorApplied: false
            ),
            macros: MacroBreakdown(
                proteinTargetG: 180,
                fatTargetG: 72,
                carbTargetG: 0,
                proteinGPerKg: 2.0,
                fatGPerKg: 0.8
            ),
            tdeeKcal: 2991
        )

        let (warnings, level) = PlanSafetyValidator.validate(context)

        XCTAssertTrue(warnings.contains { $0.code == "macroInfeasible" })
        XCTAssertEqual(warnings.first { $0.code == "macroInfeasible" }?.severity, .error)
        XCTAssertEqual(level, .error)
    }

    func testFixture11_CarbsZeroStrongWarningViaValidator() {
        let input = FormaCalculationTestFixtures.maleModerateCut
        let context = PlanSafetyValidator.Context(
            input: input,
            pace: PaceBreakdown(
                paceDescription: "test",
                requestedWeeklyLossKg: 0.45,
                weeklyLossFractionOfBodyWeight: 0.005,
                requestedDailyDeficitKcal: 495
            ),
            calories: CalorieTargetBreakdown(
                calorieFloorKcal: 1500,
                rawCalorieTargetKcal: 1400,
                calorieTargetKcal: 1400,
                requestedDailyDeficitKcal: 495,
                appliedDailyDeficitKcal: 495,
                calorieFloorApplied: false
            ),
            macros: MacroBreakdown(
                proteinTargetG: 180,
                fatTargetG: 72,
                carbTargetG: 0,
                proteinGPerKg: 2.0,
                fatGPerKg: 0.8
            ),
            tdeeKcal: 2991
        )

        let (warnings, level) = PlanSafetyValidator.validate(context)

        XCTAssertTrue(warnings.contains { $0.code == "carbsZero" })
        XCTAssertEqual(warnings.first { $0.code == "carbsZero" }?.severity, .strongWarning)
        XCTAssertEqual(level, .strongWarning)
    }

    // MARK: - 12. Maintenance target

    func testFixture12_MaintenanceTarget() throws {
        let input = FormaCalculationTestFixtures.maintenance
        let result = try FormaCalculationEngine.calculate(input)

        XCTAssertEqual(result.goalDirection, .maintain)
        XCTAssertEqual(result.requestedDailyDeficitKcal, 0)
        XCTAssertEqual(result.dailyDeficitKcal, 0)
        XCTAssertEqual(result.calorieTargetKcal, result.tdeeKcal)
        XCTAssertEqual(result.weightLossRateKgPerWeek, 0, accuracy: 0.001)
        XCTAssertNil(result.pace)
        XCTAssertTrue(result.warnings.contains { $0.code == "maintainWithLossPreset" })
    }

    // MARK: - 13. Goal weight equal to current weight

    func testFixture13_GoalEqualsCurrentWeight() throws {
        let input = FormaCalculationTestFixtures.goalEqualsCurrent
        let result = try FormaCalculationEngine.calculate(input)

        XCTAssertEqual(result.goalDirection, .maintain)
        XCTAssertEqual(input.weightKg, input.goalWeightKg)
        XCTAssertEqual(result.calorieTargetKcal, result.tdeeKcal)
        XCTAssertEqual(result.dailyDeficitKcal, 0)
    }

    // MARK: - 14. Invalid inputs

    func testFixture14_InvalidAge() {
        let input = invalidInput { PlanCalculationInput(
            ageYears: 0,
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
            referenceDate: FormaCalculationTestFixtures.referenceDate,
            isWorkoutDay: false
        ) }
        assertInvalid(input, message: "Age must be greater than zero.")
    }

    func testFixture14_InvalidHeight() {
        let input = invalidInput { PlanCalculationInput(
            ageYears: 24,
            sex: .male,
            heightCm: 0,
            weightKg: 90,
            goalWeightKg: 80,
            activityLevel: .moderatelyActive,
            trainingFrequencyPerWeek: 3,
            averageStepsPerDay: 5000,
            bodyFatPercent: nil,
            dietPreference: nil,
            weightLossPace: .preset(.moderate),
            referenceDate: FormaCalculationTestFixtures.referenceDate,
            isWorkoutDay: false
        ) }
        assertInvalid(input, message: "Height must be greater than zero.")
    }

    func testFixture14_InvalidWeight() {
        let input = invalidInput { PlanCalculationInput(
            ageYears: 24,
            sex: .male,
            heightCm: 177,
            weightKg: -5,
            goalWeightKg: 80,
            activityLevel: .moderatelyActive,
            trainingFrequencyPerWeek: 3,
            averageStepsPerDay: 5000,
            bodyFatPercent: nil,
            dietPreference: nil,
            weightLossPace: .preset(.moderate),
            referenceDate: FormaCalculationTestFixtures.referenceDate,
            isWorkoutDay: false
        ) }
        assertInvalid(input, message: "Weight must be greater than zero.")
    }

    func testFixture14_ImpossibleGoalWithLossPace() throws {
        let input = PlanCalculationInput(
            ageYears: 30,
            sex: .male,
            heightCm: 180,
            weightKg: 70,
            goalWeightKg: 75,
            activityLevel: .moderatelyActive,
            trainingFrequencyPerWeek: 3,
            averageStepsPerDay: 6000,
            bodyFatPercent: nil,
            dietPreference: nil,
            weightLossPace: .advancedKgPerWeek(0.5),
            referenceDate: FormaCalculationTestFixtures.referenceDate,
            isWorkoutDay: false
        )
        let result = try FormaCalculationEngine.calculate(input)

        XCTAssertEqual(result.goalDirection, .gain)
        XCTAssertTrue(result.warnings.contains { $0.code == "lossPaceWithNonCutGoal" })
        XCTAssertEqual(
            result.warnings.first { $0.code == "lossPaceWithNonCutGoal" }?.severity,
            .error
        )
        XCTAssertEqual(result.safetyLevel, .error)
    }

    func testFixture14_InvalidAdvancedWeeklyPace() {
        let input = PlanCalculationInput(
            ageYears: 30,
            sex: .male,
            heightCm: 180,
            weightKg: 80,
            goalWeightKg: 75,
            activityLevel: .moderatelyActive,
            trainingFrequencyPerWeek: 3,
            averageStepsPerDay: 6000,
            bodyFatPercent: nil,
            dietPreference: nil,
            weightLossPace: .advancedKgPerWeek(0),
            referenceDate: FormaCalculationTestFixtures.referenceDate,
            isWorkoutDay: false
        )
        assertInvalid(input, message: WeightLossPaceValidationError.zeroForFatLossGoal.message)
    }

    func testFixture14_InvalidGoalDate() {
        let input = PlanCalculationInput(
            ageYears: 30,
            sex: .male,
            heightCm: 180,
            weightKg: 80,
            goalWeightKg: 75,
            activityLevel: .moderatelyActive,
            trainingFrequencyPerWeek: 3,
            averageStepsPerDay: 6000,
            bodyFatPercent: nil,
            dietPreference: nil,
            weightLossPace: .goalDate(FormaCalculationTestFixtures.referenceDate),
            referenceDate: FormaCalculationTestFixtures.referenceDate,
            isWorkoutDay: false
        )
        assertInvalid(input, message: WeightLossPaceValidationError.goalDateNotInFuture.message)
    }

    // MARK: - Safety level aggregation

    func testSafetyLevelEscalatesWithSeverity() throws {
        let ok = try FormaCalculationEngine.calculate(FormaCalculationTestFixtures.maleModerateCut)
        XCTAssertEqual(ok.safetyLevel, .ok)

        let caution = try FormaCalculationEngine.calculate(FormaCalculationTestFixtures.calorieFloorCut)
        XCTAssertNotEqual(caution.safetyLevel, .ok)

        let strong = try FormaCalculationEngine.calculate(FormaCalculationTestFixtures.unsafePaceCut)
        XCTAssertEqual(strong.safetyLevel, .strongWarning)
    }

    // MARK: - Explainability

    func testExplanationIncludesAllRequiredLinesForCut() throws {
        let result = try FormaCalculationEngine.calculate(FormaCalculationTestFixtures.maleModerateCut)
        let explanation = result.explanation

        XCTAssertFalse(explanation.bmrLine.isEmpty)
        XCTAssertFalse(explanation.tdeeLine.isEmpty)
        XCTAssertNotNil(explanation.lossRateLine)
        XCTAssertNotNil(explanation.dailyDeficitLine)
        XCTAssertFalse(explanation.calorieTargetLine.isEmpty)
        XCTAssertFalse(explanation.proteinLine.isEmpty)
        XCTAssertFalse(explanation.waterLine.isEmpty)
        XCTAssertGreaterThanOrEqual(explanation.allLines.count, 7)
    }

    // MARK: - Helpers

    private func resultForActiveUser() throws -> PlanCalculationResult {
        try FormaCalculationEngine.calculate(FormaCalculationTestFixtures.activeCut)
    }

    private func moderateDeficitForWeight(_ weightKg: Double) -> Int {
        let weekly = weightKg * FormaCalculationConstants.presetModerateWeeklyLossFraction
        return FormaCalculationExpectations.expectedDailyDeficitKcal(weeklyLossKg: weekly)
    }

    private func invalidInput(_ builder: () -> PlanCalculationInput) -> PlanCalculationInput {
        builder()
    }

    private func assertInvalid(_ input: PlanCalculationInput, message: String) {
        XCTAssertThrowsError(try FormaCalculationEngine.calculate(input)) { error in
            XCTAssertEqual(error as? PlanCalculationError, .invalidInput(message))
        }
    }
}
