//
//  MaintenanceEstimateCalculatorTests.swift
//  Fitness CoachTests
//
//  Forma — Unit tests for learned maintenance estimation behavior.
//

import XCTest
@testable import Fitness_Coach

final class MaintenanceEstimateCalculatorTests: XCTestCase {

    private var calendar: Calendar {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(secondsFromGMT: 0)!
        return calendar
    }

    // MARK: - Sufficiency & method selection

    func testInsufficientDataReturnsUnavailable() {
        let estimate = MaintenanceEstimateCalculator.estimate(
            Fixtures.input(
                foodLoggedDays: 4,
                weightEntryCount: 3,
                totalDays: 7
            )
        )

        XCTAssertEqual(estimate.method, .unavailable)
        XCTAssertEqual(estimate.confidence, .unavailable)
        XCTAssertNil(estimate.estimatedMaintenanceKcal)
        XCTAssertEqual(estimate.trendDirection, .unclear)
    }

    func testLowConfidenceReturnsTrendBucketOnly() {
        let estimate = MaintenanceEstimateCalculator.estimate(
            Fixtures.input(
                foodLoggedDays: 5,
                weightEntryCount: 3,
                totalDays: 7,
                averageDailyCalories: 2_000,
                startingWeightKg: 80,
                endingWeightKg: 79.5
            )
        )

        XCTAssertEqual(estimate.confidence, .low)
        XCTAssertEqual(estimate.method, .trendBucketOnly)
        XCTAssertNil(estimate.estimatedMaintenanceKcal)
        XCTAssertNotNil(estimate.estimatedDailyEnergyBalanceKcal)
    }

    func testMediumConfidenceReturnsRoundedLearnedMaintenance() {
        let estimate = MaintenanceEstimateCalculator.estimate(
            Fixtures.input(
                foodLoggedDays: 10,
                weightEntryCount: 3,
                totalDays: 14,
                averageDailyCalories: 2_000,
                startingWeightKg: 80,
                endingWeightKg: 79,
                staticTDEE: 2_400
            )
        )

        XCTAssertEqual(estimate.confidence, .medium)
        XCTAssertEqual(estimate.method, .conservativeBlend)
        XCTAssertEqual(estimate.estimatedMaintenanceKcal, 2_500)
        XCTAssertEqual(estimate.estimatedMaintenanceKcal! % 25, 0)
    }

    func testHighConfidenceUsesLearnedMaintenance() {
        let estimate = MaintenanceEstimateCalculator.estimate(
            Fixtures.input(
                foodLoggedDays: 20,
                weightEntryCount: 4,
                totalDays: 28,
                averageDailyCalories: 2_000,
                startingWeightKg: 80,
                endingWeightKg: 78,
                staticTDEE: 2_400
            )
        )

        XCTAssertEqual(estimate.confidence, .high)
        XCTAssertEqual(estimate.method, .learnedEnergyBalance)
        XCTAssertEqual(estimate.estimatedMaintenanceKcal, 2_550)
    }

    // MARK: - Energy-balance direction

    func testWeightLossIncreasesMaintenanceAboveAverageIntake() {
        let averageIntake = 2_000
        let estimate = MaintenanceEstimateCalculator.estimate(
            Fixtures.input(
                foodLoggedDays: 10,
                weightEntryCount: 3,
                totalDays: 14,
                averageDailyCalories: Double(averageIntake),
                startingWeightKg: 80,
                endingWeightKg: 79,
                staticTDEE: nil
            )
        )

        XCTAssertEqual(estimate.method, .learnedEnergyBalance)
        XCTAssertGreaterThan(estimate.estimatedMaintenanceKcal!, averageIntake)
    }

    func testWeightGainDecreasesMaintenanceBelowAverageIntake() {
        let averageIntake = 2_500
        let estimate = MaintenanceEstimateCalculator.estimate(
            Fixtures.input(
                foodLoggedDays: 10,
                weightEntryCount: 3,
                totalDays: 14,
                averageDailyCalories: Double(averageIntake),
                startingWeightKg: 80,
                endingWeightKg: 81,
                staticTDEE: nil
            )
        )

        XCTAssertEqual(estimate.method, .learnedEnergyBalance)
        XCTAssertLessThan(estimate.estimatedMaintenanceKcal!, averageIntake)
    }

