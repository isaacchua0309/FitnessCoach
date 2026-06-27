//
//  WeightLossPacePreviewBuilderTests.swift
//  Fitness CoachTests
//
//  Forma — Tests for pace preview and choice resolution.
//

import XCTest
@testable import Fitness_Coach

final class WeightLossPacePreviewBuilderTests: XCTestCase {

    private let weightKg = 80.0
    private let goalWeightKg = 72.0

    func testModeratePresetPreviewIsSustainable() {
        let preview = WeightLossPacePreviewBuilder.build(
            choice: .moderate,
            advancedDraft: .default,
            weightKg: weightKg,
            goalWeightKg: goalWeightKg
        )

        XCTAssertTrue(preview.isSaveable)
        XCTAssertEqual(preview.safetyDisplay, .sustainable)
        XCTAssertNil(preview.warningMessage)
        XCTAssertEqual(preview.weeklyLossKg ?? 0, 0.4, accuracy: 0.01)
        XCTAssertEqual(preview.dailyDeficitKcal, 440)
        XCTAssertEqual(
            preview.deficitSummaryLine,
            "0.4 kg/week is about a 440 kcal daily deficit."
        )
    }

    func testAdvancedWeeklyPreviewUsesEngineDeficit() {
        let preview = WeightLossPacePreviewBuilder.build(
            choice: .advanced,
            advancedDraft: WeightLossAdvancedPaceDraft(period: .weekly, amountText: "0.5"),
            weightKg: weightKg,
            goalWeightKg: goalWeightKg
        )

        XCTAssertTrue(preview.isSaveable)
        XCTAssertEqual(preview.weeklyLossKg ?? 0, 0.5, accuracy: 0.001)
        XCTAssertEqual(preview.dailyDeficitKcal, 550)
        XCTAssertEqual(
            preview.deficitSummaryLine,
            "0.5 kg/week is about a 550 kcal daily deficit."
        )
    }

    func testAdvancedMonthlyConvertsToWeeklyEquivalent() {
        let preview = WeightLossPacePreviewBuilder.build(
            choice: .advanced,
            advancedDraft: WeightLossAdvancedPaceDraft(period: .monthly, amountText: "2.0"),
            weightKg: weightKg,
            goalWeightKg: goalWeightKg
        )

        let weeksPerMonth = FormaCalculationConstants.daysPerAverageMonth / 7.0
        XCTAssertEqual(preview.weeklyLossKg ?? 0, 2.0 / weeksPerMonth, accuracy: 0.01)
        XCTAssertEqual(preview.monthlyLossKg ?? 0, 2.0, accuracy: 0.01)
    }

    func testEmptyAdvancedInputIsNotSaveable() {
        let preview = WeightLossPacePreviewBuilder.build(
            choice: .advanced,
            advancedDraft: WeightLossAdvancedPaceDraft(period: .weekly, amountText: ""),
            weightKg: weightKg,
            goalWeightKg: goalWeightKg
        )

        XCTAssertFalse(preview.isSaveable)
        XCTAssertNotNil(preview.validationError)
    }

    func testFastAdvancedPaceShowsWarningCopy() {
        let preview = WeightLossPacePreviewBuilder.build(
            choice: .advanced,
            advancedDraft: WeightLossAdvancedPaceDraft(period: .weekly, amountText: "0.85"),
            weightKg: weightKg,
            goalWeightKg: goalWeightKg
        )

        XCTAssertTrue(preview.isSaveable)
        XCTAssertEqual(preview.safetyDisplay, .tooAggressive)
        XCTAssertEqual(preview.warningMessage, WeightLossPacePreviewBuilder.paceWarningCopy)
    }

    func testInferAdvancedFromStoredWeeklyLoss() {
        let inferred = WeightLossPaceChoiceResolver.infer(
            aggressiveness: .moderate,
            expectedWeeklyLossKg: 0.55,
            weightKg: 80,
            goalWeightKg: 72
        )

        XCTAssertEqual(inferred.choice, .advanced)
        XCTAssertEqual(inferred.advancedDraft.amountText, "0.55")
    }

    func testInferPresetWhenWeeklyLossMatchesPreset() {
        let inferred = WeightLossPaceChoiceResolver.infer(
            aggressiveness: .moderate,
            expectedWeeklyLossKg: 0.4,
            weightKg: 80,
            goalWeightKg: 72
        )

        XCTAssertEqual(inferred.choice, .moderate)
    }

    func testBridgeUsesExplicitWeightLossPace() throws {
        let input = CalorieTargetInput(
            age: 24,
            sex: .male,
            heightCm: 177,
            weightKg: 90,
            goalWeightKg: 80,
            estimatedBodyFatPercentage: nil,
            activityLevel: .moderatelyActive,
            trainingFrequencyPerWeek: 3,
            averageSteps: 5000,
            aggressiveness: .moderate,
            weightLossPace: .advancedKgPerWeek(0.5)
        )

        let result = try PlanCalculationBridge.calorieTargetResult(from: input)

        XCTAssertEqual(result.estimatedDailyDeficit, 550)
        XCTAssertEqual(result.targets.expectedWeeklyWeightLossKg ?? 0, 0.5, accuracy: 0.01)
    }
}
