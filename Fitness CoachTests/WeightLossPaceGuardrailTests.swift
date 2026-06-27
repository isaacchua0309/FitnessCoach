//
//  WeightLossPaceGuardrailTests.swift
//  Fitness CoachTests
//
//  Additional pure validation guardrails for WeightLossPaceValidator.
//

import XCTest
@testable import Fitness_Coach

final class WeightLossPaceGuardrailTests: XCTestCase {

    private let referenceDate = FormaCalculationTestFixtures.referenceDate
    private let weightKg = 80.0
    private let goalWeightKg = 72.0

    func testValidateForCalculationThrowsOnStructuralError() {
        XCTAssertThrowsError(
            try WeightLossPaceValidator.validateForCalculation(
                pace: .advancedKgPerWeek(-0.25),
                weightKg: weightKg,
                goalWeightKg: goalWeightKg,
                goalDirection: .cut,
                referenceDate: referenceDate
            )
        ) { error in
            guard case PlanCalculationError.invalidInput(let message) = error else {
                return XCTFail("Expected invalidInput, got \(error)")
            }
            XCTAssertEqual(message, WeightLossPaceValidationError.negativeValue.message)
        }
    }

    func testSafetyLevelMapsErrorBeforeWarnings() {
        let result = WeightLossPaceValidator.validate(
            pace: .advancedKgPerWeek(-0.1),
            weightKg: weightKg,
            goalWeightKg: goalWeightKg,
            goalDirection: .cut,
            referenceDate: referenceDate
        )

        XCTAssertEqual(result.safetyLevel, .error)
        XCTAssertTrue(result.warnings.isEmpty)
    }

    func testNegativeMonthlyPaceRejected() {
        let result = validate(pace: .advancedKgPerMonth(-1))
        XCTAssertEqual(result.error, .negativeValue)
    }

    func testFutureGoalDateAccepted() {
        let future = Calendar.current.date(byAdding: .day, value: 30, to: referenceDate)!
        let result = validate(pace: .goalDate(future))
        XCTAssertNil(result.error)
    }

    func testPresetNeverProducesStructuralErrorForCut() {
        for preset in WeightLossPreset.allCases {
            let result = validate(pace: .preset(preset))
            XCTAssertNil(result.error, "Preset \(preset) should be structurally valid")
        }
    }

    func testEngineFlagsUnsafePaceWithStrongWarning() throws {
        let result = try FormaCalculationEngine.calculate(FormaCalculationTestFixtures.unsafePaceCut)
        XCTAssertEqual(result.safetyLevel, .strongWarning)
        XCTAssertTrue(result.warnings.contains { $0.code == "paceVeryAggressive" })
    }

    private func validate(pace: WeightLossPace) -> WeightLossPaceValidationResult {
        WeightLossPaceValidator.validate(
            pace: pace,
            weightKg: weightKg,
            goalWeightKg: goalWeightKg,
            goalDirection: .cut,
            referenceDate: referenceDate
        )
    }
}
