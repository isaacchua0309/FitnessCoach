//
//  WeightLossPaceTests.swift
//  Fitness CoachTests
//
//  Forma — Tests for WeightLossPace model and validation.
//

import XCTest
@testable import Fitness_Coach

final class WeightLossPaceTests: XCTestCase {

    private let referenceDate = FormaCalculationTestFixtures.referenceDate
    private let weightKg = 80.0
    private let goalWeightKg = 72.0

    // MARK: - Legacy mapping

    func testLegacyCalorieAggressivenessMapping() {
        XCTAssertEqual(WeightLossPreset(legacy: .conservative), .gentle)
        XCTAssertEqual(WeightLossPreset(legacy: .moderate), .moderate)
        XCTAssertEqual(WeightLossPreset(legacy: .aggressive), .aggressive)

        XCTAssertEqual(WeightLossPace(legacy: .conservative), .preset(.gentle))
        XCTAssertEqual(WeightLossPace(legacy: .moderate), .preset(.moderate))
        XCTAssertEqual(WeightLossPace(legacy: .aggressive), .preset(.aggressive))
    }

    func testPresetLegacyAggressivenessRoundTrip() {
        for preset in WeightLossPreset.allCases {
            XCTAssertEqual(preset, WeightLossPreset(legacy: preset.legacyAggressiveness))
        }
    }

    // MARK: - Preset behavior preserved

    func testPresetWeeklyLossFractions() {
        XCTAssertEqual(WeightLossPreset.gentle.weeklyLossFraction, 0.0025)
        XCTAssertEqual(WeightLossPreset.moderate.weeklyLossFraction, 0.0050)
        XCTAssertEqual(WeightLossPreset.aggressive.weeklyLossFraction, 0.0075)
    }

    func testPresetModerateWeeklyLossKg() {
        let pace = WeightLossPace.preset(.moderate)
        XCTAssertEqual(
            pace.weeklyLossKg(weightKg: 90, goalWeightKg: 80, referenceDate: referenceDate),
            0.45,
            accuracy: 0.0001
        )
    }

  // MARK: - Advanced modes

    func testAdvancedWeeklyKgPerWeek() {
        let pace = WeightLossPace.advancedKgPerWeek(0.55)
        XCTAssertEqual(
            pace.weeklyLossKg(weightKg: weightKg, goalWeightKg: goalWeightKg, referenceDate: referenceDate),
            0.55,
            accuracy: 0.0001
        )
    }

    func testAdvancedMonthlyConvertsToWeekly() {
        let pace = WeightLossPace.advancedKgPerMonth(2.0)
        let weeksPerMonth = FormaCalculationConstants.daysPerAverageMonth / 7.0
        XCTAssertEqual(
            pace.weeklyLossKg(weightKg: weightKg, goalWeightKg: goalWeightKg, referenceDate: referenceDate),
            2.0 / weeksPerMonth,
            accuracy: 0.0001
        )
    }

    // MARK: - Structural validation

    func testNegativeAdvancedWeeklyRejected() {
        let result = validate(pace: .advancedKgPerWeek(-0.5))
        XCTAssertEqual(result.error, .negativeValue)
        XCTAssertFalse(result.isValid)
    }

    func testZeroAdvancedWeeklyRejectedForCut() {
        let result = validate(pace: .advancedKgPerWeek(0))
        XCTAssertEqual(result.error, .zeroForFatLossGoal)
    }

    func testZeroAdvancedWeeklyAllowedForMaintenance() {
        let result = WeightLossPaceValidator.validate(
            pace: .advancedKgPerWeek(0),
            weightKg: weightKg,
            goalWeightKg: weightKg,
            goalDirection: .maintain,
            referenceDate: referenceDate
        )
        XCTAssertNil(result.error)
    }

    func testGoalDateInPastRejected() {
        let result = validate(pace: .goalDate(referenceDate))
        XCTAssertEqual(result.error, .goalDateNotInFuture)
    }

    // MARK: - Safety warnings

    func testModeratePresetNoPaceWarning() {
        let result = validate(pace: .preset(.moderate))
        XCTAssertNil(result.error)
        XCTAssertTrue(result.warnings.isEmpty)
        XCTAssertEqual(result.safetyLevel, .ok)
    }

    func testAggressivePresetWarnsAtThreshold() {
        // 0.75% exactly — at the warn threshold (uses >=)
        let result = validate(pace: .preset(.aggressive))
        XCTAssertTrue(result.warnings.contains { $0.code == "paceAggressive" })
        XCTAssertEqual(result.safetyLevel, .caution)
    }

    func testWarnAbovePointSevenFivePercentBodyWeightPerWeek() {
        // 0.76% of 80 kg = 0.608 kg/week
        let pace = WeightLossPace.advancedKgPerWeek(0.608)
        let result = validate(pace: pace)
        XCTAssertNil(result.error)
        XCTAssertTrue(result.warnings.contains { $0.code == "paceAggressive" })
        XCTAssertEqual(result.safetyLevel, .caution)
    }

    func testStrongWarningAboveOnePercentBodyWeightPerWeek() {
        let pace = WeightLossPace.advancedKgPerWeek(0.85)
        let result = validate(pace: pace)
        XCTAssertTrue(result.warnings.contains { $0.code == "paceVeryAggressive" })
        XCTAssertEqual(result.safetyLevel, .strongWarning)
    }

    func testWeeklyPaceAboveMaximumRejected() {
        let pace = WeightLossPace.advancedKgPerWeek(1.3)
        let result = validate(pace: pace)
        XCTAssertEqual(result.error, .exceedsMaximumWeeklyLoss(weeklyKg: 1.3, period: .weekly))
        XCTAssertFalse(result.isValid)
    }

    func testWeeklyPaceAtMaximumAccepted() {
        let pace = WeightLossPace.advancedKgPerWeek(FormaCalculationConstants.maxWeeklyWeightLossKg)
        let result = validate(pace: pace)
        XCTAssertNil(result.error)
        XCTAssertTrue(result.isValid)
    }

    func testMonthlyPaceAboveMaximumRejected() {
        let pace = WeightLossPace.advancedKgPerMonth(FormaCalculationConstants.maxMonthlyWeightLossKg + 0.5)
        let result = validate(pace: pace)
        guard case .exceedsMaximumWeeklyLoss(_, .monthly)? = result.error else {
            return XCTFail("Expected exceedsMaximumWeeklyLoss for monthly pace")
        }
        XCTAssertFalse(result.isValid)
    }

    func testLegacyCalorieAggressivenessMappingIncludesAdvancedConversion() {
        XCTAssertEqual(
            WeightLossPace(legacy: .moderate),
            .preset(.moderate)
        )
        XCTAssertEqual(
            WeightLossPace(legacy: .conservative),
            .preset(.gentle)
        )
    }

    // MARK: - Helpers

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
