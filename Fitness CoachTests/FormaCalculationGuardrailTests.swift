//
//  FormaCalculationGuardrailTests.swift
//  Fitness CoachTests
//
//  Cross-cutting invariants for the pure calculation engine.
//

import XCTest
@testable import Fitness_Coach

final class FormaCalculationGuardrailTests: XCTestCase {

    func testEngineIsDeterministicForSameInput() throws {
        let input = FormaCalculationTestFixtures.maleModerateCut
        let first = try FormaCalculationEngine.calculate(input)
        let second = try FormaCalculationEngine.calculate(input)

        XCTAssertEqual(first, second)
    }

    func testCutTargetsStayBelowTdee() throws {
        for input in FormaCalculationTestFixtures.allCutInputs {
            let result = try FormaCalculationEngine.calculate(input)
            XCTAssertEqual(result.goalDirection, .cut)
            XCTAssertLessThanOrEqual(result.calorieTargetKcal, result.tdeeKcal)
            XCTAssertGreaterThan(result.requestedDailyDeficitKcal, 0)
        }
    }

    func testMaintenanceHasNoDeficit() throws {
        let input = FormaCalculationTestFixtures.maintenance
        let result = try FormaCalculationEngine.calculate(input)

        XCTAssertEqual(result.goalDirection, .maintain)
        XCTAssertEqual(result.requestedDailyDeficitKcal, 0)
        XCTAssertEqual(result.calorieTargetKcal, result.tdeeKcal)
    }

    func testMacroAndWaterTargetsArePositive() throws {
        for input in FormaCalculationTestFixtures.allCutInputs + [FormaCalculationTestFixtures.maintenance] {
            let result = try FormaCalculationEngine.calculate(input)
            XCTAssertGreaterThan(result.calorieTargetKcal, 0)
            XCTAssertGreaterThan(result.proteinTargetG, 0)
            XCTAssertGreaterThan(result.fatTargetG, 0)
            XCTAssertGreaterThan(result.carbTargetG, 0)
            XCTAssertGreaterThan(result.waterTargetMl, 0)
        }
    }

    func testExplanationIncludesCoreSteps() throws {
        let result = try FormaCalculationEngine.calculate(FormaCalculationTestFixtures.maleModerateCut)
        let explanation = result.explanation

        XCTAssertFalse(explanation.bmrLine.isEmpty)
        XCTAssertFalse(explanation.tdeeLine.isEmpty)
        XCTAssertFalse(explanation.calorieTargetLine.isEmpty)
        XCTAssertFalse(explanation.proteinLine.isEmpty)
        XCTAssertFalse(explanation.waterLine.isEmpty)
    }
}

private extension FormaCalculationTestFixtures {

    static var allCutInputs: [PlanCalculationInput] {
        [maleModerateCut, femaleModerateCut, sedentaryCut, activeCut]
    }

    static var maintenanceInput: PlanCalculationInput {
        PlanCalculationInput(
            ageYears: maleModerateCut.ageYears,
            sex: maleModerateCut.sex,
            heightCm: maleModerateCut.heightCm,
            weightKg: maleModerateCut.weightKg,
            goalWeightKg: maleModerateCut.weightKg,
            activityLevel: maleModerateCut.activityLevel,
            trainingFrequencyPerWeek: maleModerateCut.trainingFrequencyPerWeek,
            averageStepsPerDay: maleModerateCut.averageStepsPerDay,
            bodyFatPercent: maleModerateCut.bodyFatPercent,
            dietPreference: maleModerateCut.dietPreference,
            weightLossPace: maleModerateCut.weightLossPace,
            referenceDate: referenceDate,
            isWorkoutDay: false
        )
    }
}
