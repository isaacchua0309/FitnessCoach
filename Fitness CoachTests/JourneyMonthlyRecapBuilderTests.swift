//
//  JourneyMonthlyRecapBuilderTests.swift
//  Fitness CoachTests
//

import XCTest
@testable import Fitness_Coach

final class JourneyMonthlyRecapBuilderTests: XCTestCase {

    private var calendar: Calendar = {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(secondsFromGMT: 0)!
        return calendar
    }()

    // Wednesday, 15 Nov 2023
    private let asOf = Date(timeIntervalSince1970: 1_700_044_800)

    func testFullMonthData() {
        let logs = (0..<15).map { offset in
            makeLog(
                daysAgo: offset,
                calories: offset < 12 ? 1_900 : 2_600,
                protein: 140,
                waterMl: offset < 13 ? 2_500 : 500
            )
        }
        let weights = [
            makeWeight(daysAgo: 14, kg: 90),
            makeWeight(daysAgo: 0, kg: 87.6)
        ]

        let state = build(
            monthLogs: logs,
            maturityLogs: logs,
            allWeights: weights,
            monthHealthWorkoutCount: 13,
            isAppleHealthConnected: true
        )

        XCTAssertTrue(state.isComplete)
        XCTAssertNil(state.buildingMessage)
        XCTAssertEqual(state.loggedDays, 15)
        XCTAssertEqual(state.monthWeightDeltaKg, -2.4, accuracy: 0.01)
        XCTAssertEqual(state.proteinAdherencePercent, 1.0, accuracy: 0.01)
        XCTAssertEqual(state.trainingSessions, 13)
        XCTAssertTrue(state.showsTrainingRow)
        XCTAssertTrue(state.summaryCopy.contains("15 days"))
        XCTAssertEqual(state.bestHabitCopy, FormaProductCopy.Journey.MonthlyRecap.bestHabit(for: .protein))

        XCTAssertEqual(state.rows.first { $0.id == "weight" }?.value, "↓ 2.4kg")
        XCTAssertEqual(state.rows.first { $0.id == "calories" }?.value, "80% adherence")
        XCTAssertEqual(state.rows.first { $0.id == "protein" }?.value, "100%")
        XCTAssertEqual(state.rows.first { $0.id == "training" }?.value, "13 sessions")
    }

    func testPartialCurrentMonthShowsBuildingState() {
        let logs = (0..<2).map { makeLog(daysAgo: $0, calories: 1_800, protein: 120, waterMl: 2_000) }

        let state = build(monthLogs: logs, maturityLogs: logs)

        XCTAssertFalse(state.isComplete)
        XCTAssertEqual(state.buildingMessage, FormaProductCopy.Journey.MonthlyRecap.buildingBody)
        XCTAssertEqual(state.loggedDays, 2)
        XCTAssertEqual(state.rows.first { $0.id == "logged-days" }?.value, "2 days")
        XCTAssertNotNil(state.rows.first { $0.id == "protein" })
        XCTAssertNil(state.bestHabitCopy)
        XCTAssertFalse(state.rows.contains { $0.id == "weight" })
    }

    func testNoLogsShowsOnlyBuildingMessage() {
        let state = build(monthLogs: [], maturityLogs: [])

        XCTAssertFalse(state.isComplete)
        XCTAssertEqual(state.buildingMessage, FormaProductCopy.Journey.MonthlyRecap.buildingBody)
        XCTAssertEqual(state.loggedDays, 0)
        XCTAssertTrue(state.summaryCopy.isEmpty)
        XCTAssertTrue(state.rows.isEmpty)
    }

    func testHealthDisconnectedOmitsTrainingRow() {
        let logs = (0..<5).map { makeLog(daysAgo: $0, calories: 1_800, protein: 140, waterMl: 2_000) }

        let disconnected = build(
            monthLogs: logs,
            maturityLogs: logs,
            monthHealthWorkoutCount: 8,
            isAppleHealthConnected: false
        )
        let connected = build(
            monthLogs: logs,
            maturityLogs: logs,
            monthHealthWorkoutCount: 8,
            isAppleHealthConnected: true
        )

        XCTAssertFalse(disconnected.showsTrainingRow)
        XCTAssertNil(disconnected.trainingSessions)
        XCTAssertNil(disconnected.rows.first { $0.id == "training" })

        XCTAssertTrue(connected.showsTrainingRow)
        XCTAssertEqual(connected.rows.first { $0.id == "training" }?.value, "8 sessions")
    }

    func testLoseGoalWeightDeltaFormatting() {
        let logs = (0..<4).map { makeLog(daysAgo: $0, calories: 1_800, protein: 80) }
        let weights = [
            makeWeight(daysAgo: 10, kg: 88),
            makeWeight(daysAgo: 1, kg: 86.5)
        ]

        let state = build(
            monthLogs: logs,
            maturityLogs: logs,
            allWeights: weights,
            goalDirection: .lose
        )

        XCTAssertEqual(state.rows.first { $0.id == "weight" }?.value, "↓ 1.5kg")
    }