    func testStableWeightMaintenanceNearAverageIntake() {
        let averageIntake = 2_100
        let estimate = MaintenanceEstimateCalculator.estimate(
            Fixtures.input(
                foodLoggedDays: 10,
                weightEntryCount: 3,
                totalDays: 14,
                averageDailyCalories: Double(averageIntake),
                startingWeightKg: 80,
                endingWeightKg: 80,
                staticTDEE: nil
            )
        )

        XCTAssertEqual(estimate.method, .learnedEnergyBalance)
        XCTAssertEqual(estimate.estimatedMaintenanceKcal, averageIntake)
        XCTAssertEqual(estimate.estimatedDailyEnergyBalanceKcal, 0)
    }

    // MARK: - Weight resolution

    func testUsesSevenDayAveragesWhenAvailable() {
        let estimate = MaintenanceEstimateCalculator.estimate(
            Fixtures.input(
                foodLoggedDays: 10,
                weightEntryCount: 4,
                totalDays: 14,
                averageDailyCalories: 2_000,
                startingWeightKg: 80,
                endingWeightKg: 80,
                currentSevenDayAverageKg: 78,
                previousSevenDayAverageKg: 80,
                staticTDEE: nil
            )
        )

        XCTAssertEqual(estimate.weeklyWeightChangeKg, -2)
        XCTAssertEqual(estimate.weightChangeKg, -2)
        XCTAssertEqual(estimate.trendDirection, .losingFasterThanExpected)
    }

    func testFallsBackToFirstLastWeightWhenAveragesMissing() {
        let estimate = MaintenanceEstimateCalculator.estimate(
            Fixtures.input(
                foodLoggedDays: 10,
                weightEntryCount: 3,
                totalDays: 14,
                averageDailyCalories: 2_000,
                startingWeightKg: 80,
                endingWeightKg: 79,
                staticTDEE: nil
            )
        )

        XCTAssertEqual(estimate.weightChangeKg, -1)
        XCTAssertEqual(estimate.weeklyWeightChangeKg, -0.5, accuracy: 0.001)
    }

    // MARK: - Plausibility & rounding

    func testClampsOrRejectsImplausibleMaintenance() {
        let estimate = MaintenanceEstimateCalculator.estimate(
            Fixtures.input(
                foodLoggedDays: 10,
                weightEntryCount: 3,
                totalDays: 14,
                averageDailyCalories: 1_300,
                startingWeightKg: 80,
                endingWeightKg: 73,
                staticTDEE: nil
            )
        )

        XCTAssertEqual(estimate.method, .trendBucketOnly)
        XCTAssertNil(estimate.estimatedMaintenanceKcal)
        XCTAssertTrue(
            estimate.caveats.contains {
                $0.contains("looked unrealistic")
            }
        )
    }

    func testMaintenanceRoundsToReadableIncrement() {
        let estimate = MaintenanceEstimateCalculator.estimate(
            Fixtures.input(
                foodLoggedDays: 20,
                weightEntryCount: 4,
                totalDays: 28,
                averageDailyCalories: 2_037,
                startingWeightKg: 80,
                endingWeightKg: 79.2,
                staticTDEE: nil
            )
        )

        XCTAssertEqual(estimate.method, .learnedEnergyBalance)
        XCTAssertEqual(estimate.estimatedMaintenanceKcal! % 25, 0)
    }

    // MARK: - Spike & static TDEE handling

    func testSuddenSpikeIncludesWaterWeightDisclaimer() {
        let estimate = MaintenanceEstimateCalculator.estimate(
            Fixtures.input(
                foodLoggedDays: 10,
                weightEntryCount: 3,
                totalDays: 14,
                averageDailyCalories: 2_000,
                startingWeightKg: 80,
                endingWeightKg: 79,
                hasSuddenSpike: true,
                staticTDEE: nil
            )
        )

        XCTAssertTrue(estimate.shouldShowWaterWeightDisclaimer)
        XCTAssertTrue(
            estimate.caveats.contains(FormaProductCopy.WeightSpikeEducation.holdSteadyNote)
        )
        XCTAssertTrue(estimate.sufficiency.reasons.contains(.weightTrendTooNoisy))
    }

    func testStaticTDEEBlendForMediumConfidenceIfImplemented() {
        let estimate = MaintenanceEstimateCalculator.estimate(
            Fixtures.input(
                foodLoggedDays: 10,
                weightEntryCount: 3,
                totalDays: 14,
                averageDailyCalories: 2_000,
                startingWeightKg: 80,
                endingWeightKg: 79,
                staticTDEE: 2_400
            )
        )

        XCTAssertEqual(estimate.method, .conservativeBlend)
        XCTAssertEqual(estimate.staticTDEEKcal, 2_400)
        XCTAssertTrue(
            estimate.caveats.contains {
                $0.contains("blends your real-world trend")
            }
        )
    }

