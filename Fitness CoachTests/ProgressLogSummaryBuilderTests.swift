//
//  ProgressLogSummaryBuilderTests.swift
//  Fitness CoachTests
//

import XCTest
@testable import Fitness_Coach

final class ProgressLogSummaryBuilderTests: XCTestCase {

    func testNutritionSummaryEmptyLogsReturnsZeros() {
        let summary = JourneyLogSummaryBuilder.nutritionSummary(from: [])

        XCTAssertEqual(summary.loggedDays, 0)
        XCTAssertNil(summary.averageCalories)
        XCTAssertNil(summary.averageProtein)
        XCTAssertNil(summary.averageFiber)
    }

    func testNutritionSummaryAveragesMacrosAcrossDays() {
        let logs = [
            makeLog(calories: 1_800, protein: 120, carbs: 180, fat: 50, fiber: 20),
            makeLog(calories: 2_200, protein: 140, carbs: 220, fat: 70, fiber: 30)
        ]

        let summary = JourneyLogSummaryBuilder.nutritionSummary(from: logs)

        XCTAssertEqual(summary.loggedDays, 2)
        XCTAssertEqual(summary.averageCalories, 2_000)
        XCTAssertEqual(summary.averageProtein, 130.0 as Double?)
        XCTAssertEqual(summary.averageCarbs, 200.0 as Double?)
        XCTAssertEqual(summary.averageFat, 60.0 as Double?)
        XCTAssertEqual(summary.averageFiber, 25.0 as Double?)
    }

    func testWaterSummaryEmptyLogsReturnsZeros() {
        let summary = JourneyLogSummaryBuilder.waterSummary(from: [])

        XCTAssertEqual(summary.loggedDays, 0)
        XCTAssertNil(summary.averageWaterMl)
        XCTAssertNil(summary.consistencyPercent)
    }

    func testWaterSummaryComputesAveragesAndConsistency() {
        let logs = [
            makeLog(waterMl: 2_000, waterTargetMl: 2_500),
            makeLog(waterMl: 2_100, waterTargetMl: 2_500),
            makeLog(waterMl: 500, waterTargetMl: 2_500)
        ]

        let summary = JourneyLogSummaryBuilder.waterSummary(from: logs)

        XCTAssertEqual(summary.loggedDays, 3)
        XCTAssertEqual(summary.averageWaterMl, 1_533)
        XCTAssertEqual(summary.averageWaterTargetMl, 2_500)
        XCTAssertEqual(summary.consistencyPercent ?? -1, 2.0 / 3.0, accuracy: 0.001)
    }

    func testWaterSummarySkipsConsistencyWhenNoTargets() {
        let logs = [makeLog(waterMl: 1_000, waterTargetMl: 0)]

        let summary = JourneyLogSummaryBuilder.waterSummary(from: logs)

        XCTAssertEqual(summary.loggedDays, 1)
        XCTAssertEqual(summary.averageWaterMl, 1_000)
        XCTAssertNil(summary.consistencyPercent)
    }

    private func makeLog(
        calories: Int = 0,
        protein: Double = 0,
        carbs: Double = 0,
        fat: Double = 0,
        fiber: Double? = nil,
        waterMl: Int = 0,
        waterTargetMl: Int = 2_500
    ) -> DailyLog {
        DailyLog(
            id: UUID(),
            date: Date(),
            weightKg: nil,
            targets: UserTargets(
                calorieTarget: 2_000,
                proteinTarget: 150,
                carbTarget: 200,
                fatTarget: 60,
                waterTargetMl: waterTargetMl,
                expectedWeeklyWeightLossKg: 0.5,
                aggressiveness: .moderate
            ),
            totals: MacroTotals(
                calories: calories,
                protein: protein,
                carbs: carbs,
                fat: fat,
                fiber: fiber,
                sodium: nil
            ),
            waterConsumedMl: waterMl,
            steps: nil,
            workoutCaloriesBurned: 0,
            dailyReviewId: nil,
            createdAt: Date(),
            updatedAt: Date()
        )
    }
}