    func testGainGoalWeightDeltaFormatting() {
        let logs = (0..<4).map { makeLog(daysAgo: $0, calories: 2_200, protein: 80) }
        let weights = [
            makeWeight(daysAgo: 10, kg: 60),
            makeWeight(daysAgo: 1, kg: 61.8)
        ]

        let state = build(
            monthLogs: logs,
            maturityLogs: logs,
            allWeights: weights,
            goalDirection: .gain
        )

        XCTAssertEqual(state.rows.first { $0.id == "weight" }?.value, "↑ 1.8kg")
    }

    func testMaintainGoalWeightDeltaFormatting() {
        let logs = (0..<4).map { makeLog(daysAgo: $0, calories: 2_000, protein: 80) }
        let weights = [
            makeWeight(daysAgo: 10, kg: 75),
            makeWeight(daysAgo: 1, kg: 75.3)
        ]

        let state = build(
            monthLogs: logs,
            maturityLogs: logs,
            allWeights: weights,
            goalDirection: .maintain
        )

        XCTAssertEqual(state.rows.first { $0.id == "weight" }?.value, "±0.3kg")
    }

    func testPercentageFormattingRoundsCorrectly() {
        let logs = [
            makeLog(daysAgo: 0, calories: 1_800, protein: 140, waterMl: 2_500),
            makeLog(daysAgo: 1, calories: 2_500, protein: 60, waterMl: 500),
            makeLog(daysAgo: 2, calories: 1_950, protein: 130, waterMl: 2_400)
        ]

        let state = build(monthLogs: logs, maturityLogs: logs)

        XCTAssertEqual(state.proteinAdherencePercent, 2.0 / 3.0, accuracy: 0.01)
        XCTAssertEqual(state.rows.first { $0.id == "protein" }?.value, "67%")
        XCTAssertEqual(state.rows.first { $0.id == "water" }?.value, "67%")
    }

    func testSectionTitleUsesMonthNameSummary() {
        let logs = (0..<4).map { makeLog(daysAgo: $0, calories: 1_800, protein: 80) }
        let state = build(monthLogs: logs, maturityLogs: logs)

        XCTAssertEqual(
            state.sectionTitle,
            FormaProductCopy.Journey.MonthlyRecap.sectionTitle(monthName: "November")
        )
    }

    // MARK: - Helpers

    private func build(
        monthLogs: [DailyLog],
        maturityLogs: [DailyLog],
        allWeights: [WeightEntry] = [],
        monthHealthWorkoutCount: Int = 0,
        goalDirection: JourneyGoalDirection = .lose,
        isAppleHealthConnected: Bool = false,
        expectedTrainingDaysPerWeek: Int = 3
    ) -> JourneyMonthlyRecapState {
        JourneyMonthlyRecapBuilder.build(
            JourneyMonthlyRecapBuilder.Input(
                monthLogs: monthLogs,
                maturityLogs: maturityLogs,
                allWeights: allWeights,
                healthWorkoutDayStarts: [],
                monthHealthWorkoutCount: monthHealthWorkoutCount,
                goalDirection: goalDirection,
                isAppleHealthConnected: isAppleHealthConnected,
                expectedTrainingDaysPerWeek: expectedTrainingDaysPerWeek,
                asOf: asOf,
                calendar: calendar
            )
        )
    }

    private func makeLog(
        daysAgo: Int,
        calories: Double,
        protein: Double,
        waterMl: Int
    ) -> DailyLog {
        let date = calendar.date(byAdding: .day, value: -daysAgo, to: asOf)!
        return DailyLog(
            id: UUID(),
            date: date,
            weightKg: nil,
            targets: UserTargets(
                calorieTarget: 2_000,
                proteinTarget: 120,
                carbTarget: 200,
                fatTarget: 60,
                waterTargetMl: 2_000,
                expectedWeeklyWeightLossKg: 0.5,
                aggressiveness: .moderate
            ),
            totals: MacroTotals(calories: calories, protein: protein, carbs: 100, fat: 40),
            waterConsumedMl: waterMl,
            steps: nil,
            workoutCaloriesBurned: 0,
            dailyReviewId: nil,
            createdAt: date,
            updatedAt: date
        )
    }

    private func makeWeight(daysAgo: Int, kg: Double) -> WeightEntry {
        let date = calendar.date(byAdding: .day, value: -daysAgo, to: asOf)!
        return WeightEntry(
            id: UUID(),
            date: date,
            weightKg: kg,
            note: nil,
            createdAt: date
        )
    }
}
