//
//  PlanCalculationBridgeTests.swift
//  Fitness CoachTests
//
//  Forma — Integration tests for wiring CalorieTargetInput through the bridge.
//

import XCTest
@testable import Fitness_Coach

final class PlanCalculationBridgeTests: XCTestCase {

    func testBridgeMapsMaleModerateCutFixture() throws {
        let legacy = CalorieTargetInput(
            age: 24,
            sex: .male,
            heightCm: 177,
            weightKg: 90,
            goalWeightKg: 80,
            estimatedBodyFatPercentage: nil,
            activityLevel: .moderatelyActive,
            trainingFrequencyPerWeek: 3,
            averageSteps: 5000,
            aggressiveness: .moderate
        )

        let result = try PlanCalculationBridge.calorieTargetResult(from: legacy)

        XCTAssertEqual(result.estimatedBMR, 1891)
        XCTAssertEqual(result.estimatedTDEE, 2991)
        XCTAssertEqual(result.estimatedDailyDeficit, 495)
        XCTAssertEqual(result.targets.calorieTarget, 2496)
        XCTAssertEqual(result.targets.proteinTarget, 180, accuracy: 0.5)
        XCTAssertEqual(result.targets.waterTargetMl, 3150)
        XCTAssertEqual(result.targets.aggressiveness, .moderate)
        XCTAssertEqual(result.targets.expectedWeeklyWeightLossKg ?? 0, 0.45, accuracy: 0.02)
    }

    func testLegacyAggressivenessMapsToPacePresets() throws {
        let gentle = try PlanCalculationBridge.calorieTargetResult(from: input(aggressiveness: .conservative))
        let moderate = try PlanCalculationBridge.calorieTargetResult(from: input(aggressiveness: .moderate))
        let aggressive = try PlanCalculationBridge.calorieTargetResult(from: input(aggressiveness: .aggressive))

        XCTAssertLessThan(gentle.estimatedDailyDeficit, moderate.estimatedDailyDeficit)
        XCTAssertLessThan(moderate.estimatedDailyDeficit, aggressive.estimatedDailyDeficit)
    }

    private func input(aggressiveness: CalorieAggressiveness) -> CalorieTargetInput {
        CalorieTargetInput(
            age: 24,
            sex: .male,
            heightCm: 177,
            weightKg: 90,
            goalWeightKg: 80,
            estimatedBodyFatPercentage: nil,
            activityLevel: .moderatelyActive,
            trainingFrequencyPerWeek: 3,
            averageSteps: 5000,
            aggressiveness: aggressiveness
        )
    }
}