    func testMissingStaticTDEEDoesNotCrash() {
        let estimate = MaintenanceEstimateCalculator.estimate(
            Fixtures.input(
                foodLoggedDays: 10,
                weightEntryCount: 3,
                totalDays: 14,
                averageDailyCalories: 2_000,
                startingWeightKg: 80,
                endingWeightKg: 79,
                staticTDEE: nil
            )
        )

        XCTAssertEqual(estimate.confidence, .medium)
        XCTAssertEqual(estimate.method, .learnedEnergyBalance)
        XCTAssertEqual(estimate.estimatedMaintenanceKcal, 2_550)
        XCTAssertNil(estimate.staticTDEEKcal)
    }

    // MARK: - Cutting trend direction

    func testCuttingTrendDirectionLosingAboutExpected() {
        let estimate = MaintenanceEstimateCalculator.estimate(
            Fixtures.cuttingTrendInput(weeklyWeightChangeKg: -0.5)
        )

        XCTAssertEqual(estimate.trendDirection, .losingAboutAsExpected)
    }

    func testCuttingTrendDirectionLosingTooFast() {
        let estimate = MaintenanceEstimateCalculator.estimate(
            Fixtures.cuttingTrendInput(weeklyWeightChangeKg: -1.0)
        )

        XCTAssertEqual(estimate.trendDirection, .losingFasterThanExpected)
    }

    func testCuttingTrendDirectionLosingTooSlow() {
        let estimate = MaintenanceEstimateCalculator.estimate(
            Fixtures.cuttingTrendInput(weeklyWeightChangeKg: -0.1)
        )

        XCTAssertEqual(estimate.trendDirection, .losingSlowerThanExpected)
    }
}

// MARK: - Fixtures

private enum Fixtures {

  static func input(
        foodLoggedDays: Int,
        weightEntryCount: Int,
        totalDays: Int,
        averageDailyCalories: Double? = nil,
        startingWeightKg: Double? = nil,
        endingWeightKg: Double? = nil,
        currentSevenDayAverageKg: Double? = nil,
        previousSevenDayAverageKg: Double? = nil,
        staticTDEE: Double? = 2_400,
        calorieTarget: Double? = 1_800,
        goalWeightKg: Double? = 70,
        currentWeightKg: Double? = 80,
        hasSuddenSpike: Bool = false
    ) -> MaintenanceEstimateInput {
        let calendar = gregorianCalendar
        let endDate = calendar.date(from: DateComponents(year: 2026, month: 6, day: 28, hour: 12))!
        let startDate = calendar.date(
            byAdding: .day,
            value: -(totalDays - 1),
            to: endDate,
            wrappingComponents: false
        )!

        return MaintenanceEstimateInput(
            startDate: startDate,
            endDate: endDate,
            averageDailyCalories: averageDailyCalories,
            foodLoggedDays: foodLoggedDays,
            totalDays: totalDays,
            calendarSpanDays: nil,
            startingWeightKg: startingWeightKg,
            endingWeightKg: endingWeightKg,
            currentSevenDayAverageKg: currentSevenDayAverageKg,
            previousSevenDayAverageKg: previousSevenDayAverageKg,
            weightEntryCount: weightEntryCount,
            staticTDEE: staticTDEE,
            calorieTarget: calorieTarget,
            goalWeightKg: goalWeightKg,
            currentWeightKg: currentWeightKg,
            hasSuddenSpike: hasSuddenSpike
        )
    }

    static func cuttingTrendInput(weeklyWeightChangeKg: Double) -> MaintenanceEstimateInput {
        let previousAverage = 80.0
        let currentAverage = previousAverage + weeklyWeightChangeKg

        return input(
            foodLoggedDays: 10,
            weightEntryCount: 4,
            totalDays: 14,
            averageDailyCalories: 2_000,
            startingWeightKg: 80,
            endingWeightKg: currentAverage,
            currentSevenDayAverageKg: currentAverage,
            previousSevenDayAverageKg: previousAverage,
            staticTDEE: nil,
            goalWeightKg: 70,
            currentWeightKg: 80
        )
    }

    private static var gregorianCalendar: Calendar {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(secondsFromGMT: 0)!
        return calendar
    }
}
